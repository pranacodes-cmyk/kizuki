// Mirrors src/lib/logic.test.ts — keep cases and expected values identical.
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/models.dart';
import 'package:mimi/logic/logic.dart';

const now = 1800000000000;

void main() {
  group('onboarding rules', () {
    test('maps self-reported level to JLPT band', () {
      expect([0, 1, 2, 3, 4].map(levelToJlpt).toList(), ['N5', 'N5', 'N4', 'N3', 'N2']);
    });
    test('estimates words per month from daily minutes', () {
      expect(wordsPerMonth(25), 510);
      expect(wordsPerMonth(5), 102);
    });
    test('recommends daily minutes for a fluency goal', () {
      expect(recommendedMinutes(9), 25);
      expect(recommendedMinutes(12), 20);
      expect(recommendedMinutes(3), 60);
      expect(recommendedMinutes(36), 5);
    });
    test('labels the goal month', () {
      expect(goalDateLabel(DateTime(2026, 10, 21), 9), 'Jul 2027');
      expect(goalDateLabel(DateTime(2026, 1, 5), 12), 'Jan 2027');
    });
    test('plan reflects the chosen minutes, reason and level', () {
      final items = planItems(reasonList: ['anime'], challengeList: ['motivation'], dailyMinutes: 25, window: 'night', streakGoal: 14, jlpt: 'N4', clipCount: 120);
      expect(items[0].title, '25-minute daily sessions');
      expect(items[1].title, 'Understand anime without subtitles');
      expect(items[2].title, 'A 14-day streak goal');
      expect(items[2].body, 'Friendly reminders at night');
      expect(items[3].title, '510 new words a month');
      expect(items[4].body, 'Matched to your level (N4) and interests');
    });
  });

  group('feed ranking', () {
    test('hashes like the web client', () {
      expect(fnv1a('a'), 3826002220);
      expect(fnv1a('mimi:abc-12'), fnv1a('mimi:abc-12'));
    });
    const clips = [
      RankClip(id: 'a-1', videoId: 'a', level: 'N5', topics: ['anime'], quality: 5),
      RankClip(id: 'a-2', videoId: 'a', level: 'N5', topics: ['anime'], quality: 5),
      RankClip(id: 'b-1', videoId: 'b', level: 'N3', topics: ['work'], quality: 4),
      RankClip(id: 'c-1', videoId: 'c', level: 'N5', topics: ['travel'], quality: 3),
    ];
    test('prefers clips that match interests and level', () {
      expect(clipScore(clips[0], reasonList: ['anime'], jlpt: 'N5', seen: {}, seed: 's1'),
          greaterThan(clipScore(clips[2], reasonList: ['anime'], jlpt: 'N5', seen: {}, seed: 's1')));
    });
    test('never plays the same video twice in a row when it can avoid it', () {
      final order = rankFeed(clips, reasonList: ['anime'], jlpt: 'N5', seen: {}, seed: 's1');
      expect(order.length, 4);
      for (var i = 1; i < order.length; i++) {
        expect(order[i].split('-')[0], isNot(order[i - 1].split('-')[0]));
      }
    });
    test('pushes already-seen clips down', () {
      final order = rankFeed(clips, reasonList: ['anime'], jlpt: 'N5', seen: {'a-1': 2, 'a-2': 2}, seed: 's1');
      expect(order[0], 'c-1');
    });
  });

  group('spaced repetition', () {
    test('new card: again → 1 minute, good → 10 minutes', () {
      final c = newCard(now);
      expect(answerCard(c, 'again', now).due, now + minuteMs);
      final g = answerCard(c, 'good', now);
      expect(g.state, 'learning');
      expect(g.due, now + 10 * minuteMs);
    });
    test('learning card graduates to 1 day, then grows by ease', () {
      final l = answerCard(answerCard(newCard(now), 'good', now), 'good', now);
      expect(l.state, 'review');
      expect(l.interval, 1);
      expect(l.due, now + dayMs);
      final r = answerCard(l, 'good', now);
      expect(r.interval, 3);
      final r2 = answerCard(r, 'good', now);
      expect(r2.interval, 8);
    });
    test('lapse lowers ease and relearns at half the interval', () {
      final review = newCard(now).copyWith(state: 'review', interval: 10, ease: 2.5);
      final lapsed = answerCard(review, 'again', now);
      expect(lapsed.state, 'relearning');
      expect(lapsed.ease, closeTo(2.3, 0.001));
      expect(lapsed.lapses, 1);
      final back = answerCard(lapsed, 'good', now);
      expect(back.state, 'review');
      expect(back.interval, 5);
    });
    test('labels intervals', () {
      expect(formatInterval(30000), '<1m');
      expect(formatInterval(10 * minuteMs), '10m');
      expect(formatInterval(3 * 3600000), '3h');
      expect(formatInterval(3 * dayMs), '3d');
      expect(formatInterval(60 * dayMs), '2mo');
      expect(nextIntervalLabel(newCard(now), 'again', now), '1m');
      expect(nextIntervalLabel(newCard(now), 'good', now), '10m');
    });
    test('words become known automatically after 21 days interval', () {
      final c = newCard(now).copyWith(state: 'review', interval: 21);
      expect(wordStatus(status: 'learning', card: c), 'known');
      expect(wordStatus(status: 'learning', card: c.copyWith(interval: 20)), 'learning');
      expect(wordStatus(status: 'ignored', card: c), 'ignored');
    });
    test('session keeps a card until it graduates', () {
      final s = ReviewSession(['x', 'y']);
      var x = newCard(now);
      x = s.answer(x, 'good', now);
      expect(s.queue, ['y', 'x']);
      s.answer(newCard(now), 'again', now);
      x = s.answer(x, 'good', now);
      expect(x.state, 'review');
      expect(s.queue, ['y']);
      expect(s.answered, 3);
    });
  });

  group('streaks and goals', () {
    final today = DateTime(2026, 10, 21);
    Map<String, DayActivity> act(List<String> keys) => {for (final k in keys) k: const DayActivity(sec: 120, clips: 1)};
    test('counts consecutive days including today', () {
      expect(currentStreak(act(['2026-10-19', '2026-10-20', '2026-10-21']), today), 3);
    });
    test("keeps yesterday's streak alive until today ends", () {
      expect(currentStreak(act(['2026-10-19', '2026-10-20']), today), 2);
    });
    test('breaks after a missed day', () {
      expect(currentStreak(act(['2026-10-18', '2026-10-19']), today), 0);
    });
    test('less than a minute without clips or reviews is not an active day', () {
      expect(currentStreak({'2026-10-21': const DayActivity(sec: 30)}, today), 0);
    });
    test('best streak across month boundary', () {
      expect(bestStreak(act(['2026-09-29', '2026-09-30', '2026-10-01', '2026-10-05'])), 3);
    });
    test('goal minutes left rounds up', () {
      expect(minutesLeft(25, 0), 25);
      expect(minutesLeft(25, 61), 24);
      expect(minutesLeft(25, 1500), 0);
      expect(minutesLeft(25, 9999), 0);
    });
    test('heat levels', () {
      expect([0, 100, 600, 1200, 1500].map((s) => heatLevel(s, 25)).toList(), [0, 1, 2, 3, 4]);
    });
    test('heatmap ends on the current week, Monday first', () {
      final w = heatmapWeeks(today, 3);
      expect(w.length, 3);
      expect(w[2][0], '2026-10-19');
      expect(w[0][0], '2026-10-05');
      expect(dayKey(today), '2026-10-21');
    });
  });

  group('achievements, search, kana, sync', () {
    test('unlocks only new achievements', () {
      const s = Stats(clips: 10);
      expect(newlyUnlocked(s, ['first-clip']).map((a) => a.id).toList(), ['clips-10']);
    });
    test('normalizes queries across scripts', () {
      expect(normalizeQuery('ネコ'), 'ねこ');
      expect(normalizeQuery(' Neko '), 'neko');
    });
    test('builds kana decks', () {
      expect(kanaDeck('hiragana').length, 71);
      final k = kanaDeck('katakana').first;
      expect([k.id, k.kana, k.romaji], ['k:ア', 'ア', 'a']);
      expect(toKatakana('きゃ'), 'キャ');
    });
    test('merges saved words by newest update', () {
      final m = mergeByUpdatedAt({
        'a': {'v': 1, 'updatedAt': 5},
        'b': {'v': 1, 'updatedAt': 5},
      }, {
        'a': {'v': 2, 'updatedAt': 9},
        'b': {'v': 2, 'updatedAt': 5},
        'c': {'v': 2, 'updatedAt': 1},
      });
      expect(m, {
        'a': {'v': 2, 'updatedAt': 9},
        'b': {'v': 1, 'updatedAt': 5},
        'c': {'v': 2, 'updatedAt': 1},
      });
    });
    test('merges activity by max counter', () {
      final m = mergeActivity({'d': const DayActivity(sec: 100, clips: 2, words: 1)}, {'d': const DayActivity(sec: 50, clips: 3, reviews: 4)});
      expect(m['d']!.toJson(), {'sec': 100, 'clips': 3, 'reviews': 4, 'words': 1});
    });
  });

  group('clip search', () {
    Word w(String s, String b, String r, String ro, [String? d]) => Word(s: s, b: b, r: r, ro: ro, p: 'noun', d: d, t0: 0, t1: 0);
    final clips = [
      Clip(id: 'x-1', videoId: 'x', title: '', level: 'N4', start: 0, end: 1, topics: const ['animals'], grammar: const ['〜てる — ongoing action'], quality: 4, lines: [
        Line(start: 0, end: 1, en: 'The cat is walking.', sp: 'A', ja: '猫が歩いてる。', words: [w('猫', '猫', 'ねこ', 'neko', '1467640'), w('歩いてる', '歩く', 'あるいてる', 'aruiteru', '1514320')]),
      ]),
      Clip(id: 'y-1', videoId: 'y', title: '', level: 'N5', start: 0, end: 1, topics: const ['food'], grammar: const ['〜たい — want to'], quality: 4, lines: [
        Line(start: 0, end: 1, en: 'I want to eat ramen.', sp: 'A', ja: 'ラーメンが食べたい。', words: [w('ラーメン', 'ラーメン', '', 'raamen'), w('食べたい', '食べる', 'たべたい', 'tabetai')]),
      ]),
    ];
    test('finds a word by kanji, kana, katakana or romaji', () {
      expect(searchClips(clips, '猫'), ['x-1']);
      expect(searchClips(clips, 'ネコ'), ['x-1']);
      expect(searchClips(clips, 'neko'), ['x-1']);
      expect(searchClips(clips, '歩く'), ['x-1']);
    });
    test('finds English text and applies filters', () {
      expect(searchClips(clips, 'ramen'), ['y-1']);
      expect(searchClips(clips, '', level: 'N5'), ['y-1']);
      expect(searchClips(clips, '', grammar: '〜てる'), ['x-1']);
      expect(searchClips(clips, ''), ['y-1', 'x-1']);
    });
    test('word keys prefer dictionary ids', () {
      expect(clipWordKeys(clips[0]), ['d1467640', 'd1514320']);
      expect(wordKeyOf(null, 'よし'), 'bよし');
    });
    test('hear it again: other clips with the word, best level fit first', () {
      final more = [
        ...clips,
        Clip(id: 'z-1', videoId: 'z', title: '', level: 'N2', start: 0, end: 1, topics: const [], grammar: const [], quality: 3, lines: [
          Line(start: 0, end: 1, en: 'A cat', sp: '', ja: '猫だ', words: [w('猫', '猫', 'ねこ', 'neko', '1467640')]),
        ]),
      ];
      expect(clipsWithWord(more, 'd1467640', 'none', 'N2'), ['z-1', 'x-1']);
      expect(clipsWithWord(more, 'd1467640', 'x-1', 'N5'), ['z-1']);
    });
  });

  group('free tier', () {
    test('free learners get 10 clips a day, premium is unlimited', () {
      expect(canWatchClip(false, 9, 10), true);
      expect(canWatchClip(false, 10, 10), false);
      expect(canWatchClip(true, 500, 10), true);
    });
  });

  group('saved words', () {
    Card card(int due, [double interval = 0]) => newCard(due).copyWith(state: interval > 0 ? 'review' : 'new', interval: interval);
    final words = [
      WordLite('a', 'learning', card(now - 10), 1),
      WordLite('b', 'learning', card(now - 50), 2),
      WordLite('c', 'learning', card(now + 1000, 30), 3),
      WordLite('d', 'known', card(now - 99), 4),
      WordLite('e', 'ignored', card(now - 99), 5),
      WordLite('f', 'removed', card(now - 99), 6),
    ];
    test('reviews only due learning words, oldest first', () {
      expect(dueWordKeys(words, now), ['b', 'a']);
    });
    test('counts saved, learning, known and due', () {
      final c = wordCounts(words, now);
      expect([c.saved, c.learning, c.known, c.due], [4, 2, 2, 2]);
    });
    test("keep studying offers learning words that aren't due yet", () {
      expect(customStudyKeys(words, now), ['c']);
    });
    test('kana sessions: due first, then 10 new characters', () {
      final deck = kanaDeck('hiragana');
      final cards = {
        'h:い': newCard(now - 5).copyWith(state: 'review', interval: 3),
        'h:う': newCard(now + 999).copyWith(state: 'learning'),
      };
      final q = kanaQueue(deck, cards, now);
      expect(q.first, 'h:い');
      expect(q.length, 11);
      expect(q.sublist(1, 3), ['h:あ', 'h:え']);
      expect(kanaLearned(deck, cards), 1);
      expect(deck.length, 71);
    });
  });

  group('cloud merge', () {
    final local = <String, dynamic>{
      'updatedAt': 10, 'onboarded': true, 'profile': {'name': 'Local'},
      'words': {'a': {'updatedAt': 5, 'status': 'learning'}}, 'seen': {'c1': 1}, 'history': [{'clipId': 'c1', 'at': 3}],
      'activity': {'2026-10-21': {'sec': 100, 'clips': 1, 'reviews': 0, 'words': 0}}, 'totals': {'clips': 1, 'seconds': 100, 'reviews': 0},
      'achievementsSeen': ['first-clip'], 'kana': {'h:あ': {'reps': 1}}, 'reviewSessions': 0,
    };
    final remote = <String, dynamic>{
      'updatedAt': 20, 'onboarded': false, 'profile': {'name': 'Remote'},
      'words': {'a': {'updatedAt': 9, 'status': 'known'}, 'b': {'updatedAt': 1, 'status': 'learning'}}, 'seen': {'c1': 3, 'c2': 1},
      'history': [{'clipId': 'c2', 'at': 7}, {'clipId': 'c1', 'at': 3}], 'activity': {'2026-10-21': {'sec': 40, 'clips': 2, 'reviews': 5, 'words': 1}},
      'totals': {'clips': 3, 'seconds': 40, 'reviews': 5}, 'achievementsSeen': ['clips-10'], 'kana': {'h:あ': {'reps': 4}}, 'reviewSessions': 2,
    };
    test('merges words, counters and history; newer single values win', () {
      final m = mergeState(local, remote);
      expect(m['profile']['name'], 'Remote');
      expect(m['onboarded'], true);
      expect(m['words']['a']['status'], 'known');
      expect((m['words'] as Map).keys.toList()..sort(), ['a', 'b']);
      expect(m['seen'], {'c1': 3, 'c2': 1});
      expect((m['history'] as List).map((h) => h['clipId']).toList(), ['c2', 'c1']);
      expect(m['activity']['2026-10-21'], {'sec': 100, 'clips': 2, 'reviews': 5, 'words': 1});
      expect(m['totals'], {'clips': 3, 'seconds': 100, 'reviews': 5});
      expect(m['achievementsSeen'], ['clips-10', 'first-clip']);
      expect(m['kana']['h:あ']['reps'], 4);
      expect(m['reviewSessions'], 2);
      expect(m['updatedAt'], 20);
    });
  });
}
