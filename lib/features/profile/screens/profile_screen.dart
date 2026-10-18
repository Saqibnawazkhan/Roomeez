import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/models.dart';
import '../../auth/widgets/sample_user_sheet.dart';

/// "0.9.0 (2)", or null where the platform can't tell (e.g. in tests).
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, AppUser user) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _ProfileDialog(user: user),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).updateProfile(name: result.$1, phone: result.$2);
      if (context.mounted) showAppSnack(context, 'Profile updated');
    } catch (error) {
      if (context.mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You can sign in again with this email or a different one.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (context.mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message:
          '• You will leave all your groups. If you manage one, the next member becomes the manager.\n'
          '• Your email and mobile number are removed, and you are signed out.\n'
          '• Expenses you added stay in the groups, so everyone\'s balances stay correct.\n\n'
          'This can\'t be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Your account was deleted')));
    } catch (error) {
      if (context.mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final muted = context.text.bodyLarge?.copyWith(color: context.appColors.muted);
    return Scaffold(
      appBar: NeuHeader(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: MemberAvatar(name: user.name, size: 84)),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
          ),
          if (user.email != null) Text(user.email!, textAlign: TextAlign.center, style: muted),
          if (user.phone != null) Text(PhoneNumber.format(user.phone!), textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 10),
          _AccountRow(
            icon: Icons.edit_rounded,
            hue: NeuHues.teal,
            title: 'Edit name and mobile',
            subtitle: 'How others see you in groups',
            onTap: () => _edit(context, ref, user),
          ),
          if (ref.watch(prototypeToolsProvider) != null)
            _AccountRow(
              icon: Icons.swap_horiz_rounded,
              hue: NeuHues.indigo,
              title: 'Switch demo user',
              subtitle: 'Try the app as someone else',
              onTap: () => showSampleUserSheet(context, ref),
            ),
          const NeuSectionLabel('Help'),
          _AccountRow(
            icon: Icons.chat_rounded,
            hue: NeuHues.sky,
            title: 'Send feedback',
            subtitle: 'Report a problem or share an idea',
            onTap: () => SharePlus.instance.share(
              ShareParams(
                subject: 'Roomeez feedback',
                text: 'Roomeez ${ref.read(appVersionProvider).value ?? ''} feedback:\n\n',
              ),
            ),
          ),
          const NeuSectionLabel('Sign-in'),
          _AccountRow(
            icon: Icons.logout_rounded,
            hue: NeuHues.amber,
            title: 'Sign out',
            subtitle: 'To use a different email or Google account',
            onTap: () => _signOut(context, ref),
          ),
          _AccountRow(
            icon: Icons.delete_forever_rounded,
            hue: context.appColors.negative,
            title: 'Delete account',
            titleColor: context.appColors.negative,
            subtitle: 'Remove your account and personal details',
            onTap: () => _deleteAccount(context, ref),
          ),
          if (ref.watch(appVersionProvider).value case final version?)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                'Roomeez $version',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.appColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row on the account screen: colored icon, title, subtitle, chevron.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.hue,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: NeuPressable(
        onTap: onTap,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            NeuIconDisc(icon: icon, color: hue, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: titleColor ?? palette.text),
                  ),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.user});

  final AppUser user;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.user.name);
  late final TextEditingController _phone = TextEditingController(
    text: widget.user.phone == null ? '' : PhoneNumber.format(widget.user.phone!),
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuTextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 12),
            NeuTextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
              decoration: const InputDecoration(labelText: 'Mobile number (optional)', hintText: '0300 1234567'),
              validator: PhoneNumber.optionalFieldError,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((_name.text, PhoneNumber.normalizeOptional(_phone.text)));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
