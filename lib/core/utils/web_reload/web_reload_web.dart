// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js' as js;

/// Hard reload browser web page pada Flutter Web.
/// Menghapus cache storage, unregister Service Worker, dan memaksa browser
/// mengambil resource bundle terbaru dari server menggunakan cache buster.
void reloadWebPage() {
  try {
    if (js.context.hasProperty('forceHardReload')) {
      js.context.callMethod('forceHardReload');
      return;
    }
  } catch (_) {}

  // Fallback native jika helper JS belum tersedia
  try {
    if (html.window.navigator.serviceWorker != null) {
      html.window.navigator.serviceWorker!.getRegistrations().then((registrations) {
        for (final reg in registrations) {
          reg.unregister();
        }
      });
    }
  } catch (_) {}

  try {
    final currentUrl = Uri.parse(html.window.location.href);
    final params = Map<String, String>.from(currentUrl.queryParameters);
    params['_v'] = DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = currentUrl.replace(queryParameters: params).toString();
    html.window.location.href = newUrl;
    html.window.location.reload();
  } catch (_) {
    html.window.location.reload();
  }
}

