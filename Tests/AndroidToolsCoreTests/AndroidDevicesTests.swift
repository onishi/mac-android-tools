import XCTest
@testable import AndroidToolsCore

final class AndroidDevicesTests: XCTestCase {
    func testParsesConnectedDevices() {
        let output = """
        List of devices attached
        emulator-5554\tdevice product:sdk_gphone64_arm64 model:sdk_gphone64_arm64
        emulator-5556\toffline

        """

        XCTAssertEqual(AndroidDevices.parse(output), [
            AndroidDevice(serial: "emulator-5554", state: "device"),
            AndroidDevice(serial: "emulator-5556", state: "offline"),
        ])
    }

    func testIgnoresMalformedLines() {
        XCTAssertEqual(AndroidDevices.parse("List of devices attached\nnoise\n"), [])
    }
}
