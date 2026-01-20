//
//  BarcodeScannerViewController.swift
//  InvCU
//

import UIKit
import AVFoundation

protocol BarcodeScannerDelegate:  AnyObject {
    func didScanBarcode(_ code: String)
    func didEncounterError(_ error: String)
}

class BarcodeScannerViewController: UIViewController {
    weak var delegate: BarcodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedCode: String?
    private var lastScanTime: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {
            delegate?.didEncounterError("Failed to create capture session")
            return
        }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didEncounterError("No camera available")
            return
        }
        
        let videoInput:  AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didEncounterError("Camera access denied")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didEncounterError("Could not add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // Support Code 128 and other common barcode types
            metadataOutput.metadataObjectTypes = [
                . code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .qr
            ]
        } else {
            delegate?.didEncounterError("Could not add metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = . resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        // Add scanning frame overlay
        addScanningFrame()
    }
    
    private func addScanningFrame() {
        let frameWidth:  CGFloat = 300
        let frameHeight: CGFloat = 150
        
        let frameView = UIView()
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 8
        frameView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(frameView)
        
        NSLayoutConstraint.activate([
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frameView.widthAnchor.constraint(equalToConstant: frameWidth),
            frameView.heightAnchor.constraint(equalToConstant: frameHeight)
        ])
    }
    
    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

extension BarcodeScannerViewController:  AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        // Prevent duplicate scans within 2 seconds
        if let lastCode = lastScannedCode,
           let lastTime = lastScanTime,
           lastCode == stringValue,
           Date().timeIntervalSince(lastTime) < 2.0 {
            return
        }
        
        lastScannedCode = stringValue
        lastScanTime = Date()
        
        // Haptic feedback
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        print("Scanned barcode: \(stringValue)")
        delegate?.didScanBarcode(stringValue)
    }
}
