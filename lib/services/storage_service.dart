import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show requireUid;
import 'package:uuid/uuid.dart';

class StorageService {
  final _client = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String> uploadAvatar(XFile file, {String? oldUrl}) async {
    final userId = requireUid(_client);
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    // 用 uuid 唯一文件名 + upsert:false（纯 INSERT），与群头像一致。
    // 原本固定路径 + upsert:true 会走 ON CONFLICT DO UPDATE，被 media 桶
    // 的 storage RLS 拒（无 SELECT 策略 + UPDATE 限制），导致更换头像 403。
    final path = 'avatars/$userId/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    // 删除旧头像，避免孤儿文件占用配额（尽力而为，失败忽略）
    if (oldUrl != null && oldUrl.isNotEmpty) {
      final oldPath = _pathFromPublicUrl(oldUrl);
      if (oldPath != null) {
        try {
          await _client.storage.from('media').remove([oldPath]);
        } catch (_) {}
      }
    }
    return _client.storage.from('media').getPublicUrl(path);
  }

  /// 从公开 URL 反解出 storage 内的对象路径（用于删除旧文件）。
  String? _pathFromPublicUrl(String url) {
    const marker = '/object/public/media/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    return Uri.decodeComponent(
      url.substring(i + marker.length).split('?').first,
    );
  }

  /// 群头像：用 uuid 文件名且不 upsert，每次都是 INSERT（INSERT 策略仅要求
  /// 已登录即可），避免触发 storage 的 UPDATE 策略（要求路径第2段=本人uid）。
  Future<String> uploadGroupAvatar(String conversationId, XFile file) async {
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = 'avatars/groups/$conversationId/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadPostImage(XFile file) async {
    final userId = requireUid(_client);
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = 'posts/$userId/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from('media').uploadBinary(path, bytes);
    return _client.storage.from('media').getPublicUrl(path);
  }

  Future<List<String>> uploadPostImages(List<XFile> files) async {
    final urls = await Future.wait(files.map(uploadPostImage));
    return urls;
  }

  Future<String> uploadPostVideo(XFile file) async {
    final userId = requireUid(_client);
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'mp4';
    final path = 'posts/$userId/videos/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _videoMime(ext), upsert: false),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  Future<({String url, int size})> uploadChatFile(
    Uint8List bytes,
    String fileName,
  ) async {
    final userId = requireUid(_client);
    final ext = fileName.contains('.') ? fileName.split('.').last : '';
    final safeName = '${_uuid.v4()}${ext.isNotEmpty ? '.$ext' : ''}';
    final path = 'chat/$userId/files/$safeName';
    // 已知类型用其正规 MIME（.m4a→audio/mp4、pdf、office、zip 等），未知类型
    // 回退 octet-stream。桶已放开 allowed_mime_types，任意类型均可上传。
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _chatFileContentType(ext),
          ),
        );
    final url = _client.storage.from('media').getPublicUrl(path);
    return (url: url, size: bytes.length);
  }

  Future<String> uploadChatImage(XFile file) async {
    final userId = requireUid(_client);
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final path = 'chat/$userId/images/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: _imageMime(ext)),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  static String _imageMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<String> uploadChatAudio(Uint8List bytes, {String ext = 'aac'}) async {
    final userId = requireUid(_client);
    // Map extension to supported MIME type
    final mime = _audioMime(ext);
    final path = 'chat/$userId/audio/${_uuid.v4()}.$ext';
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: mime),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  static String _audioMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      case 'opus':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4'; // record 包 aacLc 实为 MP4/M4A 容器
      case 'mp4':
        return 'audio/mp4';
      default:
        return 'audio/mp4';
    }
  }

  Future<({String url, int size})> uploadChatVideo(XFile file) async {
    final userId = requireUid(_client);
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'mp4';
    final path = 'chat/$userId/video/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: _videoMime(ext)),
        );
    final url = _client.storage.from('media').getPublicUrl(path);
    return (url: url, size: bytes.length);
  }

  static String _videoMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
      case 'qt':
        return 'video/quicktime';
      default:
        // The media bucket allows application/octet-stream. Use it for less
        // common video containers so uploads do not fail on a MIME whitelist.
        return 'application/octet-stream';
    }
  }

  // 聊天文件上传的 content-type：已知类型返回 media 桶白名单内的正规 MIME，
  // 未知类型返回 octet-stream 兜底。避免 m4a 等被存储服务探测成白名单外类型。
  static String _chatFileContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'm4a':
      case 'm4b':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
      case 'oga':
      case 'opus':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'weba':
        return 'audio/webm';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
      case 'qt':
        return 'video/quicktime';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
