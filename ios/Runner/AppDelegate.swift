import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 앱 시작 시 기존 DB를 App Group으로 마이그레이션
    migrateDBToAppGroupIfNeeded()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 기존 Documents/memo_copypaste.db → App Group 컨테이너로 마이그레이션
  /// Documents에 DB가 있으면 항상 App Group으로 복사 (최신 데이터 동기화)
  private func migrateDBToAppGroupIfNeeded() {
    guard let groupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
    ) else {
      NSLog("[메모복붙] App Group 컨테이너를 찾을 수 없음")
      return
    }

    let fm = FileManager.default
    let dbName = "memo_copypaste.db"
    let destDB = groupURL.appendingPathComponent(dbName)

    // 기존 DB 위치 찾기
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    let sourceDB = URL(fileURLWithPath: documentsPath).appendingPathComponent(dbName)

    if fm.fileExists(atPath: sourceDB.path) {
      do {
        // App Group에 이미 있으면 삭제 후 최신으로 덮어씀
        if fm.fileExists(atPath: destDB.path) {
          try fm.removeItem(at: destDB)
        }
        try fm.copyItem(at: sourceDB, to: destDB)
        // WAL, SHM 파일도 복사
        for suffix in ["-wal", "-shm"] {
          let src = URL(fileURLWithPath: sourceDB.path + suffix)
          let dst = URL(fileURLWithPath: destDB.path + suffix)
          if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
          }
          if fm.fileExists(atPath: src.path) {
            try fm.copyItem(at: src, to: dst)
          }
        }
        NSLog("[메모복붙] DB 마이그레이션 완료: %@ → %@", sourceDB.path, destDB.path)
      } catch {
        NSLog("[메모복붙] DB 마이그레이션 실패: %@", error.localizedDescription)
      }
    } else {
      NSLog("[메모복붙] Documents에 기존 DB 없음")
    }
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

    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    let sourceDB = URL(fileURLWithPath: documentsPath).appendingPathComponent(dbName)

    let destDB = groupURL.appendingPathComponent(dbName)

    guard fm.fileExists(atPath: sourceDB.path) else {
      result(false)
      return
    }

    do {
      if fm.fileExists(atPath: destDB.path) {
        try fm.removeItem(at: destDB)
      }
      try fm.copyItem(at: sourceDB, to: destDB)

      for suffix in ["-wal", "-shm"] {
        let srcExtra = URL(fileURLWithPath: sourceDB.path + suffix)
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

    // 플러그인 레지스트라를 통해 MethodChannel 설정
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DBSharingPlugin")
    NSLog("[메모복붙] MethodChannel 설정 중 (via registrar)")
    let channel = FlutterMethodChannel(
      name: "com.copynote.memo_copypaste/db_sharing",
      binaryMessenger: registrar!.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getAppGroupPath" {
        if let groupURL = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
        ) {
          result(groupURL.path)
        } else {
          result(nil)
        }
      } else if call.method == "getDBPath" {
        if let groupURL = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
        ) {
          let dbPath = groupURL.appendingPathComponent("memo_copypaste.db").path
          NSLog("[메모복붙] getDBPath → %@", dbPath)
          result(dbPath)
        } else {
          NSLog("[메모복붙] getDBPath: App Group 없음")
          result(nil)
        }
      } else if call.method == "copyDBToAppGroup" {
        self?.copyDBToAppGroup(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
