import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bgTaskId: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Keep the relay (MS sync) forwarding for a short window if the app is
    // briefly backgrounded — see lib/services/ms_relay/background_keepalive.dart.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundKeepAlive") {
      let channel = FlutterMethodChannel(
        name: "wealth/background_keepalive",
        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "begin":
          self?.beginRelayBackgroundTask()
          result(nil)
        case "end":
          self?.endRelayBackgroundTask()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func beginRelayBackgroundTask() {
    endRelayBackgroundTask()
    bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "ms-relay") { [weak self] in
      // Expiration handler — iOS is reclaiming the time; release the task.
      self?.endRelayBackgroundTask()
    }
  }

  private func endRelayBackgroundTask() {
    if bgTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(bgTaskId)
      bgTaskId = .invalid
    }
  }
}
