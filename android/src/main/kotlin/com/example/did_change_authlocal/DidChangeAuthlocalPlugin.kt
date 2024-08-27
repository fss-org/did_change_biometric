package com.example.did_change_authlocal

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException

import android.security.keystore.KeyProperties
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.InvalidKeyException
import java.security.Key
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.*
import androidx.biometric.BiometricPrompt

import android.content.Context
import android.util.Log


/** DidChangeAuthlocalPlugin */
class DidChangeAuthlocalPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var keyStore: KeyStore? = null
  private val KEY_NAME = "did_change_authlocal"
  private var biometricPrompt: BiometricPrompt? = null
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "did_change_authlocal")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.getApplicationContext()
  }

  @RequiresApi(Build.VERSION_CODES.N)
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {

    when (call.method) {
      "check" -> settingFingerPrint(result)
      "create_key" -> createKey(result)
      "isAvailableBiometric" -> isAvailableBiometric(result)
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun settingFingerPrint(result: Result) {
    val cipher: Cipher = getCipher()
    val secretKey: SecretKey = getSecretKey()

    try {
      cipher.init(Cipher.ENCRYPT_MODE, secretKey)
      result.success("biometric_valid")
    } catch (e: KeyPermanentlyInvalidatedException) {
      result.error("biometric_did_change",
        "Yes your hand has been changed, please login to activate again", e.toString())
    } catch (e: InvalidKeyException) {
      e.printStackTrace()
      result.error("biometric_invalid", "Invalid biometric", e.toString())
    }

    /* 認証ダイアログ表示は Flutter の local_auth で対応可能なので不要
    // Title required
    val promptInfo = BiometricPrompt.PromptInfo.Builder()
      .setTitle("Biometric")
      .setDescription("Check Biometric")
      .setNegativeButtonText("OK")
      .build()

    try {
      cipher.init(Cipher.ENCRYPT_MODE, secretKey)
      biometricPrompt?.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    } catch (e: KeyPermanentlyInvalidatedException) {
      // 認証エラーで例外が発生したらキーストアから削除して新しく作り直しているので、次回からは認証が通る
      // 認証エラー時に新しく勝手に登録されたら意味がないので削除
      keyStore?.deleteEntry(KEY_NAME)
      if (getCurrentKey(KEY_NAME) == null) {
        generateSecretKey(KeyGenParameterSpec.Builder(KEY_NAME,
          KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_CBC)
          .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
          .setUserAuthenticationRequired(true) // Invalidate the keys if the user has registered a new biometric
          .setInvalidatedByBiometricEnrollment(true).build())
      }
    }
     */
  }

  private fun isAvailableBiometric(result: Result) {
    var isAvailable = false
    val biometricManager = BiometricManager.from(context)
    when (biometricManager.canAuthenticate(BIOMETRIC_STRONG)) {
      BiometricManager.BIOMETRIC_SUCCESS -> {
        isAvailable = true
        Log.d("MY_APP_TAG", "App can authenticate using biometrics.")
      }
      BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
        Log.e("MY_APP_TAG", "No biometric features available on this device.")
      BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
        Log.e("MY_APP_TAG", "Biometric features are currently unavailable.")
      BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
        // Prompts the user to create credentials that your app accepts.
        Log.e("MY_APP_TAG", "BIOMETRIC_ERROR_NONE_ENROLLED")
      }
    }
    result.success(isAvailable)
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun createKey(result: Result) {
    // Delete existing key if it exists
    if (getCurrentKey(KEY_NAME) != null) {
      keyStore?.deleteEntry(KEY_NAME)
    }
    generateSecretKey(KeyGenParameterSpec.Builder(KEY_NAME,
      KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
      .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
      .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
      .setUserAuthenticationRequired(true)
      .setInvalidatedByBiometricEnrollment(true)
      .build())
    result.success("create_key_success")
  }

  fun getCurrentKey(keyName: String): Key? {
    keyStore?.load(null)
    return keyStore?.getKey(keyName, null)
  }

  @RequiresApi(Build.VERSION_CODES.N)
  fun getSecretKey(): SecretKey {
    try {
      keyStore = KeyStore.getInstance("AndroidKeyStore")
      keyStore?.load(null)
    } catch (e: Exception) {
      e.printStackTrace()
    }
    var keyGenerator: KeyGenerator? = null
    try {
      keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
    } catch (e: Exception) {
      e.printStackTrace()
    }
    try {
      if (getCurrentKey(KEY_NAME) == null) {
        keyGenerator!!.init(
          KeyGenParameterSpec.Builder(KEY_NAME,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(
            KeyProperties.BLOCK_MODE_CBC)
            .setUserAuthenticationRequired(true).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setInvalidatedByBiometricEnrollment(true)
            .build())
        keyGenerator.generateKey()
      }

    } catch (e: Exception) {
      e.printStackTrace()
    }
    return keyStore?.getKey(KEY_NAME, null) as SecretKey
  }

  @RequiresApi(Build.VERSION_CODES.M)
  fun getCipher(): Cipher {
    return Cipher.getInstance(
      KeyProperties.KEY_ALGORITHM_AES + "/"
              + KeyProperties.BLOCK_MODE_CBC + "/"
              + KeyProperties.ENCRYPTION_PADDING_PKCS7)
  }

  @RequiresApi(Build.VERSION_CODES.M)
  fun generateSecretKey(keyGenParameterSpec: KeyGenParameterSpec) {
    val keyGenerator = KeyGenerator.getInstance(
      KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
    keyGenerator.init(keyGenParameterSpec)
    keyGenerator.generateKey()
  }
}
