import AppKit
import AndroidToolsCore
import Foundation

private enum SendError: LocalizedError {
    case noImage
    case imageConversion

    var errorDescription: String? {
        switch self {
        case .noImage: return "Mac のクリップボードに画像がありません。画像をコピーしてから実行してください。"
        case .imageConversion: return "クリップボードの画像を PNG に変換できませんでした。"
        }
    }
}

@main
enum SendClipboardImageApp {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        do {
            let image = try clipboardImage()
            let data = try pngData(from: image)
            let serial = try ensureTabletIsRunning()
            let fileName = outputName()
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: temporaryURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: temporaryURL) }

            let remotePath = "\(ToolConfiguration.remoteDownloadDirectory)/\(fileName)"
            try AndroidBridge.adb(serial: serial, arguments: ["push", temporaryURL.path, remotePath])
            try AndroidBridge.adb(serial: serial, arguments: [
                "shell", "am", "broadcast",
                "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
                "-d", "file://\(remotePath)",
            ])
            showAlert(title: "画像をAndroidへ送る", message: "Downloads に保存しました。\n\(fileName)", style: .informational)
        } catch {
            showAlert(title: "画像をAndroidへ送る", message: error.localizedDescription, style: .critical)
        }
    }

    private static func clipboardImage() throws -> NSImage {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) { return image }
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingContentsConformToTypes: NSImage.imageTypes]
        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: options)?.first as? URL,
           let image = NSImage(contentsOf: url) { return image }
        throw SendError.noImage
    }

    private static func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SendError.imageConversion
        }
        return png
    }

    private static func ensureTabletIsRunning() throws -> String {
        if let serial = try? AndroidBridge.tabletSerial(requireBooted: true) { return serial }

        let launcher = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent(ToolConfiguration.tabletAppName)
        if FileManager.default.fileExists(atPath: launcher.path) {
            NSWorkspace.shared.openApplication(at: launcher, configuration: .init())
        }

        for _ in 0..<30 {
            Thread.sleep(forTimeInterval: 1)
            if let serial = try? AndroidBridge.tabletSerial(requireBooted: true) { return serial }
        }
        throw AndroidToolError.tabletUnavailable
    }

    private static func outputName() -> String {
        if let requested = ProcessInfo.processInfo.environment["SEND_CLIPBOARD_OUTPUT_NAME"], !requested.isEmpty {
            return requested.hasSuffix(".png") ? requested : requested + ".png"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Clipboard-\(formatter.string(from: Date())).png"
    }

    private static func showAlert(title: String, message: String, style: NSAlert.Style) {
        guard ProcessInfo.processInfo.environment["SEND_CLIPBOARD_NO_ALERT"] == nil else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
