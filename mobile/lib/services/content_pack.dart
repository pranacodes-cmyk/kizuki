import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../logic/logic.dart';
import 'config.dart';

/// A downloaded, fully verified content pack that the library loads instead of the bundle.
class ActivePack {
  final String url;
  final ContentPackManifest manifest;

  /// Files byte-identical to this build's bundled copy: read from the app, never stored twice.
  final Set<String> bundled;
  final Map<String, ContentPackFile> files;
  ActivePack(this.url, this.manifest, this.bundled) : files = {for (final f in manifest.files) f.name: f};
  int get version => manifest.version;

  /// Checksums of the files this pack keeps on the device.
  Set<String> get stored => {for (final f in manifest.files) if (!bundled.contains(f.name)) f.sha256};
}

/// Server-sent clip library: more clips without an app update. The bundled library is always
/// the default. The public `content_settings` row names a newer pack; it downloads in the
/// background, every file is checked (sha-256 + size) and the whole pack is parsed with the
/// app's own rules, and only then it is used — from the next app start. The off switch, a
/// cleared link, a failed check or a pack not newer than the bundle all mean the bundle.
/// Files live in the cache directory (re-downloadable, never backed up); if the system clears
/// them the app quietly returns to the bundle and downloads again. Mirrors src/lib/content-pack.ts.
class ContentPackStore {
  final Directory dir;
  final http.Client client;
  final AssetBundle bundle;
  ContentPackStore(this.dir, this.client, this.bundle);

  File get _active => File('${dir.path}/active.json');
  Directory get _objects => Directory('${dir.path}/objects');
  File objectFile(String sha) => File('${_objects.path}/$sha.json');

  /// The verified pack to load instead of the bundle, or null.
  Future<ActivePack?> active(int bundledVersion) async {
    try {
      if (!await _active.exists()) return null;
      final j = jsonDecode(await _active.readAsString());
      if (j is! Map || j['url'] is! String || j['version'] is! int) return null;
      final version = j['version'] as int;
      if (version <= bundledVersion) return null;
      final m = contentPackManifest(j['manifest'], version);
      if (m == null) return null;
      final bundled = ((j['bundled'] as List?) ?? const []).whereType<String>().toSet();
      for (final f in m.files) {
        if (bundled.contains(f.name)) continue;
        final o = objectFile(f.sha256);
        if (!await o.exists() || await o.length() != f.bytes) return null;
      }
      return ActivePack(j['url'] as String, m, bundled);
    } catch (_) {
      return null;
    }
  }

  /// Text of one pack file (from the device, or the bundle when identical).
  Future<String> readText(ActivePack p, String name) async {
    final f = p.files[name];
    if (f == null) throw StateError('pack has no $name');
    if (p.bundled.contains(name)) return bundle.loadString('assets/data/$name', cache: false);
    return objectFile(f.sha256).readAsString();
  }

  /// Stops using the downloaded pack from the next start (the bundle takes over).
  Future<void> deactivate() async {
    try {
      if (await _active.exists()) await _active.delete();
    } catch (_) {}
  }

  /// One update check against the server row. Returns what happened: 'offline', 'keep',
  /// 'bundled', 'activated' or `failed:<reason>`. [inUse] are checksums the running app still
  /// reads (its loaded pack), so they are never deleted underneath it.
  Future<String> sync({required int bundledVersion, Set<String> inUse = const {}}) async {
    final Map row;
    try {
      final res = await client.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/content_settings?id=eq.1&select=updates_enabled,pack_version,pack_url'),
        headers: {'apikey': AppConfig.supabasePublishableKey},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return 'offline';
      final rows = jsonDecode(res.body);
      if (rows is! List || rows.isEmpty || rows.first is! Map) return 'offline';
      row = rows.first as Map;
    } catch (_) {
      return 'offline';
    }
    final current = await active(bundledVersion);
    final action = contentPackAction(row['updates_enabled'], row['pack_version'], row['pack_url'], bundledVersion, current?.version);
    if (action == 'keep') {
      await _sweep({...current!.stored, ...inUse});
      return 'keep';
    }
    if (action == 'bundled') {
      await deactivate();
      await _sweep(inUse);
      return 'bundled';
    }
    final url = founderVideoUrl(row['pack_url'])!;
    final version = (row['pack_version'] as num).toInt();
    try {
      final r = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return 'failed:manifest';
      final m = contentPackManifest(jsonDecode(utf8.decode(r.bodyBytes)), version);
      if (m == null) return 'failed:manifest';
      await _objects.create(recursive: true);
      final bundled = <String>{};
      for (final f in m.files) {
        final o = objectFile(f.sha256);
        if (await o.exists() && await o.length() == f.bytes) continue;
        if (await _matchesBundled(f)) {
          bundled.add(f.name);
          continue;
        }
        final res = await client.get(Uri.parse(contentObjectUrl(url, f.sha256))).timeout(const Duration(seconds: 90));
        if (res.statusCode != 200) return 'failed:download';
        final raw = await compute(_inflateChecked, (res.bodyBytes, f.sha256, f.bytes));
        if (raw == null) return 'failed:checksum';
        final tmp = File('${o.path}.tmp');
        await tmp.writeAsBytes(raw, flush: true);
        await tmp.rename(o.path);
      }
      final pack = ActivePack(url, m, bundled);
      final problem = await check(pack);
      if (problem != null) return 'failed:$problem';
      final tmp = File('${_active.path}.tmp');
      await tmp.writeAsString(jsonEncode({'version': m.version, 'url': url, 'manifest': m.toJson(), 'bundled': bundled.toList()}), flush: true);
      await tmp.rename(_active.path);
      await _sweep({...pack.stored, ...inUse});
      return 'activated';
    } catch (e) {
      return 'failed:${e.runtimeType}';
    }
  }

