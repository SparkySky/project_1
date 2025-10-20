package com.meowResQ.mysafezone

import io.flutter.app.FlutterApplication
import com.huawei.agconnect.AGConnectInstance

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        try {
            AGConnectInstance.initialize(this)
            android.util.Log.i("MainApplication", "AGConnectInstance initialized successfully.")
        } catch (e: Exception) {
            android.util.Log.e("MainApplication", "Error initializing AGConnectInstance", e)
        }
    }
}
