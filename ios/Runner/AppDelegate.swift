import Flutter
import UIKit
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VentAIStorage") {
      registerStorageChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VentAIDevice") {
      registerDeviceChannel(messenger: registrar.messenger())
    }
  }

  /// com.ventai.app/device: "availableMemory" returns the bytes this process can
  /// still allocate before iOS terminates it (os_proc_available_memory).
  private func registerDeviceChannel(messenger: FlutterBinaryMessenger) {
    let deviceChannel = FlutterMethodChannel(
      name: "com.ventai.app/device",
      binaryMessenger: messenger
    )
    deviceChannel.setMethodCallHandler { call, result in
      guard call.method == "availableMemory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Int(os_proc_available_memory()))
    }
  }

  /// com.ventai.app/storage: "excludeFromBackup" marks a file as excluded from
  /// iCloud/Finder backup. Returns false (not an error) if the file doesn't exist.
  private func registerStorageChannel(messenger: FlutterBinaryMessenger) {
    let storageChannel = FlutterMethodChannel(
      name: "com.ventai.app/storage",
      binaryMessenger: messenger
    )
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
        return
      }
      guard FileManager.default.fileExists(atPath: path) else {
        result(false)
        return
      }
      var fileURL = URL(fileURLWithPath: path)
      do {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try fileURL.setResourceValues(resourceValues)
        result(true)
      } catch {
        result(FlutterError(code: "BACKUP_EXCLUDE_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}
