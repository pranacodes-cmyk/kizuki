import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/logic.dart';
import 'config.dart';

/// A downloaded, fully verified language pack (one language).
class LocalePack {
  final String url;
  final LocalePackManifest manifest;
  final Map<String, LocalePackFile> files;
  LocalePack(this.url, this.manifest) : files = {for (final f in manifest.files) f.name: f};
  String get lang => manifest.lang;
  int get version => manifest.version;
}

/// Language packs: the whole clip library, dictionary and explanations in the learner's
/// language. Mirrors src/lib/locale-pack.ts (shared rules in logic.dart / logic.ts).
///
/// English is the library itself and the curated starter clips come translated inside the app
/// (`assets/data/locale/<lang>.json`), so nothing has to download before learning starts. The rest
/// downloads in the background only for a non-English language once the learner has trial or
/// Premium access (localePackDue). The public content_settings.locale_packs row names each
/// language's manifest on two mirrors. Every file is checked (sha-256 + size) as it arrives and
/// is written under a temporary name first, so a cut connection never leaves a half file; files
/// already verified are kept, so a slow or interrupted download continues where it stopped. The
/// whole pack is then parsed with the shared rules, and only then recorded — used from the next
/// start, where every file is checked again before it is read. Any failure keeps what the
/// learner has (English + starter translations) and retries later with a growing wait. Files
/// live in the cache directory (re-downloadable, never backed up).
class LocalePackStore {
  final Directory dir;
  final http.Client client;
  LocalePackStore(this.dir, this.client);

  File _activeFile(String lang) => File('${dir.path}/$lang.json');
  Directory get _objects => Directory('${dir.path}/objects');
  File objectFile(String sha) => File('${_objects.path}/$sha.json');

