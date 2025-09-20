package com.example.untitled

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Flutter 엔진 정리
        if (flutterEngine != null) {
            flutterEngine?.lifecycleChannel?.appIsDetached()
        }
    }
}
