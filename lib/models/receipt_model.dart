class ReceiptModel {
  final String id;
  final int receiptNumber;
  final String userId;
  final String? subscriptionId;
  final String gymId;
  final DateTime issueDate;
  final String description;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final double vatRate;
  final String paymentMethod;
  final DateTime? validityStart;
  final DateTime? validityEnd;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related objects
  final UserProfile? user;
  final GymInfo? gym;
  final SubscriptionModel? subscription;

  ReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.userId,
    this.subscriptionId,
    required this.gymId,
    required this.issueDate,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.vatRate = 0.0,
    required this.paymentMethod,
    this.validityStart,
    this.validityEnd,
    this.status = 'issued',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.gym,
    this.subscription,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as int,
      userId: json['user_id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      gymId: json['gym_id'] as String,
      issueDate: DateTime.parse(json['issue_date'] as String),
      description: json['description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: double.parse(json['unit_price'].toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      vatRate: double.parse(json['vat_rate']?.toString() ?? '0'),
      paymentMethod: json['payment_method'] as String,
      validityStart:
          json['validity_start'] != null
              ? DateTime.parse(json['validity_start'] as String)
              : null,
      validityEnd:
          json['validity_end'] != null
              ? DateTime.parse(json['validity_end'] as String)
              : null,
      status: json['status'] as String? ?? 'issued',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      user:
          json['user_profiles'] != null
              ? UserProfile.fromJson(
                json['user_profiles'] as Map<String, dynamic>,
              )
              : null,
      gym:
          json['gym_info'] != null
              ? GymInfo.fromJson(json['gym_info'] as Map<String, dynamic>)
              : null,
      subscription:
          json['subscriptions'] != null
              ? SubscriptionModel.fromJson(
                json['subscriptions'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_number': receiptNumber,
      'user_id': userId,
      'subscription_id': subscriptionId,
      'gym_id': gymId,
      'issue_date': issueDate.toIso8601String().split('T')[0],
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'vat_rate': vatRate,
      'payment_method': paymentMethod,
      'validity_start': validityStart?.toIso8601String().split('T')[0],
      'validity_end': validityEnd?.toIso8601String().split('T')[0],
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ItalianReceiptModel {
  final String id;
  final String receiptNumber;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Customer Information
  final String customerName;
  final String? customerTaxCode;
  final String? customerAddress;

  // Receipt Details
  final String description;
  final int quantity;
  final double unitPrice;
  final double discountPercentage;
  final String vatRate;
  final double vatAmount;
  final double amount;
  final String paymentMethod;

  // Validity Period
  final DateTime? validityStartDate;
  final DateTime? validityEndDate;
  final DateTime? issueDate;

  // Notes
  final String? notes;
  final String? fiscalNotes;
  final String status;

  // Organization Info
  final OrganizationInfo? organizationInfo;
  final UserProfile? creator;

  ItalianReceiptModel({
    required this.id,
    required this.receiptNumber,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    required this.customerName,
    this.customerTaxCode,
    this.customerAddress,
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.discountPercentage = 0.0,
    this.vatRate = '0',
    this.vatAmount = 0.0,
    required this.amount,
    this.paymentMethod = 'cash',
    this.validityStartDate,
    this.validityEndDate,
    this.issueDate,
    this.notes,
    this.fiscalNotes,
    this.status = 'issued',
    this.organizationInfo,
    this.creator,
  });

  factory ItalianReceiptModel.fromJson(Map<String, dynamic> json) {
    return ItalianReceiptModel(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as String,
      createdBy: json['created_by'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      customerName: json['customer_name'] as String,
      customerTaxCode: json['customer_tax_code'] as String?,
      customerAddress: json['customer_address'] as String?,
      description: json['description'] as String,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: double.parse(json['unit_price']?.toString() ?? '0'),
      discountPercentage: double.parse(
        json['discount_percentage']?.toString() ?? '0',
      ),
      vatRate: json['vat_rate'] as String? ?? '0',
      vatAmount: double.parse(json['vat_amount']?.toString() ?? '0'),
      amount: double.parse(json['amount']?.toString() ?? '0'),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      validityStartDate:
          json['validity_start_date'] != null
              ? DateTime.parse(json['validity_start_date'])
              : null,
      validityEndDate:
          json['validity_end_date'] != null
              ? DateTime.parse(json['validity_end_date'])
              : null,
      issueDate:
          json['issue_date'] != null
              ? DateTime.parse(json['issue_date'])
              : null,
      notes: json['notes'] as String?,
      fiscalNotes: json['fiscal_notes'] as String?,
      status: json['status'] as String? ?? 'issued',
      organizationInfo:
          json['organization_info'] != null
              ? OrganizationInfo.fromJson(json['organization_info'])
              : null,
      creator:
          json['user_profiles'] != null
              ? UserProfile.fromJson(json['user_profiles'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_number': receiptNumber,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'customer_name': customerName,
      'customer_tax_code': customerTaxCode,
      'customer_address': customerAddress,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_percentage': discountPercentage,
      'vat_rate': vatRate,
      'vat_amount': vatAmount,
      'amount': amount,
      'payment_method': paymentMethod,
      'validity_start_date': validityStartDate?.toIso8601String().split('T')[0],
      'validity_end_date': validityEndDate?.toIso8601String().split('T')[0],
      'issue_date': issueDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'fiscal_notes': fiscalNotes,
      'status': status,
    };
  }

  double get subtotal => quantity * unitPrice;
  double get discountAmount => (subtotal * discountPercentage) / 100;
  double get taxableAmount => subtotal - discountAmount;
  double get totalAmount => taxableAmount + vatAmount;

  String get formattedIssueDate =>
      issueDate != null
          ? '${issueDate!.day.toString().padLeft(2, '0')}-${issueDate!.month.toString().padLeft(2, '0')}-${issueDate!.year}'
          : '';

  String get formattedValidityPeriod {
    if (validityStartDate != null && validityEndDate != null) {
      return 'dal ${validityStartDate!.day.toString().padLeft(2, '0')}-${validityStartDate!.month.toString().padLeft(2, '0')}-${validityStartDate!.year} al ${validityEndDate!.day.toString().padLeft(2, '0')}-${validityEndDate!.month.toString().padLeft(2, '0')}-${validityEndDate!.year}';
    }
    return '';
  }

  String get paymentMethodText {
    switch (paymentMethod.toLowerCase()) {
      case 'satispay':
        return 'Satispay';
      case 'sumup':
        return 'SumUp';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico Bancario';
      case 'credit_card':
        return 'Carta di Credito';
      default:
        return paymentMethod;
    }
  }
}

class OrganizationInfo {
  final String id;
  final String name;
  final String address;
  final String taxCode;
  final String? phone;
  final String? email;

  OrganizationInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.taxCode,
    this.phone,
    this.email,
  });

  factory OrganizationInfo.fromJson(Map<String, dynamic> json) {
    return OrganizationInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      taxCode: json['tax_code'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final bool isActive;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.role = 'student',
    this.isActive = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'student',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class GymInfo {
  final String id;
  final String name;
  final String address;
  final String taxCode;
  final String? phone;
  final String? email;

  GymInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.taxCode,
    this.phone,
    this.email,
  });

  factory GymInfo.fromJson(Map<String, dynamic> json) {
    return GymInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      taxCode: json['tax_code'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}

class SubscriptionModel {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool autoRenewal;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.autoRenewal = false,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amount: double.parse(json['amount'].toString()),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: json['is_active'] as bool? ?? true,
      autoRenewal: json['auto_renewal'] as bool? ?? false,
    );
  }
}
