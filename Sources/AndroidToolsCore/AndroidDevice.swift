import Foundation

public struct AndroidDevice: Equatable {
    public let serial: String
    public let state: String
}

public enum AndroidDevices {
    public static func parse(_ output: String) -> [AndroidDevice] {
        output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2 else { return nil }
            return AndroidDevice(serial: String(fields[0]), state: String(fields[1]))
        }
    }
}

public enum AndroidToolError: LocalizedError {
    case sdkNotFound
    case commandFailed(String)
    case tabletUnavailable
    case tabletBooting

    public var errorDescription: String? {
        switch self {
        case .sdkNotFound:
            return "Android SDK が見つかりません。ANDROID_SDK_ROOT を設定してください。"
        case .commandFailed(let message):
            return message
        case .tabletUnavailable:
            return "Android Tablet が起動していません。"
        case .tabletBooting:
            return "Android Tablet は起動処理中です。少し待ってから再実行してください。"
        }
    }
}

public enum AndroidBridge {
    public static func tabletSerial(requireBooted: Bool = false) throws -> String {
        guard let adb = ToolConfiguration.adbURL else { throw AndroidToolError.sdkNotFound }
        let devicesResult = try ProcessRunner.run(adb, ["devices"])
        guard devicesResult.status == 0 else {
            throw AndroidToolError.commandFailed(devicesResult.error.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        for device in AndroidDevices.parse(devicesResult.output)
            where device.serial.hasPrefix("emulator-") && device.state == "device" {
            let name = try ProcessRunner.run(adb, ["-s", device.serial, "emu", "avd", "name"])
            guard name.status == 0,
                  name.output.trimmingCharacters(in: .whitespacesAndNewlines) == ToolConfiguration.avdName else { continue }

            if requireBooted {
                let boot = try ProcessRunner.run(adb, ["-s", device.serial, "shell", "getprop", "sys.boot_completed"])
                guard boot.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1" else {
                    throw AndroidToolError.tabletBooting
                }
            }
            return device.serial
        }
        throw AndroidToolError.tabletUnavailable
    }

    @discardableResult
    public static func adb(serial: String, arguments: [String]) throws -> ProcessResult {
        guard let adb = ToolConfiguration.adbURL else { throw AndroidToolError.sdkNotFound }
        let result = try ProcessRunner.run(adb, ["-s", serial] + arguments)
        guard result.status == 0 else {
            let detail = result.error.isEmpty ? result.output : result.error
            throw AndroidToolError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }
}
