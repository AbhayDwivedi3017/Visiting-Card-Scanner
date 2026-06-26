import '../../domain/repository/card_repository.dart';
import '../../core/database/database_helper.dart';
import '../../services/excel_service.dart';
import '../models/card_data.dart';
import '../models/excel_ref.dart';
import '../models/digital_card.dart';

class CardRepositoryImpl implements CardRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExcelService _excelService = ExcelService.instance;

  @override
  Future<List<CardData>> getCards({String? query, String? companyFilter, int? excelSheetFilter}) {
    return _dbHelper.getCards(
      query: query,
      companyFilter: companyFilter,
      excelSheetFilter: excelSheetFilter,
    );
  }

  @override
  Future<CardData?> getCard(int id) {
    return _dbHelper.getCard(id);
  }

  @override
  Future<int> saveCard(CardData card) async {
    // 1. Insert into database
    final cardId = await _dbHelper.insertCard(card);
    final savedCard = card.copyWith(id: cardId);

    // 2. If it is linked to an Excel sheet, append row to XLSX file
    if (card.excelRefId != null) {
      final excelRef = await _dbHelper.getExcelRef(card.excelRefId!);
      if (excelRef != null) {
        await _excelService.appendRow(excelRef.filePath, savedCard);
      }
    }

    return cardId;
  }

  @override
  Future<int> updateCard(CardData card) async {
    if (card.id == null) return -1;
    
    // Get old card details to find it in Excel
    final oldCard = await _dbHelper.getCard(card.id!);

    // Update in database
    final rowsAffected = await _dbHelper.updateCard(card);

    if (rowsAffected > 0 && oldCard != null) {
      // Sync with Excel
      // Scenario A: Card was linked to Excel sheet, and now it is linked to the SAME or DIFFERENT sheet
      if (card.excelRefId != null) {
        final newExcelRef = await _dbHelper.getExcelRef(card.excelRefId!);
        if (newExcelRef != null) {
          if (oldCard.excelRefId == card.excelRefId) {
            // Update row in same excel sheet
            await _excelService.updateRow(newExcelRef.filePath, oldCard, card);
          } else {
            // Deleted from old sheet (if exists)
            if (oldCard.excelRefId != null) {
              final oldExcelRef = await _dbHelper.getExcelRef(oldCard.excelRefId!);
              if (oldExcelRef != null) {
                await _excelService.deleteRow(oldExcelRef.filePath, oldCard);
              }
            }
            // Append to new excel sheet
            await _excelService.appendRow(newExcelRef.filePath, card);
          }
        }
      } 
      // Scenario B: Card was linked to Excel, and now unlinked (excelRefId is null)
      else if (oldCard.excelRefId != null) {
        final oldExcelRef = await _dbHelper.getExcelRef(oldCard.excelRefId!);
        if (oldExcelRef != null) {
          await _excelService.deleteRow(oldExcelRef.filePath, oldCard);
        }
      }
    }

    return rowsAffected;
  }

  @override
  Future<int> deleteCard(int id) async {
    final card = await _dbHelper.getCard(id);
    if (card == null) return 0;

    // Delete from Excel sheet if linked
    if (card.excelRefId != null) {
      final excelRef = await _dbHelper.getExcelRef(card.excelRefId!);
      if (excelRef != null) {
        await _excelService.deleteRow(excelRef.filePath, card);
      }
    }

    // Delete from database
    return await _dbHelper.deleteCard(id);
  }

  @override
  Future<CardData?> checkDuplicate(String phone, String email) {
    return _dbHelper.checkDuplicate(phone, email);
  }

  @override
  Future<List<String>> getDistinctCompanies() {
    return _dbHelper.getDistinctCompanies();
  }

  @override
  Future<List<ExcelRef>> getExcelRefs() {
    return _dbHelper.getExcelRefs();
  }

  @override
  Future<ExcelRef?> getExcelRef(int id) {
    return _dbHelper.getExcelRef(id);
  }

  @override
  Future<ExcelRef> createExcelRef(String name) {
    return _excelService.createExcelFile(name);
  }

  @override
  Future<ExcelRef> renameExcelRef(ExcelRef ref, String newName) {
    return _excelService.renameExcelFile(ref, newName);
  }

  @override
  Future<void> deleteExcelRef(ExcelRef ref) async {
    // 1. Delete Excel file and reference
    await _excelService.deleteExcelFile(ref);
    
    // Note: SQLite table constraints will set excel_ref_id to NULL automatically for related scanned cards.
  }

  @override
  Future<List<DigitalCard>> getDigitalCards() {
    return _dbHelper.getDigitalCards();
  }

  @override
  Future<DigitalCard?> getDigitalCard(int scannedCardId) {
    return _dbHelper.getDigitalCardByScannedCardId(scannedCardId);
  }

  @override
  Future<int> saveDigitalCard(DigitalCard digitalCard) {
    return _dbHelper.insertDigitalCard(digitalCard);
  }

  @override
  Future<void> deleteDigitalCard(int id) async {
    await _dbHelper.deleteDigitalCard(id);
  }

  @override
  Future<Map<String, int>> getStats() {
    return _dbHelper.getStats();
  }
}
