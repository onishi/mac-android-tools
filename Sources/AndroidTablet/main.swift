import AppKit
import AndroidToolsCore
import Foundation

@main
enum AndroidTabletApp {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        do {
            if (try? AndroidBridge.tabletSerial()) != nil {
                activateEmulator()
            } else {
                try launchEmulator()
            }
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private static func activateEmulator() {
        // Emulator の console port を持つプロセスを adb が直接返さないため、AVD 名で特定する。
        let pgrep = try? ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/pgrep"),
            ["-f", "qemu-system-.*@\(ToolConfiguration.avdName)"]
        )
        guard let pidText = pgrep?.output.split(whereSeparator: \.isNewline).first,
              let pid = Int32(pidText) else { return }
        NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])
    }

    private static func launchEmulator() throws {
        guard let emulator = ToolConfiguration.emulatorURL else { throw AndroidToolError.sdkNotFound }
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent("android-tablet-emulator.log")
        _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)

        let process = Process()
        process.executableURL = emulator
        process.arguments = ["@\(ToolConfiguration.avdName)"]
        process.standardOutput = log
        process.standardError = log
        try process.run()
    }

    private static func showAlert(_ message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Android Tablet"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}
