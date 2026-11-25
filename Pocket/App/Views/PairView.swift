// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import PocketKit
import SwiftUI

/// The first pairing: scan the code Zenith shows. Scanning it with the
/// Camera app works too, through the `zenith-pocket` link.
struct PairView: View {
    var onIntro: (() -> Void)?

    @Environment(PocketModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var problem: String?
    @State private var found = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(eyebrow: "Zenith Pocket", badge: nil,
                     sentence: PocketSentence(lead: "Pair with ", value: "your Mac", after: ".",
                                              rest: "Scan the code in Zenith Settings → iPhone & Watch.", tone: .plain))
                viewfinder
                    .padding(.horizontal, 20).padding(.top, 28)
                    .blurFade(index: 3)
                Text(problem ?? "Everything between Pocket and your Mac is sealed with a key only the two of them hold.")
                    .font(K.sans(13)).foregroundStyle(problem == nil ? K.faint : K.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(Motion.quick, value: problem)
                    .padding(.horizontal, 24).padding(.top, 14)
                    .blurFade(index: 4)
                if let onIntro {
                    Button("What does Pocket do?", action: onIntro)
                        .font(K.sans(13, bold: true)).foregroundStyle(K.muted)
                        .pressable()
                        .padding(.horizontal, 24).padding(.top, 18)
                        .blurFade(index: 5)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .task {
            guard camera == .notDetermined else { return }
            _ = await AVCaptureDevice.requestAccess(for: .video)
            camera = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    @ViewBuilder
    private var viewfinder: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        Group {
            switch camera {
            case .authorized:
                QRScanner { code in scanned(code) }
                    .overlay { ScanFrame(found: found) }
            case .notDetermined:
                Color.black.overlay { ScanFrame() }
            default:
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "camera").font(.system(size: 22, weight: .medium)).foregroundStyle(K.muted)
                    Text("Pocket can't use the camera.").font(K.sans(17, bold: true))
                    Text("Allow it in Settings, or scan Zenith's code with the Camera app.")
                        .font(K.sans(13)).foregroundStyle(K.muted).fixedSize(horizontal: false, vertical: true)
                    PillButton(title: "Open Settings", primary: true) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .background(K.card)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(shape)
        .surface(radius: 28)
    }

    private func scanned(_ code: String) {
        guard let url = URL(string: code), model.open(url) else {
            Haptics.warning()
            problem = "That code isn't from Zenith. Open Zenith Settings → iPhone & Watch on your Mac."
            return
        }
        Haptics.success()
        problem = nil
        found = true
    }
}
