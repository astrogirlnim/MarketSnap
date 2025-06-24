import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register the background task
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "syncPendingMediaTask")
    
    // Register for other plugins
    GeneratedPluginRegistrant.register(with: self)

    // Register a periodic task for iOS
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "1", frequency: NSNumber(value: 900)) // 15 minutes

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
