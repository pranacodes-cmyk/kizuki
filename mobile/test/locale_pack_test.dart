// Language packs: download only with access → every file checked on arrival → whole pack
// parsed → used from the next start; a cut or corrupt download keeps what the learner has and
// resumes later. Mirrors the web behaviour in src/lib/locale-pack.ts.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimi/data/content.dart';
import 'package:mimi/logic/logic.dart';
import 'package:mimi/services/locale_pack.dart';

String sha(String s) => sha256.convert(utf8.encode(s)).toString();
int size(String s) => utf8.encode(s).length;

const primary = 'https://backend.example.com/storage/v1/object/public/content/locale/vi/v2.json';
const mirror = 'https://pub-x.r2.dev/locale/vi/v2.json';

final lines = jsonEncode({'v1-0': {'s': 'abcd1234', 't': 'Xin chào', 'l': ['Chào']}});
final dictFile = jsonEncode({'1': {'m': ['con mèo'], 'ex': <String>[]}});
final grammarFile = jsonEncode({'〜て — request': '〜て — lời nhờ'});
final packFiles = <String, String>{
  'lines.json': lines,
  'dict.json': dictFile,
  'grammar.json': grammarFile,
  for (var i = 0; i < 32; i++) 'notes-${i.toString().padLeft(2, '0')}.json': i == 3 ? jsonEncode({'v1-0': {'s': 'abcd1234', 'w': <String, Object>{}, 'l': <String, Object>{}}}) : '{}',
};
String manifest({int version = 2}) => jsonEncode({
      'lang': 'vi',
      'version': version,
      'files': [for (final e in packFiles.entries) {'name': e.key, 'sha256': sha(e.value), 'bytes': size(e.value)}],
    });

Map<String, Object?> pointers({int version = 2}) => {'vi': {'v': version, 'urls': [primary, mirror]}};

