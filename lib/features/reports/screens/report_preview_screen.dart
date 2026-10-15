import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/services/report_builder.dart';
import '../../groups/group_providers.dart';

/// On-screen preview of a period report, with PDF share and print.
/// The PDF is built on the device from exactly the data shown here.
class ReportPreviewScreen extends ConsumerStatefulWidget {
  const ReportPreviewScreen({super.key, required this.groupId, required this.range});

  final String groupId;
  final DateRange range;

  @override
  ConsumerState<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  bool _busy = false;

  Future<void> _export(ReportData data, {required bool share}) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(pdfReportServiceProvider);
      final bytes = await service.build(data);
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: service.fileName(data));
      } else {
        await Printing.layoutPdf(name: service.fileName(data), onLayout: (_) async => bytes);
      }
    } catch (error) {
      if (mounted) showAppSnack(context, 'Couldn\'t create the PDF on this device.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(groupSnapshotProvider(widget.groupId));
    final data = snapshot.value == null ? null : ReportBuilder.build(snapshot.value!, widget.range);

    return Scaffold(
      appBar: AppBar(title: const Text('Report preview')),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (_) => _ReportBody(data: data!),
      ),
      bottomNavigationBar: data == null
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _export(data, share: false),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print / Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _export(data, share: true),
                          icon: _busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.ios_share_rounded),
                          label: const Text('Share PDF'),
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final muted = context.appColors.muted;
    final summary = data.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXPENSE REPORT',
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(data.group.name, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Code ${data.group.code}  ·  ${AppDates.range(data.range)} (${data.range.dayCount} days)',
                style: context.text.bodySmall?.copyWith(color: muted),
              ),
              Text(
                'Generated ${AppDates.dateTime(data.generatedAt)}',
                style: context.text.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const SectionHeader('Summary'),
        AppCard(
          child: Column(
            children: [
              _kv(
                context,
                'Total expenses',
                AmountText(summary.totalExpensesPaisa, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              _kv(context, 'Number of expenses', Text('${summary.expenseCount}')),
              _kv(context, 'Paid from personal money', AmountText(summary.paidPersonallyPaisa)),
              _kv(context, 'Paid from group fund', AmountText(summary.paidFromFundPaisa)),
              if (summary.voidedCount > 0) _kv(context, 'Voided entries (not counted)', Text('${summary.voidedCount}')),
              if (summary.byCategory.isNotEmpty) ...[
                const Divider(height: 20),
                for (final entry in summary.byCategory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CategoryIcon(entry.key, size: 28),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.key.label)),
                        AmountText(entry.value),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (data.fundAsOfEnd.hasFund || data.contributions.isNotEmpty) ...[
          SectionHeader('Group fund (as of ${AppDates.day(data.range.end)})'),
          Card(
            color: context.appColors.fundContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: context.appColors.onFundContainer),
                child: Column(
                  children: [
                    _kv(context, 'Total contributions to date', AmountText(data.fundAsOfEnd.contributedPaisa)),
                    _kv(context, 'Spent from fund to date', AmountText(data.fundAsOfEnd.spentPaisa)),
                    _kv(
                      context,
                      'Remaining',
                      AmountText(data.fundAsOfEnd.remainingPaisa, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (data.contributions.isNotEmpty) ...[
                      const Divider(height: 20),
                      for (final c in data.contributions)
                        _kv(
                          context,
                          '${data.nameOf(c.memberUserId)} · ${c.type.label} · ${AppDates.short(c.date)}',
                          AmountText(c.amountPaisa),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SectionHeader('Members in this period'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, m) in data.members.indexed) ...[
                if (i > 0) const Divider(indent: 16),
                _MemberRow(member: m, data: data),
              ],
            ],
          ),
        ),
        const SectionHeader('Daily expenses'),
        if (data.days.isEmpty)
          const AppCard(
            child: EmptyState(icon: Icons.event_busy, title: 'No expenses in this period'),
          ),
        for (final day in data.days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(AppDates.weekday(day.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                AmountText(day.totalPaisa, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          for (final e in day.expenses) ...[_ExpenseBlock(expense: e, data: data), const SizedBox(height: 8)],
        ],
      ],
    );
  }

  Widget _kv(BuildContext context, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w600),
            child: value,
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.data});

  final GroupMember member;
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final b = data.summary.balanceOf(member.userId);
    final period = member.endDate == null
        ? 'Since ${AppDates.day(member.startDate)}'
        : '${AppDates.short(member.startDate)} – ${AppDates.day(member.endDate!)} (${member.status.label.toLowerCase()})';
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: member.displayName, size: 32, muted: !member.isActive),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(period, style: context.text.bodySmall?.copyWith(color: context.appColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LabeledValue(label: 'Paid in', value: AmountText(b?.paidInPaisa ?? 0)),
              ),
              Expanded(
                child: LabeledValue(label: 'Share', value: AmountText(b?.sharePaisa ?? 0)),
              ),
              Expanded(
                child: LabeledValue(label: 'Net', value: AmountText(b?.netPaisa ?? 0, signed: true, colorize: true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseBlock extends StatelessWidget {
  const _ExpenseBlock({required this.expense, required this.data});

  final Expense expense;
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final muted = context.appColors.muted;
    final paidBy = e.paymentSource == PaymentSource.groupFund ? 'Group fund' : data.nameOf(e.paidByUserId);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${e.title}  ·  ${e.category.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              AmountText(e.totalPaisa, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Added by ${data.nameOf(e.createdByUserId)}  ·  Paid by $paidBy${e.isEdited ? '  ·  Edited' : ''}',
            style: context.text.bodySmall?.copyWith(color: muted),
          ),
          if (e.isItemized) ...[
            const SizedBox(height: 8),
            for (final item in e.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name, style: context.text.bodySmall)),
                    Text(
                      '${Quantity.format(item.quantityMilli)} × ${Money.format(item.unitPricePaisa, withCurrency: false)}',
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 72,
                      child: AmountText(
                        item.lineTotalPaisa,
                        withCurrency: false,
                        textAlign: TextAlign.right,
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (e.notes != null) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${e.notes}',
              style: context.text.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
