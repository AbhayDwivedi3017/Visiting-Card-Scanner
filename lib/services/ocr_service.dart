import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/models/card_data.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Performs offline OCR on the image and parses the extracted lines.
  Future<CardData> scanCardImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      
      // Extract all lines of text
      final List<String> lines = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          lines.add(line.text.trim());
        }
      }
      
      return parseLines(lines, imagePath);
    } catch (e) {
      // Return empty card on error or log
      return CardData.empty().copyWith(
        imagePath: imagePath,
        notes: 'Error scanning image: $e',
      );
    }
  }

  /// Intelligently parses a list of lines extracted from a visiting card.
  /// Made public and independent of ML Kit classes for easy unit testing.
  CardData parseLines(List<String> rawLines, [String imagePath = '']) {
    // 1. Preprocess and clean lines
    final List<String> lines = rawLines
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Fields to extract
    String name = '';
    String designation = '';
    String company = '';
    String phone = '';
    String altPhone = '';
    String email = '';
    String website = '';
    String address = '';
    String city = '';
    String state = '';
    String country = '';
    String pincode = '';
    List<String> unclassified = [];

    // Regex Patterns
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', caseSensitive: false);
    final websiteRegex = RegExp(r'(https?://)?(www\.)?[a-zA-Z0-9.-]+\.(com|org|net|co|info|in|edu|gov|io|tech|biz|us|uk|ae)', caseSensitive: false);
    
    // Multi-format Phone Regex
    final phoneRegex = RegExp(r'(\+?\d{1,4}[\s-]?)?(\(?\d{2,5}\)?[\s-]?)?\d{3,5}[\s-]?\d{3,5}');
    
    // Indian Pincode (6 digits) or US Zip (5 digits)
    final pincodeRegex = RegExp(r'\b\d{5,6}\b');

    // List of lines representing candidate text for name/company/designation
    final List<String> candidates = List.from(lines);

    // 2. Extract Email (High Confidence Match)
    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i];
      final emailMatch = emailRegex.firstMatch(line);
      if (emailMatch != null) {
        email = emailMatch.group(0) ?? '';
        candidates.removeAt(i);
        break; // Assume single email on card or take the first
      }
    }

    // 3. Extract Website (High Confidence Match)
    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i];
      final websiteMatch = websiteRegex.firstMatch(line);
      if (websiteMatch != null) {
        // Exclude email addresses being matched as websites
        if (!line.contains('@')) {
          website = websiteMatch.group(0) ?? '';
          candidates.removeAt(i);
          break;
        }
      }
    }

    // 4. Extract Phone Numbers
    final List<String> foundPhones = [];
    for (int i = candidates.length - 1; i >= 0; i--) {
      final line = candidates[i];
      if (!_isPhoneLine(line)) continue;
      
      // Clean letters and symbols commonly present in phone lines to see if it contains a phone
      final cleanLine = line.replaceAll(RegExp(r'[a-zA-Z\s\:\-]'), '');
      if (cleanLine.length >= 8 && phoneRegex.hasMatch(line)) {
        // Extract all possible phone numbers from this line
        final matches = phoneRegex.allMatches(line);
        for (var match in matches) {
          final matchText = match.group(0)?.trim() ?? '';
          if (matchText.replaceAll(RegExp(r'\D'), '').length >= 8) {
            foundPhones.add(line); // Store the original line which contains the phone
            break;
          }
        }
        candidates.removeAt(i);
      }
    }

    // Classify phones into Mobile vs Alternate Phone
    if (foundPhones.isNotEmpty) {
      // Heuristic: Check for labels like "m", "cell", "mob", "p", "ph"
      String? primary;
      String? secondary;

      for (var pLine in foundPhones) {
        final lower = pLine.toLowerCase();
        final rawNum = _cleanPhoneNumber(pLine);

        if (lower.contains('m:') || lower.contains('mob') || lower.contains('cell') || lower.contains('mobile') || lower.contains('personal')) {
          primary = rawNum;
        } else if (lower.contains('tel') || lower.contains('off') || lower.contains('alt') || lower.contains('work') || lower.contains('land')) {
          secondary = rawNum;
        }
      }

      // Fallback: If no labels, first is primary, second is alt
      if (primary == null && secondary == null) {
        primary = _cleanPhoneNumber(foundPhones[0]);
        if (foundPhones.length > 1) {
          secondary = _cleanPhoneNumber(foundPhones[1]);
        }
      } else if (primary != null && secondary == null && foundPhones.length > 1) {
        // Primary found, assign another one to alt
        for (var pLine in foundPhones) {
          final cleaned = _cleanPhoneNumber(pLine);
          if (cleaned != primary) {
            secondary = cleaned;
            break;
          }
        }
      } else if (secondary != null && primary == null && foundPhones.length > 1) {
        // Secondary found, assign another one to primary
        for (var pLine in foundPhones) {
          final cleaned = _cleanPhoneNumber(pLine);
          if (cleaned != secondary) {
            primary = cleaned;
            break;
          }
        }
      }

      phone = primary ?? '';
      altPhone = secondary ?? '';
    }

    // 5. Extract Pincode
    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i];
      final pinMatch = pincodeRegex.firstMatch(line);
      if (pinMatch != null) {
        pincode = pinMatch.group(0) ?? '';
        break; // Keep line for address extraction
      }
    }

    // 6. Extract Designation (Heuristics)
    final designationKeywords = [
      'director', 'manager', 'ceo', 'cfo', 'cto', 'founder', 'co-founder', 'president',
      'vice president', 'vp', 'executive', 'consultant', 'developer', 'engineer',
      'specialist', 'analyst', 'partner', 'architect', 'officer', 'leader', 'lead',
      'chief', 'representative', 'associate', 'administrator', 'supervisor', 'head',
      'freelancer', 'freelance', 'designer', 'artist', 'developer', 'programmer'
    ];

    double maxDesignationScore = 0;
    int designationIdx = -1;

    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i].toLowerCase();
      double score = 0;

      for (var keyword in designationKeywords) {
        if (line == keyword) {
          score += 1.0;
        } else if (line.contains(keyword)) {
          score += 0.7;
        }
      }

      // Designation usually isn't very long (less than 40 chars)
      if (score > 0 && candidates[i].length < 40) {
        if (score > maxDesignationScore) {
          maxDesignationScore = score;
          designationIdx = i;
        }
      }
    }

    if (designationIdx != -1) {
      designation = candidates[designationIdx];
      candidates.removeAt(designationIdx);
    }

    // 7. Extract Company (Heuristics)
    final companyKeywords = [
      'ltd', 'limited', 'inc', 'incorporated', 'co.', 'company', 'corp', 'corporation',
      'technologies', 'technology', 'solutions', 'software', 'systems', 'group',
      'industries', 'enterprises', 'services', 'partners', 'labs', 'kloudera'
    ];

    double maxCompanyScore = 0;
    int companyIdx = -1;

    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i].toLowerCase();
      double score = 0;

      for (var keyword in companyKeywords) {
        if (line.contains(keyword)) {
          score += 0.8;
        }
      }

      // Check if line contains logo indicators or common naming
      if (line.contains('www.') || line.contains('@')) continue;

      if (score > maxCompanyScore) {
        maxCompanyScore = score;
        companyIdx = i;
      }
    }

    if (companyIdx != -1) {
      company = candidates[companyIdx];
      candidates.removeAt(companyIdx);
    }

    // 8. Extract Address & Location (Heuristics)
    final addressKeywords = [
      'street', 'road', 'rd', 'avenue', 'ave', 'lane', 'ln', 'block', 'sector', 'plot',
      'phase', 'building', 'bldg', 'floor', 'flr', 'plaza', 'tower', 'industrial area',
      'nagar', 'city', 'state', 'country', 'floor', 'office', 'suite', 'hwy', 'highway'
    ];

    final List<String> addressLines = [];
    final List<int> indicesToRemove = [];

    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i];
      final lower = line.toLowerCase();
      bool isAddress = false;

      // Contains pincode
      if (pincode.isNotEmpty && line.contains(pincode)) {
        isAddress = true;
      } else {
        // Matches address keywords
        for (var keyword in addressKeywords) {
          if (lower.contains(keyword)) {
            isAddress = true;
            break;
          }
        }
      }

      // Or contains trailing state/city patterns
      if (isAddress) {
        addressLines.add(line);
        indicesToRemove.add(i);
      }
    }

    // Remove address lines from candidates from back to front
    for (int i = indicesToRemove.length - 1; i >= 0; i--) {
      candidates.removeAt(indicesToRemove[i]);
    }

    if (addressLines.isNotEmpty) {
      address = addressLines.join(', ');

      // Extract City, State, Country from the address line containing the pincode
      String targetLine = '';
      if (pincode.isNotEmpty) {
        targetLine = addressLines.firstWhere((l) => l.contains(pincode), orElse: () => addressLines.last);
      } else {
        targetLine = addressLines.last;
      }

      // Split by comma first to preserve multi-word city names (e.g. San Francisco)
      final parts = targetLine.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      if (parts.isNotEmpty) {
        // Remove pincode
        parts.removeWhere((p) => p == pincode);
        for (int j = 0; j < parts.length; j++) {
          parts[j] = parts[j].replaceAll(pincode, '').trim();
        }
        parts.removeWhere((p) => p.isEmpty);

        if (parts.isNotEmpty) {
          final lastPart = parts.last;
          final knownCountries = ['india', 'usa', 'united states', 'uk', 'united kingdom', 'canada', 'australia'];
          if (knownCountries.contains(lastPart.toLowerCase()) || lastPart.toLowerCase() == 'us') {
            country = lastPart;
            parts.removeLast();
          }
        }

        if (parts.isNotEmpty) {
          state = parts.last;
          if (parts.length >= 2) {
            city = parts[parts.length - 2];
          }
        }
      }

      // Default country to India if pincode is 6 digits and country not set
      if (pincode.length == 6 && country.isEmpty) {
        country = 'India';
      }
    }

    // 9. Extract Name (Heuristic: First clean line that is capitalize-cased, has 2-3 words)
    int nameIdx = -1;
    for (int i = 0; i < candidates.length; i++) {
      final line = candidates[i];
      
      // Clean names should not have numbers, email signs, or url slashes
      if (RegExp(r'\d|@|\/|\\').hasMatch(line)) continue;
      
      final words = line.split(' ').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
      
      // Heuristic: Name is typically 2 to 3 words
      if (words.length >= 2 && words.length <= 4) {
        bool allCapitalized = true;
        for (var word in words) {
          if (word.isEmpty) continue;
          final firstLetter = word[0];
          // Check if capitalized
          if (firstLetter != firstLetter.toUpperCase() || RegExp(r'^[a-zA-Z]$').hasMatch(firstLetter) == false) {
            allCapitalized = false;
            break;
          }
        }
        
        if (allCapitalized) {
          nameIdx = i;
          break;
        }
      }
    }

    if (nameIdx != -1) {
      name = candidates[nameIdx];
      candidates.removeAt(nameIdx);
    } else {
      // Fallback: If no capitalized name found, check the first line of the card
      if (candidates.isNotEmpty) {
        name = candidates[0];
        candidates.removeAt(0);
      }
    }

    // 10. Anything remaining goes to unclassified/notes
    unclassified.addAll(candidates);

    return CardData(
      name: name,
      designation: designation,
      company: company,
      phone: phone,
      altPhone: altPhone,
      email: email,
      website: website,
      address: address,
      city: city,
      state: state,
      country: country,
      pincode: pincode,
      notes: unclassified.join('\n'),
      imagePath: imagePath,
      scanDate: DateTime.now(),
    );
  }

  /// Cleans formatting from phone numbers
  String _cleanPhoneNumber(String input) {
    // Remove labels like M:, Mobile:, etc.
    String clean = input.replaceAll(RegExp(r'(mob(ile)?|cell|tel|p(h(one)?)?|off(ice)?|land(line)?|alt(ernate)?)\s*[:\-\+]?', caseSensitive: false), '');
    clean = clean.trim();
    // Return formatted string with spacing preserved if not excessive
    return clean;
  }

  bool _isPhoneLine(String line) {
    final lower = line.toLowerCase();
    final addressKeywords = ['street', 'road', 'sector', 'plot', 'phase', 'building', 'floor', 'plaza', 'tower', 'nagar', 'avenue', 'block'];
    for (var keyword in addressKeywords) {
      if (lower.contains(keyword)) return false;
    }
    final letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    final digitCount = line.replaceAll(RegExp(r'\D'), '').length;
    if (letterCount > 6 && letterCount > digitCount) return false;
    return true;
  }

  void dispose() {
    _recognizer.close();
  }
}
