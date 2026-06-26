import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/customer.dart';
import '../../models/doc_ref.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../services/customer_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../viewmodels/create_customer_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doc_manager_tile.dart';
import '../../widgets/doc_upload_tile.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';
import '../document_preview_screen.dart';

/// Create / edit customer — required Name / Mobile / Address / Documents /
/// Assurity person details. Pass [existing] to open in edit mode.
class CreateCustomerScreen extends StatelessWidget {
  const CreateCustomerScreen({super.key, this.existing});

  final Customer? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateCustomerViewModel(
        context.read<CustomerService>(),
        context.read<AuthController>(),
        existing: existing,
      ),
      child: const _CreateCustomerView(),
    );
  }
}

class _CreateCustomerView extends StatefulWidget {
  const _CreateCustomerView();

  @override
  State<_CreateCustomerView> createState() => _CreateCustomerViewState();
}

class _CreateCustomerViewState extends State<_CreateCustomerView> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  static const _docTypes = [
    KycDocType.aadhaar,
    KycDocType.pan,
    KycDocType.dl,
    KycDocType.rentalAgreement,
    KycDocType.photo,
  ];

  Future<void> _pickDob(CreateCustomerViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.dob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime(2010),
    );
    if (picked != null) vm.dob = picked;
  }

  Future<void> _pickBranch(CreateCustomerViewModel vm) async {
    final picked = await OptionSheet.show<Branch>(
      context,
      title: 'Branch',
      selected: vm.branch,
      options: Branch.values
          .map((b) => SheetOption(value: b, label: b.label))
          .toList(),
    );
    if (picked != null) vm.branch = picked;
  }

  void _showError(String message) {
    final c = context.colors;
    final width = MediaQuery.of(context).size.width;
    final left = (width - 320).clamp(16.0, width);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(message,
                    style: AppTextStyles.body.copyWith(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: c.danger,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: left, right: 16, bottom: 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _submit(CreateCustomerViewModel vm) async {
    if (_submitting) return;
    final formOk = _formKey.currentState!.validate();
    final branchMissing = vm.branch == null;
    // Documents are required only when creating (edit manages them live).
    final docsMissing = !vm.isEditing && vm.docs.isEmpty;

    if (!formOk || branchMissing || docsMissing) {
      _showError(branchMissing
          ? 'Select a branch'
          : docsMissing
              ? 'Add at least one document'
              : 'Please fix the highlighted fields');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await vm.submit();
      if (!mounted) return;
      Navigator.of(context).pop();
      final base = result.pending
          ? 'Submitted. Awaiting Super admin confirmation.'
          : (vm.isEditing ? 'Customer updated.' : 'Customer created.');
      final msg = result.failedDocs.isEmpty
          ? base
          : '$base Some documents failed to upload: '
              '${result.failedDocs.join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<CreateCustomerViewModel>();
    // Rebuild when documents change (edit mode live management).
    context.watch<CustomerService>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
          title: Text(vm.isEditing ? 'Edit customer' : 'Create customer')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 500,
          phone: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(context.screenHPadding),
              children: [
                PickerField(
                  label: 'Branch',
                  required: true,
                  placeholder: 'Branch 1 / Branch 2',
                  value: vm.branch?.label,
                  onTap: () => _pickBranch(vm),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First name',
                        required: true,
                        controller: vm.firstNameController,
                        validator: (v) => Validators.required(v, field: 'Name'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Last name',
                        controller: vm.lastNameController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Mobile number',
                  required: true,
                  prefixText: '+91 ',
                  controller: vm.phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Age',
                        controller: vm.ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PickerField(
                        label: 'DOB',
                        placeholder: 'Select date',
                        value: vm.dob == null ? null : Formatters.date(vm.dob!),
                        onTap: () => _pickDob(vm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Address',
                  required: true,
                  controller: vm.addressController,
                  maxLines: 3,
                  minLines: 2,
                  validator: (v) => Validators.required(v, field: 'Address'),
                ),
                const SizedBox(height: AppSpacing.lg),
                _RequiredLabel('Documents', !vm.isEditing),
                const SizedBox(height: AppSpacing.xs),
                Text('Upload a file or take a photo (pdf, png, heic, jpg, jpeg)',
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                ..._docSection(context, vm),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Text('Assurity person details',
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                    Text(' *', style: AppTextStyles.h2.copyWith(color: c.danger)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Name',
                  required: true,
                  controller: vm.assurityNameController,
                  validator: (v) =>
                      Validators.required(v, field: 'Assurity person name'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Mobile number',
                  required: true,
                  prefixText: '+91 ',
                  controller: vm.assurityMobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RequiredLabel('ID proof', !vm.isEditing),
                const SizedBox(height: AppSpacing.sm),
                _assurityDocTile(context, vm),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Remarks',
                  hint: 'Any notes about this customer',
                  controller: vm.remarksController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                    label: vm.isEditing ? 'Save' : 'Create',
                    onPressed: () => _submit(vm)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Document widgets ────────────────────────────────────────────────────────
  List<Widget> _docSection(BuildContext context, CreateCustomerViewModel vm) {
    if (!vm.isEditing) {
      // Create: collect picked files, uploaded on submit.
      return [
        for (final d in _docTypes) ...[
          DocUploadTile(
            label: d.label,
            fileName: vm.docs[d]?.name,
            onTakePhoto: () async {
              final p = await pickPhotoDoc();
              if (p != null) vm.setDocument(d, p);
            },
            onUpload: () async {
              final p = await pickFileDoc();
              if (p != null) vm.setDocument(d, p);
            },
            onRemove: () => vm.removeDocument(d),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ];
    }
    // Edit: manage existing documents live.
    return [
      for (final d in _docTypes) ...[
        _liveDocTile(context, vm, d.wire, d.label),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Widget _assurityDocTile(BuildContext context, CreateCustomerViewModel vm) {
    if (!vm.isEditing) {
      return DocUploadTile(
        label: 'ID proof',
        fileName: vm.assurityIdProof?.name,
        onTakePhoto: () async {
          final p = await pickPhotoDoc();
          if (p != null) vm.assurityIdProof = p;
        },
        onUpload: () async {
          final p = await pickFileDoc();
          if (p != null) vm.assurityIdProof = p;
        },
        onRemove: () => vm.assurityIdProof = null,
      );
    }
    return _liveDocTile(context, vm, 'assurity_id_proof', 'ID proof');
  }

  /// A document tile bound to the live backend (edit mode): download / replace /
  /// delete an already-stored document.
  Widget _liveDocTile(
      BuildContext context, CreateCustomerViewModel vm, String wire, String label) {
    final customers = context.read<CustomerService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final id = vm.existingId!;
    final current = customers.byId(id);
    final ref = current?.uploadedDocs
        .where((d) => d.docTypeWire == wire)
        .cast<DocRef?>()
        .firstOrNull;

    Future<void> replace(PickedDoc? picked) async {
      if (picked == null) return;
      try {
        await customers.uploadDocument(id, wire, picked);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }

    void open() => navigator.push(MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            title: label,
            fileName: ref!.fileName,
            loader: () => customers.documentBytes(ref.id),
          ),
        ));

    Future<void> remove() async {
      try {
        await customers.deleteDocument(id, ref!.id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }

    return DocManagerTile(
      label: label,
      fileName: ref?.fileName,
      onTakePhoto: () async => replace(await pickPhotoDoc()),
      onUpload: () async => replace(await pickFileDoc()),
      onDownload: ref == null ? null : open,
      onDelete: ref == null ? null : remove,
    );
  }
}

/// A field label with an optional trailing red required asterisk.
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text, [this.required = true]);

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RichText(
      text: TextSpan(
        text: text,
        style: AppTextStyles.label.copyWith(color: c.textSub),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: AppTextStyles.label.copyWith(color: c.danger),
            ),
        ],
      ),
    );
  }
}
