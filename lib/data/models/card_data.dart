class CardData {
  final int? id;
  final int? excelRefId;
  final String name;
  final String designation;
  final String company;
  final String phone;
  final String altPhone;
  final String email;
  final String website;
  final String address;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String notes;
  final String imagePath;
  final DateTime scanDate;

  CardData({
    this.id,
    this.excelRefId,
    required this.name,
    required this.designation,
    required this.company,
    required this.phone,
    required this.altPhone,
    required this.email,
    required this.website,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    required this.notes,
    required this.imagePath,
    required this.scanDate,
  });

  CardData copyWith({
    int? id,
    int? excelRefId,
    String? name,
    String? designation,
    String? company,
    String? phone,
    String? altPhone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? notes,
    String? imagePath,
    DateTime? scanDate,
  }) {
    return CardData(
      id: id ?? this.id,
      excelRefId: excelRefId ?? this.excelRefId,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      altPhone: altPhone ?? this.altPhone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      scanDate: scanDate ?? this.scanDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'excel_ref_id': excelRefId,
      'name': name,
      'designation': designation,
      'company': company,
      'phone': phone,
      'alt_phone': altPhone,
      'email': email,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
      'notes': notes,
      'image_path': imagePath,
      'scan_date': scanDate.toIso8601String(),
    };
  }

  factory CardData.fromMap(Map<String, dynamic> map) {
    return CardData(
      id: map['id'] as int?,
      excelRefId: map['excel_ref_id'] as int?,
      name: (map['name'] ?? '') as String,
      designation: (map['designation'] ?? '') as String,
      company: (map['company'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      altPhone: (map['alt_phone'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      website: (map['website'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      country: (map['country'] ?? '') as String,
      pincode: (map['pincode'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      imagePath: (map['image_path'] ?? '') as String,
      scanDate: DateTime.parse((map['scan_date'] ?? DateTime.now().toIso8601String()) as String),
    );
  }

  List<dynamic> toExcelRow() {
    return [
      name,
      designation,
      company,
      phone,
      altPhone,
      email,
      website,
      address,
      city,
      state,
      country,
      pincode,
      notes,
      scanDate.toIso8601String(),
    ];
  }

  factory CardData.empty() {
    return CardData(
      name: '',
      designation: '',
      company: '',
      phone: '',
      altPhone: '',
      email: '',
      website: '',
      address: '',
      city: '',
      state: '',
      country: '',
      pincode: '',
      notes: '',
      imagePath: '',
      scanDate: DateTime.now(),
    );
  }
}
