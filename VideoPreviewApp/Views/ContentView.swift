//
//  ContentView.swift
//  VideoPreviewApp
//
//  Created by Ihor on 04/04/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        VStack {
            
            cameraPicker
            
            audioPicker
            
            filterPicker
            
            if cameraManager.cameraPermissionIsGranted {
                cameraPreview
            }
            
            HStack {
                startButton
                
                stopButton
                
                Button(cameraManager.isRecording ? "Stop" : "Record") {
                    cameraManager.isRecording ? cameraManager.stopRecording() : cameraManager.startRecording()
                }
            }
        }
        .toast(message: cameraManager.toastMessage)
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            cameraManager.checkAuthorization()
        }
    }
}

// MARK: - Views
extension ContentView {
    private var cameraPicker: some View {
        HStack {
            Text("Select camera:")
            
            Menu {
                ForEach(cameraManager.videoCaptureDeviceList, id: \.self) { item in
                    
                    Button {
                        cameraManager.selectedVideoCaptureDevice = item
                        cameraManager.switchVideoDeviceInput()
                    } label: {
                        HStack {
                            if cameraManager.selectedVideoCaptureDevice == item {
                                Image(systemName: "checkmark")
                            }
                            
                            Text(item.localizedName)
                        }
                    }
                }
            } label: {
                Text(cameraManager.selectedVideoCaptureDevice?.localizedName ?? "")
            }
        }
    }
    
    private var audioPicker: some View {
        HStack {
            Text("Select audio:")
            
            Menu {
                ForEach(cameraManager.audioCaptureDeviceList, id: \.self) { item in
                    
                    Button {
                        cameraManager.selectedAudioCaptureDevice = item
                        cameraManager.switchAudioDeviceInput()
                    } label: {
                        HStack {
                            if cameraManager.selectedAudioCaptureDevice == item {
                                Image(systemName: "checkmark")
                            }
                            
                            Text(item.localizedName)
                        }
                    }
                }
            } label: {
                Text(cameraManager.selectedAudioCaptureDevice?.localizedName ?? "")
            }
        }
    }
    
    private var filterPicker: some View {
        HStack {
            Text("Select filter:")
            
            Menu {
                ForEach(cameraManager.filtersList, id: \.self) { item in
                    Button {
                        cameraManager.selectedFilter = item
                    } label: {
                        HStack {
                            if cameraManager.selectedFilter == item {
                                Image(systemName: "checkmark")
                            }
                            
                            Text(item)
                        }
                    }
                }
            } label: {
                Text(cameraManager.selectedFilter)
            }
        }
    }
    
    private var cameraPreview: some View {
        FrameView(image: cameraManager.currentFrames)
    }
    
    private var startButton: some View {
        Button("Enable Camera") {
            cameraManager.enableCamera()
        }
    }
    
    private var stopButton: some View {
        Button("Disable Camera") {
            cameraManager.disableCamera()
        }
    }
}

#Preview {
    ContentView()
}
