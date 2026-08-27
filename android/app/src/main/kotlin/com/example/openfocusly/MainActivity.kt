package com.example.openfocusly

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.view.WindowManager
import android.view.KeyEvent
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "saf"
        private const val REQUEST_CREATE = 71
        private const val REQUEST_OPEN = 72
        private const val REQUEST_PICK_DIRECTORY = 73
    }

    private var pendingFileResult: MethodChannel.Result? = null
    private var volumeEvents: EventChannel.EventSink? = null
    private var volumeButtonsEnabled = false
    private var pendingDirectoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)
                "create" -> createDocument(call, result)
                "open" -> openDocument(call, result)
                "write" -> writeBytes(call, result)
                "read" -> readBytes(call, result)
                "pickDirectory" -> pickDirectory(result)
                "listMarkdownFiles" -> listMarkdownFiles(call, result)
                "readTextFile" -> readTextFile(call, result)
                "writeTextFile" -> writeTextFile(call, result)
                "documentInfo" -> documentInfo(call, result)
                "deleteDocument" -> deleteDocument(call, result)
                "setKeepScreenOn" -> setKeepScreenOn(call, result)
                "setFullscreen" -> setFullscreen(call, result)
                "setVolumeButtons" -> setVolumeButtons(call, result)
                else -> result.notImplemented()
            }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "saf/volume").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { volumeEvents = events }
            override fun onCancel(arguments: Any?) { volumeEvents = null }
        })
    }

    private fun createDocument(call: MethodCall, result: MethodChannel.Result) {
        pendingFileResult = result
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mime") ?: "*/*"
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "file")
        }, REQUEST_CREATE)
    }

    private fun openDocument(call: MethodCall, result: MethodChannel.Result) {
        pendingFileResult = result
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mime") ?: "*/*"
        }, REQUEST_OPEN)
    }

    private fun writeBytes(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(call.argument<String>("uri") ?: throw IllegalArgumentException("missing uri"))
            val bytes = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException("missing bytes")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IllegalStateException("cannot open output stream")
            result.success(true)
        } catch (e: Exception) { result.error("write", e.message, null) }
    }

    private fun readBytes(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(call.argument<String>("uri") ?: throw IllegalArgumentException("missing uri"))
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
            result.success(bytes)
        } catch (e: Exception) { result.error("read", e.message, null) }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error("PICKER_BUSY", "The folder picker is already open.", null)
            return
        }
        pendingDirectoryResult = result
        try {
            startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                },
                REQUEST_PICK_DIRECTORY
            )
        } catch (e: Exception) {
            pendingDirectoryResult = null
            result.error("PICKER_LAUNCH_FAILED", e.message, null)
        }
    }

    private fun listMarkdownFiles(call: MethodCall, result: MethodChannel.Result) {
        try {
            val treeUri = Uri.parse(call.argument<String>("treeUri") ?: throw IllegalArgumentException("missing treeUri"))
            val tree = DocumentFile.fromTreeUri(this, treeUri) ?: throw IllegalStateException("selected folder is unavailable")
            result.success(tree.listFiles().filter { it.isFile && it.name?.endsWith(".md", true) == true }.map {
                mapOf("uri" to it.uri.toString(), "name" to (it.name ?: "nota.md"), "size" to it.length(), "lastModified" to it.lastModified())
            })
        } catch (e: Exception) { result.error("listMarkdownFiles", e.message, null) }
    }

    private fun readTextFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(call.argument<String>("uri") ?: throw IllegalArgumentException("missing uri"))
            val text = contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            result.success(text)
        } catch (e: Exception) { result.error("readTextFile", e.message, null) }
    }

    private fun writeTextFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val treeUri = call.argument<String>("treeUri") ?: throw IllegalArgumentException("missing treeUri")
            val fileName = call.argument<String>("fileName") ?: throw IllegalArgumentException("missing fileName")
            val content = call.argument<String>("content") ?: ""
            val existingUri = call.argument<String>("existingUri")
            val tree = DocumentFile.fromTreeUri(this, Uri.parse(treeUri)) ?: throw IllegalStateException("selected folder is unavailable")
            var target: DocumentFile? = null
            if (!existingUri.isNullOrBlank()) {
                target = DocumentFile.fromSingleUri(this, Uri.parse(existingUri))
                if (target != null && target.exists() && target.name != fileName) target.renameTo(fileName)
            }
            if (target == null || !target.exists()) target = tree.findFile(fileName)
            if (target == null || !target.exists()) target = tree.createFile("text/markdown", fileName)
            if (target == null) throw IllegalStateException("could not create markdown file")
            contentResolver.openOutputStream(target.uri, "wt")?.use { it.write(content.toByteArray(Charsets.UTF_8)) } ?: throw IllegalStateException("cannot write markdown file")
            result.success(target.uri.toString())
        } catch (e: Exception) { result.error("writeTextFile", e.message, null) }
    }

    private fun documentInfo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(call.argument<String>("uri") ?: throw IllegalArgumentException("missing uri"))
            val file = DocumentFile.fromSingleUri(this, uri) ?: throw IllegalStateException("file not found")
            result.success(mapOf("uri" to file.uri.toString(), "name" to (file.name ?: ""), "size" to file.length(), "exists" to file.exists(), "canWrite" to file.canWrite()))
        } catch (e: Exception) { result.error("documentInfo", e.message, null) }
    }

    private fun deleteDocument(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(call.argument<String>("uri") ?: throw IllegalArgumentException("missing uri"))
            result.success(DocumentFile.fromSingleUri(this, uri)?.delete() == true)
        } catch (e: Exception) { result.error("deleteDocument", e.message, null) }
    }

    private fun setKeepScreenOn(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        if (enabled) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        result.success(true)
    }

    private fun setFullscreen(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController
            if (enabled) {
                controller?.hide(android.view.WindowInsets.Type.systemBars())
                controller?.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                controller?.show(android.view.WindowInsets.Type.systemBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (enabled) {
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            } else 0
        }
        result.success(true)
    }


    private fun setVolumeButtons(call: MethodCall, result: MethodChannel.Result) {
        volumeButtonsEnabled = call.argument<Boolean>("enabled") ?: false
        result.success(true)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeButtonsEnabled) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> { volumeEvents?.success("up"); return true }
                KeyEvent.KEYCODE_VOLUME_DOWN -> { volumeEvents?.success("down"); return true }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_CREATE, REQUEST_OPEN -> {
                val callback = pendingFileResult
                pendingFileResult = null
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    callback?.success(data.data.toString())
                } else {
                    callback?.success(null)
                }
            }

            REQUEST_PICK_DIRECTORY -> {
                val callback = pendingDirectoryResult
                pendingDirectoryResult = null

                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    callback?.success(null)
                    return
                }

                val treeUri = data.data!!
                try {
                    val takeFlags = (data.flags) and (
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    if (takeFlags != 0) {
                        contentResolver.takePersistableUriPermission(treeUri, takeFlags)
                    }
                } catch (_: SecurityException) {
                }

                val directory = DocumentFile.fromTreeUri(this, treeUri)
                if (directory == null) {
                    callback?.error(
                        "INVALID_DIRECTORY",
                        "selected directory is unavailable",
                        null
                    )
                    return
                }

                callback?.success(
                    mapOf(
                        "uri" to treeUri.toString(),
                        "name" to (directory.name ?: "cartella")
                    )
                )
            }
        }
    }
}

import android.media.MediaPlayer
// ... inside class:
private var mediaPlayer: MediaPlayer? = null

// in the when(call.method) block add:
"playSound" -> playSound(call, result)

private fun playSound(call: MethodCall, result: MethodChannel.Result) {
    val path = call.argument<String>("path")
    if (path == null) { result.error("playSound", "missing path", null); return }
    try {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setDataSource(path)
            prepare()
            setOnCompletionListener { it.release() }
            start()
        }
        result.success(true)
    } catch (e: Exception) { result.error("playSound", e.message, null) }
}

override fun onDestroy() { mediaPlayer?.release(); super.onDestroy() }