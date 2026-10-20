import AppKit
import AndroidToolsCore
import ApplicationServices
import Foundation

private let macEisuKeyCode: Int64 = 102
private let macKanaKeyCode: Int64 = 104
private let androidEisuKeyCode = "212"
private let androidKanaKeyCode = "218"

private final class KeyboardController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isEnabled = true

    var isTapActive: Bool {
        eventTap.map(CGEvent.tapIsEnabled(tap:)) ?? false
    }

    func startEventTap() -> Bool {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return true
        }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: opaqueSelf
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard isEnabled, type == .keyDown, isAndroidEmulatorFrontmost else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == macEisuKeyCode {
            sendAndroidKey(androidEisuKeyCode)
            return nil
        }
        if keyCode == macKanaKeyCode {
            sendAndroidKey(androidKanaKeyCode)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private var isAndroidEmulatorFrontmost: Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return app.executableURL?.lastPathComponent.hasPrefix("qemu-system-") == true
            || app.localizedName?.contains("Android Emulator") == true
    }

    private func sendAndroidKey(_ keyCode: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let serial = try AndroidBridge.tabletSerial()
                try AndroidBridge.adb(serial: serial, arguments: ["shell", "input", "keyevent", keyCode])
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tabletUnavailable, object: error)
                }
            }
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<KeyboardController>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
}

private extension Notification.Name {
    static let tabletUnavailable = Notification.Name("AndroidTabletUnavailable")
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keyboardController = KeyboardController()
    private var statusItem: NSStatusItem!
    private var stateItem: NSMenuItem!
    private var enabledItem: NSMenuItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showTabletUnavailable(_:)),
            name: .tabletUnavailable,
            object: nil
        )
        refreshPermissionState(prompt: true)
        permissionTimer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPermissionState(prompt: false)
        }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "あ/A"
        statusItem.button?.toolTip = "Android 日本語切替"

        let menu = NSMenu()
        stateItem = NSMenuItem(title: "アクセシビリティ権限を確認中", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        enabledItem = NSMenuItem(title: "キー転送を有効にする", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        let eisu = NSMenuItem(title: "英数キーをテスト", action: #selector(testEisuKey), keyEquivalent: "")
        eisu.target = self
        menu.addItem(eisu)
        let kana = NSMenuItem(title: "かなキーをテスト", action: #selector(testKanaKey), keyEquivalent: "")
        kana.target = self
        menu.addItem(kana)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "アクセシビリティ設定を開く", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func refreshPermissionState(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        let active = trusted && keyboardController.startEventTap()
        stateItem.title = active ? "キー転送: 利用可能" : "アクセシビリティ権限が必要です"
        statusItem.button?.title = active ? "あ/A" : "あ/A!"
    }

    @objc private func toggleEnabled() {
        keyboardController.isEnabled.toggle()
        enabledItem.state = keyboardController.isEnabled ? .on : .off
    }

    @objc private func testEisuKey() { sendTestKey(androidEisuKeyCode) }
    @objc private func testKanaKey() { sendTestKey(androidKanaKeyCode) }

    private func sendTestKey(_ keyCode: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let serial = try AndroidBridge.tabletSerial()
                try AndroidBridge.adb(serial: serial, arguments: ["shell", "input", "keyevent", keyCode])
            } catch {
                DispatchQueue.main.async { self.showError(error) }
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func showTabletUnavailable(_ notification: Notification) {
        showError(notification.object as? Error ?? AndroidToolError.tabletUnavailable)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Android 日本語切替"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

@main
enum AndroidJapaneseSwitchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
