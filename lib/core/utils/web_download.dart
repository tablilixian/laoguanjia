import 'dart:convert';
import 'dart:html' as html;

void downloadJson(String jsonString, String tableName) {
  final bytes = utf8.encode(jsonString);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', '$tableName.json')
    ..click();
  html.Url.revokeObjectUrl(url);
}
