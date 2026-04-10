from django.urls import path

from . import views

urlpatterns = [
    # Financial accounts
    path('accounts/', views.FinancialAccountListCreateView.as_view(), name='account_list'),
    path('accounts/sync/', views.SyncAllAccountsView.as_view(), name='sync_all_accounts'),
    path('accounts/sync/<str:task_id>/', views.SyncTaskStatusView.as_view(), name='sync_task_status'),
    path('accounts/<int:pk>/', views.FinancialAccountDetailView.as_view(), name='account_detail'),
    path('accounts/<int:pk>/sync/', views.AccountSyncView.as_view(), name='account_sync'),
    path('accounts/<int:pk>/auth/', views.AccountAuthView.as_view(), name='account_auth'),
    path('accounts/<int:pk>/credentials/', views.AccountCredentialsView.as_view(), name='account_credentials'),
    # Snapshots
    path('accounts/<int:account_id>/snapshots/', views.AccountSnapshotListCreateView.as_view(), name='snapshot_list'),
    path('snapshots/<int:pk>/', views.AccountSnapshotDetailView.as_view(), name='snapshot_detail'),
    # Account bulk create (discover is in brokers/urls.py to avoid <str:code> catch-all)
    path('accounts/bulk/', views.BulkAccountCreateView.as_view(), name='account_bulk_create'),
    # CSV import
    path('import/csv/', views.CSVImportView.as_view(), name='csv_import'),
    # Wealth dashboard
    path('wealth/summary/', views.WealthSummaryView.as_view(), name='wealth_summary'),
    path('wealth/history/', views.WealthHistoryView.as_view(), name='wealth_history'),
    path('wealth/breakdown/', views.WealthBreakdownView.as_view(), name='wealth_breakdown'),
]
