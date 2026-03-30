import IOKit.pwr_mgt

class DisplaySleepManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func toggle() {
        isActive ? deactivate() : activate()
    }

    private func activate() {
        let reason = "Prevent display sleep" as CFString
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        isActive = true
    }

    private func deactivate() {
        IOPMAssertionRelease(assertionID)
        isActive = false
    }
}
