import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../providers/accounts_provider.dart';

class QuickSnapshotSheet extends ConsumerStatefulWidget {
  final List<Account> accounts;
  final VoidCallback onDismiss;
  final VoidCallback onSnapshotsAdded;

  const QuickSnapshotSheet({
    super.key,
    required this.accounts,
    required this.onDismiss,
    required this.onSnapshotsAdded,
  });

  @override
  ConsumerState<QuickSnapshotSheet> createState() => _QuickSnapshotSheetState();
}

class _QuickSnapshotSheetState extends ConsumerState<QuickSnapshotSheet>
    with SingleTickerProviderStateMixin {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, GlobalKey> _cardKeys = {};
  final Set<int> _submitting = {};
  final Set<int> _completed = {};
  final Map<int, String> _errors = {};
  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey<SliverAnimatedListState>();
  late List<Account> _visibleAccounts;

  @override
  void initState() {
    super.initState();
    _visibleAccounts = List.from(widget.accounts);
    for (final account in widget.accounts) {
      final controller = TextEditingController(
        text: account.latestSnapshot?.balance ?? '',
      );
      _controllers[account.id] = controller;

      final cardKey = GlobalKey();
      _cardKeys[account.id] = cardKey;

      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          if (controller.text.isNotEmpty) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
          // Scroll to keep the focused field visible above the keyboard
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = cardKey.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                alignment: 0.5,
                duration: const Duration(milliseconds: 300),
              );
            }
          });
        }
      });
      _focusNodes[account.id] = focusNode;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _buildAccountCard(
    Account account,
    Animation<double> animation, {
    bool isRemoving = false,
  }) {
    final isSubmitting = _submitting.contains(account.id);
    final error = _errors[account.id];

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Card(
          key: isRemoving ? null : _cardKeys[account.id],
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  account.broker.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[account.id],
                        focusNode: _focusNodes[account.id],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Balance (${account.currency})',
                          isDense: true,
                          errorText: error,
                        ),
                        enabled: !isRemoving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: isSubmitting || isRemoving
                          ? null
                          : () => _submitSnapshot(account),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSnapshot(Account account) async {
    final balanceText = _controllers[account.id]?.text ?? '';
    final balance = double.tryParse(balanceText);
    if (balance == null) {
      setState(() {
        _errors[account.id] = 'Please enter a valid number';
      });
      return;
    }

    setState(() {
      _submitting.add(account.id);
      _errors.remove(account.id);
    });

    try {
      final repository = ref.read(accountRepositoryProvider);
      await repository.addSnapshot(
        accountId: account.id,
        balance: balance,
        currency: account.currency,
        snapshotDate: DateTime.now(),
      );

      _submitting.remove(account.id);
      _completed.add(account.id);

      // Animate removal of the card
      final index = _visibleAccounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        final removedAccount = _visibleAccounts.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildAccountCard(
            removedAccount,
            animation,
            isRemoving: true,
          ),
          duration: const Duration(milliseconds: 300),
        );
      }

      // Refresh the accounts provider so the banner updates
      ref.invalidate(accountsProvider);

      // Check if all done
      if (_visibleAccounts.isEmpty) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _submitting.remove(account.id);
        _errors[account.id] = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quick Balance Update',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: widget.onDismiss,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update today\'s balances for your manual accounts',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Account list or completion state
            if (_visibleAccounts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All done!',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: widget.onSnapshotsAdded,
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                sliver: SliverAnimatedList(
                  key: _listKey,
                  initialItemCount: _visibleAccounts.length,
                  itemBuilder: (context, index, animation) {
                    if (index >= _visibleAccounts.length) {
                      return const SizedBox.shrink();
                    }
                    final account = _visibleAccounts[index];
                    return _buildAccountCard(account, animation);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
