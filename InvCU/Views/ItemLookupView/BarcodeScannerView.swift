//
//  BarcodeScannerView.swift
//  InvCU
//
//  Created by work on 11/15/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {
    @Binding var isPresented: Bool
    let onBarcodeScanned: (String) -> Void
    
    @StateObject private var scanner = BarcodeScanner()
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            CameraPreview(scanner: scanner)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName:  "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                        Text("Reading barcode...")
                            .font(. headline)
                            .foregroundColor(.white)
                    } else {
                        Text("Scan Barcode")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Hold steady and wait for focus")
                            .font(.subheadline)
                            . foregroundColor(.white.opacity(0.8))
                    }
                }
                . padding(20)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
                .padding(.bottom, 40)
            }
            
            Rectangle()
                .strokeBorder(isProcessing ? Color.green : Color.white, lineWidth: 3)
                .frame(width: 280, height: 180)
                .animation(.easeInOut, value: isProcessing)
        }
        .onAppear {
            scanner.startScanning()
        }
        . onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: scanner.scannedCode) { oldValue, newValue in
            if let code = newValue, !isProcessing {
                isProcessing = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Final scanned code: \(code)")
                    onBarcodeScanned(code)
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview:  UIViewRepresentable {
    let scanner: BarcodeScanner
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: . zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session:  scanner.session)
        previewLayer.videoGravity = . resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context:  Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK:  - Barcode Scanner Class

class BarcodeScanner:  NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    
    let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var captureDevice: AVCaptureDevice?
    
    private var lastScannedCode: String?
    private var scanCount:  [String: Int] = [:]
    private let requiredScans = 3
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("Failed to get camera device")
            return
        }
        
        captureDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: . main)
                output.metadataObjectTypes = [
                    . ean8,
                    .ean13,
                    .qr,
                    .code128,
                    .code39,
                    .code93,
                    .upce
                ]
            }
            
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
            print("Camera setup complete with autofocus enabled")
            
        } catch {
            print("Failed to setup camera: \(error.localizedDescription)")
        }
    }
    
    func startScanning() {
        scanCount.removeAll()
        lastScannedCode = nil
        scannedCode = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard scannedCode == nil else { return }
        
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            scanCount[stringValue, default: 0] += 1
            
            print("Scan attempt: \(stringValue) - Count: \(scanCount[stringValue] ?? 0)")
            
            if scanCount[stringValue] ??  0 >= requiredScans {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                print("Confirmed barcode after \(requiredScans) scans: \(stringValue)")
                scannedCode = stringValue
                stopScanning()
            }
        }
    }
}

// MARK: - Preview

struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerView(isPresented: .constant(true)) { code in
            print("Scanned:  \(code)")
        }
    }
}
