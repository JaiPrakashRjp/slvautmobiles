import 'doc_ref.dart';
import 'enums.dart';
import 'gated_entity.dart';
import 'kyc_document.dart';

/// A customer / renter / borrower. Shared across Auto Sale, Rental and Loan
/// modules. Never logs in. Gated: status `active` means "Verified" in the UI.
class Customer with GatedEntity {
  Customer({
    required this.id,
    required this.firstName,
    this.lastName = '',
    required this.phone,
    this.address = '',
    this.branch,
    this.age,
    this.dob,
    List<KycDocument>? documents,
    this.assurityName,
    this.assurityMobile,
    this.assurityIdProof,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    List<DocRef>? uploadedDocs,
  })  : documents = documents ?? [],
        uploadedDocs = uploadedDocs ?? [];

  @override
  final String id;
  String firstName;
  String lastName;
  String phone;
  String address;
  Branch? branch;
  int? age;
  DateTime? dob;
  List<KycDocument> documents;

  /// Assurity (guarantor) person details. ID proof holds the uploaded file name
  /// (path/URL in Phase 7); null = not attached.
  String? assurityName;
  String? assurityMobile;
  String? assurityIdProof;

  /// KYC documents already stored on the backend (for download / replace / delete).
  List<DocRef> uploadedDocs;

  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  @override
  EntityStatus status;
  @override
  String? confirmedBy;
  @override
  DateTime? confirmedAt;
  @override
  String? rejectionReason;

  String get fullName =>
      lastName.isEmpty ? firstName : '$firstName $lastName';
}
