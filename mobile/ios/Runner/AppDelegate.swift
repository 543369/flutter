import Flutter
import UIKit
import UserNotifications
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var appleResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "petcare/apple", binaryMessenger: controller.binaryMessenger).setMethodCallHandler { [weak self] call, result in
        guard let self = self, call.method == "signIn", let nonce = call.arguments as? String else { result(FlutterMethodNotImplemented); return }
        guard self.appleResult == nil else { result(FlutterError(code: "BUSY", message: nil, details: nil)); return }
        self.appleResult = result
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = nonce
        let authorization = ASAuthorizationController(authorizationRequests: [request])
        authorization.delegate = self
        authorization.presentationContextProvider = self
        authorization.performRequests()
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { return window! }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    defer { appleResult = nil }
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
      appleResult?(FlutterError(code: "NO_TOKEN", message: nil, details: nil)); return
    }
    appleResult?(token)
  }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    appleResult?(FlutterError(code: "APPLE_CANCELLED_OR_FAILED", message: nil, details: nil))
    appleResult = nil
  }
}
