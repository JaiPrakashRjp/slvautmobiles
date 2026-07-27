import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../models/vehicle.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../viewmodels/create_vehicle_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doc_upload_tile.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Create / edit a RENTAL vehicle. Same `vehicles` table as sale vehicles, but
/// scoped to module = rental (via [RentalVehicleService]) with a reduced field
/// set: Branch, Model, Fuel type, Registration number, Insurance / FC / Permit
/// dates, RC / Permit / Insurance (flag + document), Remarks. Owned-hand and
/// chassis are handled internally (owned-hand = second-hand; no chassis).
class RentalVehicleFormScreen extends StatelessWidget {
  const RentalVehicleFormScreen({super.key, this.existing});

  final Vehicle? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateVehicleViewModel(
        context.read<RentalVehicleService>(),
        context.read<AuthController>(),
        existing: existing,
        rental: true,
      ),
      child: const _RentalVehicleFormView(),
    );
  }
}

class _RentalVehicleFormView extends StatefulWidget {
  const _RentalVehicleFormView();

  @override
  State<_RentalVehicleFormView> createState() => _RentalVehicleFormViewState();
}

class _RentalVehicleFormViewState extends State<_RentalVehicleFormView> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

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

  Future<void> _pickDate(
      DateTime? current, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _takePhotoInto(ValueChanged<PickedDoc> onPicked) async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    onPicked(PickedDoc(name: img.name, bytes: bytes, mimeType: img.mimeType));
  }

  Future<void> _uploadFileInto(ValueChanged<PickedDoc> onPicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedDocExtensions,
      withData: true,
    );
    final f = result?.files.singleOrNull;
    if (f?.bytes != null) onPicked(PickedDoc(name: f!.name, bytes: f.bytes!));
  }

  Future<void> _submit(CreateVehicleViewModel vm) async {
    if (_submitting) return;
    final formOk = _formKey.currentState!.validate();
    final missing = <String>[];
    if (vm.branch == null) missing.add('Branch');
    if (vm.insuranceDate == null) missing.add('Insurance date');
    if (vm.fcDate == null) missing.add('FC date');
    if (vm.permitDate == null) missing.add('Permit date');
    if (!formOk || missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(missing.isNotEmpty
            ? 'Required: ${missing.join(', ')}'
            : 'Please fix the highlighted fields'),
      ));
      return;
    }

    setState(() => _submitting = true);
    final editing = vm.isEditing;
    final messenger = ScaffoldMessenger.of(context);
    final future = vm.submit();
    if (mounted) Navigator.of(context).pop();
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              PickerField(
                label: 'Branch',
                required: true,
                placeholder: 'Branch 1 / Branch 2',
                value: vm.branch?.label,
                onTap: () => _pickBranch(vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Vehicle number',
                required: true,
                hint: 'KA-01-AB-1234',
                controller: vm.regNoController,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.required(v, field: 'Vehicle number'),
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

              // ── Document validity dates ────────────────────────────────
              PickerField(
                label: 'Insurance date',
                required: true,
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.insuranceDate == null
                    ? null
                    : Formatters.date(vm.insuranceDate!),
                onTap: () =>
                    _pickDate(vm.insuranceDate, (d) => vm.insuranceDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'FC date',
                required: true,
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value:
                    vm.fcDate == null ? null : Formatters.date(vm.fcDate!),
                onTap: () => _pickDate(vm.fcDate, (d) => vm.fcDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Permit date',
                required: true,
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.permitDate == null
                    ? null
                    : Formatters.date(vm.permitDate!),
                onTap: () => _pickDate(vm.permitDate, (d) => vm.permitDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Papers: RC / Permit / Insurance (flag + document) ──────
              Text('Papers',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),
              _paper(vm, 'RC', VehicleDocType.rc, vm.rc, (v) => vm.rc = v),
              _paper(vm, 'Permit', VehicleDocType.permit, vm.permit,
                  (v) => vm.permit = v),
              _paper(vm, 'Insurance', VehicleDocType.insurance, vm.insurance,
                  (v) => vm.insurance = v),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Remarks',
                hint: 'Any notes about this vehicle',
                controller: vm.remarksController,
                maxLines: 3,
              ),

              // Only super admin can set status; admins always create pending.
              if (context.read<AuthController>().isSuperAdmin ||
                  vm.isEditing) ...[
                const SizedBox(height: AppSpacing.lg),
                PickerField(
                  label: 'Status',
                  value: vm.status == EntityStatus.active
                      ? 'Verified'
                      : 'Not verified',
                  onTap: () => _pickStatus(vm),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: vm.isEditing ? 'Save' : 'Create',
                loading: _submitting,
                onPressed: () => _submit(vm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One paper row: a Yes/No flag + a document upload tile for that paper.
  Widget _paper(CreateVehicleViewModel vm, String label, VehicleDocType type,
      bool value, ValueChanged<bool> onChanged) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: value,
              activeColor: c.primary,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Text(label, style: AppTextStyles.body.copyWith(color: c.textMain)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: DocUploadTile(
            label: '$label document',
            fileName: vm.documents[type]?.name,
            onTakePhoto: () => _takePhotoInto((doc) => vm.setDocument(type, doc)),
            onUpload: () => _uploadFileInto((doc) => vm.setDocument(type, doc)),
            onRemove: () => vm.removeDocument(type),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
