// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the home page's shortcut row in "Customize Home".
//
// While the edit mode is on, each shortcut under the widgets wiggles with a
// remove badge and can be dragged along the row: the tile follows the
// pointer, the others spring aside to make room, and on release it springs
// into its new place. The strip's Shortcuts side lists every shortcut this
// Mac can show; adding one flies its icon into the row
// (`matchedGeometryEffect`), removing one shrinks, blurs and fades it out.
// A shortcut past what the row holds at the island's width (it would scroll)
// is dimmed with a tooltip, and the strip offers no more. Reduce Motion
// turns the flights and springs into fades.
//
// The drag is SwiftUI's own gesture inside the island, not a drag session,
// so nothing leaves the island and the shelf never sees it.

extension NotchControlItem {
    /// The id the icon flying from the strip into the row shares.
    var zenithFlightID: String { "shortcut." + rawValue }
}

/// A shortcut tile's edit mode: the badge, the drag, the wiggle, the flight
/// in, and the dimming of one the row has no room for.
struct ZenithHomeShortcutEditing: ViewModifier {
    let item: NotchControlItem
    let index: Int
    let capacity: Int
    let service: NotchService
    let namespace: Namespace.ID
    @ObservedObject private var editor = ZenithHomeEditor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview

    init(item: NotchControlItem, index: Int, capacity: Int, service: NotchService, namespace: Namespace.ID) {
        self.item = item
        self.index = index
        self.capacity = capacity
        self.service = service
        self.namespace = namespace
    }

    func body(content: Content) -> some View {
        let editing = editor.editing && !preview
        let landing = editing && editor.landingShortcuts.contains(item)
        let overflow = editing && index >= capacity
        let dragging = editing && editor.shortcutDrag?.item == item
        let text = ZenithStrings.home(l10n.language)
        let words = ZenithStrings.homeShortcuts(l10n.language)
        let name = item.title(l10n)
        content
            .allowsHitTesting(!editing)
            .opacity(landing ? 0 : overflow ? 0.35 : 1)
            .blur(radius: landing ? 6 : 0)
            .overlay {
                if landing {
                    ZenithIslandIcon(symbol: item.symbol, hex: item.zenithIconHex, size: 34)
                        .matchedGeometryEffect(id: item.zenithFlightID, in: namespace)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 3)
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .opacity.combined(with: .scale(scale: 1.15))))
                }
            }
            .overlay {
                if editing {
                    // The drag's handle: the whole tile, the tile itself taking no clicks.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                            .onChanged { editor.dragShortcut(item, translation: $0.translation) }
                            .onEnded { _ in editor.dropShortcut(item, service: service) })
                        .help(overflow ? words.noRoom : words.dragHint)
                }
            }
            .overlay(alignment: .top) {
                if editing, !dragging {
                    Button { editor.removeShortcut(item, service: service) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(ZenithStatus.error, in: Circle())
                            .overlay { Circle().strokeBorder(Color.black, lineWidth: 1.5) }
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(ZenithAppIconButtonStyle())
                    // On the icon's corner, which sits 3 points down the tile's top.
                    .offset(x: 17, y: -8)
                    .help(text.remove(name))
                    .accessibilityLabel(text.remove(name))
                    .transition(.scale(scale: 0.4).combined(with: .opacity)
                        .animation(ZenithMorph.animation(reduceMotion: reduceMotion).delay(ZenithMotion.layerStagger)))
                }
            }
            .modifier(ZenithHomeWiggle(active: editing && !reduceMotion && !dragging, index: index + 1))
            .scaleEffect(dragging && !(editor.shortcutDrag?.settling ?? false) ? 1.08 : 1)
            .offset(editing ? editor.shortcutOffset(item) : .zero)
            .zIndex(dragging ? 1 : 0)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                // The row's places, measured at rest.
                if editing, editor.shortcutDrag == nil { editor.shortcutFrames[item] = frame }
            }
            .accessibilityActions {
                if editing {
                    Button(words.moveLeft) { editor.moveShortcut(item, by: -1, service: service) }
                    Button(words.moveRight) { editor.moveShortcut(item, by: 1, service: service) }
                    Button(text.remove(name)) { editor.removeShortcut(item, service: service) }
                }
            }
            .transition(.asymmetric(insertion: .zenithMorph(reduceMotion: reduceMotion),
                                    removal: .zenithHomeDeparture(reduceMotion: reduceMotion)))
    }
}

/// A shortcut in the strip's Shortcuts side: its tinted icon over its name,
/// a check once it is in the row, dimmed with a tooltip once the row is full.
struct ZenithHomeShortcutCandidate: View {
    let item: NotchControlItem
    @ObservedObject var service: NotchService
    let namespace: Namespace.ID
    let capacity: Int
    @ObservedObject private var editor = ZenithHomeEditor.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.home(l10n.language)
        let words = ZenithStrings.homeShortcuts(l10n.language)
        let added = editor.shortcuts.contains(item)
        let addable = added || editor.shortcuts.canAdd(item, available: editor.availableShortcuts, capacity: capacity)
        let name = item.title(l10n)
        Button { editor.toggleShortcut(item, service: service) } label: {
            ZenithHomeStripIcon(name: name, added: added, addable: addable) {
                if added {
                    ZenithIslandIcon(symbol: item.symbol, hex: item.zenithIconHex, size: 34, lifted: false)
                } else {
                    // The icon that flies into the row when the shortcut joins it.
                    ZenithIslandIcon(symbol: item.symbol, hex: item.zenithIconHex, size: 34, lifted: false)
                        .matchedGeometryEffect(id: item.zenithFlightID, in: namespace)
                }
            }
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .disabled(!addable)
        .help(addable ? (added ? text.remove(name) : text.add(name)) : words.noRoom)
        .accessibilityLabel(added ? text.remove(name) : text.add(name))
        .accessibilityAddTraits(added ? .isSelected : [])
    }
}
