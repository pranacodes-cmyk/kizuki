import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.kizukijapan.app/widgets", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "publish" {
          let defaults = UserDefaults(suiteName: "group.com.kizukijapan.app.widgets")
          if let raw = call.arguments as? String { defaults?.set(raw, forKey: "snapshot") }
          else { defaults?.removeObject(forKey: "snapshot") }
          if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
          result(nil)
        } else if call.method == "pin" { result(false) }
        else { result(FlutterMethodNotImplemented) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