  /// The pack recorded for [lang] whose files are all on the device, or null.
  Future<LocalePack?> active(String lang) async {
    try {
      final f = _activeFile(lang);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map || j['url'] is! String || j['version'] is! int) return null;
      final m = localePackManifest(j['manifest'], lang, j['version'] as int);
      if (m == null || founderVideoUrl(j['url']) == null) return null;
      for (final x in m.files) {
        final o = objectFile(x.sha256);
        if (!await o.exists() || await o.length() != x.bytes) return null;
      }
      return LocalePack(j['url'] as String, m);
    } catch (_) {
      return null;
    }
  }

  /// One pack file as text, checked against its manifest every time it is read.
  Future<String> readText(LocalePack p, String name) async {
    final f = p.files[name];
    if (f == null) throw StateError('language pack has no $name');
    final text = await compute(_readChecked, (objectFile(f.sha256).path, f.sha256, f.bytes));
    if (text == null) throw const FormatException('language pack checksum');
    return text;
  }

  /// Stops using [lang]'s pack from the next start (starter translations + English).
  Future<void> deactivate(String lang) async {
    try {
      final f = _activeFile(lang);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// One check for [lang]: 'skip', 'offline', 'none', 'keep', 'activated' or `failed:<reason>`.
  /// [inUse] are checksums the running app still reads, so they are never deleted underneath it.
  Future<String> sync(String lang, {required bool hasAccess, Set<String> inUse = const {}, VoidCallback? onDownload}) async {
    if (lang == 'en' || !hasAccess) return 'skip';
    final Object? row;
    try {
      final res = await client.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/content_settings?id=eq.1&select=locale_packs'),
        headers: {'apikey': AppConfig.supabasePublishableKey},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return 'offline';
      final rows = jsonDecode(res.body);
      if (rows is! List || rows.isEmpty || rows.first is! Map) return 'offline';
      row = (rows.first as Map)['locale_packs'];
    } catch (_) {
      return 'offline';
    }
    final pointer = localePackPointer(row, lang);
    if (pointer == null) {
      // The founder switched this language off: starter translations + English.
      await deactivate(lang);
      await _sweep(inUse);
      return 'none';
    }
    final current = await active(lang);
    if (!localePackDue(lang, hasAccess, current?.version ?? 0, pointer.version)) return 'keep';
    onDownload?.call();
    var outcome = 'failed:download';
    for (final url in pointer.urls) {
      outcome = await _fromMirror(lang, pointer.version, url);
      if (outcome == 'activated') {
        await _sweep(inUse);
        return outcome;
      }
    }
    return outcome;
  }

  Future<String> _fromMirror(String lang, int version, String url) async {
    final LocalePackManifest m;
    try {
      final r = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return 'failed:manifest';
      final parsed = localePackManifest(jsonDecode(utf8.decode(r.bodyBytes)), lang, version);
      if (parsed == null) return 'failed:manifest';
      m = parsed;
    } catch (_) {
      return 'failed:manifest';
    }
    try {
      await _objects.create(recursive: true);
      for (final f in m.files) {
        final o = objectFile(f.sha256);
        if (await o.exists() && await o.length() == f.bytes) continue; // verified earlier
        final res = await client.get(Uri.parse(contentObjectUrl(url, f.sha256))).timeout(const Duration(seconds: 90));
        if (res.statusCode != 200) return 'failed:download';
        final raw = await compute(_inflateChecked, (res.bodyBytes, f.sha256, f.bytes));
        if (raw == null) return 'failed:checksum';
        final tmp = File('${o.path}.tmp');
        await tmp.writeAsBytes(raw, flush: true);
        await tmp.rename(o.path);
      }
      final pack = LocalePack(url, m);
      final problem = await check(pack);
      if (problem != null) return 'failed:$problem';
      final tmp = File('${_activeFile(lang).path}.tmp');
      await tmp.writeAsString(jsonEncode({'version': m.version, 'url': url, 'manifest': m.toJson()}), flush: true);
      await tmp.rename(_activeFile(lang).path);
      return 'activated';
    } on FormatException {
      return 'failed:checksum';
    } catch (e) {
      return 'failed:${e.runtimeType}';
    }
  }

  /// Re-reads every file (checksum again) and parses it with the shared rules. Null when usable.
  Future<String?> check(LocalePack p) async {
    for (final f in p.manifest.files) {
      final problem = await compute(_checkFile, (f.name, await readText(p, f.name)));
      if (problem != null) return problem;
    }
    return null;
  }

  /// Removes stored files no recorded pack needs any more (and half-written downloads).
  Future<void> _sweep(Set<String> inUse) async {
    try {
      if (!await _objects.exists()) return;
      final keep = {...inUse};
      for (final l in languages) {
        if (l.code == 'en') continue;
        final p = await active(l.code);
        if (p != null) keep.addAll(p.manifest.files.map((f) => f.sha256));
      }
      await for (final e in _objects.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final sha = name.endsWith('.json') ? name.substring(0, name.length - 5) : null;
        if (sha == null || !keep.contains(sha)) await e.delete();
      }
    } catch (_) {}
  }
}

/// App-wide store + the background check for the current language.
class LocalePacks {
  /// Language whose pack is downloading right now ('' = none) — Settings shows it.
  static final downloading = ValueNotifier<String>('');

  /// Settings line for [lang]: 'ready' (full translation on this device), 'downloading' or
  /// 'starter' (the bundled first-clip translations; the rest in English for now).
  static Future<String> state(String lang) async {
    if (lang == 'en') return 'starter';
    if (downloading.value == lang) return 'downloading';
    final s = await store();
    return await s?.active(lang) != null ? 'ready' : 'starter';
  }

  static LocalePackStore? _store;
  static Timer? _timer;
  static String? _running;
  static String? _pending;
  static int _failures = 0;
  static final Set<String> _settled = {};

  static Future<LocalePackStore?> store() async {
    try {
      return _store ??= LocalePackStore(Directory('${(await getApplicationCacheDirectory()).path}/locale-pack'), http.Client());
    } catch (_) {
      return null; // No file system access (tests): starter translations + English.
    }
  }

  /// Checks [lang]'s pack in the background once learning access exists; a failed or offline
  /// check retries with a growing wait (5 s → 30 min). [inUse] = files the app reads now.
  static void schedule(String lang, bool hasAccess, {Set<String> inUse = const {}, Duration delay = const Duration(seconds: 4)}) {
    if (lang == 'en' || !hasAccess || _settled.contains(lang) || _running == lang) return;
    if (_timer != null && _pending == lang) return; // already waiting for this language
    _timer?.cancel();
    _pending = lang;
    _timer = Timer(delay, () async {
      _timer = null;
      final s = await store();
      if (s == null) return;
      _running = lang;
      final outcome = await s.sync(lang, hasAccess: hasAccess, inUse: inUse, onDownload: () => downloading.value = lang);
      _running = null;
      downloading.value = '';
      debugPrint('KIZUKI_CONTENT language pack $lang $outcome');
      if (outcome.startsWith('failed') || outcome == 'offline') {
        schedule(lang, hasAccess, inUse: inUse, delay: Duration(milliseconds: localeRetryDelayMs(_failures++)));
      } else {
        _failures = 0;
        _settled.add(lang);
      }
    });
  }
}

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

String? _readChecked((String, String, int) a) {
  try {
    final raw = File(a.$1).readAsBytesSync();
    if (raw.length != a.$3 || sha256.convert(raw).toString() != a.$2) return null;
    return utf8.decode(raw);
  } catch (_) {
    return null;
  }
}

String? _checkFile((String, String) a) {
  try {
    return localeFileProblem(a.$1, jsonDecode(a.$2));
  } catch (_) {
    return 'parse';
  }
}
