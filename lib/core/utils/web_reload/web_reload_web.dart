// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Reload browser web page pada Flutter Web.
void reloadWebPage() {
  html.window.location.reload();
}
