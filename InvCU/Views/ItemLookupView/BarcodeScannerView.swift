//
//  BarcodeScannerView.swift
//  InvCU
//
//  Created by work on 11/15/25.
//

import SwiftUI
import AVFoundation // For camera input and barcode detection
import Combine      // For ObservableObject and @Published

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {
    @Binding var isPresented: Bool               // Controls if the scanner is shown
    let onBarcodeScanned: (String) -> Void      // Callback when barcode is scanned
    
    @StateObject private var scanner = BarcodeScanner() // Barcode scanner object
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraPreview(scanner: scanner)  // Shows live camera preview
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Instructions overlay
                    VStack(spacing: 12) {
                        Text("Scan Barcode")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Position barcode within the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.bottom, 40)
                }
                
                // Rectangle frame to guide scanning
                Rectangle()
                    .strokeBorder(Color.brandNavy, lineWidth: 3)
                    .frame(width: 250, height: 250)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false } // Close scanner
                        .foregroundColor(.white)
                }
            }
            .onAppear { scanner.startScanning() }   // Start camera when view appears
            .onDisappear { scanner.stopScanning() } // Stop camera when view disappears
            .onChange(of: scanner.scannedCode) { oldValue, newValue in
                if let code = newValue {
                    onBarcodeScanned(code)           // Call the callback
                    isPresented = false               // Close scanner
                }
            }
        }
    }
}

// MARK: - Camera Preview (wraps UIKit view in SwiftUI)

struct CameraPreview: UIViewRepresentable {
    let scanner: BarcodeScanner
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        // Add live camera preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: scanner.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Make sure preview layer always matches view bounds
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator() // Needed to store the previewLayer
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer? // Store preview layer reference
    }
}

// MARK: - Barcode Scanner Class

class BarcodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String? // Stores scanned barcode, auto-updates SwiftUI views
    
    let session = AVCaptureSession()          // Camera session
    private let output = AVCaptureMetadataOutput() // Metadata output (barcode data)
    
    override init() {
        super.init()
        setupSession() // Configure camera session
    }
    
    private func setupSession() {
        // Get default camera
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }   // Add camera input
        if session.canAddOutput(output) {
            session.addOutput(output)                                // Add output
            output.setMetadataObjectsDelegate(self, queue: .main)    // Set delegate to detect barcodes
            output.metadataObjectTypes = [.ean8, .ean13, .qr, .code128, .code39] // Supported types
        }
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning() // Start camera
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning() // Stop camera
        }
    }
    
    // Called automatically when camera detects barcode
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            scannedCode = stringValue // Save scanned code
            stopScanning()            // Stop after first scan
        }
    }
}

// MARK: - Preview

struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerView(isPresented: .constant(true)) { code in
            print("Scanned: \(code)") // Preview callback
        }
    }
}
