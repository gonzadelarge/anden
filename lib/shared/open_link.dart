import 'package:url_launcher/url_launcher.dart';

import 'messages.dart';

/// Opens [url] in the browser. Tells the user when it cannot.
Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened) showMessage('No se pudo abrir el enlace');
}
