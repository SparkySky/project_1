package com.meowResQ.mysafezone

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Build
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable autofill compatibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill = android.view.View.IMPORTANT_FOR_AUTOFILL_YES_EXCLUDE_DESCENDANTS
        }
    }
}