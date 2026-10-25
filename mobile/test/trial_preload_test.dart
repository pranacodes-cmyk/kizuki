import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/services/trial_preload.dart';

void main() {
  test('warm-up page never creates a YouTube player', () {
    final html = warmupHtml('dQw4w9WgXcQ');
    expect(html.contains('new YT.Player'), isFalse);
    expect(html.contains('"/embed/" + id'), isTrue);
    expect(html.contains('var id = "dQw4w9WgXcQ"'), isTrue);
  });

  test('warm-up page rejects an unsafe video id', () {
    expect(warmupHtml('x"; alert(1); "').contains('var id = ""'), isTrue);
  });
}
