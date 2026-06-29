import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/models/card_data.dart';
import '../data/models/excel_ref.dart';
import '../core/database/database_helper.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._init();
  
  ExcelService._init();

  final List<String> _headers = [
    'Name', 'Designation', 'Company', 'Phone', 'Alternate Phone', 
    'Email', 'Website', 'LinkedIn', 'Address', 'City', 'State', 'Country', 
    'Pincode', 'Notes', 'Scan Date'
  ];

  /// Gets the system documents directory where Excel files are stored
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Creates a new Excel sheet with standard headers
  Future<ExcelRef> createExcelFile(String name) async {
    try {
      // Clean name
      String fileName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!fileName.endsWith('.xlsx')) {
        fileName = '$fileName.xlsx';
      }

      final path = await _localPath;
      final fullPath = p.join(path, fileName);
      final file = File(fullPath);

      if (await file.exists()) {
        throw Exception('File already exists at $fullPath');
      }

      // Create Excel Workbook
      final excel = Excel.createExcel();
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      final Sheet sheet = excel[defaultSheet];

      // Append headers
      sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

      // Save workbook bytes
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.create(recursive: true);
        await file.writeAsBytes(fileBytes);
      } else {
        throw Exception('Failed to save Excel bytes');
      }

      // Save to database
      final ref = ExcelRef(
        name: fileName,
        filePath: fullPath,
        createdAt: DateTime.now(),
      );

      final id = await DatabaseHelper.instance.insertExcelRef(ref);
      return ref.copyWith(id: id);
    } catch (e) {
      throw Exception('Error creating Excel file: $e');
    }
  }

  /// Appends a new card row to the specified Excel file
  Future<void> appendRow(String filePath, CardData card) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Excel file does not exist at $filePath');
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      final Sheet sheet = excel[defaultSheet];

      // Convert card data row to CellValues
      final rowData = card.toExcelRow().map((val) {
        if (val == null) return TextCellValue('');
        return TextCellValue(val.toString());
      }).toList();

      sheet.appendRow(rowData);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
      }
    } catch (e) {
      throw Exception('Error appending row to Excel: $e');
    }
  }

  /// Updates an existing card row in the Excel sheet
  Future<void> updateRow(String filePath, CardData oldCard, CardData newCard) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Excel file does not exist at $filePath');
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      final Sheet sheet = excel[defaultSheet];

      int targetRowIndex = -1;

      // Find the row containing the old card (match by email or phone)
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        // Columns: Phone is col 3, Email is col 5
        final phoneVal = row.length > 3 ? row[3]?.value?.toString() : '';
        final emailVal = row.length > 5 ? row[5]?.value?.toString() : '';

        if ((oldCard.phone.isNotEmpty && phoneVal == oldCard.phone) ||
            (oldCard.email.isNotEmpty && emailVal == oldCard.email)) {
          targetRowIndex = i;
          break;
        }
      }

      if (targetRowIndex != -1) {
        final newRow = newCard.toExcelRow();
        for (int col = 0; col < newRow.length; col++) {
          final val = newRow[col];
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: targetRowIndex),
            TextCellValue(val?.toString() ?? ''),
          );
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
        }
      } else {
        // Fallback: If not found, append it as a new row
        await appendRow(filePath, newCard);
      }
    } catch (e) {
      throw Exception('Error updating row in Excel: $e');
    }
  }

  /// Deletes a card row from the Excel sheet
  Future<void> deleteRow(String filePath, CardData card) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      final Sheet sheet = excel[defaultSheet];

      int targetRowIndex = -1;

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final phoneVal = row.length > 3 ? row[3]?.value?.toString() : '';
        final emailVal = row.length > 5 ? row[5]?.value?.toString() : '';

        if ((card.phone.isNotEmpty && phoneVal == card.phone) ||
            (card.email.isNotEmpty && emailVal == card.email)) {
          targetRowIndex = i;
          break;
        }
      }

      if (targetRowIndex != -1) {
        // Excel package doesn't have direct deleteRow(index), so we shift rows manually
        // or clear cell values. Clearing cells or rebuilding sheet are common options.
        // Let's clear the row contents or rewrite the spreadsheet.
        // Rebuilding is safer to maintain sheet integrity without blank rows.
        
        final List<List<CellValue>> allRows = [];
        // Keep header
        allRows.add(sheet.rows[0].map((c) => TextCellValue(c?.value?.toString() ?? '')).toList());

        for (int i = 1; i < sheet.maxRows; i++) {
          if (i == targetRowIndex) continue; // Skip deleted row
          final row = sheet.rows[i];
          allRows.add(row.map((c) => TextCellValue(c?.value?.toString() ?? '')).toList());
        }

        // Clear sheet and rewrite
        // Excel package updateCell range
        final excelNew = Excel.createExcel();
        final String newSheetName = excelNew.getDefaultSheet() ?? 'Sheet1';
        final Sheet newSheet = excelNew[newSheetName];

        for (var row in allRows) {
          newSheet.appendRow(row);
        }

        final fileBytes = excelNew.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
        }
      }
    } catch (e) {
      throw Exception('Error deleting row from Excel: $e');
    }
  }

  /// Renames an Excel file on disk and in the DB
  Future<ExcelRef> renameExcelFile(ExcelRef ref, String newName) async {
    try {
      String cleanName = newName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!cleanName.endsWith('.xlsx')) {
        cleanName = '$cleanName.xlsx';
      }

      final file = File(ref.filePath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist at ${ref.filePath}');
      }

      final parentPath = file.parent.path;
      final newFullPath = p.join(parentPath, cleanName);
      
      if (await File(newFullPath).exists()) {
        throw Exception('Target file already exists: $cleanName');
      }

      // Rename on disk
      await file.rename(newFullPath);

      // Update in DB
      final updatedRef = ref.copyWith(
        name: cleanName,
        filePath: newFullPath,
      );

      await DatabaseHelper.instance.updateExcelRef(updatedRef);
      return updatedRef;
    } catch (e) {
      throw Exception('Error renaming Excel file: $e');
    }
  }

  /// Deletes an Excel file from disk and DB
  Future<void> deleteExcelFile(ExcelRef ref) async {
    try {
      final file = File(ref.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      if (ref.id != null) {
        await DatabaseHelper.instance.deleteExcelRef(ref.id!);
      }
    } catch (e) {
      throw Exception('Error deleting Excel file: $e');
    }
  }
}
