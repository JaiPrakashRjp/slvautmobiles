import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../models/vehicle.dart';
import '../../services/financer_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../viewmodels/create_vehicle_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doc_upload_tile.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Create / edit vehicle — Owned-hand spec. The Owned hand is chosen first; the
/// rest of the form (common + first-hand / second-hand groups) appears based on
/// it. Pass [existing] to open the form in edit mode.
class CreateVehicleScreen extends StatelessWidget {
  const CreateVehicleScreen({super.key, this.existing});

  final Vehicle? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateVehicleViewModel(
        context.read<VehicleService>(),
        context.read<AuthController>(),
        existing: existing,
      ),
      child: const _CreateVehicleView(),
    );
  }
}

class _CreateVehicleView extends StatefulWidget {
  const _CreateVehicleView();

  @override
  State<_CreateVehicleView> createState() => _CreateVehicleViewState();
}

class _CreateVehicleViewState extends State<_CreateVehicleView> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickDate(
    DateTime? current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final now = DateTime(2026, 6, 2);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2010),
      lastDate: DateTime(2032),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickHand(CreateVehicleViewModel vm) async {
    final picked = await OptionSheet.show<VehicleType>(
      context,
      title: 'Owned hand',
      selected: vm.hand,
      options: VehicleType.values
          .map((t) => SheetOption(value: t, label: t.label))
          .toList(),
    );
    if (picked != null) vm.hand = picked;
  }

  Future<void> _pickBranch(CreateVehicleViewModel vm) async {
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

  Future<void> _pickFuel(CreateVehicleViewModel vm) async {
    final picked = await OptionSheet.show<FuelType>(
      context,
      title: 'Vehicle type',
      selected: vm.fuelType,
      options: FuelType.values
          .map((t) => SheetOption(value: t, label: t.label))
          .toList(),
    );
    if (picked != null) vm.fuelType = picked;
  }

  Future<void> _pickShowroom(CreateVehicleViewModel vm) async {
    final picked = await OptionSheet.show<Showroom>(
      context,
      title: 'Showroom',
      selected: vm.showroom,
      options: Showroom.values
          .map((s) => SheetOption(value: s, label: s.label))
          .toList(),
    );
    if (picked != null) vm.showroom = picked;
  }

  Future<void> _pickStatus(CreateVehicleViewModel vm) async {
    final picked = await OptionSheet.show<EntityStatus>(
      context,
      title: 'Status',
      selected: vm.status,
      options: const [
        SheetOption(value: EntityStatus.active, label: 'Verified'),
        SheetOption(
            value: EntityStatus.pendingConfirmation, label: 'Not verified'),
      ],
    );
    if (picked != null) vm.status = picked;
  }

  Future<void> _pickSaleStatus(CreateVehicleViewModel vm) async {
    final picked = await OptionSheet.show<SaleStatus>(
      context,
      title: 'Sale status',
      selected: vm.saleStatus,
      options: SaleStatus.values
          .map((s) => SheetOption(value: s, label: s.label))
          .toList(),
    );
    if (picked != null) vm.saleStatus = picked;
  }

  Future<void> _pickFinancer(CreateVehicleViewModel vm) async {
    final financerService = context.read<FinancerService>();
    final messenger = ScaffoldMessenger.of(context); // capture before any await
    final financers = financerService.all();
    // -1 = add new, 0 = none, >0 = real financer id
    final options = [
      const SheetOption<int>(value: 0, label: '— None —'),
      const SheetOption<int>(value: -1, label: '＋ Add new financer'),
      ...financers.map((f) => SheetOption<int>(value: f.id, label: f.name)),
    ];
    final picked = await OptionSheet.show<int>(
      context,
      title: 'Financer',
      selected: vm.financerId ?? 0,
      options: options,
      searchable: financers.length > 5,
      searchHint: 'Search financers',
    );
    if (picked == null) return;
    if (picked == 0) {
      vm.financerId = null;
      return;
    }
    if (picked == -1) {
      // Inline add — show a quick dialog
      final nameCtrl = TextEditingController();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add financer'),
          content: TextField(
            controller: nameCtrl,
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
      if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
        try {
          final newFinancer =
              await financerService.create(nameCtrl.text.trim());
          vm.financerId = newFinancer.id;
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to add financer: $e')),
            );
          }
        }
      }
      nameCtrl.dispose();
      return;
    }
    vm.financerId = picked;
  }

  /// Captures a photo from the camera, then reports the picked file (bytes).
  Future<void> _takePhotoInto(ValueChanged<PickedDoc> onPicked) async {
    final XFile? img =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    onPicked(PickedDoc(name: img.name, bytes: bytes, mimeType: img.mimeType));
  }

  /// Uploads a file (pdf/png/heic/jpg/jpeg), then reports the picked file (bytes).
  Future<void> _uploadFileInto(ValueChanged<PickedDoc> onPicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedDocExtensions,
      withData: true, // load bytes into memory on all platforms
    );
    final f = result?.files.singleOrNull;
    if (f?.bytes != null) {
      onPicked(PickedDoc(name: f!.name, bytes: f.bytes!));
    }
  }

  /// Shows a small error message anchored to the bottom-right corner.
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

  bool _submitting = false;

  Future<void> _submit(CreateVehicleViewModel vm) async {
    if (_submitting) return;
    if (vm.hand == null) {
      _showError('Select the owned hand');
      return;
    }
    // Per-field inline validation for the mounted text fields.
    final formOk = _formKey.currentState!.validate();
    // Non-form required fields (date pickers) checked manually.
    final missing = <String>[];
    if (vm.branch == null) missing.add('Branch');
    if (vm.isSecondHand) {
      if (vm.insuranceDate == null) missing.add('Insurance date');
      if (vm.fcDate == null) missing.add('FC date');
      if (vm.permitDate == null) missing.add('Permit date');
    }
    if (!formOk || missing.isNotEmpty) {
      _showError(missing.isNotEmpty
          ? 'Required: ${missing.join(', ')}'
          : 'Please fix the highlighted fields');
      return;
    }

    _submitting = true;
    final editing = vm.isEditing;
    // Optimistic UI: fire the save (it reads the form fields synchronously now),
    // close the screen immediately, and report the outcome via the root
    // messenger. The record + document uploads finish on the app-level service
    // in the background, so the app feels instant even when the server is slow.
    final messenger = ScaffoldMessenger.of(context);
    final future = vm.submit();
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(editing ? 'Saving…' : 'Creating…'),
      duration: const Duration(seconds: 1),
    ));
    future.then((result) {
      final base = result.pending
          ? 'Submitted. Awaiting Super admin confirmation.'
          : (editing ? 'Vehicle updated.' : 'Vehicle created.');
      final msg = result.failedDocs.isEmpty
          ? base
          : '$base Some documents failed to upload: '
              '${result.failedDocs.join(', ')}.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<CreateVehicleViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
          title: Text(vm.isEditing ? 'Edit vehicle' : 'Create vehicle')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 500,
          phone: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(context.screenHPadding),
              children: [
                // Step 1 — Owned hand. Always shown, always first.
                PickerField(
                  label: 'Owned hand',
                  required: true,
                  placeholder: 'Select first hand / second hand',
                  value: vm.hand?.label,
                  onTap: () => _pickHand(vm),
                ),
                if (vm.hand == null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choose the owned hand to continue.',
                    style: AppTextStyles.caption.copyWith(color: c.textSub),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  ..._commonFields(context, vm),
                  if (vm.isFirstHand) ..._firstHandFields(context, vm),
                  if (vm.isSecondHand) ..._secondHandFields(context, vm),
                  // Only super admin can manually set status; admins always
                  // create pending — backend enforces this too.
                  if (context.read<AuthController>().isSuperAdmin || vm.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PickerField(
                      label: 'Status',
                      value: vm.status == EntityStatus.active
                          ? 'Verified'
                          : 'Not verified',
                      onTap: () => _pickStatus(vm),
                    ),
                  ],
                  if (vm.isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PickerField(
                      label: 'Sale status',
                      value: vm.saleStatus.label,
                      onTap: () => _pickSaleStatus(vm),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                      label: vm.isEditing ? 'Save' : 'Create',
                      loading: _submitting,
                      onPressed: () => _submit(vm)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Common (both hand types) ───────────────────────────────────────────────
  List<Widget> _commonFields(BuildContext context, CreateVehicleViewModel vm) {
    return [
      PickerField(
        label: 'Branch',
        required: true,
        placeholder: 'Branch 1 / Branch 2',
        value: vm.branch?.label,
        onTap: () => _pickBranch(vm),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Chassis number',
        required: true,
        hint: 'Enter chassis number',
        controller: vm.chassisController,
        textInputAction: TextInputAction.next,
        validator: (v) => Validators.required(v, field: 'Chassis number'),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Vehicle model',
        required: true,
        hint: 'e.g. Bajaj RE',
        controller: vm.modelController,
        textInputAction: TextInputAction.next,
        validator: (v) => Validators.required(v, field: 'Vehicle model'),
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'Vehicle type',
        placeholder: 'CNG / LPG / Electric',
        value: vm.fuelType?.label,
        onTap: () => _pickFuel(vm),
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'Purchase date',
        leadingIcon: Icons.calendar_today_outlined,
        trailingIcon: Icons.calendar_today_outlined,
        placeholder: 'Select date',
        value: vm.purchaseDate == null
            ? null
            : Formatters.date(vm.purchaseDate!),
        onTap: () => _pickDate(vm.purchaseDate, (d) => vm.purchaseDate = d),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Buying expenses',
        hint: '₹0',
        controller: vm.buyingExpensesController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'Financer',
        placeholder: 'Select financer (optional)',
        value: context.read<FinancerService>().byId(vm.financerId ?? 0)?.name,
        onTap: () => _pickFinancer(vm),
      ),
      if (vm.financerId != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => vm.financerId = null,
            child: const Text('Clear'),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Remarks',
        hint: 'Any notes about this vehicle',
        controller: vm.remarksController,
        textInputAction: TextInputAction.next,
        maxLines: 3,
      ),
    ];
  }

  // ── First hand only ────────────────────────────────────────────────────────
  List<Widget> _firstHandFields(
      BuildContext context, CreateVehicleViewModel vm) {
    return [
      const SizedBox(height: AppSpacing.lg),
      const _SectionLabel('First hand details'),
      const SizedBox(height: AppSpacing.md),
      PickerField(
        label: 'Showroom',
        placeholder: 'Amba / Acetec / Khivraj',
        value: vm.showroom?.label,
        onTap: () => _pickShowroom(vm),
      ),
    ];
  }

  // ── Second hand only ───────────────────────────────────────────────────────
  List<Widget> _secondHandFields(
      BuildContext context, CreateVehicleViewModel vm) {
    return [
      const SizedBox(height: AppSpacing.lg),
      const _SectionLabel('Second hand details'),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: 'Vehicle number',
        required: true,
        hint: 'KA-01-AB-1234',
        controller: vm.regNoController,
        textInputAction: TextInputAction.next,
        validator: (v) => Validators.required(v, field: 'Vehicle number'),
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'Insurance date',
        required: true,
        leadingIcon: Icons.calendar_today_outlined,
        trailingIcon: Icons.calendar_today_outlined,
        placeholder: 'Select date',
        value: vm.insuranceDate == null
            ? null
            : Formatters.date(vm.insuranceDate!),
        onTap: () => _pickDate(vm.insuranceDate, (d) => vm.insuranceDate = d),
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'FC date',
        required: true,
        leadingIcon: Icons.calendar_today_outlined,
        trailingIcon: Icons.calendar_today_outlined,
        placeholder: 'Select date',
        value: vm.fcDate == null ? null : Formatters.date(vm.fcDate!),
        onTap: () => _pickDate(vm.fcDate, (d) => vm.fcDate = d),
      ),
      const SizedBox(height: AppSpacing.lg),
      PickerField(
        label: 'Permit date',
        required: true,
        leadingIcon: Icons.calendar_today_outlined,
        trailingIcon: Icons.calendar_today_outlined,
        placeholder: 'Select date',
        value: vm.permitDate == null ? null : Formatters.date(vm.permitDate!),
        onTap: () => _pickDate(vm.permitDate, (d) => vm.permitDate = d),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Documents required',
          style: AppTextStyles.label.copyWith(color: context.colors.textSub)),
      const SizedBox(height: AppSpacing.xs),
      Text('Upload a file or take a photo (pdf, png, heic, jpg, jpeg)',
          style: AppTextStyles.caption.copyWith(color: context.colors.textSub)),
      const SizedBox(height: AppSpacing.sm),
      for (final d in VehicleDocType.values.where((d) =>
          d != VehicleDocType.rc &&
          d != VehicleDocType.permit &&
          d != VehicleDocType.insurance)) ...[
        DocUploadTile(
          label: d.label,
          fileName: vm.documents[d]?.name,
          onTakePhoto: () => _takePhotoInto((doc) => vm.setDocument(d, doc)),
          onUpload: () => _uploadFileInto((doc) => vm.setDocument(d, doc)),
          onRemove: () => vm.removeDocument(d),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.md),
      const _SectionLabel('Previous owner details'),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: 'Name',
        hint: 'Previous owner name',
        controller: vm.prevOwnerNameController,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Mobile number',
        hint: '10-digit mobile',
        controller: vm.prevOwnerMobileController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Address',
        hint: 'Previous owner address',
        controller: vm.prevOwnerAddressController,
        maxLines: 2,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Documents',
          style: AppTextStyles.label.copyWith(color: context.colors.textSub)),
      const SizedBox(height: AppSpacing.xs),
      Text('Upload a file or take a photo (pdf, png, heic, jpg, jpeg)',
          style: AppTextStyles.caption.copyWith(color: context.colors.textSub)),
      const SizedBox(height: AppSpacing.sm),
      DocUploadTile(
        label: 'ID proof',
        fileName: vm.prevOwnerIdProof?.name,
        onTakePhoto: () => _takePhotoInto((doc) => vm.prevOwnerIdProof = doc),
        onUpload: () => _uploadFileInto((doc) => vm.prevOwnerIdProof = doc),
        onRemove: () => vm.prevOwnerIdProof = null,
      ),
      const SizedBox(height: AppSpacing.sm),
      DocUploadTile(
        label: 'Photo',
        fileName: vm.prevOwnerPhoto?.name,
        onTakePhoto: () => _takePhotoInto((doc) => vm.prevOwnerPhoto = doc),
        onUpload: () => _uploadFileInto((doc) => vm.prevOwnerPhoto = doc),
        onRemove: () => vm.prevOwnerPhoto = null,
      ),
    ];
  }
}

/// Small bold section heading used to separate the conditional field groups.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(text, style: AppTextStyles.h2.copyWith(color: c.textMain));
  }
}


