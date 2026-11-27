// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Collaboration
import SwiftUI

/// Zenith fork: the Mac account at the top of the Settings sidebar. Read once
/// from this Mac's local directory (login picture, full name, whether the
/// account is an admin) plus the computer's name: nothing that asks for a
/// permission, no Apple Account, iCloud or Contacts, nothing logged or sent.
/// Read again only after the card opened Users & Groups and Zenith is back.
final class SettingsAccountStore: ObservableObject {
    static let shared = SettingsAccountStore()

    @Published private(set) var summary: SettingsAccountSummary
    @Published private(set) var photo: NSImage?

    private var loaded = false
    private var posed = false
    private var returnObserver: NSObjectProtocol?

    private static let usersAndGroups = URL(string: "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension")

    init() {
        summary = SettingsAccountSummary(
            name: SettingsAccountSummary.displayName(fullName: NSFullUserName(), userName: NSUserName()),
            kind: nil, computer: "")
    }

    func load() {
        guard !loaded, !posed else { return }
        loaded = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let read = Self.read()
            DispatchQueue.main.async {
                guard let self, !self.posed else { return }
                if self.summary != read.summary { self.summary = read.summary }
                self.photo = read.photo
            }
        }
    }

    func openUsersAndGroups() {
        guard let url = Self.usersAndGroups else { return }
        NSWorkspace.shared.open(url)
        // The picture or name may change there; read them once Zenith is back.
        guard returnObserver == nil else { return }
        returnObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                if let observer = self.returnObserver { NotificationCenter.default.removeObserver(observer) }
                self.returnObserver = nil
                self.loaded = false
                self.load()
            }
    }

    /// The offscreen renders show a fixed placeholder, never the real account.
    func catalogPose(_ summary: SettingsAccountSummary) {
        posed = true
        self.summary = summary
        photo = nil
    }

    private static func read() -> (summary: SettingsAccountSummary, photo: NSImage?) {
        let authority = CBIdentityAuthority.local()
        let user = CBIdentity(name: NSUserName(), authority: authority) as? CBUserIdentity
        let admins = CBIdentity(name: "admin", authority: authority) as? CBGroupIdentity
        var kind: SettingsAccountSummary.Kind?
        if let user, let admins { kind = user.isMember(ofGroup: admins) ? .admin : .standard }
        let name = SettingsAccountSummary.displayName(fullName: user?.fullName ?? NSFullUserName(),
                                                      userName: NSUserName())
        let summary = SettingsAccountSummary(name: name, kind: kind,
                                             computer: ZenithLockScreenAccount.deviceName())
        return (summary, user?.image.flatMap { thumbnail($0, side: 96) })
    }

    /// The login picture shrunk once to what the card draws, so the full
    /// size picture is not kept around.
    private static func thumbnail(_ image: NSImage, side: Int) -> NSImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Fill the square from the picture's centre, as the circle crops it.
        let scale = CGFloat(side) / CGFloat(min(source.width, source.height))
        let size = CGSize(width: CGFloat(source.width) * scale, height: CGFloat(source.height) * scale)
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2,
                                        width: size.width, height: size.height))
        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: side / 2, height: side / 2))
    }
}

/// The card above the sidebar's search: the login picture (or the initials),
/// the full name, and the account type with the computer's name. Clicking it
/// opens Users & Groups.
struct SettingsAccountCard: View {
    @ObservedObject private var store = SettingsAccountStore.shared
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    var body: some View {
        let summary = store.summary
        Button(action: store.openUsersAndGroups) {
            HStack(spacing: 12) {
                SettingsAccountAvatar(photo: store.photo, initials: summary.initials, size: 50)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                    let computer = summary.computer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !computer.isEmpty {
                        Label(computer, systemImage: "laptopcomputer")
                            .labelStyle(SettingsAccountLineLabelStyle())
                            .font(.system(size: 11.5))
                            .foregroundStyle(contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let kind = summary.kind {
                        Text(kind.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(kind == .admin ? Color.accentColor : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((kind == .admin ? Color.accentColor : Color.primary).opacity(0.14)))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(hovering ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0.04))
            }
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.35))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Users & Groups")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([summary.name, summary.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint("Opens Users & Groups in System Settings")
        .accessibilityAddTraits(.isButton)
        .onAppear { store.load() }
    }
}

/// An icon and its text on one line, a little apart.
private struct SettingsAccountLineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

/// The login picture in a circle, or the initials on a soft grey gradient
/// as Contacts draws an account without one.
private struct SettingsAccountAvatar: View {
    let photo: NSImage?
    let initials: String
    let size: CGFloat

    var body: some View {
        ZStack {
            if let photo {
                Image(nsImage: photo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.66, green: 0.68, blue: 0.73),
                                        Color(red: 0.51, green: 0.53, blue: 0.58)],
                               startPoint: .top, endPoint: .bottom)
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.48))
                        .foregroundStyle(.white)
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
