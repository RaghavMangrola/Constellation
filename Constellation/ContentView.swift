//
//  AudioVisualizerView.swift
//  Constellation
//
//  Main view integrating audio processing and constellation visualization
//  Thread-safe UI updates using @MainActor and proper state management
//

import SwiftUI
import AVFoundation

struct AudioVisualizerView: View {
    @StateObject private var audioProcessor = AudioProcessor()
    @StateObject private var peakFinder = PeakFinder()
    @StateObject private var renderer = ConstellationRenderer()
    
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    @State private var showingPermissionAlert = false
    @State private var isInitialized = false
    
    private var hasPermission: Bool {
        permissionStatus == .granted
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main constellation view
            if hasPermission && isInitialized {
                ConstellationMetalView(renderer: renderer)
                    .ignoresSafeArea()
                    .overlay(alignment: .bottomTrailing) {
                        // Status overlay
                        VStack(alignment: .trailing, spacing: 4) {
                            if audioProcessor.isRecording {
                                Text("Recording")
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(.red.opacity(0.6))
                                    .cornerRadius(6)
                                
                                Text("Peaks: \(peakFinder.currentPeaks.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text("Constellation: \(peakFinder.constellation.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                    }
            } else {
                // Minimal permission overlay
                VStack(spacing: 16) {
                    Image(systemName: permissionStatus == .denied ? "mic.slash.circle" : "waveform.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if permissionStatus == .undetermined {
                        Button("Enable Microphone") {
                            requestMicrophonePermission()
                        }
                        .buttonStyle(.borderedProminent)
                    } else if permissionStatus == .denied {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onAppear {
            setupComponents()
            checkMicrophonePermission()
        }
        .onChange(of: permissionStatus) { newValue in
            if newValue == .granted {
                // Auto-start recording when permission is granted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioProcessor.startRecording()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkMicrophonePermission()
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This app requires microphone access to create audio visualizations. Please enable microphone access in Settings.")
        }
    }
    
    @MainActor
    private func setupComponents() {
        // Wire up component references (thread-safe)
        audioProcessor.peakFinder = peakFinder
        peakFinder.audioProcessor = audioProcessor
        renderer.peakFinder = peakFinder
        
        isInitialized = true
    }
    
    @MainActor
    private func toggleRecording() {
        guard hasPermission else {
            showingPermissionAlert = true
            return
        }
        
        if audioProcessor.isRecording {
            audioProcessor.stopRecording()
        } else {
            audioProcessor.startRecording()
        }
    }
    
    private func checkMicrophonePermission() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [self] granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .granted : .denied
                if !granted {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Preview

#Preview {
    AudioVisualizerView()
}
