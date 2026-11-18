import Foundation

/// What happened when the person asked to free memory.
enum PurgeResult: Equatable {
    case freed, cancelled, failed

    /// osascript exits 0 when purge ran. When the person cancels the password prompt it exits
    /// non-zero and its error output carries AppleScript error -128 ("User canceled").
    init(status: Int32, errorOutput: String) {
        if status == 0 {
            self = .freed
        } else if errorOutput.contains("-128") {
            self = .cancelled
        } else {
            self = .failed
        }
    }
}

/// Runs `/usr/sbin/purge`, which needs administrator rights. macOS shows its own password
/// prompt; the app never sees or stores the password.
enum Purge {
    static func run() async -> PurgeResult {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        // osascript shows the prompt in its own process; this side only waits for it to exit.
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: PurgeResult(status: finished.terminationStatus, errorOutput: output))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: .failed)
            }
        }
    }
}
