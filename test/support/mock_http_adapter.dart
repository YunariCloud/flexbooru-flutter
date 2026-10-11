import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Map<String, dynamic> postJson(
  int id, {
  String rating = 'g',
  String tag = 'solo',
}) => {
  'id': id,
  'rating': rating,
  'tag_string_general': tag,
  'image_width': 100,
  'image_height': 100,
};
