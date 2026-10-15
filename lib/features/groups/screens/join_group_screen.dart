import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/services/group_code_generator.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  GroupPreview? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name.text = user?.name ?? '';
    _phone.text = user == null ? '' : PhoneNumber.format(user.phone);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (!GroupCodeFormat.isValid(_code.text)) {
      showAppSnack(context, 'Group codes are 6 to 8 letters or numbers.', isError: true);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final preview = await ref.read(groupRepositoryProvider).findGroupByCode(code: _code.text, userId: user.id);
      if (!mounted) return;
      if (preview.isAlreadyMember) {
        context.pushReplacement(Routes.group(preview.groupId));
        return;
      }
      if (preview.pendingRequestId != null) {
        context.pushReplacement(Routes.joinStatus(preview.pendingRequestId!));
        return;
      }
      setState(() => _preview = preview);
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    final user = ref.read(currentUserProvider);
    final phone = PhoneNumber.normalize(_phone.text);
    if (user == null) return;
    if (_name.text.trim().length < 2 || phone == null) {
      showAppSnack(context, 'Enter your name and a valid mobile number.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final request = await ref
          .read(groupRepositoryProvider)
          .requestToJoin(userId: user.id, code: _code.text, name: _name.text, phone: phone);
      if (!mounted) return;
      context.pushReplacement(Routes.joinStatus(request.id));
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Join group')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Ask a member for the group code.',
            style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: preview == null,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
              ),
            ],
            style: context.text.titleLarge?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Group code', hintText: 'e.g. RMZ4B7', counterText: ''),
            onSubmitted: (_) => _find(),
          ),
          const SizedBox(height: 16),
          if (preview == null)
            BusyButton(label: 'Find group', busy: _busy, onPressed: _find)
          else ...[
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_work_outlined, color: context.colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preview.name, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '${preview.activeMemberCount} members',
                          style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => setState(() => _preview = null), child: const Text('Change')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const InfoBanner(icon: Icons.lock_outline, message: 'A member will need to approve you.'),
            const SectionHeader('Your details'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone)),
            ),
            const SizedBox(height: 20),
            BusyButton(label: 'Send join request', busy: _busy, onPressed: _request),
          ],
        ],
      ),
    );
  }
}
