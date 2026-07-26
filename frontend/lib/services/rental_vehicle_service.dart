import 'api_vehicle_service.dart';

/// Vehicle service scoped to the **rental** module. Same table, same fields,
/// same create / documents / approval functionality as the sale vehicle
/// service — only the module differs, so rental keeps its own independent
/// vehicle pool (module = rental, separate from auto_sale).
class RentalVehicleService extends ApiVehicleService {
  RentalVehicleService({super.client}) : super(module: 'rental');
}
