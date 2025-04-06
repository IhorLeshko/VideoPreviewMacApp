//
//  CameraManager.swift
//  VideoPreviewApp
//
//  Created by Ihor on 04/04/2025.
//

import SwiftUI
import Foundation
import AVFoundation
import AppKit
import CoreAudio

class CameraManager: NSObject, ObservableObject {
    @Published private(set) var cameraPermissionIsGranted: Bool = false
    
    // devices list
    @Published private(set) var videoCaptureDeviceList: [AVCaptureDevice] = []
    @Published private(set) var audioCaptureDeviceList: [AVCaptureDevice] = []
    @Published private(set) var filtersList: [String] = ["None", "CIComicEffect", "CIPhotoEffectNoir", "CICrystallize", "CISepiaTone"]
    
    // selected devices
    @Published var selectedVideoCaptureDevice: AVCaptureDevice?
    @Published var selectedAudioCaptureDevice: AVCaptureDevice?
    @Published var selectedFilter: String = "None"
    
    // preview frames
    @Published var currentFrames: CGImage?
    
    // user notification
    @Published var toastMessage: String? = nil
    private var toastQueue: [String] = []
    private var isToastShowing = false
    
    // session setup
    private var captureSession: AVCaptureSession = AVCaptureSession()
    private var videoCaptureDeviceInput: AVCaptureDeviceInput?
    private var videoCaptureVideoOutput: AVCaptureVideoDataOutput?
    private var audioCaptureDeviceInput: AVCaptureDeviceInput?
    private var audioCaptureVideoOutput: AVCaptureAudioDataOutput?
    
    // recording
    @Published var isRecording = false
    private var videoURL: URL?
    private var audioURL: URL?
    private var assetWriter: AVAssetWriter?
    private var audioAssetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var audioAssetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private lazy var ciContext: CIContext = {
        let options = [CIContextOption.priorityRequestLow: false,
                       CIContextOption.useSoftwareRenderer: false]
        return CIContext(options: options)
    }()
    
    deinit {
        removeDeviceObservers()
    }
    
    func enableCamera() {
        captureSession.startRunning()
    }
    
    func disableCamera() {
        captureSession.stopRunning()
        currentFrames = nil
    }
}

// MARK: - Session setup
extension CameraManager {
    func setUpCaptureSession() {
        captureSession.sessionPreset = .hd1920x1080
        
        let videoDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .deskViewCamera, .external],
            mediaType: .video,
            position: .front)
        
        let audioDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified)
        
        videoCaptureDeviceList = videoDiscoverySession.devices
        audioCaptureDeviceList = audioDiscoverySession.devices
        
        if let videoDevice = videoDiscoverySession.devices.first,
           let audioDevice = audioDiscoverySession.devices.first {
            selectedVideoCaptureDevice = videoDevice
            selectedAudioCaptureDevice = audioDevice
            
            setupDeviceInput(isVideo: true)
            setupDeviceInput(isVideo: false)
            setupDeviceOutput()
        }
        
        setupDeviceObservers()
    }
    
    func switchVideoDeviceInput() {
        if let input = videoCaptureDeviceInput {
            captureSession.removeInput(input)
            print("removed video input")
        }
        
        setupDeviceInput(isVideo: true)
    }
    
    func switchAudioDeviceInput() {
        if let input = audioCaptureDeviceInput {
            captureSession.removeInput(input)
            print("removed audio input")
        }
        
        setupDeviceInput(isVideo: false)
    }
    
    func setupDeviceInput(isVideo: Bool) {
        guard let selectedVideoCaptureDevice, let selectedAudioCaptureDevice else { return }
        
        do {
            switch isVideo {
            case true:
                videoCaptureDeviceInput = try AVCaptureDeviceInput(device: selectedVideoCaptureDevice)
                
                if captureSession.canAddInput(videoCaptureDeviceInput!) {
                    captureSession.addInput(videoCaptureDeviceInput!)
                }
            case false:
                audioCaptureDeviceInput = try AVCaptureDeviceInput(device: selectedAudioCaptureDevice)
                
                if captureSession.canAddInput(audioCaptureDeviceInput!) {
                    captureSession.addInput(audioCaptureDeviceInput!)
                }
            }
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func setupDeviceOutput() {
        videoCaptureVideoOutput = AVCaptureVideoDataOutput()
        videoCaptureVideoOutput?.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoCaptureVideoOutput?.alwaysDiscardsLateVideoFrames = false
        
        audioCaptureVideoOutput = AVCaptureAudioDataOutput()
        
        if captureSession.canAddOutput(videoCaptureVideoOutput!) {
            captureSession.addOutput(videoCaptureVideoOutput!)
        }
        
        if captureSession.canAddOutput(audioCaptureVideoOutput!) {
            captureSession.addOutput(audioCaptureVideoOutput!)
        }
        
        captureSession.commitConfiguration()
        
        let videoQueue = DispatchQueue(label: "captureQueue")
        let audioQueue = DispatchQueue(label: "audioQueue")
        
        
        videoCaptureVideoOutput?.setSampleBufferDelegate(self, queue: videoQueue)
        audioCaptureVideoOutput?.setSampleBufferDelegate(self, queue: audioQueue)
    }
}

// MARK: - Input device observers
extension CameraManager {
    private func setupDeviceObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceWasConnected(_:)),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceWasDisconnected(_:)),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }
    
    private func removeDeviceObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleDeviceWasConnected(_ notification: Notification) {
        if let device = notification.object as? AVCaptureDevice {
            print("Device connected: \(device.localizedName)")
            
            showToast("Device connected: \(device.localizedName)")
            
            refreshDeviceLists()
        }
    }
    
    @objc private func handleDeviceWasDisconnected(_ notification: Notification) {
        if let device = notification.object as? AVCaptureDevice {
            print("Device disconnected: \(device.localizedName)")
            
            if selectedAudioCaptureDevice == device {
                selectedAudioCaptureDevice = nil
            }
            
            if selectedVideoCaptureDevice == device {
                selectedVideoCaptureDevice = nil
            }
            
            showToast("Device disconnected: \(device.localizedName)")
            
            refreshDeviceLists()
        }
    }
    
    private func refreshDeviceLists() {
        videoCaptureDeviceList = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .deskViewCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        audioCaptureDeviceList = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified).devices
        
        if selectedAudioCaptureDevice == nil {
            selectedAudioCaptureDevice = audioCaptureDeviceList.first
            switchAudioDeviceInput()
        }
        
        if selectedVideoCaptureDevice == nil {
            selectedVideoCaptureDevice = videoCaptureDeviceList.first
            switchVideoDeviceInput()
        }
    }
}

