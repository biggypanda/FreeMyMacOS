import Foundation
import Testing
@testable import FreeMyMacOSCore

// MARK: - Fakes (no disk access)

/// Records every scan call and can hold scans suspended until opened.
/// Deterministic: tests wait for a number of entries instead of sleeping.
private actor ScanGate {
    private(set) var calls: [String] = []
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var entryWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(open: Bool) {
        isOpen = open
    }

    func close() {
        isOpen = false
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }

    /// Called by the fake scanner: records the call, then suspends while closed.
    func pass(_ id: String) async {
        calls.append(id)
        let ready = entryWaiters.filter { calls.count >= $0.count }
        entryWaiters.removeAll { calls.count >= $0.count }
        ready.forEach { $0.continuation.resume() }
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Returns once at least `count` scan calls have been made in total.
    func waitForCalls(_ count: Int) async {
        if calls.count >= count { return }
        await withCheckedContinuation { entryWaiters.append((count, $0)) }
    }
}

private struct FakeScanner: Scanning {
    let results: [String: ScanResult]
    let gate: ScanGate

    func scan(_ target: CleanTarget) async -> ScanResult {
        await gate.pass(target.id)
        return results[target.id]
            ?? ScanResult(targetID: target.id, bytes: 0, itemCount: 0, status: .missing, topItems: [])
    }
}

private actor CleanLog {
    private(set) var calls: [String] = []
    func record(_ id: String) { calls.append(id) }
}

private struct FakeCleaner: Cleaning {
    let reports: [String: CleanReport]
    let log: CleanLog

    func clean(_ target: CleanTarget) async -> CleanReport {
        await log.record(target.id)
        return reports[target.id] ?? CleanReport(targetID: target.id, freedBytes: 0, failures: [])
    }
}

// MARK: - Helpers

private func target(_ id: String, _ tier: CleanTier = .safe) -> CleanTarget {
    CleanTarget(
        id: id, title: id, detail: "Test target.", symbol: "folder",
        group: .system, tier: tier, roots: []
    )
}

private func result(_ id: String, _ bytes: Int64, _ status: ScanStatus = .ok) -> ScanResult {
    ScanResult(targetID: id, bytes: bytes, itemCount: bytes > 0 ? 1 : 0, status: status, topItems: [])
}

private struct Fixture {
    let model: AppModel
    let gate: ScanGate
    let log: CleanLog

    @MainActor
    init(
        targets: [CleanTarget],
        results: [ScanResult],
        reports: [CleanReport] = [],
        gateOpen: Bool = true
    ) {
        gate = ScanGate(open: gateOpen)
        log = CleanLog()
        let scanner = FakeScanner(
            results: Dictionary(uniqueKeysWithValues: results.map { ($0.targetID, $0) }),
            gate: gate
        )
        let cleaner = FakeCleaner(
            reports: Dictionary(uniqueKeysWithValues: reports.map { ($0.targetID, $0) }),
            log: log
        )
        model = AppModel(targets: targets, scanner: scanner, cleaner: cleaner)
    }
}

// MARK: - Tests

@MainActor
@Suite struct AppModelTests {
    @Test func startsIdle() {
        let f = Fixture(targets: [target("a")], results: [])
        #expect(f.model.phase == .idle)
        #expect(f.model.results.isEmpty)
        #expect(f.model.selection.isEmpty)
    }

    @Test func scanSelectsSafeNonEmptyOnly() async {
        let f = Fixture(
            targets: [
                target("safe.full"), target("careful.full", .careful),
                target("safe.empty"), target("safe.denied"),
            ],
            results: [
                result("safe.full", 500), result("careful.full", 700),
                result("safe.empty", 0), result("safe.denied", 0, .permissionDenied),
            ]
        )
        await f.model.scan()
        #expect(f.model.phase == .ready)
        #expect(f.model.selection == ["safe.full"])
        #expect(f.model.results.count == 4)
        #expect(f.model.results["careful.full"]?.bytes == 700)
    }

    @Test func missingTargetsHidden() async {
        let f = Fixture(
            targets: [target("a"), target("gone"), target("b")],
            results: [result("a", 10), result("gone", 0, .missing), result("b", 0)]
        )
        await f.model.scan()
        #expect(f.model.visibleTargets.map(\.id) == ["a", "b"])
    }

    @Test func selectedBytesIgnoresPermissionDenied() async {
        let f = Fixture(
            targets: [target("a"), target("denied", .careful)],
            results: [result("a", 100), result("denied", 999, .permissionDenied)]
        )
        await f.model.scan()
        f.model.selection = ["a", "denied"]
        #expect(f.model.selectedBytes == 100)
    }

    @Test func cleanSumsFreedBytesAndCollectsFailures() async {
        let failA = CleanFailure(path: "/x/a/1", reason: "Permission denied")
        let failB = CleanFailure(path: "/x/b/1", reason: "Could not delete")
        let f = Fixture(
            targets: [target("a"), target("b"), target("c")],
            results: [result("a", 100), result("b", 250), result("c", 40)],
            reports: [
                CleanReport(targetID: "a", freedBytes: 100, failures: [failA]),
                CleanReport(targetID: "b", freedBytes: 250, failures: [failB]),
            ]
        )
        await f.model.scan()
        f.model.selection = ["a", "b"]
        await f.model.clean()
        #expect(f.model.phase == .done(freed: 350))
        #expect(f.model.failures == [failA, failB])
        #expect(await f.log.calls == ["a", "b"])
        // Initial scan of 3 targets, then a rescan of the 2 cleaned ones.
        let scanned = await f.gate.calls
        #expect(scanned.count == 5)
        #expect(Array(scanned.suffix(2)).sorted() == ["a", "b"])
    }

    @Test func cleanSkipsTargetsThatAreNotOk() async {
        let f = Fixture(
            targets: [target("a"), target("denied")],
            results: [result("a", 100), result("denied", 0, .permissionDenied)],
            reports: [CleanReport(targetID: "a", freedBytes: 100, failures: [])]
        )
        await f.model.scan()
        f.model.selection = ["a", "denied"]
        await f.model.clean()
        #expect(await f.log.calls == ["a"])
        #expect(f.model.phase == .done(freed: 100))
    }

    @Test func failuresClearedWhenNextCleanStarts() async {
        let fail = CleanFailure(path: "/x/a/1", reason: "Permission denied")
        let f = Fixture(
            targets: [target("a"), target("b")],
            results: [result("a", 100), result("b", 50)],
            reports: [CleanReport(targetID: "a", freedBytes: 0, failures: [fail])]
        )
        await f.model.scan()
        f.model.selection = ["a"]
        await f.model.clean()
        #expect(f.model.failures == [fail])
        f.model.acknowledgeDone()
        #expect(f.model.phase == .ready)
        await f.model.scan()
        #expect(f.model.failures == [fail])   // kept across a scan
        f.model.selection = ["b"]
        await f.model.clean()
        #expect(f.model.failures.isEmpty)
    }

    @Test func needsConfirmationWhenCarefulSelected() async {
        let f = Fixture(
            targets: [target("a"), target("risky", .careful)],
            results: [result("a", 10), result("risky", 20)]
        )
        await f.model.scan()
        #expect(f.model.needsConfirmation == false)
        f.model.selection.insert("risky")
        #expect(f.model.needsConfirmation)
        #expect(f.model.selectedBytes == 30)
    }

    @Test func reentrantScanIgnored() async {
        let targets = [target("a"), target("b"), target("c")]
        let f = Fixture(
            targets: targets,
            results: [result("a", 1), result("b", 2), result("c", 3)],
            gateOpen: false
        )
        let first = Task { await f.model.scan() }
        await f.gate.waitForCalls(targets.count)
        #expect(f.model.phase == .scanning)

        await f.model.scan()   // must return immediately, no side effects
        #expect(f.model.phase == .scanning)
        #expect(await f.gate.calls.count == targets.count)

        await f.gate.open()
        await first.value
        #expect(f.model.phase == .ready)
        #expect(await f.gate.calls.sorted() == ["a", "b", "c"])
    }

    @Test func cleanIgnoredWhileScanning() async {
        let f = Fixture(
            targets: [target("a"), target("b")],
            results: [result("a", 10), result("b", 20)],
            reports: [CleanReport(targetID: "a", freedBytes: 10, failures: [])]
        )
        await f.model.scan()
        #expect(f.model.selection == ["a", "b"])

        await f.gate.close()
        let rescan = Task { await f.model.scan() }
        await f.gate.waitForCalls(4)
        #expect(f.model.phase == .scanning)

        await f.model.clean()
        #expect(await f.log.calls.isEmpty)
        #expect(f.model.phase == .scanning)

        await f.gate.open()
        await rescan.value
        #expect(f.model.phase == .ready)
        #expect(await f.log.calls.isEmpty)
    }

    @Test func acknowledgeDoneWaitsForRescan() async {
        let f = Fixture(
            targets: [target("a"), target("b")],
            results: [result("a", 100), result("b", 50)],
            reports: [CleanReport(targetID: "a", freedBytes: 100, failures: [])]
        )
        await f.model.scan()
        f.model.selection = ["a"]

        await f.gate.close()
        let clean = Task { await f.model.clean() }
        await f.gate.waitForCalls(3)   // 2 initial scans + the rescan of "a", held open
        #expect(f.model.phase == .done(freed: 100))

        // The "Freed" hold ends while the rescan still runs: the old bytes must not come back.
        f.model.acknowledgeDone()
        #expect(f.model.phase == .done(freed: 100))
        await f.model.clean()   // still busy: ignored
        #expect(await f.log.calls == ["a"])

        await f.gate.open()
        await clean.value
        #expect(f.model.phase == .ready)
        #expect(f.model.results["a"]?.bytes == 100)
    }

    @Test func doneStaysUntilAcknowledged() async {
        let f = Fixture(
            targets: [target("a")],
            results: [result("a", 100)],
            reports: [CleanReport(targetID: "a", freedBytes: 100, failures: [])]
        )
        await f.model.scan()
        await f.model.clean()
        #expect(f.model.phase == .done(freed: 100))
        f.model.acknowledgeDone()
        #expect(f.model.phase == .ready)
    }

    @Test func cancelledScanDiscardsPartialResults() async {
        let f = Fixture(
            targets: [target("a"), target("b")],
            results: [result("a", 10), result("b", 20)],
            gateOpen: false
        )
        let scan = Task { await f.model.scan() }
        await f.gate.waitForCalls(2)
        scan.cancel()
        await f.gate.open()
        await scan.value
        #expect(f.model.results.isEmpty)
        #expect(f.model.phase == .idle)
        #expect(f.model.selection.isEmpty)
    }
}
