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
            case "checkIfFaceIDChanged":
                self.checkIfFaceIDChanged(result: result)
            case "createKeychainItem":
                self.createKeychainItem(result: result)
            case "get_token":
                self.authenticateBiometric { data,code in
                    switch code {
                    case 200:
                        result(data)
                    case -7:
                        result(FlutterError(code:"biometric_invalid",message:"Invalid biometric",details: data as Any))
                    default:
                        result(FlutterError(code:"unknow", message: data, details: nil))
                    }}
            default:
                result(FlutterMethodNotImplemented)
        }
    }

    private func createKeychainItem(result: @escaping FlutterResult) {
        let accessControl = SecAccessControlCreateWithFlags(nil, 
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, 
            .biometryCurrentSet, 
            nil)!

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "biometricCheck",
            kSecValueData as String: "someData".data(using: .utf8)!,
            kSecAttrAccessControl as String: accessControl
        ]

        // First, delete the old item if it exists
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "biometricCheck"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess {
            result(true)
        } else {
            result(FlutterError(code: "CREATE_KEYCHAIN_ITEM_FAILED", message: "Error creating Keychain item", details: status))
        }
    }

    private func checkIfFaceIDChanged(result: @escaping FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "biometricCheck",
            kSecReturnData as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip // Do not prompt user
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            result(200) // Face ID has not changed
        } else if status == errSecItemNotFound || status == errSecAuthFailed {
            result(500) // Keychain item not found or authentication failed, treat as Face ID changed
        } else {
            result(FlutterError(code: "CHECK_KEYCHAIN_ITEM_FAILED", message: "Error checking Keychain item", details: status))
        }
    }

    func authenticateBiometric(complete : @escaping (String?, Int?) -> Void){
        let context = LAContext()
        var authError : NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) == false {
            complete(nil, authError?.code)
            return
        }
        
        if let biometricData = context.evaluatedPolicyDomainState {
            let base64Data = biometricData.base64EncodedData()
            let token = String(data: base64Data, encoding: .utf8)
            complete(token, 200)
        }else {
            complete(nil, 998)
        }
    }

}


public class DidChangeBiometricPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "face_id_checker", binaryMessenger: registrar.messenger())
        let instance = DidChangeBiometricPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
}
