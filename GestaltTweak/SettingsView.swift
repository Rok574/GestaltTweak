//
//  SettingsView.swift
//  GestaltTweak
//
//  Settings sheet modeled after rooootdev/mond's SettingsView (AGPL-3.0).
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: GestaltViewModel

    @AppStorage("method") private var method = "bad_query"
    @AppStorage("atomic_write") private var persistAfterReboot = true
    @AppStorage("dismiss_after_import") private var dismissAfterImport = false

    @State private var showsRespringConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section { appInfoRow }

                Section {
                    Picker("Method", selection: $method) {
                        Text("bad_query").tag("bad_query")
                        Text("cmg").tag("cmg")
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.runExploit()
                        dismiss()
                    } label: {
                        Text("Run Exploit")
                    }
                } header: {
                    Label("Engine", systemImage: "wrench.and.screwdriver")
                } footer: {
                    Text(method == "cmg"
                        ? "CMG: works on iOS 27.0 b1 - b4. Only MobileGestalt is reachable this way. Fall back to it when bad_query is a no-go."
                        : "bad_query: works on iOS 27.0 b1 - b4. Credit to forcequit.")
                }

                Section {
                    Toggle("Persist after reboot", isOn: $persistAfterReboot)

                    Toggle("Dismiss after importing", isOn: $dismissAfterImport)
                } header: {
                    Label("Preferences", systemImage: "gear")
                } footer: {
                    Text("Persist after reboot rewrites MobileGestalt in-place on the same inode so iOS (hopefully) keeps the file after a restart. Turn it off to use atomic file replacement instead. Dismiss after importing closes the wallpaper explorer once a pack is saved.")
                }

                Section {
                    Button {
                        showsRespringConfirmation = true
                    } label: {
                        Text("Respring")
                    }
                } header: {
                    Label("Utilities", systemImage: "hammer")
                } footer: {
                    Text("Respring trick by neonmodder123, Swift port by skadz108.")
                }

                Section {
                    CreditsRow(name: "frs0n", role: "GestaltEdit", profile: URL(string: "https://github.com/frs0n")!)
                    CreditsRow(name: "forcequit", role: "bad_query exploit", profile: URL(string: "https://github.com/forcequitOS")!)
                    CreditsRow(name: "roooot", role: "mond", profile: URL(string: "https://github.com/rooootdev")!)
                    CreditsRow(name: "leminlimez", role: "Nugget (tweak keys)", profile: URL(string: "https://github.com/leminlimez")!)
                    CreditsRow(name: "neonmodder123", role: "Respring method", profile: URL(string: "https://github.com/neonmodder123")!)
                    CreditsRow(name: "skadz108", role: "Respring Swift port", profile: URL(string: "https://github.com/skadz108")!)
                } header: {
                    Label("Credits", systemImage: "person.3.fill")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Are you sure?", isPresented: $showsRespringConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") { viewModel.respring() }
            } message: {
                Text("Confirm that you want to respring.")
            }
        }
    }

    private var appInfoRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 50, height: 50)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("GestaltTweak")
                    .font(.headline)
                Text("Version \(versionText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}

struct CreditsRow: View {
    let name: String
    let role: String
    let profile: URL

    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.open(profile)
        }
    }

    private var avatarURL: URL {
        URL(string: profile.absoluteString + ".png") ?? profile
    }
}