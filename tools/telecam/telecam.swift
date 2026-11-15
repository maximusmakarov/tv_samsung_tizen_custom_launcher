import Foundation
import AVFoundation
import AppKit

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let outDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TELECAM_DIR"] ?? "./snapshots")
    var last = 0.0
    let ctx = CIContext()

    func start() {
        guard let dev = AVCaptureDevice.default(for: .video) else { FileHandle.standardError.write("NO_CAMERA\n".data(using: .utf8)!); exit(2) }
        guard let input = try? AVCaptureDeviceInput(device: dev) else { FileHandle.standardError.write("NO_INPUT\n".data(using: .utf8)!); exit(3) }
        guard session.canAddInput(input) else { FileHandle.standardError.write("CANNOT_ADD_INPUT\n".data(using: .utf8)!); exit(4) }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cam"))
        if session.canAddOutput(output) { session.addOutput(output) }
        session.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date().timeIntervalSince1970
        if now - last < 2.0 { return }
        last = now
        guard let buf = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: buf)
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try? data.write(to: outDir.appendingPathComponent("tv-latest.jpg"))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let cam = Camera()
cam.start()
app.run()
