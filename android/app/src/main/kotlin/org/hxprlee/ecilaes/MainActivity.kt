package org.hxprlee.ecilaes

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Enable edge-to-edge before super.onCreate so the decor window applies
    // transparent system bars from the first frame onward.
    WindowCompat.setDecorFitsSystemWindows(window, false)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      window.navigationBarColor = android.graphics.Color.TRANSPARENT
      window.statusBarColor = android.graphics.Color.TRANSPARENT
    }
    super.onCreate(savedInstanceState)
  }

  override fun getIntent(): Intent {
    return super.getIntent() ?: Intent()
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(SharePlugin())
  }
}