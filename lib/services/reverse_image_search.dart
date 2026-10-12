import '../models/post.dart';

class ReverseImageEngine {
  const ReverseImageEngine(
    this.id,
    this.name,
    this.host,
    this.path,
    this.parameter, {
    this.extra = const {},
  });
  final String id, name, host, path, parameter;
  final Map<String, String> extra;
  Uri searchUrl(String image) =>
      Uri.https(host, path, {...extra, parameter: image});
}

const reverseImageEngines = [
  ReverseImageEngine(
    'google',
    'Google Lens',
    'lens.google.com',
    '/uploadbyurl',
    'url',
  ),
  ReverseImageEngine(
    'bing',
    'Bing Visual Search',
    'www.bing.com',
    '/images/searchbyimage/upload',
    'imgurl',
    extra: {'cbir': 'sbi'},
  ),
  ReverseImageEngine(
    'yandex',
    'Yandex Images',
    'yandex.com',
    '/images/search',
    'url',
    extra: {'rpt': 'imageview'},
  ),
  ReverseImageEngine('tineye', 'TinEye', 'tineye.com', '/search', 'url'),
  ReverseImageEngine(
    'saucenao',
    'SauceNAO',
    'saucenao.com',
    '/search.php',
    'url',
  ),
  ReverseImageEngine('iqdb', 'IQDB', 'iqdb.org', '/', 'url'),
];
String? reverseImageUrl(Post post) {
  final candidates = [
    post.sampleUrl,
    post.previewUrl,
    if (!post.isVideo) post.originUrl,
  ];
  for (final value in candidates) {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        !RegExp(
          r'\.(mp4|webm|mkv|mov)$',
          caseSensitive: false,
        ).hasMatch(uri.path)) {
      return value;
    }
  }
  return null;
}
