import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/personal_loan_financer_service.dart';
import '../../services/personal_loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Create a personal loan — vehicle number, financer (own master + add new),
/// loan amount, EMI amount, tenure, loan date and the reminder phone.
class NewPersonalLoanScreen extends StatefulWidget {
  const NewPersonalLoanScreen({super.key});

  @override
  State<NewPersonalLoanScreen> createState() => _NewPersonalLoanScreenState();
}

class _NewPersonalLoanScreenState extends State<NewPersonalLoanScreen> {
  final _vehicleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  int? _financerId;
  DateTime? _loanDate;
  bool _submitting = false;

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _amountCtrl.dispose();
    _emiCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  int get _amount =>
      int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _emi =>
      int.tryParse(_emiCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _tenure => int.tryParse(_tenureCtrl.text.trim()) ?? 0;

  Future<void> _pickFinancer() async {
    final svc = context.read<PersonalLoanFinancerService>();
    final messenger = ScaffoldMessenger.of(context);
    final financers = svc.all();
    final options = [
      const SheetOption<int>(value: -1, label: '＋ Add new financer'),
      ...financers.map((f) => SheetOption<int>(value: f.id, label: f.name)),
    ];
    final picked = await OptionSheet.show<int>(
      context,
      title: 'Financer',
      selected: _financerId,
      options: options,
      searchable: financers.length > 5,
      searchHint: 'Search financers',
    );
    if (picked == null) return;
    if (picked == -1) {
      final nameCtrl = TextEditingController();
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add financer'),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Finance company name', hintText: 'e.g. HDFC Bank'),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Add')),
          ],
        ),
      );
      if (ok == true && nameCtrl.text.trim().isNotEmpty) {
        try {
          final f = await svc.create(nameCtrl.text.trim());
          setState(() => _financerId = f.id);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
        }
      }
      nameCtrl.dispose();
      return;
    }
    setState(() => _financerId = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loanDate ?? DateTime(2026, 6, 5),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked != null) setState(() => _loanDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final missing = <String>[];
    if (_vehicleCtrl.text.trim().isEmpty) missing.add('Vehicle number');
    if (_loanDate == null) missing.add('Loan date');
    if (_amount <= 0) missing.add('Loan amount');
    if (_emi <= 0) missing.add('EMI amount');
    if (_tenure <= 0) missing.add('Tenure');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Required: ${missing.join(', ')}')),
      );
      return;
    }
    setState(() => _submitting = true);
    final service = context.read<PersonalLoanService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await service.create(
        vehicleNumber: _vehicleCtrl.text.trim(),
        financerId: _financerId,
        loanAmount: _amount,
        emiAmount: _emi,
        tenureMonths: _tenure,
        loanDate: _loanDate!,
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Loan created.')));
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final financers = context.watch<PersonalLoanFinancerService>();
    final financerName = _financerId == null
        ? null
        : financers.byId(_financerId!)?.name;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('New personal loan')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppTextField(
                label: 'Vehicle number',
                required: true,
                hint: 'KA-01-AB-1234',
                controller: _vehicleCtrl,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Financer',
                leadingIcon: Icons.account_balance_outlined,
                placeholder: 'Select or add financer',
                value: financerName,
                onTap: _pickFinancer,
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Loan date',
                required: true,
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: _loanDate == null ? null : Formatters.date(_loanDate!),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Loan amount',
                required: true,
                prefixText: '₹ ',
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'EMI amount',
                      required: true,
                      prefixText: '₹ ',
                      controller: _emiCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Tenure (months)',
                      required: true,
                      controller: _tenureCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_emi > 0 && _tenure > 0) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('EMI × tenure',
                          style: AppTextStyles.body
                              .copyWith(color: c.onPrimary.withValues(alpha: 0.8))),
                      Text(
                          '${Formatters.currency(_emi)} × $_tenure = ${Formatters.currency(_emi * _tenure)}',
                          style: TextStyle(
                              color: c.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Create loan',
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
