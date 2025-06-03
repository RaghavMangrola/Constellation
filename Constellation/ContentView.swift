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
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Audio Constellation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Real-time audio fingerprint visualization")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Inspired by Shazam's star constellation approach")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                        .italic()
                }
                .padding(.top, 20)
                
                // Metal constellation view
                if hasPermission && isInitialized {
                    ConstellationMetalView(renderer: renderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                } else {
                    // Placeholder view
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        VStack(spacing: 16) {
                            Image(systemName: permissionStatus == .denied ? "mic.slash.circle" : "waveform.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.6))
                            
                            switch permissionStatus {
                            case .undetermined:
                                Text("Microphone access needed")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Tap below to enable microphone access and start visualizing audio")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button("Enable Microphone") {
                                    requestMicrophonePermission()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                
                            case .denied:
                                Text("Microphone access denied")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Please enable microphone access in Settings to visualize audio as star constellations")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button("Open Settings") {
                                    openSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                
                            case .granted:
                                Text("Initializing...")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.white)
                                
                            @unknown default:
                                Text("Unknown permission state")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Controls
                HStack(spacing: 30) {
                    // Record button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(audioProcessor.isRecording ? Color.red : Color.green)
                                .frame(width: 80, height: 80)
                                .scaleEffect(audioProcessor.isRecording ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: audioProcessor.isRecording)
                            
                            Image(systemName: audioProcessor.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(!hasPermission)
                    .opacity(hasPermission ? 1.0 : 0.5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(audioProcessor.isRecording ? "Recording..." : hasPermission ? "Tap to start" : "Enable microphone first")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if audioProcessor.isRecording {
                            Text("Peaks: \(peakFinder.currentPeaks.count)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("Constellation: \(peakFinder.constellation.count)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if hasPermission {
                            Text("Listen to music or make sounds")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("Microphone permission required")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            setupComponents()
            checkMicrophonePermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Check permission status when app returns to foreground
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
