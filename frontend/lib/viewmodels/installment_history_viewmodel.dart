import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/vehicle.dart';
import '../services/customer_service.dart';
import '../services/sale_service.dart';
import '../services/vehicle_service.dart';

/// Backs the installment history screen (mockup 10). Resolves the relevant
/// sale either directly by id or via the customer's active installment sale.
class InstallmentHistoryViewModel extends ChangeNotifier {
  InstallmentHistoryViewModel({
    this.saleId,
    this.customerId,
    required SaleService sales,
    required VehicleService vehicles,
    required CustomerService customers,
    required AuthController auth,
  })  : _sales = sales,
        _vehicles = vehicles,
        _customers = customers,
        _auth = auth;

  final String? saleId;
  final String? customerId;
  final SaleService _sales;
  final VehicleService _vehicles;
  final CustomerService _customers;
  final AuthController _auth;

  Sale? get sale {
    if (saleId != null) return _sales.byId(saleId!);
    if (customerId != null) {
      return _sales
          .forCustomer(customerId!)
          .where((s) => s.installments.isNotEmpty)
          .cast<Sale?>()
          .firstOrNull;
    }
    return null;
  }

  Customer? get customer {
    final s = sale;
    return s == null ? null : _customers.byId(s.customerId);
  }

  Vehicle? get vehicle {
    final s = sale;
    return s == null ? null : _vehicles.byId(s.vehicleId);
  }

  bool get canRecordPayment => sale?.isActive ?? false;

  void markPaid(String installmentId) {
    final s = sale;
    if (s == null || !s.isActive) return;
    // fire-and-forget; SaleService updates its cache and notifies listeners
    _sales.markPaid(s.id, installmentId).ignore();
  }

  String get actorId => _auth.currentUser?.id ?? 'u_super';
}
