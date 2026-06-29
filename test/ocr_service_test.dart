import 'package:flutter_test/flutter_test.dart';
import 'package:kloudera_scanner/services/ocr_service.dart';
import 'package:kloudera_scanner/data/models/card_data.dart';

void main() {
  group('OcrService Heuristic Parser Tests', () {
    late OcrService ocrService;

    setUp(() {
      ocrService = OcrService();
    });

    test('Parses standard business card text accurately', () {
      final mockLines = [
        'Kloudera Technologies',
        'John Doe',
        'Senior Software Architect',
        'Mobile: +91 98765 43210',
        'Office: +91 120 456789',
        'john.doe@kloudera.com',
        'www.kloudera.com',
        'linkedin.com/in/johndoe',
        'A-14, Sector 62, Noida, UP, 201301',
      ];

      final CardData result = ocrService.parseLines(mockLines);

      expect(result.name, equals('John Doe'));
      expect(result.designation, equals('Senior Software Architect'));
      expect(result.company, equals('Kloudera Technologies'));
      expect(result.phone, equals('+91 98765 43210'));
      expect(result.altPhone, equals('+91 120 456789'));
      expect(result.email, equals('john.doe@kloudera.com'));
      expect(result.website, equals('www.kloudera.com'));
      expect(result.linkedin, equals('https://linkedin.com/in/johndoe'));
      expect(result.pincode, equals('201301'));
      expect(result.state, equals('UP'));
      expect(result.city, equals('Noida'));
      expect(result.country, equals('India')); // Auto-inferred for 6-digit pin
    });

    test('Parses card with alternate layout and label prefixes', () {
      final mockLines = [
        'CEO & Founder',
        'Jane Smith',
        'ACME Systems Corporation',
        'Tel: (555) 019-2834',
        'Mob: (555) 019-5678',
        'jane.smith@acmesystems.com',
        'https://acmesystems.com',
        'LinkedIn: janesmith',
        '100 Pine Street, San Francisco, CA, 94111, USA',
      ];

      final CardData result = ocrService.parseLines(mockLines);

      expect(result.name, equals('Jane Smith'));
      expect(result.designation, equals('CEO & Founder'));
      expect(result.company, equals('ACME Systems Corporation'));
      // Heuristic should match Mob as primary and Tel as alt
      expect(result.phone, equals('(555) 019-5678'));
      expect(result.altPhone, equals('(555) 019-2834'));
      expect(result.email, equals('jane.smith@acmesystems.com'));
      expect(result.website, equals('https://acmesystems.com'));
      expect(result.linkedin, equals('https://linkedin.com/in/janesmith'));
      expect(result.pincode, equals('94111'));
      expect(result.state, equals('CA'));
      expect(result.city, equals('San Francisco'));
    });

    test('Handles missing fields gracefully', () {
      final mockLines = [
        'Bob Johnson',
        'Freelancer',
        'bob.johnson@freelance.org',
      ];

      final CardData result = ocrService.parseLines(mockLines);

      expect(result.name, equals('Bob Johnson'));
      expect(result.designation, equals('Freelancer'));
      expect(result.company, isEmpty);
      expect(result.phone, isEmpty);
      expect(result.email, equals('bob.johnson@freelance.org'));
      expect(result.address, isEmpty);
    });
  });
}
