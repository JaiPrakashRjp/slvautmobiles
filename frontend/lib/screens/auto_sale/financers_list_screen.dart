import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financer.dart';
import '../../services/financer_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';

/// Master list of finance companies. Users can add and delete entries.
class FinancersListScreen extends StatelessWidget {
  const FinancersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<FinancerService>();
    final service = context.read<FinancerService>();
    final financers = service.all();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Financers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => service.refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, service),
        icon: const Icon(Icons.add),
        label: const Text('Add financer'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: financers.isEmpty
              ? const EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No financers yet',
                  subtitle: 'Tap "Add financer" to add a finance company.',
                )
              : ListView.separated(
                  padding: EdgeInsets.all(context.screenHPadding),
                  itemCount: financers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) =>
                      _FinancerTile(financer: financers[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, FinancerService service) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add financer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Finance company name',
            hintText: 'e.g. HDFC Bank',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await service.create(controller.text.trim());
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add financer: $e')),
          );
        }
      }
    }
    controller.dispose();
  }
}

class _FinancerTile extends StatelessWidget {
  const _FinancerTile({required this.financer});

  final Financer financer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = context.read<FinancerService>();

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(financer.name,
                style: AppTextStyles.body.copyWith(color: c.textMain)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, service),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, FinancerService service) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete financer',
      message:
          'Remove "${financer.name}"? Vehicles linked to this financer will lose the association.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (confirmed == true) {
      try {
        await service.delete(financer.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

