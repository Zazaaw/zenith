// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → iPhone & Watch → Watchtower: the sites to watch,
/// the optional Vercel and Netlify tokens for deploys, and the folder whose
/// repos are checked for work never pushed. It writes `PocketWatchtowerDefaults`
/// and the secrets; `PocketWatchtowerPart` does the watching.
struct PocketWatchtowerSection: View {
    @AppStorage(PocketWatchtowerDefaults.watchSites) private var watchSites = true
    @AppStorage(PocketWatchtowerDefaults.watchSafety) private var watchSafety = true
    @AppStorage(PocketWatchtowerDefaults.safetyFolder) private var savedFolder = ""
    @ObservedObject private var vercel = VercelService.shared

    @State private var sites: [String] = []
    @State private var draft = ""
    @State private var problem: String?
    @State private var vercelDraft = ""
    @State private var netlifyDraft = ""
    @State private var hasNetlify = false
    @State private var tokenProblem: String?

    private let text = ZenithStrings.pocketWatchtower(.enUS)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            card {
                row {
                    ZenithSwitchRow(text.watchSites, isOn: $watchSites) {
                        title(text.watchSites, caption: text.watchSitesCaption)
                    }
                }
                Group {
                    ForEach(sites, id: \.self) { site in
                        divider
                        siteRow(site)
                    }
                    if sites.isEmpty {
                        divider
                        row { caption(text.noSites); Spacer(minLength: 0) }
                    }
                    divider
                    addRow
                }
                .disabled(!watchSites)
                .opacity(watchSites ? 1 : 0.5)
            }
            card {
                row { title(text.deploys, caption: text.deploysCaption); Spacer(minLength: 0) }
                divider
                vercelRow
                divider
                netlifyRow
                if let tokenProblem {
                    divider
                    row { warning(tokenProblem) }
                }
            }
            .disabled(!watchSites)
            .opacity(watchSites ? 1 : 0.5)
            card {
                row {
                    ZenithSwitchRow(text.watchSafety, isOn: $watchSafety) {
                        title(text.watchSafety, caption: text.watchSafetyCaption)
                    }
                }
                divider
                folderRow
                    .disabled(!watchSafety)
                    .opacity(watchSafety ? 1 : 0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            sites = PocketWatchtowerDefaults.siteList()
            hasNetlify = ZenithSecretStore.read(PocketWatchtowerDefaults.netlifySecret) != nil
            vercel.loadTokenIfNeeded()
        }
        .zenithSectionAnchor(.zenithPocketWatchtower)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "binoculars")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(text.title)
                    .font(ZenithType.sectionTitle)
                    .tracking(ZenithType.sectionTitleTracking)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(text.caption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 32)
        }
        .padding(.leading, 2)
    }

    // MARK: Sites

    private func siteRow(_ site: String) -> some View {
        row {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 6, height: 6).frame(width: 22)
            Text(PocketWatchtowerSupport.siteURL(site).map(PocketWatchtowerSupport.siteName) ?? site)
                .font(ZenithType.mono(12)).lineLimit(1).truncationMode(.middle)
                .help(site)
            Spacer(minLength: 12)
            Button {
                sites.removeAll { $0 == site }
                saveSites()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(text.remove)
            .accessibilityLabel(text.remove + " " + site)
        }
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(text.sitePrompt, text: $draft, prompt: Text(text.sitePrompt))
                    .textFieldStyle(.roundedBorder)
                    .font(ZenithType.mono(12))
                    .onSubmit(addSite)
                Button(text.add, action: addSite)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let problem { warning(problem) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: draft) { _, _ in problem = nil }
    }

    private func addSite() {
        let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = PocketWatchtowerSupport.siteURL(typed) else {
            problem = text.invalidSite
            return
        }
        guard !PocketWatchtowerSupport.siteURLs(sites).contains(url) else {
            problem = text.alreadyListed
            return
        }
        guard sites.count < PocketWatchtowerSupport.maximumSites else {
            problem = text.limit(PocketWatchtowerSupport.maximumSites)
            return
        }
        sites.append(url.absoluteString)
        draft = ""
        saveSites()
    }

    private func saveSites() {
        UserDefaults.standard.set(sites, forKey: PocketWatchtowerDefaults.sites)
    }

    // MARK: Tokens

    @ViewBuilder private var vercelRow: some View {
        if vercel.hasToken {
            row {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success).frame(width: 22)
                title(text.vercel, caption: text.vercelShared)
                Spacer(minLength: 0)
            }
        } else {
            tokenRow(text.vercel, caption: text.vercelMissing, value: $vercelDraft) {
                guard VercelSupport.isPlausibleToken(vercelDraft) else { return false }
                // The island's own save: one token for both, and its cache stays right.
                return vercel.saveToken(vercelDraft)
            }
        }
    }

    @ViewBuilder private var netlifyRow: some View {
        if hasNetlify {
            row {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success).frame(width: 22)
                title(text.netlify, caption: text.netlifySaved)
                Spacer(minLength: 12)
                Button(text.remove) {
                    ZenithSecretStore.delete(PocketWatchtowerDefaults.netlifySecret)
                    hasNetlify = false
                    NotificationCenter.default.post(name: PocketWatchtowerPart.tokensChanged, object: nil)
                }
            }
        } else {
            tokenRow(text.netlify, caption: text.netlifyMissing, value: $netlifyDraft) {
                // Netlify's tokens are one run of letters, digits, `_` and `-`, like Vercel's.
                guard VercelSupport.isPlausibleToken(netlifyDraft),
                      ZenithSecretStore.save(netlifyDraft, as: PocketWatchtowerDefaults.netlifySecret) else { return false }
                hasNetlify = true
                return true
            }
        }
    }

    private func tokenRow(_ name: String, caption: String, value: Binding<String>, save: @escaping () -> Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            title(name, caption: caption)
            HStack(spacing: 8) {
                SecureField(text.tokenPrompt, text: value, prompt: Text(text.tokenPrompt))
                    .textFieldStyle(.roundedBorder)
                    .font(ZenithType.mono(12))
                Button(text.save) {
                    if save() {
                        value.wrappedValue = ""
                        tokenProblem = nil
                        NotificationCenter.default.post(name: PocketWatchtowerPart.tokensChanged, object: nil)
                    } else {
                        tokenProblem = text.tokenInvalid
                    }
                }
                .disabled(value.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Folder

    private var folderRow: some View {
        let path = PocketWatchtowerDefaults.folder()
        return row {
            Image(systemName: "folder").font(.system(size: 14)).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(text.folder).font(ZenithType.rowTitle)
                Text(PocketWatchtowerSupport.displayPath(path) + " · " + text.folderCaption)
                    .font(ZenithType.mono(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            if !savedFolder.isEmpty {
                Button(text.reset) { savedFolder = "" }
            }
            Button(text.choose) { chooseFolder(from: path) }
        }
    }

    private func chooseFolder(from path: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = text.choosePrompt
        panel.directoryURL = URL(fileURLWithPath: path)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let chosen = url.path
        savedFolder = chosen == PocketWatchtowerSupport.defaultFolder(home: NSHomeDirectory()) ? "" : chosen
    }

    // MARK: Pieces

    /// The page's card: a hairline panel of rows.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(ZenithSurface.cardFill, in: shape)
            .overlay(shape.strokeBorder(ZenithSurface.hairline))
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).padding(.horizontal, 16)
    }

    private func title(_ string: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(string).font(ZenithType.rowTitle)
            if let caption { self.caption(caption) }
        }
    }

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func warning(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(ZenithStatus.warning)
            .fixedSize(horizontal: false, vertical: true)
    }
}
