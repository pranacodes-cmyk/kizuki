// Server clip packs: download → verify → use from the next start; the bundle is always the
// fallback. Mirrors the web behaviour in src/lib/content-pack.ts.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimi/services/content_pack.dart';

class _Bundle extends CachingAssetBundle {
  final Map<String, String> files;
  _Bundle(this.files);
  @override
  Future<ByteData> load(String key) async {
    final f = files[key.replaceFirst('assets/data/', '')];
    if (f == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(f)));
  }
}

String sha(String s) => sha256.convert(utf8.encode(s)).toString();
int size(String s) => utf8.encode(s).length;

const base = 'https://cdn.example.com/storage/v1/object/public/content';
const manifestUrl = '$base/packs/v2.json';
final videos = {'v1': {'title': 'Talk', 'channel': 'Ch', 'channelUrl': 'https://youtube.com/@ch'}};
final clip = {
  'id': 'v1-0', 'videoId': 'v1', 'title': 'Hi', 'level': 'N5', 'start': 0, 'end': 4.5, 'topics': ['daily'], 'grammar': <String>[], 'quality': 4,
  'lines': [{'start': 0, 'end': 2, 'en': 'Hi', 'words': [{'s': '猫', 'r': 'ねこ', 't0': 0, 't1': 1, 'd': '1'}]}],
};
final bundledIndex = jsonEncode({'version': 1, 'generatedAt': '2026-10-24', 'videos': videos, 'parts': ['content-0.json'], 'starter': ['v1-0']});
final part = jsonEncode({'clips': [clip]});
final dict = jsonEncode({'1': {'w': '猫', 'r': 'ねこ', 'j': 5, 'c': true, 'm': [{'pos': ['n'], 'g': 'cat'}], 'ex': <Object>[]}});
final packIndex = jsonEncode({'version': 2, 'generatedAt': '2026-10-25', 'videos': videos, 'parts': ['content-0.json'], 'starter': ['v1-0']});
final notes = jsonEncode({'v1-0': {'w': {'0.0': {'m': 'cat', 'n': 'A pet.'}}, 'l': <String, Object>{}}});

String manifestOf(Map<String, String> files, {List<String> notes = const ['notes-0.json']}) => jsonEncode({
      'format': 1,
      'version': 2,
      'files': [for (final e in files.entries) {'name': e.key, 'sha256': sha(e.value), 'bytes': size(e.value)}],
      'notes': notes,
    });

Map<String, Object?> row({bool enabled = true, int? version = 2, String? url = manifestUrl}) => {'updates_enabled': enabled, 'pack_version': version, 'pack_url': url};

/// Fake backend + storage. [fetched] collects the checksums of downloaded files.
http.Client server(Map<String, Object?> settings, Map<String, String> files, {List<String>? fetched, Set<String> corrupt = const {}}) {
  final byHash = {for (final f in files.values) sha(f): f};
  return MockClient((req) async {
    if (req.url.path.endsWith('/rest/v1/content_settings')) return http.Response(jsonEncode([settings]), 200);
    if (req.url.toString() == manifestUrl) return http.Response.bytes(utf8.encode(manifestOf(files)), 200);
    final m = RegExp(r'/content/objects/([0-9a-f]{64})\.json\.gz$').firstMatch(req.url.path);
    final text = m == null ? null : byHash[m.group(1)];
    if (text == null) return http.Response('missing', 404);
    fetched?.add(m!.group(1)!);
    return http.Response.bytes(gzip.encode(utf8.encode(corrupt.contains(text) ? '$text ' : text)), 200);
  });
}

