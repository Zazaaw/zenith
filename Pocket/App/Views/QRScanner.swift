// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import SwiftUI
import UIKit

/// The camera, reading QR codes. Each code's text is handed over once in a
/// row; the session runs off the main thread, as AVFoundation asks.
struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {
        controller.onCode = onCode
    }
}

/// The capture session, kept apart so its own queue can start and stop it.
private final class CaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.camera")

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let capture = CaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var lastCode: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              capture.session.canAddInput(input) else { return }
        capture.session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard capture.session.canAddOutput(output) else { return }
        capture.session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: capture.session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capture.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        capture.stop()
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        let codes = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        guard let code = codes.first else { return }
        MainActor.assumeIsolated {
            guard code != lastCode else { return }
            lastCode = code
            onCode?(code)
        }
    }
}

/// The viewfinder's frame: four corner brackets that breathe, a line of
/// light sweeping down while it looks, and a green close-in with a tick once
/// a Zenith code is read.
struct ScanFrame: View {
    var found = false
    @State private var breathe = false
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * 0.66
            let tint = found ? K.emerald : Color.white
            ZStack {
                Brackets()
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .shadow(color: tint.opacity(found ? 0.7 : 0.35), radius: found ? 12 : 6)
                    .scaleEffect(found ? 0.9 : (breathe ? 1 : 0.95))
                if !found && !reduceMotion {
                    LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 2)
                        .shadow(color: .white.opacity(0.6), radius: 6)
                        .padding(.horizontal, side * 0.08)
                        .offset(y: (sweep ? 0.42 : -0.42) * side)
                        .transition(.opacity)
                }
                if found {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(K.emerald, in: Circle())
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(Motion.spring, value: found)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { breathe = true; return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { sweep = true }
        }
    }
}

/// The four rounded corners of a square.
private struct Brackets: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = rect.width * 0.2, radius: CGFloat = 14
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1), (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        var path = Path()
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * radius))
            path.addQuadCurve(to: CGPoint(x: corner.x + dx * radius, y: corner.y), control: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
        }
        return path
    }
}
