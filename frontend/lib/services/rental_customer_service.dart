import 'api_customer_service.dart';

/// Customer service scoped to the **rental** module. Same table, same fields,
/// same create / KYC / approval functionality as the sale customer service —
/// only the module differs, so rental keeps its own independent customer list
/// (module = rental, separate from auto_sale).
class RentalCustomerService extends ApiCustomerService {
  RentalCustomerService({super.client}) : super(module: 'rental');
}