  /// Parses every file of [p] with the rules the app loads with, one file at a time (low
  /// memory). Null when the whole pack is usable.
  Future<String?> check(ActivePack p) async {
    final index = await compute(_checkIndex, (await readText(p, 'content.json'), p.manifest));
    if (index.$1 != null) return index.$1;
    final ids = <String>{};
    for (final part in index.$3) {
      final out = await compute(_checkPart, (await readText(p, part), index.$2));
      if (out.$1 != null) return out.$1;
      for (final id in out.$2) {
        if (!ids.add(id)) return 'duplicate';
      }
    }
    if (ids.isEmpty) return 'clips';
    final dict = await compute(_checkDict, await readText(p, 'dict.json'));
    if (dict != null) return dict;
    for (final n in p.manifest.notes) {
      final notes = await compute(_checkNotes, await readText(p, n));
      if (notes != null) return notes;
    }
    return null;
  }

  Future<bool> _matchesBundled(ContentPackFile f) async {
    try {
      final data = await bundle.load('assets/data/${f.name}');
      if (data.lengthInBytes != f.bytes) return false;
      return await compute(_sha256Hex, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)) == f.sha256;
    } catch (_) {
      return false;
    }
  }

  /// Removes stored files no pack needs any more (and half-written downloads).
  Future<void> _sweep(Set<String> keep) async {
    try {
      if (!await _objects.exists()) return;
      await for (final e in _objects.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final sha = name.endsWith('.json') ? name.substring(0, name.length - 5) : null;
        if (sha == null || !keep.contains(sha)) await e.delete();
      }
    } catch (_) {}
  }
}

/// App-wide store + the once-per-run background check.
class ContentPack {
  static ContentPackStore? _store;
  static bool _scheduled = false;

  static Future<ContentPackStore?> store() async {
    try {
      return _store ??= ContentPackStore(Directory('${(await getApplicationCacheDirectory()).path}/content-pack'), http.Client(), rootBundle);
    } catch (_) {
      return null; // No file system access (tests): the bundled library is used.
    }
  }

  /// Checks for a newer pack once per app run, after start-up work has settled.
  static void scheduleSync(int bundledVersion, ActivePack? inUse) {
    if (_scheduled) return;
    _scheduled = true;
    unawaited(Future<void>.delayed(const Duration(seconds: 8), () async {
      final s = await store();
      if (s == null) return;
      final outcome = await s.sync(bundledVersion: bundledVersion, inUse: inUse?.stored ?? const {});
      debugPrint('KIZUKI_CONTENT pack $outcome');
    }));
  }
}

String _sha256Hex(Uint8List b) => sha256.convert(b).toString();

/// Server files are gzip-compressed; the checksum and size are of the plain JSON.
Uint8List? _inflateChecked((Uint8List, String, int) a) {
  try {
    final b = a.$1;
    final raw = b.length > 2 && b[0] == 0x1f && b[1] == 0x8b ? Uint8List.fromList(gzip.decode(b)) : b;
    if (raw.length != a.$3) return null;
    return sha256.convert(raw).toString() == a.$2 ? raw : null;
  } catch (_) {
    return null;
  }
}

(String?, Map<String, bool>, List<String>) _checkIndex((String, ContentPackManifest) a) {
  try {
    final j = jsonDecode(a.$1);
    final problem = contentIndexProblem(j, a.$2);
    if (problem != null) return (problem, const {}, const []);
    final videos = (j as Map)['videos'] as Map;
    return (null, {for (final k in videos.keys) k as String: true}, (j['parts'] as List).cast<String>());
  } catch (_) {
    return ('index', const {}, const []);
  }
}

(String?, List<String>) _checkPart((String, Map<String, bool>) a) {
  try {
    final j = jsonDecode(a.$1);
    if (j is! Map || j['clips'] is! List) return ('part', const []);
    final ids = <String>[];
    for (final c in j['clips'] as List) {
      final problem = contentClipProblem(c, a.$2);
      if (problem != null) return (problem, const []);
      Clip.fromJson(c as Map<String, dynamic>); // the parser the app uses must accept it
      ids.add(c['id'] as String);
    }
    return (null, ids);
  } catch (_) {
    return ('clip', const []);
  }
}

String? _checkDict(String text) {
  try {
    final j = jsonDecode(text);
    final problem = contentDictProblem(j);
    if (problem != null) return problem;
    for (final v in (j as Map).values) {
      DictEntry.fromJson(v as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return 'dict';
  }
}

String? _checkNotes(String text) {
  try {
    final j = jsonDecode(text);
    final problem = contentNotesProblem(j);
    if (problem != null) return problem;
    for (final v in (j as Map).values) {
      ClipNotes.fromJson(v as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return 'notes';
  }
}
