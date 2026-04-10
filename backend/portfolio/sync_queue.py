"""
In-process sync task queue with a single dedicated thread.

Banking libraries are not thread-safe, so all sync operations run
sequentially on one background thread. This frees the main gunicorn
thread to serve other requests (graphs, snapshots, etc.) while sync
is in progress.

Usage:
    task_id = sync_queue.enqueue(user_id, callable, *args, **kwargs)
    status  = sync_queue.get_status(task_id)
"""

import logging
import queue
import threading
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable

logger = logging.getLogger(__name__)


class TaskStatus(str, Enum):
    PENDING = 'pending'
    RUNNING = 'running'
    COMPLETED = 'completed'
    FAILED = 'failed'


@dataclass
class SyncTask:
    id: str
    user_id: int
    status: TaskStatus = TaskStatus.PENDING
    result: Any = None
    error: str | None = None
    created_at: datetime = field(default_factory=datetime.now)
    started_at: datetime | None = None
    completed_at: datetime | None = None


class SyncQueue:
    """Single-threaded task queue for sync operations."""

    # Keep results for 10 minutes before cleanup
    RESULT_TTL_SECONDS = 600

    def __init__(self):
        self._queue: queue.Queue[SyncTask] = queue.Queue()
        self._tasks: dict[str, SyncTask] = {}
        self._lock = threading.Lock()
        self._worker: threading.Thread | None = None
        self._started = False

    def _ensure_worker(self):
        """Start the worker thread on first use (lazy init)."""
        if self._started:
            return
        with self._lock:
            if self._started:
                return
            self._worker = threading.Thread(
                target=self._run_worker,
                name='sync-worker',
                daemon=True,
            )
            self._worker.start()
            self._started = True
            logger.info('Sync worker thread started')

    def _run_worker(self):
        """Process tasks sequentially, one at a time."""
        while True:
            task = self._queue.get()
            try:
                task.status = TaskStatus.RUNNING
                task.started_at = datetime.now()
                logger.info('Sync task %s started for user %s', task.id, task.user_id)

                result = task._callable(*task._args, **task._kwargs)

                task.status = TaskStatus.COMPLETED
                task.result = result
                task.completed_at = datetime.now()
                logger.info('Sync task %s completed', task.id)

            except Exception as e:
                task.status = TaskStatus.FAILED
                task.error = str(e) or repr(e)
                task.completed_at = datetime.now()
                logger.exception('Sync task %s failed', task.id)

            finally:
                self._queue.task_done()
                self._cleanup_old_tasks()

    def enqueue(self, user_id: int, fn: Callable, *args, **kwargs) -> str:
        """Enqueue a sync operation. Returns a task ID for status polling."""
        self._ensure_worker()

        task_id = uuid.uuid4().hex[:12]
        task = SyncTask(id=task_id, user_id=user_id)
        # Store callable privately (not part of the dataclass fields)
        task._callable = fn
        task._args = args
        task._kwargs = kwargs

        with self._lock:
            self._tasks[task_id] = task

        self._queue.put(task)
        logger.info('Sync task %s enqueued for user %s', task_id, user_id)
        return task_id

    def get_status(self, task_id: str) -> dict | None:
        """Get the current status of a task."""
        with self._lock:
            task = self._tasks.get(task_id)

        if task is None:
            return None

        result = {
            'task_id': task.id,
            'status': task.status.value,
            'created_at': task.created_at.isoformat(),
        }

        if task.started_at:
            result['started_at'] = task.started_at.isoformat()
        if task.completed_at:
            result['completed_at'] = task.completed_at.isoformat()
        if task.status == TaskStatus.COMPLETED:
            result['result'] = task.result
        if task.status == TaskStatus.FAILED:
            result['error'] = task.error

        return result

    def has_pending_task(self, user_id: int) -> str | None:
        """Check if a user already has a pending/running sync task.
        Returns the task_id if found, None otherwise."""
        with self._lock:
            for task in self._tasks.values():
                if (task.user_id == user_id and
                        task.status in (TaskStatus.PENDING, TaskStatus.RUNNING)):
                    return task.id
        return None

    def _cleanup_old_tasks(self):
        """Remove completed/failed tasks older than TTL."""
        now = datetime.now()
        with self._lock:
            expired = [
                tid for tid, task in self._tasks.items()
                if task.completed_at and
                (now - task.completed_at).total_seconds() > self.RESULT_TTL_SECONDS
            ]
            for tid in expired:
                del self._tasks[tid]


# Module-level singleton
sync_queue = SyncQueue()
