import Foundation
import Observation

/// The state the SwiftUI views bind to: scan results, the selection and the clean flow.
///
/// Phases: `.idle` → `scan()` → `.scanning` → `.ready` → `clean()` → `.cleaning` →
/// `.done(freed:)` → `acknowledgeDone()` → `.ready`. A `scan()` or `clean()` call that
/// arrives while another operation is running returns at once and changes nothing.
/// `.done` lasts at least until the rescan after a clean has finished, so `.ready` never
/// shows the bytes from before the clean.
@MainActor @Observable
public final class AppModel {
    public enum Phase: Equatable {
        case idle, scanning, ready, cleaning, done(freed: Int64)
    }

    public private(set) var phase: Phase = .idle
    /// Latest result per target id.
    public private(set) var results: [String: ScanResult] = [:]
    /// Failures of the last clean. Kept until the next clean starts.
    public private(set) var failures: [CleanFailure] = []
    /// Ids of the targets the user wants cleaned.
    public var selection: Set<String> = []
    /// In catalog order.
    public let targets: [CleanTarget]
    /// True when the cleaner only measures and deletes nothing, so the result reads
    /// "Would free" instead of "Freed".
    public let isDryRun: Bool

    @ObservationIgnored private let scanner: any Scanning
    @ObservationIgnored private let cleaner: any Cleaning
    /// True for the whole of a scan or clean, including the rescan after a clean
    /// (when `phase` already reads `.done`). This is the re-entrancy guard.
    @ObservationIgnored private var isBusy = false
    /// `acknowledgeDone()` was called while the post-clean rescan was still running.
    @ObservationIgnored private var isDoneAcknowledged = false

    public init(targets: [CleanTarget], scanner: any Scanning, cleaner: any Cleaning, isDryRun: Bool = false) {
        self.targets = targets
        self.scanner = scanner
        self.cleaner = cleaner
        self.isDryRun = isDryRun
    }

    // MARK: - Derived state

    /// Targets that exist on this Mac (status is not `.missing`), in catalog order.
    /// A target without a result yet (scan still running) is included.
    public var visibleTargets: [CleanTarget] {
        targets.filter { results[$0.id]?.status != .missing }
    }

    /// Bytes of the selected targets whose status is `.ok`.
    public var selectedBytes: Int64 {
        cleanableSelection.reduce(Int64(0)) { $0 + (results[$1.id]?.bytes ?? 0) }
    }

    /// True when a careful-tier target would be cleaned, so the view must confirm first.
    public var needsConfirmation: Bool {
        cleanableSelection.contains { $0.tier == .careful }
    }

    /// Selected targets with status `.ok`, in catalog order: exactly what `clean()` cleans.
    private var cleanableSelection: [CleanTarget] {
        targets.filter { selection.contains($0.id) && results[$0.id]?.status == .ok }
    }

    // MARK: - Actions

    /// Measures every target concurrently; each result is written to `results` as it arrives.
    /// When done, the selection becomes the safe-tier targets with status `.ok` and bytes > 0,
    /// and the phase is `.ready`. If the calling task is cancelled, partial results are
    /// discarded: the previous results come back and the selection is left unchanged.
    public func scan() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let previous = results
        phase = .scanning
        results = [:]

        await measure(targets)

        if Task.isCancelled {
            results = previous
            phase = previous.isEmpty ? .idle : .ready
            return
        }
        selection = Set(
            targets
                .filter { target in
                    guard target.tier == .safe, let result = results[target.id] else { return false }
                    return result.status == .ok && result.bytes > 0
                }
                .map(\.id)
        )
        phase = .ready
    }

    /// Cleans the selected targets with status `.ok`, one after another, in catalog order.
    /// `failures` is cleared when the clean starts and holds every report's failures after.
    /// The phase becomes `.done(freed:)` with the sum of freed bytes; then the cleaned
    /// targets are measured again and their results updated (phase stays `.done`).
    /// Does nothing when no selected target can be cleaned.
    public func clean() async {
        guard !isBusy else { return }
        let toClean = cleanableSelection
        guard !toClean.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }

        failures = []
        isDoneAcknowledged = false
        phase = .cleaning
        var freed: Int64 = 0
        for target in toClean {
            let report = await cleaner.clean(target)
            freed += report.freedBytes
            failures += report.failures
        }
        phase = .done(freed: freed)

        await measure(toClean)
        // Drop cleaned targets that no longer have anything to clean.
        for target in toClean {
            if let result = results[target.id], result.status != .ok || result.bytes == 0 {
                selection.remove(target.id)
            }
        }
        if isDoneAcknowledged {
            isDoneAcknowledged = false
            phase = .ready
        }
    }

    /// Returns from `.done` to `.ready` (the view calls this after showing the result).
    /// While the rescan after the clean still runs, the request is remembered and the phase
    /// becomes `.ready` when the rescan finishes. Does nothing in any other phase.
    public func acknowledgeDone() {
        guard case .done = phase else { return }
        if isBusy {
            isDoneAcknowledged = true
        } else {
            phase = .ready
        }
    }

    // MARK: - Private

    /// Scans `subset` concurrently, writing each result as it arrives. Stops writing as
    /// soon as the task is cancelled, since a cancelled scan returns partial numbers.
    private func measure(_ subset: [CleanTarget]) async {
        let scanner = self.scanner
        await withTaskGroup(of: ScanResult.self) { group in
            for target in subset {
                group.addTask { await scanner.scan(target) }
            }
            for await result in group {
                if Task.isCancelled { continue }
                results[result.targetID] = result
            }
        }
    }
}
