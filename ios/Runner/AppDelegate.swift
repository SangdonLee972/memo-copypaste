import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(
        name: "com.copynote.memo_copypaste/db_sharing",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { (call, result) in
        if call.method == "getAppGroupPath" {
          if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
          ) {
            result(groupURL.path)
          } else {
            result(nil)
          }
        } else if call.method == "copyDBToAppGroup" {
          self.copyDBToAppGroup(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func copyDBToAppGroup(result: @escaping FlutterResult) {
    guard let groupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
    ) else {
      result(false)
      return
    }

    let fm = FileManager.default
    let dbName = "memo_copypaste.db"

    // sqflite stores DB in Documents directory on iOS
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    let sourceDB = URL(fileURLWithPath: documentsPath).appendingPathComponent(dbName)

    // Also check the default sqflite path (which may be in the app's databases directory)
    let appSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
    let altSourceDB = URL(fileURLWithPath: appSupportPath).appendingPathComponent(dbName)

    let destDB = groupURL.appendingPathComponent(dbName)

    var sourcePath: URL? = nil
    if fm.fileExists(atPath: sourceDB.path) {
      sourcePath = sourceDB
    } else if fm.fileExists(atPath: altSourceDB.path) {
      sourcePath = altSourceDB
    }

    guard let source = sourcePath else {
      result(false)
      return
    }

    do {
      if fm.fileExists(atPath: destDB.path) {
        try fm.removeItem(at: destDB)
      }
      try fm.copyItem(at: source, to: destDB)

      // Also copy WAL and SHM files if they exist
      for suffix in ["-wal", "-shm"] {
        let srcExtra = URL(fileURLWithPath: source.path + suffix)
        let dstExtra = URL(fileURLWithPath: destDB.path + suffix)
        if fm.fileExists(atPath: srcExtra.path) {
          if fm.fileExists(atPath: dstExtra.path) {
            try fm.removeItem(at: dstExtra)
          }
          try fm.copyItem(at: srcExtra, to: dstExtra)
        }
      }

      result(true)
    } catch {
      result(false)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
