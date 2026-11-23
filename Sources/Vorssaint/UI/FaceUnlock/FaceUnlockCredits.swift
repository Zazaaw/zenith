// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: About's credits for face unlock: Glance, whose code it is
/// adapted from (MIT, its notice in full as the licence asks), and the
/// ArcFace model from InsightFace, licensed for non-commercial research only.
struct FaceUnlockCredits: View {
    @State private var showsLicense = false
    private let text = ZenithStrings.faceUnlock(.enUS)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            Text(text.credits)
                .font(ZenithType.sectionTitle)
                .tracking(ZenithType.sectionTitleTracking)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 10) {
                credit(text.glanceCredit, link: "https://github.com/jonnyoo/glance")
                credit(text.arcFaceCredit, link: "https://github.com/deepinsight/insightface")
                Button(showsLicense ? text.hideLicense : text.showLicense) { showsLicense.toggle() }
                    .buttonStyle(.link)
                    .font(ZenithType.footnote)
                if showsLicense {
                    Text(verbatim: Self.glanceLicense)
                        .font(ZenithType.mono(10))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(ZenithSurface.cardFill, in: shape)
            .overlay(shape.strokeBorder(ZenithSurface.hairline))
        }
    }

    private func credit(_ line: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: link) {
                Link(destination: url) { Text(verbatim: link).font(ZenithType.mono(10.5)) }
            }
        }
    }

    /// Glance's licence, verbatim.
    static let glanceLicense = """
    MIT License

    Copyright (c) 2026 Jonathan Zhou

    Permission is hereby granted, free of charge, to any person obtaining a copy \
    of this software and associated documentation files (the "Software"), to deal \
    in the Software without restriction, including without limitation the rights \
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
    copies of the Software, and to permit persons to whom the Software is \
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all \
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
    SOFTWARE.
    """
}
