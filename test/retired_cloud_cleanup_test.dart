import 'package:flexbooru/services/retired_cloud_cleanup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'retired cloud credentials are removed without touching the LAN vault',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'flex_drive_oauth_config_v1': 'config',
        'flex_drive_oauth_token_v1': 'token',
        'flex_drive_sync_password_v1': 'password',
        'flex_drive_sync_enabled_v1': 'true',
        'flexbooru_sync_vault_key_v1': 'keep-local-vault-key',
      });
      await clearRetiredCloudCredentials();
      const secure = FlutterSecureStorage();
      expect(await secure.readAll(), {
        'flexbooru_sync_vault_key_v1': 'keep-local-vault-key',
      });
      await clearRetiredCloudCredentials();
      expect(
        await secure.read(key: 'flexbooru_sync_vault_key_v1'),
        'keep-local-vault-key',
      );
    },
  );
}
