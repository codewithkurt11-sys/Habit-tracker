import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../hive_boxes.dart';
import '../models/quote.dart';
import '../default_quotes.dart';

class QuotesRepository {
  Box<Quote> get _box => Hive.box<Quote>(HiveBoxes.quotes);
  final _uuid = const Uuid();

  /// Seeds the box with the bundled default quotes if empty. Safe to call
  /// on every app start.
  Future<void> seedIfEmpty() async {
    if (_box.isNotEmpty) return;
    for (final entry in kDefaultQuotes) {
      final quote = Quote(id: _uuid.v4(), text: entry[0], author: entry[1]);
      await _box.put(quote.id, quote);
    }
  }

  List<Quote> getAll() => _box.values.toList();

  /// Deterministically picks a quote for [date] using the day-of-year and
  /// year as a stable seed, so the same date always maps to the same
  /// quote (no randomness, no reshuffling on reopen).
  Quote quoteForDate(DateTime date) {
    final all = getAll();
    if (all.isEmpty) {
      // Fallback in the unlikely event seeding hasn't happened yet.
      return Quote(id: 'fallback', text: 'Welcome to your space.', author: '');
    }
    // Sort by id for a stable ordering independent of Hive's internal
    // insertion/iteration order (which is not guaranteed across sessions).
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));

    // Use the absolute day count since the Unix epoch as the rotation
    // seed. This increases monotonically and uniquely identifies a
    // calendar day, avoiding any string-concatenation edge cases (e.g.
    // ambiguity between day 1 of year 2027 and day 12 of year 270).
    final epochDay = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(1970, 1, 1)).inDays;
    final index = epochDay % sorted.length;
    return sorted[index];
  }

  Future<Quote> addCustom({
    required String text,
    required String author,
  }) async {
    final quote = Quote(
      id: _uuid.v4(),
      text: text,
      author: author.isEmpty ? 'You' : author,
      isCustom: true,
    );
    await _box.put(quote.id, quote);
    return quote;
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
