import UIKit
import Flutter
import LocalAuthentication

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up biometric authentication channel
    let controller = window?.rootViewController as! FlutterViewController
    let biometricChannel = FlutterMethodChannel(name: "team_ragnarok/biometric",
                                               binaryMessenger: controller.binaryMessenger)
    
    biometricChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "isAvailable":
        result(self.isBiometricAvailable())
      case "getAvailableBiometrics":
        result(self.getAvailableBiometrics())
      case "authenticate":
        self.authenticate(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func isBiometricAvailable() -> Bool {
    let context = LAContext()
    var error: NSError?
    
    return context.canEvaluatePolicy(.biometryAny, error: &error)
  }
  
  private func getAvailableBiometrics() -> [String] {
    let context = LAContext()
    var error: NSError?
    var availableBiometrics: [String] = []
    
    guard context.canEvaluatePolicy(.biometryAny, error: &error) else {
      return availableBiometrics
    }
    
    switch context.biometryType {
    case .faceID:
      availableBiometrics.append("face")
    case .touchID:
      availableBiometrics.append("fingerprint")
    case .opticID:
      if #available(iOS 17.0, *) {
        availableBiometrics.append("iris")
      }
    default:
      break
    }
    
    return availableBiometrics
  }
  
  private func authenticate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let context = LAContext()
    
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
      return
    }
    
    let authMessages = args["authMessages"] as? [String: Any]
    let iosMessages = authMessages?["iosMessages"] as? [String: String]
    let signInTitle = iosMessages?["signInTitle"] ?? "Autenticazione Biometrica"
    let fallbackTitle = iosMessages?["goToSettingsButton"] ?? "Usa PIN/Password"
    
    var error: NSError?
    guard context.canEvaluatePolicy(.biometryAny, error: &error) else {
      if let err = error {
        switch err.code {
        case LAError.biometryNotAvailable.rawValue:
          result(FlutterError(code: "NotAvailable", message: "Biometry not available", details: nil))
        case LAError.biometryNotEnrolled.rawValue:
          result(FlutterError(code: "NotEnrolled", message: "No biometric credentials enrolled", details: nil))
        case LAError.passcodeNotSet.rawValue:
          result(FlutterError(code: "PasscodeNotSet", message: "Passcode not set", details: nil))
        default:
          result(FlutterError(code: "NotAvailable", message: err.localizedDescription, details: nil))
        }
      } else {
        result(FlutterError(code: "NotAvailable", message: "Biometric authentication not available", details: nil))
      }
      return
    }
    
    context.localizedFallbackTitle = fallbackTitle
    
    context.evaluatePolicy(.biometryAny, localizedReason: signInTitle) { success, error in
      DispatchQueue.main.async {
        if success {
          result(true)
        } else {
          if let err = error as? LAError {
            switch err.code {
            case .userCancel:
              result(FlutterError(code: "UserCancel", message: "User canceled", details: nil))
            case .userFallback:
              result(FlutterError(code: "UserFallback", message: "User chose fallback", details: nil))
            case .systemCancel:
              result(FlutterError(code: "SystemCancel", message: "System canceled", details: nil))
            case .biometryLockout:
              result(FlutterError(code: "LockedOut", message: "Biometry locked out", details: nil))
            case .biometryNotAvailable:
              result(FlutterError(code: "NotAvailable", message: "Biometry not available", details: nil))
            case .biometryNotEnrolled:
              result(FlutterError(code: "NotEnrolled", message: "No biometric credentials enrolled", details: nil))
            case .invalidContext:
              result(FlutterError(code: "InvalidContext", message: "Invalid context", details: nil))
            case .notInteractive:
              result(FlutterError(code: "NotInteractive", message: "Not interactive", details: nil))
            default:
              result(FlutterError(code: "AuthenticationFailed", message: err.localizedDescription, details: nil))
            }
          } else {
            result(FlutterError(code: "AuthenticationFailed", message: "Authentication failed", details: nil))
          }
        }
      }
    }
  }
}