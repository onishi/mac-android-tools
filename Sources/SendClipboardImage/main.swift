import AppKit
import AndroidToolsCore
import Foundation

private enum SendError: LocalizedError {
    case noImage
    case imageConversion
    case unsupportedFile(String)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "Mac のクリップボードに画像がありません。画像をコピーしてから実行してください。"
        case .imageConversion:
            return "クリップボードの画像を PNG に変換できませんでした。"
        case .unsupportedFile(let name):
            return "「\(name)」は画像ファイルとして読み込めません。"
        }
    }
}

private enum ImageTransfer {
    static func sendClipboardImage() throws -> [String] {
        let image = try clipboardImage()
        let data = try pngData(from: image)
        let fileName = clipboardOutputName()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try sendFiles([temporaryURL])
        return [fileName]
    }

    static func sendFiles(_ urls: [URL]) throws {
        guard !urls.isEmpty else { throw SendError.noImage }
        for url in urls {
            guard url.isFileURL, NSImage(contentsOf: url) != nil else {
                throw SendError.unsupportedFile(url.lastPathComponent)
            }
        }

        let serial = try ensureTabletIsRunning()
        for url in urls {
            let remotePath = "\(ToolConfiguration.remoteDownloadDirectory)/\(url.lastPathComponent)"
            try AndroidBridge.adb(serial: serial, arguments: ["push", url.path, remotePath])
            try AndroidBridge.adb(serial: serial, arguments: [
                "shell", "am", "broadcast",
                "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
                "-d", "file://\(remotePath)",
            ])
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

    private static func clipboardOutputName() -> String {
        if let requested = ProcessInfo.processInfo.environment["SEND_CLIPBOARD_OUTPUT_NAME"], !requested.isEmpty {
            return requested.hasSuffix(".png") ? requested : requested + ".png"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Clipboard-\(formatter.string(from: Date())).png"
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasReceivedExternalAction = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder の openFiles / Services イベントに先に処理の機会を与える。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.hasReceivedExternalAction else { return }
            self.hasReceivedExternalAction = true
            self.perform {
                try ImageTransfer.sendClipboardImage()
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        hasReceivedExternalAction = true
        let urls = filenames.map(URL.init(fileURLWithPath:))
        let succeeded = perform {
            try ImageTransfer.sendFiles(urls)
            return urls.map(\.lastPathComponent)
        }
        sender.reply(toOpenOrPrint: succeeded ? .success : .failure)
    }

    @objc func sendImagesToAndroid(
        _ pasteboard: NSPasteboard,
        userData: String,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        hasReceivedExternalAction = true
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
        let urls: [URL] = objects?.compactMap { object -> URL? in
            if let url = object as? URL { return url }
            if let url = object as? NSURL { return url as URL }
            return nil
        } ?? []
        do {
            try ImageTransfer.sendFiles(urls)
            showSuccess(urls.map(\.lastPathComponent))
        } catch {
            errorPointer.pointee = error.localizedDescription as NSString
            showAlert(message: error.localizedDescription, style: .critical)
        }
        terminateSoon()
    }

    @discardableResult
    private func perform(action: () throws -> [String]) -> Bool {
        do {
            showSuccess(try action())
            terminateSoon()
            return true
        } catch {
            showAlert(message: error.localizedDescription, style: .critical)
            terminateSoon()
            return false
        }
    }

    private func showSuccess(_ fileNames: [String]) {
        let detail: String
        if fileNames.count == 1 {
            detail = "Downloads に保存しました。\n\(fileNames[0])"
        } else {
            detail = "\(fileNames.count)枚の画像を Downloads に保存しました。"
        }
        showAlert(message: detail, style: .informational)
    }

    private func showAlert(message: String, style: NSAlert.Style) {
        guard ProcessInfo.processInfo.environment["SEND_CLIPBOARD_NO_ALERT"] == nil else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "画像をAndroidへ送る"
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func terminateSoon() {
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}

@main
enum SendClipboardImageApp {
    static func main() {
        if CommandLine.arguments.contains("--register-services") {
            NSUpdateDynamicServices()
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
