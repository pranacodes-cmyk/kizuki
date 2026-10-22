// Drags a real FeedPager the way a thumb does: short, slow, quick and long swipes,
// including swipes that start on a non-scrolling transcript (as in the feed's ClipView).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/widgets/feed_pager.dart';

Widget _harness(List<int> settled, {bool transcript = false}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: FeedPager(
            itemCount: 10,
            onSettled: settled.add,
            itemBuilder: (context, i) => Column(children: [
              SizedBox(height: 200, child: Center(child: Text('video $i'))),
              Expanded(
                child: transcript
                    // Feed transcript: scrolls only by itself, so drags belong to the pager.
                    ? SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(children: [for (var l = 0; l < 30; l++) SizedBox(height: 60, child: Text('clip $i line $l'))]),
                      )
                    : Center(child: Text('clip $i')),
              ),
            ]),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a slow 25% drag moves to the next clip', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled));
    await t.timedDrag(find.text('clip 0'), const Offset(0, -200), const Duration(milliseconds: 900));
    await t.pumpAndSettle();
    expect(settled, [1]);
    expect(find.text('clip 1'), findsOneWidget);
  });

  testWidgets('a short slow drag springs back and changes nothing', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled));
    await t.timedDrag(find.text('clip 0'), const Offset(0, -80), const Duration(milliseconds: 900));
    await t.pumpAndSettle();
    expect(settled, isEmpty);
    expect(find.text('clip 0'), findsOneWidget);
  });

  testWidgets('a quick short flick moves one clip', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled));
    await t.fling(find.text('clip 0'), const Offset(0, -60), 1500);
    await t.pumpAndSettle();
    expect(settled, [1]);
  });

  testWidgets('a hard long fling never skips a clip', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled));
    await t.fling(find.text('clip 0'), const Offset(0, -700), 8000);
    await t.pumpAndSettle();
    expect(settled, [1]);
  });

  testWidgets('swipe down goes back one clip', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled));
    await t.fling(find.text('clip 0'), const Offset(0, -300), 2000);
    await t.pumpAndSettle();
    await t.fling(find.text('clip 1'), const Offset(0, 300), 2000);
    await t.pumpAndSettle();
    expect(settled, [1, 0]);
  });

  testWidgets('ten swipes on the subtitles = ten clips', (t) async {
    final settled = <int>[];
    await t.pumpWidget(_harness(settled, transcript: true));
    for (var i = 0; i < 9; i++) {
      await t.fling(find.text('clip $i line 2'), const Offset(0, -250), 1200);
      await t.pumpAndSettle();
    }
    expect(settled, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });
}
