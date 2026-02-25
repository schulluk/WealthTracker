import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../providers/accounts_provider.dart';

class AddSnapshotDialog extends ConsumerStatefulWidget {
  final Account account;
  final VoidCallback onSaved;

  const AddSnapshotDialog({
    super.key,
    required this.account,
    required this.onSaved,
  });

  @override
  ConsumerState<AddSnapshotDialog> createState() => _AddSnapshotDialogState();
}

class _AddSnapshotDialogState extends ConsumerState<AddSnapshotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _balanceController;
  late final FocusNode _balanceFocusNode;
  late String _currency;
  late DateTime _date;
  bool _loading = false;
  String? _error;

  static const _currencies = ['EUR', 'USD', 'CHF', 'GBP'];

  @override
  void initState() {
    super.initState();
    final rawBalance = widget.account.latestSnapshot?.balance;
    final prefill = rawBalance != null
        ? (double.tryParse(rawBalance)?.toStringAsFixed(2) ?? rawBalance)
        : '';
    _balanceController = TextEditingController(text: prefill);
    _balanceFocusNode = FocusNode();
    _balanceFocusNode.addListener(() {
      if (_balanceFocusNode.hasFocus && _balanceController.text.isNotEmpty) {
        _balanceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _balanceController.text.length,
        );
      }
    });
    _currency = widget.account.currency;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(accountRepositoryProvider);
      await repository.addSnapshot(
        accountId: widget.account.id,
        balance: double.parse(_balanceController.text),
        currency: _currency,
        snapshotDate: _date,
      );

      widget.onSaved();
    } catch (e) {
      // Silently handle duplicate snapshots (already exists for this date)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('already exists') ||
          errorStr.contains('duplicate') ||
          errorStr.contains('unique')) {
        // Just close the dialog without error
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Snapshot - ${widget.account.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _balanceController,
                focusNode: _balanceFocusNode,
                decoration: InputDecoration(
                  labelText: 'Balance',
                  prefixText: '$_currency ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a balance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Currency',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _currencies.map((c) {
                  return FilterChip(
                    label: Text(c),
                    selected: _currency == c,
                    onSelected: (_) {
                      setState(() {
                        _currency = c;
                      });
                    },
                    showCheckmark: false,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
