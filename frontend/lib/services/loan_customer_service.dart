import 'api_customer_service.dart';

/// Customer service scoped to the **loan** module. Same `customers` /
/// `customer_documents` tables, same fields, same create / KYC / approval
/// functionality as the sale and rental customer services — only the module
/// differs, so the loan module keeps its own independent customer list
/// (module = loan, separate from auto_sale and rental).
class LoanCustomerService extends ApiCustomerService {
  LoanCustomerService({super.client}) : super(module: 'loan');
}
