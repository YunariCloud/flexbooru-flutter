package com.flexbooru.app.flexbooru

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flexbooru.app/updates")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val path = call.argument<String>("path") ?: error("Missing APK path")
                    val file = File(path).canonicalFile
                    val root = File(filesDir, "updates").canonicalFile
                    require(file.parentFile == root && file.isFile && file.extension.equals("apk", ignoreCase = true)) {
                        "Invalid update file"
                    }
                    val archive = packageManager.getPackageArchiveInfo(file.path, 0)
                    require(archive?.packageName == packageName) { "APK belongs to another app" }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")))
                        result.success("permission")
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        startActivity(Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                        result.success("opened")
                    }
                } catch (exception: Exception) {
                    result.error("UPDATE_INSTALL_FAILED", exception.message, null)
                }
            }
    }
}
