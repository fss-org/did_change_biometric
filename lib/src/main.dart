import 'dart:io';

import 'package:did_change_authlocal/src/status_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DidChangeAuthLocal {
  final methodChannel = const MethodChannel('did_change_authlocal');
  DidChangeAuthLocal._internal();

  static final DidChangeAuthLocal _instance = DidChangeAuthLocal._internal();

  static DidChangeAuthLocal get instance => _instance;

  /// For iOS
  /// This function will check if the user has updated the biometric
  Future<AuthLocalStatus?> _checkBiometricIOS() async {
    try {
      final int result = await methodChannel.invokeMethod('didChangeBiometric');
      switch (result) {
        case 200:
          return AuthLocalStatus.valid;
        case 500:
          return AuthLocalStatus.changed;
        default:
          return null;
      }
    } on PlatformException catch (e) {
      switch (e.code) {
        case "BIOMETRICS_UNAVAILABLE":
          return AuthLocalStatus.notAvailable;
        case "BIOMETRICS_LOCKED":
          return AuthLocalStatus.valid;
        default:
          return null;
      }
    }
  }

  /// 現在デバイスに登録されている生体認証の状態を保存
  Future<bool?> createBiometricState() async {
    try {
      if (Platform.isIOS) {
        // iOS
        return await methodChannel.invokeMethod('createBiometricState');
      } else if (Platform.isAndroid) {
        // Android
        final result = await methodChannel.invokeMethod('create_key');
        return result == "create_key_success";
      } else {
        return false;
      }
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  Future<AuthLocalStatus?> onCheckBiometric() async {
    return Platform.isIOS
        ? await _checkBiometricIOS()
        : await _checkBiometricAndroid();
  }

  //For Android ( Only Fingerprint )
  //If user does not update Finger then Biometric Status will be AuthLocalStatus.valid
  Future<AuthLocalStatus?> _checkBiometricAndroid() async {
    try {
      final result = await methodChannel.invokeMethod('check');
      return result == 'biometric_valid' ? AuthLocalStatus.valid : null;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'biometric_did_change':
          return AuthLocalStatus.changed;
        case 'biometric_invalid':
          return AuthLocalStatus.invalid;
        default:
          return null;
      }
    } on MissingPluginException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }


  Future<bool> isAvailableBiometric() async {
    final value = await methodChannel.invokeMethod('isAvailableBiometric');
    return value;
  }

}
