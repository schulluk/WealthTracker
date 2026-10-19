import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for a broker's one-time code and finishes the sync.
///
/// Some brokers cannot sync unattended: Swisscard sends an SMS the moment the
/// password is accepted, and the sync only completes once that code is
/// entered. The account stays in `pending_auth` until then, so the prompt has
/// to appear right after the sync reports the challenge.
class TwoFactorPrompt extends StatefulWidget {
  final String accountName;

  /// 'sms', 'totp', 'tan' — decides the wording.
  final String twoFaType;

  /// What the broker said, e.g. which masked number the code went to.
  final String? challenge;

  /// Submits the code; returns an error message, or null on success.
  final Future<String?> Function(String code) onSubmit;

  const TwoFactorPrompt({
    super.key,
    required this.accountName,
    required this.twoFaType,
    required this.onSubmit,
    this.challenge,
  });

  @override
  State<TwoFactorPrompt> createState() => _TwoFactorPromptState();
}

class _TwoFactorPromptState extends State<TwoFactorPrompt> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _explanation {
    if (widget.challenge != null && widget.challenge!.isNotEmpty) {
      return widget.challenge!;
    }
    switch (widget.twoFaType) {
      case 'sms':
        return 'Enter the code the bank just sent you by SMS.';
      case 'totp':
        return 'Enter the current code from your authenticator app.';
      default:
        return 'Enter the code your bank asked for.';
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Code for ${widget.accountName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_explanation),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            // Lets iOS offer the code straight from the SMS.
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Code',
              hintText: '123456',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        // The same muted tone the disabled label gets.
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Checking…'),
                  ],
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
