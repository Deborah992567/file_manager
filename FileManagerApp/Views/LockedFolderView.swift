import SwiftUI

/// Biometric-gated "Locked Folder" sheet.
///
/// Three states: no folder yet (create CTA), folder locked (Face ID / Touch ID
/// gate with shake-on-fail), folder unlocked (file list + lock button + delete).
struct LockedFolderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: LockedFolderViewModel
    @State private var pendingDelete: FileItem?
    @State private var shake = false
    @State private var quickLookItem: QuickLookItem?

    init() {
        _vm = State(initialValue: LockedFolderViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            switch contentState {
            case .needsCreation:
                createState
            case .locked:
                lockedGate
            case .unlocked:
                unlockedState
            }
        }
        .animation(AppMotion.contentSwap, value: contentState)
        .offset(x: shake ? -10 : 0)
        .confirmationDialog(
            pendingDelete.map { "Delete “\($0.name)”?" } ?? "",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This moves the item to the trash. You can undo it from Recents.")
        }
        .fullScreenCover(item: $quickLookItem) { item in
            QuickLookView(urls: [item.url])
                .ignoresSafeArea()
        }
        .onAppear {
            if vm.folderExists, vm.isUnlocked { vm.reload() }
        }
    }

    // MARK: - State

    private enum ContentState {
        case needsCreation, locked, unlocked
    }

    private var contentState: ContentState {
        if !vm.folderExists { return .needsCreation }
        return vm.isUnlocked ? .unlocked : .locked
    }

    // MARK: - Create

    private var createState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentViolet.opacity(0.14))
                    .frame(width: 108, height: 108)
                Image(systemName: "lock.square.stack.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Theme.accentViolet)
            }

            Text("The Locked Folder")
                .font(Theme.Font.display(24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("A private space protected by Face ID or Touch ID. Create it once, then only biometrics can open it.")
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                Haptics.mediumTap()
                createFolder()
            } label: {
                Text("Create Locked Folder")
                    .font(Theme.Font.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.accentViolet))
            }
            .buttonStyle(PressEffectButtonStyle())
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
    }

    private func createFolder() {
        switch vm.createFolder() {
        case .success:
            Haptics.success()
            appState.showToast(.success("Locked Folder created", subtitle: "Unlock it with biometrics to start adding files."))
            vm.reload()
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    // MARK: - Gate

    private var lockedGate: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Text("Locked")
                .font(Theme.Font.display(24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("This folder is protected.\nUnlock it to view its contents.")
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if let error = vm.lastAuthError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Button {
                Haptics.tap()
                Task { await vm.unlock() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                    Text("Unlock")
                }
                .font(Theme.Font.body(16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 13)
                .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressEffectButtonStyle())
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
        .onChange(of: vm.lastAuthError) { _, error in
            guard error != nil else { return }
            withAnimation(.spring(response: 0.14, dampingFraction: 0.4)) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(response: 0.14, dampingFraction: 0.4)) { shake = false }
            }
        }
    }

    // MARK: - Unlocked

    private var unlockedState: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Locked Folder")
                    .font(Theme.Font.display(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button {
                    Haptics.tick()
                    vm.lock()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Lock")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.surfaceElevated))
                }
                .buttonStyle(PressEffectButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if vm.items.isEmpty {
                EmptyStateView(
                    icon: "lock.open",
                    title: "Unlocked",
                    subtitle: "Nothing here yet. Import files into this folder to keep them private."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.items) { item in
                            row(item)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 90)
                }
            }
        }
    }

    private func row(_ item: FileItem) -> some View {
        Button {
            Haptics.tap()
            if !item.isDirectory { quickLookItem = QuickLookItem(url: item.url) }
        } label: {
            HStack(spacing: 12) {
                FileThumbnailView(item: item, size: 46, tag: FileService.shared.tag(for: item))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(item.isDirectory ? "Folder" : "\(item.displayExtension) · \(ByteFormatter.format(item.size))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    Haptics.warn()
                    pendingDelete = item
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentCard()
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? "Folder" : "Opens a preview of this file")
        .accessibilityAction(named: "Delete") {
            Haptics.warn()
            pendingDelete = item
        }
    }

    private func confirmDelete() {
        guard let item = pendingDelete else { return }
        pendingDelete = nil
        switch vm.delete(item) {
        case .success(let mapping):
            appState.showToast(.success("Deleted", subtitle: item.name, actionTitle: "Undo") {
                try? FileService.shared.restoreDeletions(mapping)
                vm.reload()
                appState.showToast(.success("Restored", subtitle: item.name))
            })
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }
}

/// Identifiable wrapper so Quick Look can be presented as a cover item.
struct QuickLookItem: Identifiable {
    let id = UUID()
    let url: URL
}