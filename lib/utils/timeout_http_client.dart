import 'dart:async';

import 'package:http/http.dart' as http;

/// 给所有 Supabase 请求兜底超时的 HTTP client。
///
/// 弱网/假连接时请求可能永久悬挂(TCP 建立但无响应),导致各页面的
/// await 永不返回、loading 状态永不复位(全 App 审计发现 49 处此类风险)。
/// 统一在传输层加超时:悬挂 → TimeoutException → 走各页面现有的
/// catch/finally 错误路径,loading 正常复位。
///
/// 细节:
/// - storage 上传(整个文件单个 multipart POST/PUT)按 10 分钟放宽,
///   避免大视频/群文件在慢速上行下被 25s 误杀;
/// - send() 的超时只覆盖「发出请求 → 收到响应头」;响应体流另用
///   per-chunk 空闲超时兜底,中途断流同样会抛 TimeoutException。
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  static const _timeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(minutes: 10);

  bool _isStorageUpload(http.BaseRequest request) {
    return (request.method == 'POST' || request.method == 'PUT') &&
        request.url.path.contains('/storage/v1/object');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final timeout = _isStorageUpload(request) ? _uploadTimeout : _timeout;
    final res = await _inner.send(request).timeout(timeout);
    // 响应体 per-chunk 空闲超时:两个数据块间隔超时视为断流
    final guardedStream = res.stream.timeout(
      _timeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException('Response body stalled', _timeout),
        );
        sink.close();
      },
    );
    return http.StreamedResponse(
      guardedStream,
      res.statusCode,
      contentLength: res.contentLength,
      request: res.request,
      headers: res.headers,
      isRedirect: res.isRedirect,
      persistentConnection: res.persistentConnection,
      reasonPhrase: res.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
