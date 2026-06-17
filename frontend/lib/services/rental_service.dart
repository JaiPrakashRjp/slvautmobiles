import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/enums.dart';
import '../models/rental.dart';
import '../models/rental_collection.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../utils/id_gen.dart';
import 'gate.dart';

/// Rental data access. Self-contained mock (own renters + rentable vehicles)
/// so the rental demo is coherent; Phase 7 unifies this with the shared
/// Customer/Vehicle collections in Firestore.
abstract class RentalService extends ChangeNotifier {
  // Vehicle views (mockup 11)
  List<Vehicle> rentedVehicles();
  List<Vehicle> notRentedVehicles();
  List<Vehicle> availableVehicles();
  Vehicle? vehicleById(String id);

  // Renter views (mockup 14)
  List<Customer> verifiedRenters();
  Customer? renterById(String id);
  List<Rental> activeRentals();
  List<Rental> endedRentals();

  // Rental lookups
  Rental? rentalById(String id);
  List<Rental> pendingRentals();
  Rental? activeRentalForVehicle(String vehicleId);
  Rental? activeRentalForCustomer(String customerId);
  List<Rental> rentalsForVehicle(String vehicleId);

  // Service tracking
  List<Vehicle> serviceDueWithin(int days, {DateTime? now});

  // Mutations
  Rental createRental({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required String customerId,
    required RentalBasis basis,
    required int rent,
    int securityDeposit,
    required DateTime startDate,
  });
  void recordCollection(String rentalId, String collectionId);
  void endRental(String rentalId);
  void logService({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required DateTime serviceDate,
    int intervalMonths,
    int cost,
    String? servicedBy,
  });
  void confirmRental(String id, String byUserId);
  void rejectRental(String id, String reason, String byUserId);
  void deleteRental(String id);
}

class MockRentalService extends RentalService {
  MockRentalService() {
    _seed();
  }

  final List<Vehicle> _vehicles = [];
  final List<Customer> _renters = [];
  final List<Rental> _rentals = [];
  final List<ServiceRecord> _services = [];

  static final DateTime _today = DateTime(2026, 6, 2);

  /// Builds [count] collections of [rent] from [start] spaced by [basis].
  static List<RentalCollection> _buildCollections({
    required RentalBasis basis,
    required int rent,
    required DateTime start,
    required int count,
    int paidUpTo = 0,
  }) {
    return List.generate(count, (i) {
      final due = start.add(basis.cycle * i);
      return RentalCollection(
        id: IdGen.nextId('coll'),
        cycleNumber: i + 1,
        dueDate: due,
        amount: rent,
        paidDate: i < paidUpTo ? due : null,
        reminderSent: i < paidUpTo,
      );
    });
  }

