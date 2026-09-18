package com.teamragnarok.asd.app

import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executor

class MainActivity: FlutterFragmentActivity(), MethodCallHandler {
    private val BIOMETRIC_CHANNEL = "team_ragnarok/biometric"
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private lateinit var promptInfo: BiometricPrompt.PromptInfo

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL).setMethodCallHandler(this)
        
        executor = ContextCompat.getMainExecutor(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(isBiometricAvailable())
            }
            "getAvailableBiometrics" -> {
                result.success(getAvailableBiometrics())
            }
            "authenticate" -> {
                authenticate(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isBiometricAvailable(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val biometricManager = androidx.biometric.BiometricManager.from(this)
            when (biometricManager.canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
                androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS -> true
                else -> false
            }
        } else {
            false
        }
    }

    private fun getAvailableBiometrics(): List<String> {
        val availableBiometrics = mutableListOf<String>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val biometricManager = androidx.biometric.BiometricManager.from(this)
            when (biometricManager.canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
                androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS -> {
                    availableBiometrics.add("fingerprint")
                }
            }
            
            // Check for face authentication
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                when (biometricManager.canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
                    androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS -> {
                        if (!availableBiometrics.contains("fingerprint")) {
                            availableBiometrics.add("face")
                        }
                    }
                }
            }
        }
        
        return availableBiometrics
    }

    private fun authenticate(call: MethodCall, result: Result) {
        if (!isBiometricAvailable()) {
            result.error("NotAvailable", "Biometric authentication not available", null)
            return
        }

        val authMessages = call.argument<Map<String, Any?>>("authMessages")
        val androidMessages = (authMessages?.get("androidMessages") as? Map<*, *>) ?: emptyMap<Any?, Any?>()
        val signInTitle = (androidMessages["signInTitle"] as? String) ?: "Autenticazione Biometrica"
        val fingerprintHint = (androidMessages["fingerprintHint"] as? String) ?: "Tocca il sensore delle impronte"

        biometricPrompt = BiometricPrompt(this as FragmentActivity,
            executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                when (errorCode) {
                    BiometricPrompt.ERROR_USER_CANCELED -> result.error("UserCancel", "User canceled", null)
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON -> result.error("UserFallback", "User chose fallback", null)
                    BiometricPrompt.ERROR_NO_BIOMETRICS -> result.error("NotEnrolled", "No biometrics enrolled", null)
                    BiometricPrompt.ERROR_HW_NOT_PRESENT -> result.error("NotAvailable", "Hardware not present", null)
                    BiometricPrompt.ERROR_HW_UNAVAILABLE -> result.error("NotAvailable", "Hardware unavailable", null)
                    BiometricPrompt.ERROR_LOCKOUT -> result.error("LockedOut", "Too many attempts", null)
                    BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> result.error("PermanentlyLockedOut", "Permanently locked out", null)
                    else -> result.error("BiometricError", errString.toString(), null)
                }
            }

            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(authResult)
                result.success(true)
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                result.error("AuthenticationFailed", "Authentication failed", null)
            }
        })

        promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(signInTitle)
            .setSubtitle(fingerprintHint)
            .setNegativeButtonText("Usa PIN/Password")
            .setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK or androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            .build()

        biometricPrompt.authenticate(promptInfo)
    }
}