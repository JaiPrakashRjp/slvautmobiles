// App-wide enums. Kept Flutter-free so models stay pure Dart.

enum Role {
  superAdmin,
  admin;

  String get wire => this == Role.superAdmin ? 'super_admin' : 'admin';

  static Role fromWire(String s) =>
      s == 'super_admin' ? Role.superAdmin : Role.admin;

  String get label => this == Role.superAdmin ? 'Super admin' : 'Admin';
}

/// Lifecycle status shared by every gated entity (Section 5).
enum EntityStatus {
  pendingConfirmation,
  active,
  rejected;

  String get wire => switch (this) {
        EntityStatus.pendingConfirmation => 'pending_confirmation',
        EntityStatus.active => 'active',
        EntityStatus.rejected => 'rejected',
      };

  static EntityStatus fromWire(String s) => switch (s) {
        'active' => EntityStatus.active,
        'rejected' => EntityStatus.rejected,
        _ => EntityStatus.pendingConfirmation,
      };

  String get label => switch (this) {
        EntityStatus.pendingConfirmation => 'Pending approval',
        EntityStatus.active => 'Active',
        EntityStatus.rejected => 'Rejected',
      };
}

/// Account status for [AppUser].
enum AccountStatus {
  pendingProfile,
  pendingVerification,
  active,
  suspended;

  String get label => switch (this) {
        AccountStatus.pendingProfile => 'Pending profile',
        AccountStatus.pendingVerification => 'Pending verification',
        AccountStatus.active => 'Active',
        AccountStatus.suspended => 'Suspended',
      };
}

/// The four functional areas; modules an admin can be granted access to.
enum AppModule {
  autoSale,
  loans,
  rentals,
  users;

  String get wire => switch (this) {
        AppModule.autoSale => 'auto_sale',
        AppModule.loans => 'loans',
        AppModule.rentals => 'rentals',
        AppModule.users => 'users',
      };

  static AppModule fromWire(String s) => switch (s) {
        'loans' => AppModule.loans,
        'rentals' => AppModule.rentals,
        'users' => AppModule.users,
        _ => AppModule.autoSale,
      };

  /// The `modules.code` value used by the backend (differs from [wire] for some
  /// modules: loan/rental/user_management).
  String get backendCode => switch (this) {
        AppModule.autoSale => 'auto_sale',
        AppModule.loans => 'loan',
        AppModule.rentals => 'rental',
        AppModule.users => 'user_management',
      };

  static AppModule fromBackendCode(String s) => switch (s) {
        'loan' => AppModule.loans,
        'rental' => AppModule.rentals,
        'user_management' => AppModule.users,
        _ => AppModule.autoSale,
      };

  String get label => switch (this) {
        AppModule.autoSale => 'Auto sale system',
        AppModule.loans => 'Loan management',
        AppModule.rentals => 'Auto rental collection',
        AppModule.users => 'User management',
      };
}

/// Business branch a record belongs to.
enum Branch {
  branch1,
  branch2;

  String get label => this == Branch.branch1 ? 'Branch 1' : 'Branch 2';

  String get wire => this == Branch.branch1 ? 'branch_1' : 'branch_2';

  static Branch fromWire(String s) =>
      s == 'branch_2' ? Branch.branch2 : Branch.branch1;
}

enum VehicleType {
  firstHand,
  secondHand;

  String get label => this == VehicleType.firstHand ? 'First hand' : 'Second hand';

  /// Backend `owned_hand` enum value.
  String get wire => this == VehicleType.firstHand ? 'first_hand' : 'second_hand';

  static VehicleType fromWire(String s) =>
      s == 'second_hand' ? VehicleType.secondHand : VehicleType.firstHand;
}

/// Fuel / drivetrain of a vehicle (Auto Sale create form).
enum FuelType {
  cng,
  lpg,
  electric;

  String get label => switch (this) {
        FuelType.cng => 'CNG',
        FuelType.lpg => 'LPG',
        FuelType.electric => 'Electric',
      };

  String get wire => name; // cng / lpg / electric — matches backend

  static FuelType? fromWire(String? s) => s == null
      ? null
      : FuelType.values.firstWhere((e) => e.name == s,
          orElse: () => FuelType.cng);
}

/// Showroom a first-hand (new) vehicle was sourced from.
enum Showroom {
  amba,
  acetec,
  khivraj;

  String get label => switch (this) {
        Showroom.amba => 'Amba',
        Showroom.acetec => 'Acetec',
        Showroom.khivraj => 'Khivraj',
      };

  String get wire => name; // amba / acetec / khivraj — matches backend

  static Showroom? fromWire(String? s) => s == null
      ? null
      : Showroom.values.firstWhere((e) => e.name == s,
          orElse: () => Showroom.amba);
}

/// Documents required for a second-hand vehicle (uploaded on create).
enum VehicleDocType {
  rc,
  fc,
  insurance,
  permit,
  others,
  noc;