/// Fake backend + two mirrors. [down] mirrors answer 503; [corrupt] files arrive changed.
http.Client server(Object? row, {Set<String> down = const {}, Set<String> corrupt = const {}, List<String>? fetched}) {
  final byHash = {for (final f in packFiles.values) sha(f): f};
  return MockClient((req) async {
    final u = req.url.toString();
    if (req.url.path.endsWith('/rest/v1/content_settings')) return http.Response(jsonEncode([{'locale_packs': row}]), 200);
    final host = req.url.host;
    if (down.contains(host)) return http.Response('down', 503);
    if (u == primary || u == mirror) return http.Response.bytes(utf8.encode(manifest()), 200);
    final m = RegExp(r'/locale/objects/([0-9a-f]{64})\.json\.gz$').firstMatch(req.url.path);
    final text = m == null ? null : byHash[m.group(1)];
    if (text == null) return http.Response('missing', 404);
    fetched?.add('$host ${m!.group(1)}');
    return http.Response.bytes(gzip.encode(utf8.encode(corrupt.contains(text) ? '$text ' : text)), 200);
  });
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kizuki-locale'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('nothing downloads for English or without learning access', () async {
    final asked = <String>[];
    final client = MockClient((req) async {
      asked.add(req.url.toString());
      return http.Response('[]', 200);
    });
    final store = LocalePackStore(dir, client);
    expect(await store.sync('en', hasAccess: true), 'skip');
    expect(await store.sync('vi', hasAccess: false), 'skip');
    expect(asked, isEmpty);
  });

  test('a pack downloads from the second mirror when the first is down, then is used', () async {
    final store = LocalePackStore(dir, server(pointers(), down: {'backend.example.com'}));
    expect(await store.active('vi'), null);
    expect(await store.sync('vi', hasAccess: true), 'activated');
    final p = (await store.active('vi'))!;
    expect(p.version, 2);
    expect(p.url, mirror);
    expect(await store.readText(p, 'lines.json'), lines);
    expect(await store.sync('vi', hasAccess: true), 'keep');
  });

  test('a corrupt file records nothing; the retry fetches only what is still missing', () async {
    final fetched = <String>[];
    final bad = LocalePackStore(dir, server(pointers(), corrupt: {dictFile}, fetched: fetched));
    expect(await bad.sync('vi', hasAccess: true), 'failed:checksum');
    expect(await bad.active('vi'), null);
    final before = fetched.length;
    fetched.clear();
    final good = LocalePackStore(dir, server(pointers(), fetched: fetched));
    expect(await good.sync('vi', hasAccess: true), 'activated');
    expect(before, greaterThan(0));
    // lines.json arrived intact the first time and is not fetched again.
    expect(fetched.any((f) => f.endsWith(sha(lines))), false);
    expect(fetched.any((f) => f.endsWith(sha(dictFile))), true);
  });

  test('a file changed on the device after activation is caught when read', () async {
    final store = LocalePackStore(dir, server(pointers()));
    expect(await store.sync('vi', hasAccess: true), 'activated');
    final p = (await store.active('vi'))!;
    final f = store.objectFile(p.files['grammar.json']!.sha256);
    final changed = (await f.readAsString()).replaceAll('nhờ', 'nhớ');
    await f.writeAsString(changed);
    expect(utf8.encode(changed).length, size(grammarFile)); // same size: only the checksum catches it
    await expectLater(store.readText(p, 'grammar.json'), throwsA(isA<FormatException>()));
  });

  test('a switched-off language returns to the starter translations', () async {
    final store = LocalePackStore(dir, server(pointers()));
    expect(await store.sync('vi', hasAccess: true), 'activated');
    final off = LocalePackStore(dir, server(<String, Object>{}));
    expect(await off.sync('vi', hasAccess: true), 'none');
    expect(await off.active('vi'), null);
  });

  test('an unreachable backend is reported as offline (retried later)', () async {
    final store = LocalePackStore(dir, MockClient((_) async => http.Response('no', 500)));
    expect(await store.sync('vi', hasAccess: true), 'offline');
  });

  test('the library shows through a translation overlay and back to English', () {
    final index = jsonEncode({
      'version': 1, 'videos': {'v1': {'title': 'Talk', 'channel': 'Ch', 'channelUrl': 'https://youtube.com/@ch'}}, 'starter': ['v1-0'],
      'clips': [
        {'id': 'v1-0', 'videoId': 'v1', 'title': 'Hello', 'level': 'N5', 'start': 0, 'end': 4, 'topics': ['daily'], 'grammar': ['〜て — request'], 'quality': 4,
          'lines': [{'start': 0, 'end': 2, 'en': 'Hi', 'ja': 'サメ', 'words': [{'s': 'サメ', 'r': '', 't0': 0, 't1': 1, 'd': '1'}]}]},
      ],
    });
    final dict = jsonEncode({'1': {'w': '鮫', 'r': 'さめ', 'j': 5, 'c': true, 'm': [{'pos': ['n'], 'g': 'shark'}], 'ex': <Object>[]}});
    final c = Content.fromJson(index, dict);
    final sig = clipLocaleSig(c.clips.first.lines);
    c.applyOverlay('vi', {'v1-0': {'s': sig, 't': 'Xin chào', 'l': ['Chào']}}, {'1': {'m': ['cá mập'], 'ex': <String>[]}}, {'〜て — request': '〜て — lời nhờ'});
    expect(c.lang, 'vi');
    expect(c.byId['v1-0']!.title, 'Xin chào');
    expect(c.clips.first.lines.first.en, 'Chào');
    expect(c.clips.first.lines.first.ja, 'サメ');
    expect(c.clips.first.grammar, ['〜て — lời nhờ']);
    expect(c.dict['1']!.m.first.g, 'cá mập');
    c.applyOverlay('en', null, null, null);
    expect(c.byId['v1-0']!.title, 'Hello');
    expect(c.dict['1']!.m.first.g, 'shark');
  });
}
