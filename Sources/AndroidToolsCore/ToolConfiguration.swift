import Foundation

public enum ToolConfiguration {
    /// AVD Manager に表示される対象タブレットの名前。
    public static let avdName = "Android_Tablet_API_36_1"

    public static let tabletAppName = "Android Tablet.app"
    public static let remoteDownloadDirectory = "/sdcard/Download"

    public static var androidSDK: URL? {
        let environment = ProcessInfo.processInfo.environment
        let candidates: [String?] = [
            environment["ANDROID_SDK_ROOT"],
            environment["ANDROID_HOME"],
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Android/sdk").path,
        ]
        return candidates.compactMap { $0 }.map(URL.init(fileURLWithPath:)).first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    public static var adbURL: URL? {
        executable(named: "platform-tools/adb")
    }

    public static var emulatorURL: URL? {
        executable(named: "emulator/emulator")
    }

    private static func executable(named relativePath: String) -> URL? {
        guard let url = androidSDK?.appendingPathComponent(relativePath),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }
}