  String get label => switch (this) {
        VehicleDocType.rc => 'RC',
        VehicleDocType.fc => 'FC',
        VehicleDocType.insurance => 'Insurance',
        VehicleDocType.permit => 'Permit',
        VehicleDocType.others => 'Others',
        VehicleDocType.noc => 'NOC',
      };

  /// Backend `vehicle_doc_type` enum value (matches the enum names exactly).
  String get wire => name; // rc / fc / insurance / permit / others / noc
}

enum InventoryStatus {
  available,
  reserved,
  sold,
  onRent;

  String get label => switch (this) {
        InventoryStatus.available => 'Available',
        InventoryStatus.reserved => 'Reserved',
        InventoryStatus.sold => 'Sold',
        InventoryStatus.onRent => 'On rent',
      };

  String get wire => switch (this) {
        InventoryStatus.available => 'available',
        InventoryStatus.reserved => 'reserved',
        InventoryStatus.sold => 'sold',
        InventoryStatus.onRent => 'on_rent',
      };

  static InventoryStatus fromWire(String s) => switch (s) {
        'reserved' => InventoryStatus.reserved,
        'sold' => InventoryStatus.sold,
        'on_rent' => InventoryStatus.onRent,
        _ => InventoryStatus.available,
      };
}

/// Whether a vehicle has been sold (Auto Sale list tabs + detail).
enum SaleStatus {
  notSold,
  sold;

  String get label => this == SaleStatus.sold ? 'Sold' : 'Not sold';

  String get wire => this == SaleStatus.sold ? 'sold' : 'not_sold';

  static SaleStatus fromWire(String? s) =>
      s == 'sold' ? SaleStatus.sold : SaleStatus.notSold;
}

enum DepositType {
  fullCash,
  downPayment;

  String get wire => this == DepositType.fullCash ? 'full_cash' : 'down_payment';
  String get label => this == DepositType.fullCash ? 'Full cash' : 'Down payment';

  static DepositType fromWire(String s) =>
      s == 'down_payment' ? DepositType.downPayment : DepositType.fullCash;

  PaymentMode get paymentMode =>
      this == DepositType.fullCash ? PaymentMode.full : PaymentMode.installments;
}

enum PaymentMode {
  full,
  installments;

  String get label =>
      this == PaymentMode.full ? 'Full payment' : 'Advance + installments';
}

enum PaymentChannel {
  cash,
  upi,
  bank;

  String get label => switch (this) {
        PaymentChannel.cash => 'Cash',
        PaymentChannel.upi => 'UPI',
        PaymentChannel.bank => 'Bank transfer',
      };
}

enum RentalBasis {
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
        RentalBasis.daily => 'Daily',
        RentalBasis.weekly => 'Weekly',
        RentalBasis.monthly => 'Monthly',
      };

  /// Length of one billing cycle, used to compute the next collection date.
  Duration get cycle => switch (this) {
        RentalBasis.daily => const Duration(days: 1),
        RentalBasis.weekly => const Duration(days: 7),
        RentalBasis.monthly => const Duration(days: 30),
      };
}

enum PenaltyType {
  flatPerDay,
  percentPerDay;

  String get label =>
      this == PenaltyType.flatPerDay ? 'Flat ₹ per day' : '% of due per day';
}

/// Generic schedule status for installments / EMIs / collections.
enum ScheduleStatus {
  upcoming,
  dueSoon,
  paid,
  partial,
  overdue;

  String get label => switch (this) {
        ScheduleStatus.upcoming => 'Upcoming',
        ScheduleStatus.dueSoon => 'Due soon',
        ScheduleStatus.paid => 'Paid',
        ScheduleStatus.partial => 'Partial',
        ScheduleStatus.overdue => 'Overdue',
      };
}

enum KycDocType {
  aadhaar,
  pan,
  dl,
  rentalAgreement,
  photo;

  String get label => switch (this) {
        KycDocType.aadhaar => 'Aadhaar',
        KycDocType.pan => 'PAN',
        KycDocType.dl => 'Driving licence',
        KycDocType.rentalAgreement => 'Rental agreement',
        KycDocType.photo => 'Photo',
      };

  /// Backend `kyc_doc_type` enum value.
  String get wire => switch (this) {
        KycDocType.aadhaar => 'aadhaar',
        KycDocType.pan => 'pan',
        KycDocType.dl => 'dl',
        KycDocType.rentalAgreement => 'rental_agreement',
        KycDocType.photo => 'photo',
      };

  static KycDocType? fromWire(String? s) => switch (s) {
        'aadhaar' => KycDocType.aadhaar,
        'pan' => KycDocType.pan,
        'dl' => KycDocType.dl,
        'rental_agreement' => KycDocType.rentalAgreement,
        'photo' => KycDocType.photo,
        _ => null,
      };
}
