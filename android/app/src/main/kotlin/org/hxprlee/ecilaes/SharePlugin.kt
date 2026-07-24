package org.hxprlee.ecilaes

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

class SharePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler,
    PluginRegistry.NewIntentListener {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var context: android.content.Context? = null
  private var activity: Activity? = null
  private var events: EventChannel.EventSink? = null

  private val supportedHosts = setOf(
      "music.youtube.com",
      "www.youtube.com",
      "youtube.com",
      "youtu.be",
      "m.youtube.com",
  )

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, "ecilaes/share")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(binding.binaryMessenger, "ecilaes/share/updates")
    eventChannel.setStreamHandler(this)

    context = binding.applicationContext
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    context = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "shareText" -> {
        val text = call.argument<String>("text")
        val subject = call.argument<String>("subject")
        if (text.isNullOrEmpty()) {
          result.error("-1", "text is required", null)
          return
        }
        try {
          shareText(text, subject)
          result.success(true)
        } catch (e: Exception) {
          result.error("-2", e.message ?: "shareText failed", null)
        }
      }
      "shareFile" -> {
        val path = call.argument<String>("path")
        val mimeType = call.argument<String>("mimeType")
        if (path.isNullOrEmpty()) {
          result.error("-3", "path is required", null)
          return
        }
        try {
          shareFile(path, mimeType)
          result.success(true)
        } catch (e: Exception) {
          result.error("-4", e.message ?: "shareFile failed", null)
        }
      }
      "getInitialShared" -> {
        val act = activity
        if (act == null) {
          result.success(null)
          return
        }
        val payload = extractSharePayload(act.intent)
        result.success(payload)
      }
      else -> result.notImplemented()
    }
  }

  private fun shareText(text: String, subject: String?) {
    val act = activity ?: throw IllegalStateException("Activity not attached")
    val send = Intent(Intent.ACTION_SEND).apply {
      type = "text/plain"
      putExtra(Intent.EXTRA_TEXT, text)
      if (!subject.isNullOrEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
    }
    val chooser = Intent.createChooser(send, null).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    act.startActivity(chooser)
  }

  private fun shareFile(path: String, mimeType: String?) {
    val ctx = context ?: throw IllegalStateException("Context not attached")
    val act = activity ?: throw IllegalStateException("Activity not attached")
    val file = File(path)
    if (!file.exists()) throw IllegalArgumentException("File does not exist: $path")

    val authority = "${ctx.packageName}.fileprovider"
    val uri = FileProvider.getUriForFile(ctx, authority, file)

    val resolvedMime = mimeType ?: "audio/*"

    val send = Intent(Intent.ACTION_SEND).apply {
      type = resolvedMime
      putExtra(Intent.EXTRA_STREAM, uri)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val chooser = Intent.createChooser(send, null).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    act.startActivity(chooser)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    this.events = events
  }

  override fun onCancel(arguments: Any?) {
    events = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
    // Drain any intent that arrived between detach and reattach (e.g. an
    // orientation change while the activity was being recreated). Without
    // this, an intent delivered during the gap is lost because the previous
    // NewIntentListener has already been detached.
    binding.activity.intent?.let { intent ->
      extractSharePayload(intent)?.let { events?.success(it) }
      binding.activity.intent = null
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onNewIntent(intent: Intent): Boolean {
    val payload = extractSharePayload(intent) ?: return false
    events?.success(payload)
    return true
  }

  private fun extractSharePayload(intent: Intent?): Map<String, String>? {
    if (intent == null) return null
    val action = intent.action ?: return null
    return when (action) {
      Intent.ACTION_SEND -> {
        val type = intent.type ?: ""
        if (type.startsWith("text/")) {
          val text = intent.getStringExtra(Intent.EXTRA_TEXT)
          if (!text.isNullOrBlank()) {
            val url = extractUrl(text)
            if (url != null) {
              mapOf("kind" to "url", "value" to url)
            } else {
              mapOf("kind" to "text", "value" to text)
            }
          } else null
        } else null
      }
      Intent.ACTION_VIEW -> {
        val data = intent.data?.toString()
        if (!data.isNullOrBlank() && isSupportedUrl(data)) {
          mapOf("kind" to "url", "value" to data)
        } else null
      }
      else -> null
    }
  }

  private fun extractUrl(text: String): String? {
    val regex = Regex("https?://\\S+")
    val match = regex.find(text) ?: return null
    val candidate = match.value.trimEnd('.', ',', ')', ']', '!', '?', ';')
    return if (isSupportedUrl(candidate)) candidate else null
  }

  private fun isSupportedUrl(url: String): Boolean {
    val uri = runCatching { android.net.Uri.parse(url) }.getOrNull() ?: return false
    val host = uri.host?.lowercase() ?: return false
    return supportedHosts.any { host == it || host.endsWith(".$it") }
  }
}