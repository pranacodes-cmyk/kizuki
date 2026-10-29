import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/logic.dart';
import 'strings.g.dart';

/// The learner's app language — mirrors src/lib/i18n.ts.
///
/// Interface text is written in English in the code and wrapped in [tr]; the translations are
/// generated into strings.g.dart (scripts/i18n/gen_strings.ts) from the reviewed catalog in
/// scripts/i18n/ui/. Anything not translated shows in English, never as a key.
///
/// The choice is a device setting (not learner state), so signing in or switching accounts
/// never changes the language the person picked.
class I18n {
  static const _key = 'kizuki.lang';

  /// Current language code (see `languages` in logic.dart). The app rebuilds when it changes.
  static final lang = ValueNotifier<String>('en');

  /// True once the person picked a language (the first-run picker is then skipped).
  static bool chosen = false;

  static Map<String, String>? _table;

  static Future<void> load() async {
    // Month and weekday names for every app language (DateFormat follows the app language).
    try {
      await initializeDateFormatting();
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_key);
      if (isLangCode(saved)) {
        chosen = true;
        _apply(saved!);
      }
    } catch (_) {}
  }

  /// The language the phone suggests (its system language), English when unsupported.
  static String suggested() => languageForLocale(PlatformDispatcher.instance.locale.toLanguageTag());

  static Future<void> set(String code) async {
    if (!isLangCode(code)) return;
    chosen = true;
    _apply(code);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, code);
    } catch (_) {}
  }

  static void _apply(String code) {
    _table = code == 'en' ? null : uiStrings[code];
    Intl.defaultLocale = code == 'pt' ? 'pt_BR' : code;
    lang.value = code;
  }

  static Language get language => languages.firstWhere((l) => l.code == lang.value, orElse: () => languages.first);

  @visibleForTesting
  static void debugSet(String code) => _apply(code);
}

/// Interface text in the learner's language: [en] is the English text (and the lookup key);
/// `{name}` placeholders are filled from [vars].
String tr(String en, [Map<String, Object?>? vars]) => fillTemplate(I18n._table?[en] ?? en, vars);

/// Translated text whose [bracketed] part gets [highlight] (highlightParts) — Hi in ui.tsx.
List<InlineSpan> trSpans(String en, TextStyle highlight, [Map<String, Object?>? vars]) =>
    [for (final (t, hi) in highlightParts(tr(en, vars))) TextSpan(text: t, style: hi ? highlight : null)];

/// [en] in a specific language (the picker previews its own text before the choice is saved).
String trIn(String code, String en, [Map<String, Object?>? vars]) => fillTemplate((code == 'en' ? null : uiStrings[code])?[en] ?? en, vars);

/// Count text: [one] when [n] is 1, else [other]; both get `{n}` (and any [vars]).
String trn(int n, String one, String other, [Map<String, Object?>? vars]) => tr(n == 1 ? one : other, {'n': n, ...?vars});
