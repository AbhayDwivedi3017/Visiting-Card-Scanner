class DigitalCard {
  final int? id;
  final int scannedCardId;
  final String qrCodePath;
  final String vcfPath;
  final DateTime createdAt;

  DigitalCard({
    this.id,
    required this.scannedCardId,
    required this.qrCodePath,
    required this.vcfPath,
    required this.createdAt,
  });

  DigitalCard copyWith({
    int? id,
    int? scannedCardId,
    String? qrCodePath,
    String? vcfPath,
    DateTime? createdAt,
  }) {
    return DigitalCard(
      id: id ?? this.id,
      scannedCardId: scannedCardId ?? this.scannedCardId,
      qrCodePath: qrCodePath ?? this.qrCodePath,
      vcfPath: vcfPath ?? this.vcfPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scanned_card_id': scannedCardId,
      'qr_code_path': qrCodePath,
      'vcf_path': vcfPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DigitalCard.fromMap(Map<String, dynamic> map) {
    return DigitalCard(
      id: map['id'] as int?,
      scannedCardId: map['scanned_card_id'] as int,
      qrCodePath: (map['qr_code_path'] ?? '') as String,
      vcfPath: (map['vcf_path'] ?? '') as String,
      createdAt: DateTime.parse((map['created_at'] ?? DateTime.now().toIso8601String()) as String),
    );
  }
}
