// Content models — the JSON shape written by scripts/content/build.ts (same files the
// web prototype reads from public/data). Never hand-edit the JSON.

class Word {
  final String s; // surface
  final String r; // reading (hiragana) or ''
  final String ro; // romaji
  final String b; // dictionary form
  final String p; // simple part of speech
  final String? d; // dictionary id
  final List<List<String?>>? f; // furigana segments [text, ruby]
  final double t0, t1;
  const Word({required this.s, required this.r, required this.ro, required this.b, required this.p, this.d, this.f, required this.t0, required this.t1});

  bool get isPunct => p == 'punct';

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        s: j['s'] as String,
        r: j['r'] as String? ?? '',
        ro: j['ro'] as String? ?? '',
        b: j['b'] as String? ?? '',
        p: j['p'] as String? ?? 'other',
        d: j['d'] as String?,
        f: (j['f'] as List?)?.map((e) => (e as List).map((x) => x as String?).toList()).toList(),
        t0: (j['t0'] as num).toDouble(),
        t1: (j['t1'] as num).toDouble(),
      );
}

class Line {
  final double start, end;
  final String en, sp, ja;
  final List<Word> words;
  const Line({required this.start, required this.end, required this.en, required this.sp, required this.ja, required this.words});
  factory Line.fromJson(Map<String, dynamic> j) => Line(
        start: (j['start'] as num).toDouble(),
        end: (j['end'] as num).toDouble(),
        en: j['en'] as String? ?? '',
        sp: j['sp'] as String? ?? '',
        ja: j['ja'] as String? ?? '',
        words: (j['words'] as List).map((w) => Word.fromJson(w as Map<String, dynamic>)).toList(),
      );
}

class Clip {
  final String id, videoId, title, level;
  final double start, end;
  final List<String> topics, grammar;
  final int quality;
  final List<Line> lines;

  /// Audio-first video (a podcast): the picture is one still image, often a channel banner.
  final bool still;
  const Clip({
    required this.id,
    required this.videoId,
    required this.title,
    required this.level,
    required this.start,
    required this.end,
    required this.topics,
    required this.grammar,
    required this.quality,
    required this.lines,
    this.still = false,
  });
  double get duration => end - start;
  String get thumb => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  factory Clip.fromJson(Map<String, dynamic> j) => Clip(
        id: j['id'] as String,
        videoId: j['videoId'] as String,
        title: j['title'] as String,
        level: j['level'] as String,
        start: (j['start'] as num).toDouble(),
        end: (j['end'] as num).toDouble(),
        topics: (j['topics'] as List).cast<String>(),
        grammar: (j['grammar'] as List).cast<String>(),
        quality: (j['quality'] as num? ?? 3).toInt(),
        lines: (j['lines'] as List).map((l) => Line.fromJson(l as Map<String, dynamic>)).toList(),
        still: j['still'] == true,
      );
}

class Video {
  final String title, channel, channelUrl;
  const Video(this.title, this.channel, this.channelUrl);
}

class Sense {
  final List<String> pos;
  final String g;
  const Sense(this.pos, this.g);
}

class Example {
  final String ja, en;
  const Example(this.ja, this.en);
}

class DictEntry {
  final String w, r;
  final int? j;
  final bool c;
  final List<Sense> m;
  final List<Example> ex;
  const DictEntry({required this.w, required this.r, this.j, required this.c, required this.m, required this.ex});
  String get gloss => m.isEmpty ? '' : m.first.g.split(';').first.trim();
  factory DictEntry.fromJson(Map<String, dynamic> j) => DictEntry(
        w: j['w'] as String,
        r: j['r'] as String,
        j: (j['j'] as num?)?.toInt(),
        c: j['c'] as bool? ?? false,
        m: (j['m'] as List).map((s) => Sense((s['pos'] as List).cast<String>(), s['g'] as String)).toList(),
        ex: (j['ex'] as List).map((e) => Example(e['ja'] as String, e['en'] as String)).toList(),
      );
}

class WordNote {
  final String m, n;
  const WordNote(this.m, this.n);
}

class LineNote {
  final String lit, tip;
  const LineNote(this.lit, this.tip);
}

class ClipNotes {
  final Map<String, WordNote> words;
  final Map<String, LineNote> lines;
  const ClipNotes(this.words, this.lines);
  static const empty = ClipNotes({}, {});
  factory ClipNotes.fromJson(Map<String, dynamic> j) => ClipNotes(
        (j['w'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, WordNote(v['m'] as String, v['n'] as String))),
        (j['l'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, LineNote(v['lit'] as String, v['tip'] as String))),
      );
}