  void _seed() {
    // Renters
    _renters.addAll([
      _renter('rt_001', 'Manoj', 'P.', '+919876543210'),
      _renter('rt_002', 'Imran', 'K.', '+919812345678'),
      _renter('rt_003', 'Suresh', 'K.', '+919800011122'),
      _renter('rt_004', 'Ravi', 'K.', '+919733344455'),
    ]);

    // Rentable vehicles
    _vehicles.addAll([
      _vehicle('rv_001', 'KA-01-AB-1234', InventoryStatus.onRent,
          assignedTo: 'rt_001', serviceDue: DateTime(2026, 8, 15)),
      _vehicle('rv_002', 'KA-01-CD-5678', InventoryStatus.onRent,
          assignedTo: 'rt_002', serviceDue: DateTime(2026, 9, 1)),
      _vehicle('rv_003', 'KA-02-EF-9090', InventoryStatus.available,
          serviceDue: DateTime(2026, 6, 7)), // within 7 days → service due
    ]);

    // Active rental: Manoj, weekly ₹2,000 (mockup 13 — W1/W2 paid, W3 due).
    _rentals.add(Rental(
      id: IdGen.nextId('rent'),
      vehicleId: 'rv_001',
      customerId: 'rt_001',
      basis: RentalBasis.weekly,
      rent: 2000,
      securityDeposit: 4000,
      startDate: DateTime(2026, 5, 13),
      rentalStatus: 'active',
      collections: _buildCollections(
        basis: RentalBasis.weekly,
        rent: 2000,
        start: DateTime(2026, 5, 13),
        count: 4,
        paidUpTo: 2,
      ),
      createdBy: 'u_super',
      createdAt: DateTime(2026, 5, 13),
      status: EntityStatus.active,
    ));

    // Active rental: Imran, monthly ₹8,000 — on time.
    _rentals.add(Rental(
      id: IdGen.nextId('rent'),
      vehicleId: 'rv_002',
      customerId: 'rt_002',
      basis: RentalBasis.monthly,
      rent: 8000,
      securityDeposit: 8000,
      startDate: DateTime(2026, 5, 1),
      rentalStatus: 'active',
      collections: _buildCollections(
        basis: RentalBasis.monthly,
        rent: 8000,
        start: DateTime(2026, 5, 1),
        count: 3,
        paidUpTo: 2,
      ),
      createdBy: 'u_super',
      createdAt: DateTime(2026, 5, 1),
      status: EntityStatus.active,
    ));

    // Ended rentals on rv_001 (history for tabs 17/18).
    _rentals.add(_endedRental('rv_001', 'rt_003', RentalBasis.monthly, 8000,
        DateTime(2026, 1, 5), 4)); // Suresh ₹32,000
    _rentals.add(_endedRental('rv_001', 'rt_004', RentalBasis.weekly, 2000,
        DateTime(2025, 8, 4), 20)); // Ravi ₹40,000
    _rentals.add(_endedRental('rv_001', 'rt_002', RentalBasis.weekly, 2000,
        DateTime(2025, 5, 5), 9)); // Imran ₹18,000
  }

  // (seed "today" is the static _today above)

  Customer _renter(String id, String first, String last, String phone) =>
      Customer(
        id: id,
        firstName: first,
        lastName: last,
        phone: phone,
        createdBy: 'u_super',
        createdAt: DateTime(2026, 1, 1),
        status: EntityStatus.active,
      );

  Vehicle _vehicle(String id, String reg, InventoryStatus status,
          {String? assignedTo, DateTime? serviceDue}) =>
      Vehicle(
        id: id,
        regNo: reg,
        type: VehicleType.firstHand,
        inventoryStatus: status,
        assignedToCustomerId: assignedTo,
        nextServiceDueDate: serviceDue,
        createdBy: 'u_super',
        createdAt: DateTime(2026, 1, 1),
        status: EntityStatus.active,
      );

  Rental _endedRental(String vehicleId, String customerId, RentalBasis basis,
      int rent, DateTime start, int cycles) {
    return Rental(
      id: IdGen.nextId('rent'),
      vehicleId: vehicleId,
      customerId: customerId,
      basis: basis,
      rent: rent,
      startDate: start,
      endDate: start.add(basis.cycle * cycles),
      rentalStatus: 'ended',
      collections: _buildCollections(
        basis: basis,
        rent: rent,
        start: start,
        count: cycles,
        paidUpTo: cycles,
      ),
      createdBy: 'u_super',
      createdAt: start,
      status: EntityStatus.active,
    );
  }

  @override
  List<Vehicle> rentedVehicles() => _vehicles
      .where((v) => v.inventoryStatus == InventoryStatus.onRent)
      .toList();

  @override
  List<Vehicle> notRentedVehicles() => _vehicles
      .where((v) => v.inventoryStatus != InventoryStatus.onRent)
      .toList();

  @override
  List<Vehicle> availableVehicles() => _vehicles
      .where((v) => v.inventoryStatus == InventoryStatus.available)
      .toList();

  @override
  Vehicle? vehicleById(String id) =>
      _vehicles.where((v) => v.id == id).cast<Vehicle?>().firstOrNull;

  @override
  List<Customer> verifiedRenters() =>
      _renters.where((c) => c.isActive).toList();

  @override
  Customer? renterById(String id) =>
      _renters.where((c) => c.id == id).cast<Customer?>().firstOrNull;

  @override
  List<Rental> activeRentals() =>
      _rentals.where((r) => r.rentalStatus == 'active').toList();

  @override
  List<Rental> endedRentals() =>
      _rentals.where((r) => r.rentalStatus == 'ended').toList();

