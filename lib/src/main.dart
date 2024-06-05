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
  Future<AuthLocalStatus?> checkBiometricIOS() async {
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

  /// For iOS
  /// This function will create biometric policy state
  Future<bool?> createBiometricState() async {
    try {
      if (Platform.isIOS) {
        return await methodChannel.invokeMethod('createBiometricState');
      } else {
        final result = await methodChannel.invokeMethod('create_key');
        return result == "create_key_success";
      }
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  Future<AuthLocalStatus?> onCheckBiometric({String? token}) async {
    return Platform.isIOS
        ? await checkBiometricIOS()
        : await checkBiometricAndroid();
  }

  //For Android ( Only Fingerprint )
  //If user does not update Finger then Biometric Status will be AuthLocalStatus.valid
  Future<AuthLocalStatus?> checkBiometricAndroid() async {
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
}