// MARK: - Toast messages
extension CameraManager {
    func showToast(_ message: String) {
        toastQueue.append(message)
        displayNextToast()
    }
    
    private func displayNextToast() {
        guard !isToastShowing, !toastQueue.isEmpty else { return }
        
        isToastShowing = true
        toastMessage = toastQueue.removeFirst()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isToastShowing = false
            self.displayNextToast()
        }
    }
}

// MARK: - VideoSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureVideoDataOutput {
            captureVideoOutput(didOutput: sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            captureAudioOutput(didOutput: sampleBuffer)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("frame dropped")
    }
    
    private func captureVideoOutput(didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Process image for preview display
        processImage(from: pixelBuffer)
        
        // For recording
        guard isRecording,
              let writer = assetWriter,
              let input = assetWriterInput,
              let adaptor = pixelBufferAdaptor else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
        }
        
        if writer.status == .writing && input.isReadyForMoreMediaData {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let filteredImage = selectedFilter == filtersList.first ? ciImage : ciImage.applyingFilter(selectedFilter)
            
            var newPixelBuffer: CVPixelBuffer?
            
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &newPixelBuffer)
            
            if let newPixelBuffer = newPixelBuffer {
                ciContext.render(filteredImage, to: newPixelBuffer)
                
                adaptor.append(newPixelBuffer, withPresentationTime: timestamp)
            }
        }
    }
    
    private func captureAudioOutput(didOutput sampleBuffer: CMSampleBuffer) {
        guard isRecording,
        let writer = audioAssetWriter,
        let audioInput = audioAssetWriterInput else {
            return
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
        }
        
        if writer.status == .writing && audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        } else {
            print("Writer status: \(writer.status.rawValue), Ready for more data: \(audioInput.isReadyForMoreMediaData)")
        }
    }
    
    private func processImage(from pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let filteredImage = self.selectedFilter == self.filtersList.first ? ciImage : ciImage.applyingFilter(self.selectedFilter)
            
            if let cgImage = self.ciContext.createCGImage(filteredImage, from: filteredImage.extent) {
                DispatchQueue.main.async { [weak self] in
                    self?.currentFrames = cgImage
                }
            }
        }
    }
}

// MARK: - Recording/Stop & Save Actions
extension CameraManager {
    func startRecording() {
        setupVideoAssetWritter()
        
        setupAudioAssetWriter()
    }
    
