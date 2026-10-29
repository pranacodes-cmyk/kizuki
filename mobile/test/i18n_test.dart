import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/paywall.dart';
import 'package:mimi/i18n/i18n.dart';
import 'package:mimi/i18n/strings.g.dart';

// Mirrors src/lib/i18n.test.ts.
void main() {
  const langs = ['vi', 'id', 'th', 'ko', 'pt'];
  final web = jsonDecode(File('../src/lib/i18n-strings.json').readAsStringSync()) as Map<String, dynamic>;
  final keys = [for (final k in jsonDecode(File('../scripts/i18n/ui/keys.json').readAsStringSync()) as List) (k as Map)['key'] as String];
  List<String> placeholders(String s) => RegExp(r'\{\w+\}').allMatches(s).map((m) => m.group(0)!).toList()..sort();
  int count(String s, String m) => s.split(m).length - 1;

  tearDown(() => I18n.debugSet('en'));

  test('the app catalog matches the web catalog and covers every string', () {
    for (final l in langs) {
      expect(uiStrings[l], (web[l] as Map).cast<String, String>(), reason: l);
      expect(keys.where((k) => (uiStrings[l]![k] ?? '').trim().isEmpty).toList(), isEmpty, reason: l);
    }
  });

  test('translations keep placeholders, highlight brackets, bold markers and line breaks', () {
    for (final l in langs) {
      uiStrings[l]!.forEach((en, t) {
        expect(placeholders(t), placeholders(en), reason: '$l: $en');
        for (final m in ['[', ']', '**', '\n']) {
          expect(count(t, m), count(en, m), reason: '$l $m: $en');
        }
      });
    }
  });

  test('tr shows the chosen language, falls back to English and picks plural forms', () {
    I18n.debugSet('vi');
    expect(tr('Continue'), uiStrings['vi']!['Continue']);
    expect(tr('Day {n}', {'n': 5}), uiStrings['vi']!['Day {n}']!.replaceAll('{n}', '5'));
    I18n.debugSet('ko');
    expect(tr('A sentence that is not in the catalog'), 'A sentence that is not in the catalog');
    I18n.debugSet('pt');
    expect(trn(1, '{n} clip', '{n} clips'), uiStrings['pt']!['{n} clip']!.replaceAll('{n}', '1'));
    expect(trn(3, '{n} clip', '{n} clips'), uiStrings['pt']!['{n} clips']!.replaceAll('{n}', '3'));
    expect(trIn('id', 'Continue'), uiStrings['id']!['Continue']);
  });

  test('paywall keeps the live store price inside translated plan text', () {
    I18n.debugSet('vi');
    expect(priceLine(plans['yearly']!), contains(r'$54.99'));
    expect(priceLine(plans['yearly']!), isNot(contains('days free')));
    expect(planSub(plans['yearly']!), contains(r'$54.99'));
    expect(planBadge(plans['yearly']!), contains('58'));
    I18n.debugSet('en');
    expect(planSub(plans['yearly']!), r'12 months · $54.99');
    expect(planBadge(plans['yearly']!), 'Save 58%');
  });
}
