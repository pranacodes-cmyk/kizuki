// Mirrors src/lib/feed-pager.test.ts — same cases, same numbers.
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/widgets/feed_pager.dart';

const h = 800.0;

void main() {
  group('feed paging: one swipe = one clip', () {
    test('a slow drag past 18% of the screen goes to the next clip', () {
      expect(pageAfterRelease(3, 150, 0, h, 10), 4);
    });

    test('a short slow drag springs back to the same clip', () {
      expect(pageAfterRelease(3, 100, 0.1, h, 10), 3);
      expect(pageAfterRelease(3, -100, -0.1, h, 10), 3);
    });

    test('a quick flick changes clips even when it is short', () {
      expect(pageAfterRelease(3, 40, 0.5, h, 10), 4);
      expect(pageAfterRelease(3, -40, -0.5, h, 10), 2);
    });

    test('never moves more than one clip, even after a long drag', () {
      expect(pageAfterRelease(3, 1500, 3, h, 10), 4);
    });

    test('stays inside the feed at both ends', () {
      expect(pageAfterRelease(0, -300, -1, h, 10), 0);
      expect(pageAfterRelease(9, 300, 1, h, 10), 9);
    });
  });
}
