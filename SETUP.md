# Quick Setup Guide

## Build & Run

1. **Open in Xcode**:
   ```bash
   open Constellation.xcodeproj
   ```

2. **Add Microphone Permission**:
   Go to project settings → Constellation target → Info → Custom iOS Target Properties
   Add this key-value pair:
   - Key: `NSMicrophoneUsageDescription`
   - Value: `This app uses the microphone to create real-time audio visualizations.`

3. **Build and Run**:
   - Select iPhone or iPad simulator/device
   - Press Cmd+R to build and run
   - Grant microphone permission when prompted

## Testing the App

1. **Launch** and grant microphone permission
2. **Tap the green microphone button** to start recording
3. **Play music or make sounds** - you'll see star constellations appear
4. **Watch the visualization** - peaks fade over 3 seconds creating beautiful trails

## File Structure Created

- **`AudioProcessor.swift`** - AVAudioEngine + FFT processing
- **`PeakFinder.swift`** - Peak detection algorithms
- **`ConstellationRenderer.swift`** - Metal rendering engine
- **`ContentView.swift`** - Main SwiftUI interface (renamed to AudioVisualizerView)
- **`ConstellationApp.swift`** - App entry point (renamed to AudioVisualizerApp)

## Technical Features

✅ **Real-time audio processing** with AVAudioEngine  
✅ **High-performance FFT** using Accelerate framework  
✅ **Smart peak detection** with local maxima algorithms  
✅ **Metal rendering** for 60fps star constellation visualization  
✅ **Thread-safe architecture** with @MainActor and proper async handling  
✅ **Modular design** with clean separation of concerns  

The visualization shows frequency peaks as colored stars that fade over time, creating beautiful constellation patterns inspired by Shazam's audio fingerprinting approach. 