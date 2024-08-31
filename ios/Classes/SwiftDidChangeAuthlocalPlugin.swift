import Flutter
import UIKit
import LocalAuthentication

public class SwiftDidChangeAuthlocalPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "did_change_authlocal", binaryMessenger: registrar.messenger())
        let instance = SwiftDidChangeAuthlocalPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "didChangeBiometric":
            self.didChangeBiometric(result: result)
        case "createBiometricState":
            self.createBiometricState(result: result)
        case "setKeychainItem":
            self.setKeychainItem(result: result, arguments: call.arguments)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    private var keychainService: String? = nil
    private var keychainAccount: String? = nil

    func setKeychainItem(result: @escaping FlutterResult, arguments: Any?) {
        if let dic = arguments as? Dictionary<String, String?> {
            if let service = dic["service"], let account = dic["account"] {
                keychainService = service
                keychainAccount = account
                return result(true)
            }
        }
        return result(false)
    }


    private func createBiometricState(result: @escaping FlutterResult) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return result(false)
        }

        saveBiometricsPolicyState(data: context.evaluatedPolicyDomainState)
        return result(true)
    }

    private func didChangeBiometric(result: @escaping FlutterResult) {
        let context = LAContext()
        var error: NSError?
        
       // Check if biometrics can be evaluated
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError, laError.code == .biometryLockout {
                // Handle temporary lockout differently if desired
                return result(FlutterError(code: "BIOMETRICS_LOCKED", message: "Biometrics is temporarily locked", details: laError.localizedDescription))
            } else {
                // Handle other biometric errors
                return result(FlutterError(code: "BIOMETRICS_UNAVAILABLE", message: "Biometrics is not available", details: error?.localizedDescription))
            }
        }

        // Check if biometrics have changed
        if biometricsChanged() {
            return result(500)  // Biometric data has changed
        } else {
            return result(200)  // Biometric data has not changed
        }
    }

    private func biometricsChanged() -> Bool {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        // If there is no saved policy state yet, save it
        if let domainState = context.evaluatedPolicyDomainState {
            if domainState != getBiometricsPolicyState() {
                // Biometric data has changed
                return true
            }
        }

        return false
    }
    
    private func saveBiometricsPolicyState(data: Data?) {
        if let data = data, let keychainService = keychainService, let keychainAccount = keychainAccount {
            _ = KeyChainManager.save(data, service: keychainService, account: keychainAccount)
        }
    }
    
    private func getBiometricsPolicyState() -> Data? {
        if let keychainService = keychainService, let keychainAccount = keychainAccount {
            return KeyChainManager.read(service: keychainService, account: keychainAccount)
        }
        return nil
    }

}
