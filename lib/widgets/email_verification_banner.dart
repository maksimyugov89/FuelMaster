import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/services/email_verification_service.dart';

/// Напоминание подтвердить e-mail (F-2).
///
/// Подтверждение не блокирует учёт топлива: он ведётся локально. Поэтому это
/// напоминание с двумя действиями — отправить письмо ещё раз и перепроверить
/// статус, — а не экран, через который нельзя пройти.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _busy = false;
  int _cooldownLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCooldown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCooldown() async {
    final int left = await EmailVerificationService.secondsUntilResend();
    if (!mounted) return;
    setState(() => _cooldownLeft = left);
    _timer?.cancel();
    if (left <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownLeft = _cooldownLeft > 0 ? _cooldownLeft - 1 : 0;
      });
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await EmailVerificationService.send();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case VerificationSendResult.sent:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.email_verify_sent(EmailVerificationService.email ?? ''),
            ),
          ),
        );
      case VerificationSendResult.cooldown:
        await _refreshCooldown();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.email_verify_cooldown(_cooldownLeft))),
        );
      case VerificationSendResult.noUser:
        break;
      case VerificationSendResult.error:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.email_verify_error)),
        );
    }
    await _refreshCooldown();
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final bool verified = await EmailVerificationService.refresh();
    if (!mounted) return;
    setState(() => _busy = false);

    if (verified) {
      context.read<AppSettingsProvider>().setEmailVerified(true);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.email_verify_ok)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.email_verify_not_yet)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final String email = EmailVerificationService.email ?? '';

    return Card(
      elevation: 4.0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.email_verify_banner_title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.email_verify_banner_text(email),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: (_busy || _cooldownLeft > 0) ? null : _resend,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                    _cooldownLeft > 0
                        ? l10n.email_verify_cooldown(_cooldownLeft)
                        : l10n.email_verify_resend,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    l10n.email_verify_check,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
