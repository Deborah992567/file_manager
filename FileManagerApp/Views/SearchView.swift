import SwiftUI

/// Live search screen: morphing input field → debounced results grouped by
/// kind, filter chips, and a persisted recent-searches pill row.
struct SearchView: View {
    @Environment(AppState.self) private var appState

    @State private var vm: SearchViewModel
    @State private var previewContext: FilePreviewContext?

    init() {
        _vm = State(initialValue: SearchViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Kind-filter chips appear once there's a query so the input stays
            // the hero of the screen.
            if !vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
                filterChips
                    .padding(.top, 10)
            }

            results
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $previewContext) { context in
            FilePreviewSheet(context: context)
                .environment(appState)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search")
                .font(Theme.Font.display(30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 6)

            AnimatedSearchField(text: $vm.query) {
                Haptics.tick()
                vm.commitQuery()
            }
            .padding(.horizontal, 16)
            .onChange(of: vm.query) { _, _ in vm.queryChanged() }

            if vm.hasActiveQuery {
                Text("\(vm.resultCount) result\(vm.resultCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 18)
                    .transition(.opacity)
            }
        }
        .padding(.top, 8)
        .animation(AppMotion.spring, value: vm.hasActiveQuery)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(KindFilter.allCases) { kind in
                    let isSelected = vm.filter == kind
                    Button {
                        Haptics.tick()
                        withAnimation(AppMotion.quick) { vm.applyFilter(kind) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: kind.symbolName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(kind.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(isSelected ? Theme.accentSoft : Theme.surfaceElevated))
                        .overlay(Capsule().strokeBorder(isSelected ? Theme.accent.opacity(0.4) : Theme.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var results: some View {
        if vm.isSearching {
            Spacer()
            ProgressView()
                .tint(Theme.accent)
            Spacer()
        } else if vm.hasActiveQuery {
            Group {
                if vm.groups.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "magnifyingglass",
                                   title: "No matches",
                                   subtitle: "Try a different name, or clear the kind filter.")
                    Spacer()
                } else {
                    groupedResults
                }
            }
        } else if !vm.recentSearches.isEmpty {
            recentsSection
        } else {
            Spacer()
            EmptyStateView(icon: "magnifyingglass",
                           title: "Find anything",
                           subtitle: "Search by file name across every folder in Nova Files.")
            Spacer()
        }
    }

    private var groupedResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(vm.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: group.kind.symbolName)
                            Text(group.kind.label)
                            Text("· \(group.items.count)")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)

                        ForEach(group.items) { item in
                            resultRow(item)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
    }

    private func resultRow(_ item: FileItem) -> some View {
        Button {
            Haptics.tap()
            if item.isDirectory {
                NotificationCenter.default.post(name: .openFolder, object: FolderNode.directory(item.url))
            } else {
                FileService.shared.markOpened(item)
                previewContext = FilePreviewContext(item: item)
            }
        } label: {
            HStack(spacing: 12) {
                FileThumbnailView(item: item, size: 42, tag: FileService.shared.tag(for: item))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(item.isDirectory ? "Folder" : "\(ByteFormatter.format(item.size)) · \(DateFormatting.compact(item.modificationDate))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: item.isDirectory ? "chevron.right" : "doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? "Opens this folder" : "Opens a preview of this file")
    }

    private var recentsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent searches")
                        .font(Theme.Font.body(13, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Button {
                        Haptics.tick()
                        vm.clearRecents()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.recentSearches, id: \.self) { term in
                            Button {
                                Haptics.tap()
                                vm.useRecent(term)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(term)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Theme.surfaceElevated))
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18)
        }
    }
}