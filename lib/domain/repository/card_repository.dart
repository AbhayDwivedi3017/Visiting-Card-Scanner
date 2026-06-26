import '../../data/models/card_data.dart';
import '../../data/models/excel_ref.dart';
import '../../data/models/digital_card.dart';

abstract class CardRepository {
  Future<List<CardData>> getCards({String? query, String? companyFilter, int? excelSheetFilter});
  Future<CardData?> getCard(int id);
  Future<int> saveCard(CardData card);
  Future<int> updateCard(CardData card);
  Future<int> deleteCard(int id);
  
  Future<CardData?> checkDuplicate(String phone, String email);
  Future<List<String>> getDistinctCompanies();
  
  Future<List<ExcelRef>> getExcelRefs();
  Future<ExcelRef?> getExcelRef(int id);
  Future<ExcelRef> createExcelRef(String name);
  Future<ExcelRef> renameExcelRef(ExcelRef ref, String newName);
  Future<void> deleteExcelRef(ExcelRef ref);
  
  Future<List<DigitalCard>> getDigitalCards();
  Future<DigitalCard?> getDigitalCard(int scannedCardId);
  Future<int> saveDigitalCard(DigitalCard digitalCard);
  Future<void> deleteDigitalCard(int id);
  
  Future<Map<String, int>> getStats();
}