    private func setupVideoAssetWritter() {
        videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("recorded.mov")
        guard let url = videoURL else { return }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
            
            let outputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080
            ]
            
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            input.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1920,
                kCVPixelBufferHeightKey as String: 1080
            ]
            
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                               sourcePixelBufferAttributes: sourcePixelBufferAttributes)
            
            if let writer = assetWriter, writer.canAdd(input) {
                writer.add(input)
            }
            
            assetWriterInput = input
            pixelBufferAdaptor = adaptor
            isRecording = true
        } catch {
            print("Failed to create writer: \(error)")
        }
    }
    
    private func setupAudioAssetWriter() {
        audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("recorded_audio.m4a")
        guard let url = audioURL else { return }
        
        do {
            audioAssetWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
            
            // Audio output settings (AAC codec, 2 channels, 44.1kHz sample rate)
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000
            ]
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            audioInput.expectsMediaDataInRealTime = true
            
            if let writer = audioAssetWriter, writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
            
            audioAssetWriterInput = audioInput
            isRecording = true
        } catch {
            print("Failed to create audio writer: \(error)")
        }
    }
    
    func stopRecording() {
        isRecording = false
        
        assetWriterInput?.markAsFinished()
        audioAssetWriterInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            self?.audioAssetWriter?.finishWriting { [weak self] in
                
                guard let self = self, let videoURL = self.videoURL, let audioURL = self.audioURL else { return }
                
                print("Video saved to: \(self.videoURL?.path ?? "")")
                print("Audio saved to: \(self.audioURL?.path ?? "")")
                
                DispatchQueue.main.async { [weak self] in
                    self?.promptUserForSaveLocation(from: videoURL, tempAudioURL: audioURL)
                }
            }
        }
    }
}

// MARK: - Save files logic
extension CameraManager {
    private func promptUserForSaveLocation(from tempVideoURL: URL, tempAudioURL: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.movie]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = "Save Recording"
        savePanel.message = "Choose a location to save your video recording"
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = "CameraRecording.mov"
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = downloadsURL
        }
        
        if let window = NSApplication.shared.mainWindow {
            savePanel.beginSheetModal(for: window) { response in
                self.handleSavePanelResponseForVideo(response, savePanel: savePanel, tempVideoURL: tempVideoURL, tempAudioURL: tempAudioURL)
            }
        } else {
            let response = savePanel.runModal()
            self.handleSavePanelResponseForVideo(response, savePanel: savePanel, tempVideoURL: tempVideoURL, tempAudioURL: tempAudioURL)
        }
    }
    
    private func handleSavePanelResponseForVideo(_ response: NSApplication.ModalResponse, savePanel: NSSavePanel, tempVideoURL: URL, tempAudioURL: URL) {
        if response == .OK, let videoDestinationURL = savePanel.url {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if FileManager.default.fileExists(atPath: videoDestinationURL.path) {
                        try FileManager.default.removeItem(at: videoDestinationURL)
                    }
                    
                    try FileManager.default.copyItem(at: tempVideoURL, to: videoDestinationURL)
                    try? FileManager.default.removeItem(at: tempVideoURL)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.promptUserForSaveAudioLocation(from: tempAudioURL)
                    }
                    
                } catch {
                    print("Failed to save video: \(error.localizedDescription)")
                }
            }
        } else {
            DispatchQueue.global(qos: .background).async {
                try? FileManager.default.removeItem(at: tempVideoURL)
            }
        }
    }
    
    private func promptUserForSaveAudioLocation(from tempAudioURL: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.audio]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = "Save Audio Recording"
        savePanel.message = "Choose a location to save your audio recording"
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = "CameraRecording.m4a"
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = downloadsURL
        }
        
        if let window = NSApplication.shared.mainWindow {
            savePanel.beginSheetModal(for: window) { response in
                self.handleSavePanelResponseForAudio(response, savePanel: savePanel, tempAudioURL: tempAudioURL)
            }
        } else {
            let response = savePanel.runModal()
            self.handleSavePanelResponseForAudio(response, savePanel: savePanel, tempAudioURL: tempAudioURL)
        }
    }
    
    private func handleSavePanelResponseForAudio(_ response: NSApplication.ModalResponse, savePanel: NSSavePanel, tempAudioURL: URL) {
        if response == .OK, let audioDestinationURL = savePanel.url {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if FileManager.default.fileExists(atPath: audioDestinationURL.path) {
                        try FileManager.default.removeItem(at: audioDestinationURL)
                    }
                    
                    try FileManager.default.copyItem(at: tempAudioURL, to: audioDestinationURL)
                    try? FileManager.default.removeItem(at: tempAudioURL)
                    
                } catch {
                    print("Failed to save audio: \(error.localizedDescription)")
                }
            }
        } else {
            DispatchQueue.global(qos: .background).async {
                try? FileManager.default.removeItem(at: tempAudioURL)
            }
        }
    }
}

// MARK: - Permissions check
extension CameraManager {
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraPermissionIsGranted = true
            print("Camera access granted")
            self.setUpCaptureSession()
            
        case .notDetermined:
            print("Camera access not determined")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionIsGranted = granted
                    if granted {
                        print("Camera access granted")
                        self?.setUpCaptureSession()
                    } else {
                        print("Camera access denied")
                    }
                }
            }
            
        case .denied:
            print("Camera access denied")
            self.cameraPermissionIsGranted = false
            
        case .restricted:
            print("Camera access restricted")
            self.cameraPermissionIsGranted = false
            
        @unknown default:
            fatalError("Unknown authorization status")
        }
    }
}
