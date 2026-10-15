import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../group_providers.dart';

class JoinStatusScreen extends ConsumerStatefulWidget {
  const JoinStatusScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<JoinStatusScreen> createState() => _JoinStatusScreenState();
}

class _JoinStatusScreenState extends ConsumerState<JoinStatusScreen> {
  bool _busy = false;

  Future<void> _simulateApproval() async {
    setState(() => _busy = true);
    try {
      final tools = ref.read(prototypeToolsProvider);
      if (tools == null) return;
      final approver = await tools.simulateApprovalByMember(widget.requestId);
      if (mounted) showAppSnack(context, 'Approved by $approver (simulated)');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(myJoinRequestsProvider);
    JoinRequest? request;
    for (final r in requests.value ?? const <JoinRequest>[]) {
      if (r.id == widget.requestId) request = r;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Join request')),
      body: requests.isLoading && request == null
          ? const LoadingView()
          : request == null
          ? const Center(
              child: EmptyState(icon: Icons.search_off, title: 'Request not found'),
            )
          : _body(context, request),
    );
  }

  Widget _body(BuildContext context, JoinRequest request) {
    final (IconData icon, Color color, String title, String message) = switch (request.status) {
      JoinRequestStatus.pending => (
        Icons.hourglass_top_rounded,
        context.colors.tertiary,
        'Waiting for approval',
        'A member of "${request.groupName}" needs to approve you.',
      ),
      JoinRequestStatus.approved => (
        Icons.check_circle_rounded,
        context.appColors.positive,
        'You\'re in!',
        'Welcome to "${request.groupName}".',
      ),
      JoinRequestStatus.declined => (
        Icons.cancel_outlined,
        context.colors.error,
        'Request declined',
        'Your request to join "${request.groupName}" was declined.',
      ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            children: [
              _row(context, 'Group', request.groupName),
              _row(context, 'Requested', AppDates.dateTime(request.requestedAt)),
              if (request.decidedAt != null) _row(context, 'Decided', AppDates.dateTime(request.decidedAt!)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (request.status == JoinRequestStatus.approved)
          BusyButton(label: 'Open group', onPressed: () => context.go(Routes.group(request.groupId)))
        else if (request.isPending) ...[
          if (ref.watch(prototypeToolsProvider) != null)
            InfoBanner(
              tone: BannerTone.prototype,
              message: 'Demo: approve as a member.',
              action: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: _simulateApproval,
                      child: const Text('Approve now'),
                    ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
        ] else
          OutlinedButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: context.appColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
