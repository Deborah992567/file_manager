import SwiftUI

/// Settings: appearance, defaults, storage management, security and about.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    @State private var vm: SettingsViewModel
    @State private var showStorage = false

    init() {
        _vm = State(initialValue: SettingsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Settings")
                    .font(Theme.Font.display(30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                appearanceSection
                defaultsSection
                storageSection
                securitySection
                aboutSection
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showStorage) {
            StorageView()
                .environment(appState)
        }
        .onAppear { vm.loadUsage() }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        SettingsCard(title: "Appearance") {
            SettingsRow(icon: "paintpalette.fill", tint: Theme.accentViolet) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent color").font(Theme.Font.body(15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 12) {
                        ForEach(AccentChoice.allCases) { choice in
                            Button {
                                Haptics.tick()
                                withAnimation(AppMotion.quick) { settings.accentChoice = choice }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(choice.color).frame(width: 16, height: 16)
                                    Text(choice.label)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(settings.accentChoice == choice ? Theme.textPrimary : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(settings.accentChoice == choice ? Theme.accentSoft : Theme.surfaceElevated))
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }

            SettingsRow(icon: "circle.lefthalf.filled", tint: Theme.accent) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme").font(Theme.Font.body(15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(ThemePreference.allCases) { mode in
                            Button {
                                Haptics.tick()
                                withAnimation(AppMotion.quick) { settings.themePreference = mode }
                            } label: {
                                Text(mode.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(settings.themePreference == mode ? .white : Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(settings.themePreference == mode ? Theme.accent : Theme.surfaceElevated))
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var defaultsSection: some View {
        SettingsCard(title: "Defaults") {
            SettingsRow(icon: "square.grid.2x2.fill", tint: Theme.accentViolet) {
                Picker("Default view", selection: Bindable(settings).defaultViewMode) {
                    Text("Grid").tag(ViewMode.grid)
                    Text("List").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
            }

            SettingsRow(icon: "arrow.up.arrow.down", tint: Theme.accent) {
                Picker("Default sort", selection: Bindable(settings).defaultSort) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var storageSection: some View {
        SettingsCard(title: "Storage") {
            Button {
                Haptics.softTap()
                showStorage = true
            } label: {
                HStack {
                    settingsLeadingIcon("internaldrive.fill", tint: Theme.success)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Storage breakdown")
                            .font(Theme.Font.body(15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let snapshot = vm.snapshot {
                            Text("\(snapshot.itemCount) files · \(ByteFormatter.format(snapshot.totalUsed))")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(QuietButtonStyle())
        }
    }

    private var securitySection: some View {
        SettingsCard(title: "Security") {
            SettingsRow(icon: "faceid", tint: Theme.accentViolet) {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(isOn: Bindable(settings).isBiometricEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face ID / Touch ID")
                                .font(Theme.Font.body(15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(vm.isBiometricAvailable ? "Lock the app with biometrics" : "Not available on this device")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(vm.isBiometricAvailable ? Theme.textSecondary : Theme.danger)
                        }
                    }
                    .tint(Theme.accent)
                    .disabled(!vm.isBiometricAvailable)
                    .onChange(of: settings.isBiometricEnabled) { _, enabled in
                        if enabled && !vm.isBiometricAvailable {
                            settings.isBiometricEnabled = false
                            appState.showToast(.warning("Biometrics unavailable", subtitle: "Set up Face ID in Settings first."))
                        } else if enabled {
                            Haptics.mediumTap()
                        }
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            SettingsRow(icon: "app.badge.fill", tint: Theme.accent) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nova Files")
                        .font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Version \(appVersion)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Card + row helpers

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                content
            }
            .padding(8)
            .contentCard()
        }
        .padding(.horizontal, 16)
    }
}

struct SettingsRow<Content: View>: View {
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            settingsLeadingIcon(icon, tint: tint)
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

func settingsLeadingIcon(_ icon: String, tint: Color) -> some View {
    Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 40, height: 40)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.14)))
}