import FreeMyMacOSCore
import SwiftUI

/// Right side: targets grouped under small headers. Missing targets are hidden.
struct TargetList: View {
    @Bindable var model: AppModel
    @Binding var expandedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Targets the last scan found missing. Kept hidden while a rescan re-measures them,
    /// so they do not flash back in for a moment.
    @State private var knownMissing: Set<String> = []

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.group) { section in
                        Text(title(of: section.group))
                            .font(Theme.groupHeader)
                            .tracking(Theme.groupHeaderTracking)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.rowHorizontalPadding)
                            .padding(.top, Theme.groupHeaderTopPadding)
                            .padding(.bottom, Theme.groupHeaderBottomPadding)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(section.targets) { target in
                            TargetRow(
                                target: target,
                                result: model.results[target.id],
                                isSelected: model.selection.contains(target.id),
                                canToggle: model.phase == .ready && model.results[target.id]?.status == .ok,
                                isExpanded: expandedID == target.id,
                                onToggleExpanded: { toggleExpanded(target.id) },
                                onToggleSelected: { toggleSelected(target.id) }
                            )
                            .id(target.id)
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.top, Theme.listTopPadding)
                .padding(.leading, Theme.listLeadingPadding)
                .padding(.trailing, Theme.listTrailingPadding)
                .padding(.bottom, Theme.listBottomPadding)
            }
            .scrollIndicators(.automatic)
            .animation(Theme.motion(reduced: reduceMotion), value: groups.flatMap(\.targets).map(\.id))
            .onChange(of: model.results) {
                knownMissing.formUnion(model.results.filter { $0.value.status == .missing }.keys)
                knownMissing.subtract(model.results.filter { $0.value.status != .missing }.keys)
            }
            .task(id: expandedID) {
                // Bring the opened row into view once it has finished opening.
                guard let expandedID else { return }
                guard (try? await Task.sleep(for: Theme.scrollToExpandedDelay)) != nil else { return }
                withAnimation(Theme.motion(reduced: reduceMotion)) {
                    proxy.scrollTo(expandedID)
                }
            }
        }
    }

    private struct Section {
        let group: CleanGroup
        let targets: [CleanTarget]
    }

    private var groups: [Section] {
        let visible = model.visibleTargets.filter {
            model.results[$0.id] != nil || !knownMissing.contains($0.id)
        }
        return CleanGroup.allCases.compactMap { group in
            let targets = visible.filter { $0.group == group }
            return targets.isEmpty ? nil : Section(group: group, targets: targets)
        }
    }

    private func title(of group: CleanGroup) -> String {
        switch group {
        case .developer: String(localized: "Developer")
        case .browsers: String(localized: "Browsers")
        case .apps: String(localized: "Apps")
        case .system: String(localized: "System")
        }
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(Theme.motion(reduced: reduceMotion)) {
            expandedID = expandedID == id ? nil : id
        }
    }

    private func toggleSelected(_ id: String) {
        withAnimation(Theme.motion(reduced: reduceMotion)) {
            model.setSelected(id, !model.selection.contains(id))
        }
    }
}
