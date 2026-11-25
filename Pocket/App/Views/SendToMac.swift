// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PhotosUI
import PocketKit
import SwiftUI
import UniformTypeIdentifiers

/// The Mac tab's way in: a card that opens Send to Mac.
struct SendToMacCard: View {
    let open: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            open()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.blue.opacity(0.14))
                    .overlay(Image(systemName: "paperplane.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(K.blue))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send to Mac").font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                    Text("text, a link, a photo or a small file").font(K.mono(11)).foregroundStyle(K.faint)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(K.faint)
            }
            .macCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// Send to Mac: clipboard text onto the Mac's clipboard, a link into its
/// browser, a photo (shrunk to fit) or a small file into ~/Downloads/Pocket.
/// Sealed end to end like everything else, through the reused drop slots.
struct SendToMacSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case clipboard, link, photo, file
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clipboard: return "Clipboard"
            case .link: return "Open link"
            case .photo: return "Photo"
            case .file: return "File"
            }
        }
        var symbol: String {
            switch self {
            case .clipboard: return "doc.on.clipboard"
            case .link: return "link"
            case .photo: return "photo"
            case .file: return "doc"
            }
        }
    }

    @Environment(PocketModel.self) private var model
    @State private var kind = Kind.clipboard
    @State private var pasted = ""
    @State private var link = ""
    @State private var photo: PhotosPickerItem?
    @State private var preparing = false
    @State private var importing = false
    @Namespace private var selection

    var body: some View {
        let store = model.mac
        MacSheetFrame(eyebrow: "Send to Mac",
                      sentence: PocketSentence(lead: "Drop it here, ", value: "it lands", after: "", rest: "on your Mac.", tone: .info)) {
            kinds
            Group {
                switch kind {
                case .clipboard: clipboard
                case .link: linkField
                case .photo: photoPicker
                case .file: filePicker
                }
            }
            .transition(.opacity.combined(with: .offset(y: 6)))
            .id(kind)
            .disabled(!model.canControl() || preparing || store.dropping)
            if preparing || store.dropping {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(K.muted)
                    Text(preparing ? "Getting it ready…" : "Sealing and sending…").font(K.mono(11)).foregroundStyle(K.faint)
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
            if !store.recent.isEmpty {
                SectionLabel(text: "Recent").padding(.top, 8)
                Rows {
                    ForEach(Array(store.recent.enumerated()), id: \.element.id) { index, sent in
                        Row(symbol: symbol(sent.kind), title: sent.title.isEmpty ? "Text" : sent.title,
                            meta: sent.detail + " · " + PocketPresentation.ago(sent.at, now: Date()).replacingOccurrences(of: " ago", with: ""),
                            divider: index < store.recent.count - 1) {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(K.emerald)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(Motion.spring, value: store.recent)
            }
            if let problem = model.controlProblem() {
                Text(problem).font(K.sans(13)).foregroundStyle(K.faint).padding(.horizontal, 4)
            }
        }
        .animation(Motion.spring, value: kind)
        .animation(Motion.quick, value: preparing || store.dropping)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await send(item) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { send(file: url) }
        }
    }

    // MARK: Kinds

    private var kinds: some View {
        HStack(spacing: 8) {
            ForEach(Kind.allCases) { option in
                let on = option == kind
                Button {
                    Haptics.select()
                    kind = option
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: option.symbol).font(.system(size: 17, weight: .semibold))
                        Text(option.title).font(K.sans(11, bold: true)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(on ? K.bg : K.fg)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(K.fg)
                                .matchedGeometryEffect(id: "kind", in: selection)
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(K.card)
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: Clipboard

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pasted.isEmpty {
                Text("Paste what you copied on this iPhone, then send it to the Mac's clipboard.")
                    .font(K.sans(14)).foregroundStyle(K.muted).fixedSize(horizontal: false, vertical: true)
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in pasted = String((strings.first ?? "").prefix(20_000)) }
                }
                .buttonBorderShape(.capsule)
                .tint(K.fg)
                .labelStyle(.titleAndIcon)
            } else {
                Text(pasted).font(K.mono(12.5)).foregroundStyle(K.fg).lineLimit(4)
                HStack(spacing: 8) {
                    Text("from your clipboard").font(K.mono(10.5)).foregroundStyle(K.faint)
                    Spacer()
                    Button("Clear") { pasted = "" }.font(K.sans(13, bold: true)).foregroundStyle(K.muted)
                    if let url = Self.webURL(pasted) {
                        smallButton("Open") {
                            model.openOnMac(url)
                            pasted = ""
                        }
                    }
                    smallButton("Send", primary: true) {
                        model.sendText(pasted)
                        pasted = ""
                    }
                }
            }
        }
        .macCard()
    }

    // MARK: Link

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("https://", text: $link)
                .font(K.mono(13)).foregroundStyle(K.fg)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit(openLink)
            HStack {
                Text("opens in your Mac's browser").font(K.mono(10.5)).foregroundStyle(K.faint)
                Spacer()
                smallButton("Open", primary: true, action: openLink)
                    .disabled(Self.webURL(link) == nil)
            }
        }
        .macCard()
    }

    private func openLink() {
        guard let url = Self.webURL(link) else {
            model.show("Pocket opens http and https links only.", ok: false)
            return
        }
        model.openOnMac(url)
        link = ""
    }

    /// http(s) with a host, as the Mac will accept; a bare domain gets https.
    static func webURL(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" "), !trimmed.contains("\n") else { return nil }
        if !trimmed.contains("://"), trimmed.contains(".") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host()?.isEmpty == false else { return nil }
        return url
    }

    // MARK: Photo and file

    private var photoPicker: some View {
        PhotosPicker(selection: $photo, matching: .images, preferredItemEncoding: .compatible) {
            Self.pickLabel("photo.on.rectangle", "Choose a photo", "made smaller to travel, saved to ~/Downloads/Pocket")
        }
        .buttonStyle(PressStyle())
    }

    private var filePicker: some View {
        Button {
            importing = true
        } label: {
            Self.pickLabel("doc.badge.arrow.up", "Choose a file", "up to 180 KB, saved to ~/Downloads/Pocket")
        }
        .buttonStyle(PressStyle())
    }

    nonisolated private static func pickLabel(_ symbol: String, _ title: String, _ meta: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(K.muted).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                Text(meta).font(K.mono(10.5)).foregroundStyle(K.faint)
            }
            Spacer()
        }
        // The card's look spelled out: PhotosPicker builds its label off the main actor.
        .padding(14)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func send(_ item: PhotosPickerItem) async {
        preparing = true
        defer {
            preparing = false
            photo = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            model.show("Pocket couldn't read that photo.", ok: false)
            return
        }
        let jpeg = await Task.detached(priority: .userInitiated) { PocketMacSend.jpeg(image) }.value
        guard let jpeg else {
            model.show(PocketMacSend.tooBig, ok: false)
            return
        }
        Haptics.success()
        model.drop(jpeg, name: PocketMacSend.photoName(), kind: .photo)
    }

    private func send(file url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= PocketDrop.fitBytes, let data = try? Data(contentsOf: url) else {
            model.show(size > PocketDrop.fitBytes ? PocketMacSend.tooBig : "Pocket couldn't read that file.", ok: false)
            return
        }
        Haptics.success()
        model.drop(data, name: url.lastPathComponent, kind: .file)
    }

    // MARK: Pieces

    private func smallButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.press()
            action()
        } label: {
            Text(title).font(K.sans(14, bold: true))
                .foregroundStyle(primary ? K.bg : K.fg)
                .padding(.horizontal, 16).frame(height: 34)
                .background(primary ? K.fg : K.fg.opacity(0.1), in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    private func symbol(_ kind: MacStore.Sent.Kind) -> String {
        switch kind {
        case .text: return "doc.on.clipboard"
        case .link: return "link"
        case .photo: return "photo"
        case .file: return "doc"
        }
    }
}
