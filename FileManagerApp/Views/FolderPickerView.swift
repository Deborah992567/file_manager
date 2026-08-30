import SwiftUI

/// In-app folder destination picker used by Move / Copy of both the batch bar
/// and the single-file preview. Shows only sub-folders of the sandbox so the
/// user can never end up outside their own files.
struct FolderPickerView: View {
    let title: String
    let rootURL: URL
    /// A folder (or file) that must not appear as a destination.
    let excludedIDs: Set<String>
    let onSelect: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stack: [URL] = []
    @State private var folders: [URL] = []
    @State private var scanned = false

    private var current: URL { stack.last ?? rootURL }

    init(title: String = "Move here", rootURL: URL, excludedIDs: Set<String>, onSelect: @escaping (URL) -> Void) {
        self.title = title
        self.rootURL = rootURL
        self.excludedIDs = excludedIDs
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Group {
                if folders.isEmpty {
                    EmptyStateView(icon: "folder.fill.badge.plus",
                                   title: "No sub-folders",
                                   subtitle: "Create folders to have somewhere to move files into.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(folders, id: \.self) { folder in
                                folderRow(folder)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(stack.isEmpty ? "Choose folder" : current.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if stack.isEmpty {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            _ = withAnimation(AppMotion.spring) { stack.removeLast() }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(title) {
                        Haptics.rigidTap()
                        onSelect(current)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.surface)
        .task(id: current) { scan() }
    }

    private func folderRow(_ folder: URL) -> some View {
        Button {
            Haptics.tap()
            withAnimation(AppMotion.spring) { stack.append(folder) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                Text(folder.lastPathComponent)
                    .font(Theme.Font.body(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentCard()
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityHint("Opens \(folder.lastPathComponent) to pick a deeper destination")
    }

    private func scan() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: current,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        folders = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
            .filter { !excludedIDs.contains($0.path) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        scanned = true
    }
}

#Preview {
    FolderPickerView(
        rootURL: FileService.shared.rootURL,
        excludedIDs: [],
        onSelect: { _ in }
    )
}