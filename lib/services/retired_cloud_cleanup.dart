import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remove credentials for the retired cloud backend; app data stays intact.
Future<void> clearRetiredCloudCredentials({
  FlutterSecureStorage? storage,
}) async {
  final secure = storage ?? const FlutterSecureStorage();
  for (final key in const [
    'flex_drive_oauth_config_v1',
    'flex_drive_oauth_token_v1',
    'flex_drive_sync_password_v1',
    'flex_drive_sync_enabled_v1',
  ]) {
    await secure.delete(key: key);
  }
}
