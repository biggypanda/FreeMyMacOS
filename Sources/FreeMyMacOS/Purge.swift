import Foundation

/// Runs `/usr/sbin/purge`, which needs administrator rights. macOS shows its own password
/// prompt; the app never sees or stores the password.
enum Purge {
    /// True if purge ran. False if the person cancelled the prompt or anything failed.
    static func run() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // osascript shows the prompt in its own process; this side only waits for it to exit.
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: false)
            }
        }
    }
}
