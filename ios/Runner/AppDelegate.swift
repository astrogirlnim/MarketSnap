import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins first
    GeneratedPluginRegistrant.register(with: self)
    
    // Register the background processing task with the same identifier used in Info.plist
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "syncPendingMediaTask")
    
    // Note: iOS doesn't support true periodic background tasks like Android
    // The workmanager plugin will simulate periodic behavior using iOS background app refresh
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
