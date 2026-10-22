// Feed paging: one swipe = exactly one clip. Mirrors src/lib/feed-pager.ts (same numbers,
// mirrored tests in test/feed_pager_test.dart).
import 'package:flutter/widgets.dart';

/// Drag past this fraction of the screen, or flick faster than this (px/ms), to change clips.
const double swipeDistance = 0.18;
const double swipeVelocity = 0.35;

/// Which clip to settle on after a release. offset/velocity are positive towards the next clip.
int pageAfterRelease(int base, double offset, double velocity, double pageHeight, int count) {
  var dir = 0;
  if (offset > pageHeight * swipeDistance || (offset > 0 && velocity > swipeVelocity)) {
    dir = 1;
  } else if (offset < -pageHeight * swipeDistance || (offset < 0 && velocity < -swipeVelocity)) {
    dir = -1;
  }
  final last = count - 1 < 0 ? 0 : count - 1;
  return (base + dir).clamp(0, last);
}

/// Snaps a full-height vertical PageView (pageSnapping: false) with [pageAfterRelease]:
/// a short or slow swipe is still a swipe, and a long fling never skips a clip.
class FeedPagePhysics extends ScrollPhysics {
  /// Page the current drag started on.
  final int Function() basePage;
  final int count;
  const FeedPagePhysics({required this.basePage, required this.count, super.parent});

  @override
  FeedPagePhysics applyTo(ScrollPhysics? ancestor) => FeedPagePhysics(basePage: basePage, count: count, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) || (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final h = position.viewportDimension;
    if (h <= 0) return null;
    final base = basePage();
    final target = pageAfterRelease(base, position.pixels - base * h, velocity / 1000, h, count) * h;
    final tolerance = toleranceFor(position);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Full-height vertical pager for the feed: [FeedPagePhysics] + reports the clip it settles
/// on (never a clip a drag only passed over). Mirrors useFeedPager in src/lib/feed-pager.ts.
class FeedPager extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSettled;
  const FeedPager({super.key, required this.itemCount, required this.itemBuilder, required this.onSettled});
  @override
  State<FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends State<FeedPager> {
  final _pages = PageController();
  int _base = 0; // page the current drag started on
  int _settled = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _pageAt(ScrollMetrics m) => (m.pixels / m.viewportDimension).round().clamp(0, widget.itemCount - 1);

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || n.metrics.viewportDimension <= 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _base = _pageAt(n.metrics);
    } else if (n is ScrollEndNotification) {
      final page = _pageAt(n.metrics);
      _base = page;
      if (page != _settled) {
        _settled = page;
        widget.onSettled(page);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          pageSnapping: false,
          physics: FeedPagePhysics(basePage: () => _base, count: widget.itemCount),
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        ),
      );
}
