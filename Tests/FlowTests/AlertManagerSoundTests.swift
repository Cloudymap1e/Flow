#if os(macOS)
import XCTest
@testable import Flow

final class AlertManagerSoundTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = AlertManager.shared.setCustomSound(url: nil)
        UserDefaults.standard.removeObject(forKey: "AlertManager.customSoundURL")
    }

    func testStoresOriginalSoundPath() throws {
        let manager = AlertManager.shared
        let systemSound = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        let stored = try XCTUnwrap(manager.setCustomSound(url: systemSound))

        XCTAssertEqual(stored.path, systemSound.path)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "AlertManager.customSoundURL"), systemSound.path)
        XCTAssertEqual(manager.debug_currentSoundURL?.path, systemSound.path)
        XCTAssertTrue(manager.debug_reloadSound())
    }

    func testCustomSoundCanBePlayedAfterSelection() {
        let manager = AlertManager.shared
        let systemSound = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        XCTAssertNotNil(manager.setCustomSound(url: systemSound))
        XCTAssertTrue(manager.debug_playCurrentSoundOnce())
        manager.stopSound()
    }
}
#endif