  @override
  Rental? rentalById(String id) =>
      _rentals.where((r) => r.id == id).cast<Rental?>().firstOrNull;

  @override
  List<Rental> pendingRentals() => _rentals.where((r) => r.isPending).toList();

  @override
  Rental? activeRentalForVehicle(String vehicleId) => _rentals
      .where((r) => r.vehicleId == vehicleId && r.rentalStatus == 'active')
      .cast<Rental?>()
      .firstOrNull;

  @override
  Rental? activeRentalForCustomer(String customerId) => _rentals
      .where((r) => r.customerId == customerId && r.rentalStatus == 'active')
      .cast<Rental?>()
      .firstOrNull;

  @override
  List<Rental> rentalsForVehicle(String vehicleId) {
    final list = _rentals.where((r) => r.vehicleId == vehicleId).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  @override
  List<Vehicle> serviceDueWithin(int days, {DateTime? now}) {
    final ref = now ?? _today;
    return _vehicles.where((v) {
      final due = v.nextServiceDueDate;
      if (due == null) return false;
      final d = DateTime(due.year, due.month, due.day)
          .difference(DateTime(ref.year, ref.month, ref.day))
          .inDays;
      return d <= days;
    }).toList();
  }

  @override
  Rental createRental({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required String customerId,
    required RentalBasis basis,
    required int rent,
    int securityDeposit = 0,
    required DateTime startDate,
  }) {
    final rental = Rental(
      id: IdGen.nextId('rent'),
      vehicleId: vehicleId,
      customerId: customerId,
      basis: basis,
      rent: rent,
      securityDeposit: securityDeposit,
      startDate: startDate,
      rentalStatus: 'active',
      collections: _buildCollections(
        basis: basis,
        rent: rent,
        start: startDate,
        count: basis == RentalBasis.monthly ? 6 : 8,
      ),
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
    _rentals.insert(0, rental);
    final v = vehicleById(vehicleId);
    if (v != null) {
      v.inventoryStatus = InventoryStatus.onRent;
      v.assignedToCustomerId = customerId;
    }
    notifyListeners();
    return rental;
  }

  @override
  void recordCollection(String rentalId, String collectionId) {
    final rental = rentalById(rentalId);
    final coll = rental?.collections
        .where((c) => c.id == collectionId)
        .cast<RentalCollection?>()
        .firstOrNull;
    if (coll != null) {
      coll.paidDate = DateTime.now();
      notifyListeners();
    }
  }

  @override
  void endRental(String rentalId) {
    final rental = rentalById(rentalId);
    if (rental != null) {
      rental.rentalStatus = 'ended';
      rental.endDate = DateTime.now();
      final v = vehicleById(rental.vehicleId);
      if (v != null) {
        v.inventoryStatus = InventoryStatus.available;
        v.assignedToCustomerId = null;
      }
      notifyListeners();
    }
  }

  @override
  void logService({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required DateTime serviceDate,
    int intervalMonths = 3,
    int cost = 0,
    String? servicedBy,
  }) {
    final record = ServiceRecord(
      id: IdGen.nextId('svc'),
      vehicleId: vehicleId,
      serviceDate: serviceDate,
      intervalMonths: intervalMonths,
      cost: cost,
      servicedBy: servicedBy,
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
    _services.add(record);
    // On Super Admin action (immediately active), update the denormalised date.
    if (record.isActive) {
      final v = vehicleById(vehicleId);
      if (v != null) v.nextServiceDueDate = record.nextServiceDueDate;
    }
    notifyListeners();
  }

  @override
  void confirmRental(String id, String byUserId) {
    final r = rentalById(id);
    if (r != null) {
      Gate.confirm(r, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void rejectRental(String id, String reason, String byUserId) {
    final r = rentalById(id);
    if (r != null) {
      Gate.reject(r, reason: reason, byUserId: byUserId);
      r.rentalStatus = 'rejected';
      final v = vehicleById(r.vehicleId);
      if (v != null) {
        v.inventoryStatus = InventoryStatus.available;
        v.assignedToCustomerId = null;
      }
      notifyListeners();
    }
  }

  @override
  void deleteRental(String id) {
    _rentals.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