void main() {
  final bundle = _Bundle({'content.json': bundledIndex, 'content-0.json': part, 'dict.json': dict});
  final packFiles = {'content.json': packIndex, 'content-0.json': part, 'dict.json': dict, 'notes-0.json': notes};
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kizuki-pack'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a newer pack downloads only what the bundle lacks, then is used from the next start', () async {
    final fetched = <String>[];
    final store = ContentPackStore(dir, server(row(), packFiles, fetched: fetched), bundle);
    expect(await store.active(1), null);
    expect(await store.sync(bundledVersion: 1), 'activated');
    expect(fetched.toSet(), {sha(packIndex), sha(notes)});
    final p = (await store.active(1))!;
    expect(p.version, 2);
    expect(p.bundled, {'content-0.json', 'dict.json'});
    expect(await store.readText(p, 'content.json'), packIndex);
    expect(await store.readText(p, 'content-0.json'), part);
    expect(await store.readText(p, 'notes-0.json'), notes);
    expect(await store.check(p), null);
    // Already have it: nothing downloads again.
    fetched.clear();
    expect(await store.sync(bundledVersion: 1), 'keep');
    expect(fetched, isEmpty);
    // A later build that bundles the same library version ignores the download.
    expect(await store.active(2), null);
  });

  test('the server off switch or a cleared link returns to the bundle and frees space', () async {
    expect(await ContentPackStore(dir, server(row(), packFiles), bundle).sync(bundledVersion: 1), 'activated');
    expect(await ContentPackStore(dir, server(row(enabled: false), packFiles), bundle).sync(bundledVersion: 1), 'bundled');
    final store = ContentPackStore(dir, server(row(url: null), packFiles), bundle);
    expect(await store.active(1), null);
    expect(Directory('${dir.path}/objects').listSync(), isEmpty);
    expect(await store.sync(bundledVersion: 1), 'bundled');
  });

  test('files the running app still reads are kept until the next start', () async {
    expect(await ContentPackStore(dir, server(row(), packFiles), bundle).sync(bundledVersion: 1), 'activated');
    final inUse = (await ContentPackStore(dir, server(row(), packFiles), bundle).active(1))!.stored;
    expect(await ContentPackStore(dir, server(row(enabled: false), packFiles), bundle).sync(bundledVersion: 1, inUse: inUse), 'bundled');
    expect(Directory('${dir.path}/objects').listSync().length, 2);
  });

  test('a pack not newer than the bundle is never downloaded', () async {
    final fetched = <String>[];
    expect(await ContentPackStore(dir, server(row(version: 2), packFiles, fetched: fetched), bundle).sync(bundledVersion: 2), 'bundled');
    expect(fetched, isEmpty);
  });

  test('a corrupted download is never used', () async {
    final store = ContentPackStore(dir, server(row(), packFiles, corrupt: {notes}), bundle);
    expect(await store.sync(bundledVersion: 1), 'failed:checksum');
    expect(await store.active(1), null);
  });

  test('a pack whose clips the app cannot show is rejected as a whole', () async {
    final badPart = jsonEncode({'clips': [{...clip, 'videoId': 'unknown'}]});
    final store = ContentPackStore(dir, server(row(), {...packFiles, 'content-0.json': badPart}), bundle);
    expect(await store.sync(bundledVersion: 1), 'failed:video');
    expect(await store.active(1), null);
  });

  test('offline keeps whatever the device already uses', () async {
    expect(await ContentPackStore(dir, server(row(), packFiles), bundle).sync(bundledVersion: 1), 'activated');
    final offline = MockClient((_) async => throw const SocketException('offline'));
    final store = ContentPackStore(dir, offline, bundle);
    expect(await store.sync(bundledVersion: 1), 'offline');
    expect((await store.active(1))?.version, 2);
  });

  test('files cleared by the system mean the bundle again, then a fresh download', () async {
    final store = ContentPackStore(dir, server(row(), packFiles), bundle);
    expect(await store.sync(bundledVersion: 1), 'activated');
    Directory('${dir.path}/objects').deleteSync(recursive: true);
    expect(await store.active(1), null);
    expect(await store.sync(bundledVersion: 1), 'activated');
    expect((await store.active(1))?.version, 2);
  });
}
