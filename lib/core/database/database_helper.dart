import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/models/card_data.dart';
import '../../data/models/excel_ref.dart';
import '../../data/models/digital_card.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kloudera_scanner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  FutureOr<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE excel_refs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        file_path TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE scanned_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        excel_ref_id INTEGER,
        name TEXT,
        designation TEXT,
        company TEXT,
        phone TEXT,
        alt_phone TEXT,
        email TEXT,
        website TEXT,
        address TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        pincode TEXT,
        notes TEXT,
        image_path TEXT,
        scan_date TEXT NOT NULL,
        FOREIGN KEY (excel_ref_id) REFERENCES excel_refs (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE digital_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanned_card_id INTEGER NOT NULL,
        qr_code_path TEXT,
        vcf_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (scanned_card_id) REFERENCES scanned_cards (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- ExcelRefs Operations ---
  Future<int> insertExcelRef(ExcelRef ref) async {
    final db = await instance.database;
    return await db.insert('excel_refs', ref.toMap());
  }

  Future<List<ExcelRef>> getExcelRefs() async {
    final db = await instance.database;
    final maps = await db.query('excel_refs', orderBy: 'created_at DESC');
    return maps.map((map) => ExcelRef.fromMap(map)).toList();
  }

  Future<ExcelRef?> getExcelRef(int id) async {
    final db = await instance.database;
    final maps = await db.query('excel_refs', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return ExcelRef.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateExcelRef(ExcelRef ref) async {
    final db = await instance.database;
    return await db.update(
      'excel_refs',
      ref.toMap(),
      where: 'id = ?',
      whereArgs: [ref.id],
    );
  }

  Future<int> deleteExcelRef(int id) async {
    final db = await instance.database;
    return await db.delete(
      'excel_refs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- ScannedCards Operations ---
  Future<int> insertCard(CardData card) async {
    final db = await instance.database;
    return await db.insert('scanned_cards', card.toMap());
  }

  Future<List<CardData>> getCards({String? query, String? companyFilter, int? excelSheetFilter}) async {
    final db = await instance.database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      whereClause = '(name LIKE ? OR company LIKE ? OR phone LIKE ? OR email LIKE ?)';
      final searchVal = '%$query%';
      whereArgs.addAll([searchVal, searchVal, searchVal, searchVal]);
    }

    if (companyFilter != null && companyFilter.isNotEmpty) {
      if (whereClause != null) {
        whereClause += ' AND company = ?';
      } else {
        whereClause = 'company = ?';
      }
      whereArgs.add(companyFilter);
    }

    if (excelSheetFilter != null) {
      if (whereClause != null) {
        whereClause += ' AND excel_ref_id = ?';
      } else {
        whereClause = 'excel_ref_id = ?';
      }
      whereArgs.add(excelSheetFilter);
    }

    final maps = await db.query(
      'scanned_cards',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'scan_date DESC',
    );

    return maps.map((map) => CardData.fromMap(map)).toList();
  }

  Future<CardData?> getCard(int id) async {
    final db = await instance.database;
    final maps = await db.query('scanned_cards', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return CardData.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCard(CardData card) async {
    final db = await instance.database;
    return await db.update(
      'scanned_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    final db = await instance.database;
    return await db.delete(
      'scanned_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<CardData?> checkDuplicate(String phone, String email) async {
    final db = await instance.database;
    if (phone.isEmpty && email.isEmpty) return null;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (phone.isNotEmpty && email.isNotEmpty) {
      whereClause = 'phone = ? OR email = ?';
      whereArgs.addAll([phone, email]);
    } else if (phone.isNotEmpty) {
      whereClause = 'phone = ?';
      whereArgs.add(phone);
    } else if (email.isNotEmpty) {
      whereClause = 'email = ?';
      whereArgs.add(email);
    }

    final maps = await db.query(
      'scanned_cards',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return CardData.fromMap(maps.first);
    }
    return null;
  }

  Future<List<String>> getDistinctCompanies() async {
    final db = await instance.database;
    final maps = await db.rawQuery('SELECT DISTINCT company FROM scanned_cards WHERE company IS NOT NULL AND company != "" ORDER BY company ASC');
    return maps.map((map) => map['company'] as String).toList();
  }

  // --- DigitalCards Operations ---
  Future<int> insertDigitalCard(DigitalCard digitalCard) async {
    final db = await instance.database;
    return await db.insert('digital_cards', digitalCard.toMap());
  }

  Future<List<DigitalCard>> getDigitalCards() async {
    final db = await instance.database;
    final maps = await db.query('digital_cards', orderBy: 'created_at DESC');
    return maps.map((map) => DigitalCard.fromMap(map)).toList();
  }

  Future<DigitalCard?> getDigitalCardByScannedCardId(int scannedCardId) async {
    final db = await instance.database;
    final maps = await db.query(
      'digital_cards',
      where: 'scanned_card_id = ?',
      whereArgs: [scannedCardId],
    );
    if (maps.isNotEmpty) {
      return DigitalCard.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deleteDigitalCard(int id) async {
    final db = await instance.database;
    return await db.delete(
      'digital_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get statistics
  Future<Map<String, int>> getStats() async {
    final db = await instance.database;
    final cardCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM scanned_cards');
    final fileCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM excel_refs');

    final cardsScanned = Sqflite.firstIntValue(cardCountRes) ?? 0;
    final excelFiles = Sqflite.firstIntValue(fileCountRes) ?? 0;

    return {
      'cardsScanned': cardsScanned,
      'excelFiles': excelFiles,
    };
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
