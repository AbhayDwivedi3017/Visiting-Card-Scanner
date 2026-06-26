import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repository/card_repository.dart';
import '../../data/repository/card_repository_impl.dart';
import '../../data/models/card_data.dart';
import '../../data/models/excel_ref.dart';
import '../../data/models/digital_card.dart';

// 1. Repository Provider
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepositoryImpl();
});

// 2. Cards Notifier & Provider
class CardsNotifier extends StateNotifier<AsyncValue<List<CardData>>> {
  final CardRepository _repository;

  CardsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCards();
  }

  Future<void> loadCards({String? query, String? companyFilter, int? excelSheetFilter}) async {
    state = const AsyncValue.loading();
    try {
      final cards = await _repository.getCards(
        query: query,
        companyFilter: companyFilter,
        excelSheetFilter: excelSheetFilter,
      );
      state = AsyncValue.data(cards);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<int> saveCard(CardData card) async {
    try {
      final id = await _repository.saveCard(card);
      // Reload cards list to reflect changes
      await loadCards();
      return id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCard(CardData card) async {
    try {
      await _repository.updateCard(card);
      await loadCards();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCard(int id) async {
    try {
      await _repository.deleteCard(id);
      await loadCards();
    } catch (e) {
      rethrow;
    }
  }
}

final cardsProvider = StateNotifierProvider<CardsNotifier, AsyncValue<List<CardData>>>((ref) {
  final repo = ref.watch(cardRepositoryProvider);
  return CardsNotifier(repo);
});

// 3. Excel Refs Notifier & Provider
class ExcelRefsNotifier extends StateNotifier<AsyncValue<List<ExcelRef>>> {
  final CardRepository _repository;

  ExcelRefsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRefs();
  }

  Future<void> loadRefs() async {
    state = const AsyncValue.loading();
    try {
      final refs = await _repository.getExcelRefs();
      state = AsyncValue.data(refs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ExcelRef> createExcel(String name) async {
    try {
      final ref = await _repository.createExcelRef(name);
      await loadRefs();
      return ref;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> renameExcel(ExcelRef ref, String newName) async {
    try {
      await _repository.renameExcelRef(ref, newName);
      await loadRefs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExcel(ExcelRef ref) async {
    try {
      await _repository.deleteExcelRef(ref);
      await loadRefs();
    } catch (e) {
      rethrow;
    }
  }
}

final excelRefsProvider = StateNotifierProvider<ExcelRefsNotifier, AsyncValue<List<ExcelRef>>>((ref) {
  final repo = ref.watch(cardRepositoryProvider);
  return ExcelRefsNotifier(repo);
});

// 4. Statistics Notifier & Provider
class StatsNotifier extends StateNotifier<AsyncValue<Map<String, int>>> {
  final CardRepository _repository;

  StatsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadStats();
  }

  Future<void> loadStats() async {
    try {
      final stats = await _repository.getStats();
      state = AsyncValue.data(stats);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final statsProvider = StateNotifierProvider<StatsNotifier, AsyncValue<Map<String, int>>>((ref) {
  final repo = ref.watch(cardRepositoryProvider);
  // Watch card and excel providers to trigger rebuilds when lists change
  ref.watch(cardsProvider);
  ref.watch(excelRefsProvider);
  return StatsNotifier(repo);
});

// 5. Distinct Companies Provider
final companiesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(cardRepositoryProvider);
  ref.watch(cardsProvider); // Reload when cards change
  return await repo.getDistinctCompanies();
});

// 6. Saved Digital Cards Provider
class DigitalCardsNotifier extends StateNotifier<AsyncValue<List<DigitalCard>>> {
  final CardRepository _repository;

  DigitalCardsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadDigitalCards();
  }

  Future<void> loadDigitalCards() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getDigitalCards();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveDigitalCard(DigitalCard card) async {
    try {
      await _repository.saveDigitalCard(card);
      await loadDigitalCards();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDigitalCard(int id) async {
    try {
      await _repository.deleteDigitalCard(id);
      await loadDigitalCards();
    } catch (e) {
      rethrow;
    }
  }
}

final digitalCardsProvider = StateNotifierProvider<DigitalCardsNotifier, AsyncValue<List<DigitalCard>>>((ref) {
  final repo = ref.watch(cardRepositoryProvider);
  return DigitalCardsNotifier(repo);
});

// 7. Theme Mode Notifier & Provider
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false); // false = Light Mode, true = Dark Mode

  void toggleTheme() {
    state = !state;
  }
}

final darkModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});
