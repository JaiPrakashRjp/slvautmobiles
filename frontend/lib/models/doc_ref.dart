/// A document already stored on the backend (vehicle or customer), enough for
/// the detail screen to download/replace/delete it. `docTypeWire` is the backend
/// enum value (e.g. `rc`, `prev_owner_id_proof`, `aadhaar`).
class DocRef {
  const DocRef({
    required this.id,
    required this.docTypeWire,
    required this.fileName,
  });

  final int id;
  final String docTypeWire;
  final String fileName;

  factory DocRef.fromJson(Map<String, dynamic> j) => DocRef(
        id: j['id'] as int,
        docTypeWire: j['doc_type'] as String,
        fileName: (j['file_name'] as String?) ?? '',
      );
}
