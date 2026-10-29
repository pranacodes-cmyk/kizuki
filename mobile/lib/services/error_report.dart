import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_service.dart';

/// Sends a short technical record of a screen error to public.app_errors (insert-only),
/// so a "Something went wrong" screen on a learner's phone can be diagnosed. Only the
/// error text, stack and screen path — never learner notes or account details.
class ErrorReport {
  static int _sent = 0;
  static final Set<String> _seen = {};
  static String? route;

  static void send(String kind, Object error, StackTrace? stack) {
    if (kIsWeb || _sent >= 5) return;
    final message = error.toString();
    final cut = message.length > 600 ? message.substring(0, 600) : message;
    if (!_seen.add('$kind|$cut')) return;
    _sent++;
    final st = stack?.toString();
    unawaited(() async {
      try {
        if (!await SyncService.I.ensureBackend().timeout(const Duration(seconds: 10), onTimeout: () => false)) return;
        await Supabase.instance.client.from('app_errors').insert({
          'platform': Platform.isIOS ? 'ios' : 'android',
          'kind': kind,
          'message': cut,
          'stack': st == null ? null : (st.length > 3000 ? st.substring(0, 3000) : st),
          'route': route == null ? null : (route!.length > 120 ? route!.substring(0, 120) : route),
          'user_id': SyncService.I.session?.user.id,
        });
      } catch (e) {
        debugPrint('KIZUKI_WARN error report: $e');
      }
    }());
  }
}
