import 'api_vehicle_service.dart';

/// Vehicle service scoped to the **loan** module. Same `vehicles` /
/// `vehicle_documents` tables, same fields, same create / documents / approval
/// functionality as the sale and rental vehicle services — only the module
/// differs, so the loan module keeps its own independent vehicle pool
/// (module = loan, separate from auto_sale and rental).
class LoanVehicleService extends ApiVehicleService {
  LoanVehicleService({super.client}) : super(module: 'loan');
}
