import SwiftUI
import LocalAuthentication

/// App chrome: phase routing (splash/onboarding/main), the custom tab bar,
/// global toast host and the biometric app-lock overlay.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    @State private var tab: AppTab = .browse
    @State private var showLockedFolder = false
    @State private var pendingFolder: FolderNode?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch appState.phase {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .main:
                mainShell
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.contentSwap, value: appState.phase)

        .overlay {
            ToastHost()
        }
        .overlay {
            if appState.isLocked {
                LockScreenView()
                    .transition(.opacity)
            }
        }

        .preferredColorScheme(colorScheme)
        .tint(settings.effectiveAccent)
        .onAppear {
            appState.engageBiometricLockIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLockedFolder)) { _ in
            showLockedFolder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { notification in
            if let node = notification.object as? FolderNode {
                withAnimation(AppMotion.contentSwap) {
                    tab = .browse
                    pendingFolder = node
                }
            }
        }
        .sheet(isPresented: $showLockedFolder) {
            LockedFolderView()
                .environment(appState)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
    }

    // MARK: - Main shell

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .browse:
                    HomeView(root: pendingFolder ?? FolderNode.directory(FileService.shared.rootURL, named: "On My iPhone")) {
                        Haptics.tap()
                        withAnimation(AppMotion.spring) { tab = .search }
                    }
                case .search:
                    SearchView()
                case .favorites:
                    FavoritesView()
                case .settings:
                    SettingsView()
                }
            }
            .id(tabKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)

            VStack(spacing: 0) {
                Spacer()
                CustomTabBar(selection: $tab)
            }
        }
        .animation(AppMotion.contentSwap, value: tab)
    }

    private var tabKey: String {
        "\(tab.rawValue)-\(pendingFolder?.id ?? "")"
    }

    private var colorScheme: ColorScheme? {
        switch settings.themePreference {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Biometric gate shown over everything while the app is locked.
struct LockScreenView: View {
    @Environment(AppState.self) private var appState

    @State private var shaking = false
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 110, height: 110)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                Text("Nova Files is locked")
                    .font(Theme.Font.display(26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Unlock to view your files.")
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.textSecondary)

                Button(action: authenticate) {
                    HStack(spacing: 8) {
                        Image(systemName: biometricIcon)
                        Text(isAuthenticating ? "Checking…" : "Unlock")
                    }
                    .font(Theme.Font.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressEffectButtonStyle())
                .disabled(isAuthenticating)
                .accessibilityHint("Uses Face ID or Touch ID to unlock Nova Files")
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
            // Lock-shake: a quick ±10 px horizontal bounce on failed auth.
            .offset(x: shaking ? -10 : 0)
        }
        .onAppear {
            if SecurityService.shared.isBiometricAvailable { authenticate() }
        }
    }

    private var biometricIcon: String {
        SecurityService.shared.isBiometricAvailable ? "faceid" : "touchid"
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let result = await SecurityService.shared.authenticate(reason: "Unlock Nova Files")
            await MainActor.run {
                isAuthenticating = false
                switch result {
                case .success:
                    Haptics.success()
                    appState.unlock()
                case .failure(let error):
                    Haptics.error()
                    appState.showToast(.error(error.localizedDescription))
                    shake()
                }
            }
        }
    }

    private func shake() {
        withAnimation(.spring(response: 0.14, dampingFraction: 0.4)) {
            shaking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.4)) {
                shaking = false
            }
        }
    }
}

/// Thin browser wrapper so the Browse tab has a stable entry point that can
/// honour folder-jumps from other tabs (search results / favorites).
struct HomeView: View {
    let root: FolderNode
    let onOpenSearch: () -> Void

    init(root: FolderNode, onOpenSearch: @escaping () -> Void) {
        self.root = root
        self.onOpenSearch = onOpenSearch
    }

    var body: some View {
        FileBrowserView(root: root, includeHomeChrome: true, onOpenSearch: onOpenSearch)
    }
}

extension Notification.Name {
    static let openFolder = Notification.Name("openFolder")
}