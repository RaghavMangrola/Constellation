# Quick Setup Guide

## Prerequisites

- iOS 15.0+ / iPadOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- Metal-compatible device (A7+ processor)

## Build & Run

1. **Open in Xcode**:
   ```bash
   open Constellation.xcodeproj
   ```

2. **Microphone Permission** (Already Configured):
   The project is pre-configured with microphone permission. The `NSMicrophoneUsageDescription` is already set in the Xcode project settings with the description:
   > "This app uses the microphone to create real-time audio visualizations showing frequency patterns as star constellations, similar to how audio fingerprinting works in apps like Shazam."

3. **Build and Run**:
   - Select your target iPhone or iPad (simulator or physical device)
   - Press Cmd+R to build and run
   - Grant microphone permission when prompted on first launch

## Testing the App

1. **Launch the app** and grant microphone permission when prompted
2. **Audio recording starts automatically** once permission is granted
3. **Play music, sing, or make sounds** - you'll see star constellations appear in real-time
4. **Watch the visualization** - frequency peaks appear as colored stars that fade over 3 seconds
5. **Observe the patterns** - different sounds create unique constellation patterns

### Understanding the Visualization

- **Colors**: Blue (high frequencies) → Yellow → Orange → Red (low frequencies)
- **Position**: Horizontal = frequency, Vertical = amplitude/volume
- **Size**: Larger stars = stronger/louder peaks
- **Animation**: Stars fade over 3 seconds, creating beautiful constellation trails

## Project Structure

The app consists of these main components:

- **`ConstellationApp.swift`** - Main app entry point and lifecycle management
- **`ContentView.swift`** - SwiftUI interface with AudioVisualizerView
- **`AudioProcessor.swift`** - Real-time audio processing with AVAudioEngine and FFT
- **`PeakFinder.swift`** - Advanced peak detection algorithms for constellation mapping
- **`ConstellationRenderer.swift`** - High-performance Metal rendering engine
- **`AudioConstants.swift`** - Centralized configuration and constants
- **`ConstellationShaders.metal`** - Custom Metal shaders for star visualization

## Technical Features

✅ **Real-time audio processing** with AVAudioEngine at 48kHz  
✅ **High-performance FFT** using Apple's Accelerate framework  
✅ **Smart peak detection** with local maxima and adaptive thresholding  
✅ **Metal rendering** for smooth 60fps star constellation visualization  
✅ **Thread-safe architecture** with @MainActor and proper async handling  
✅ **Modular design** with clean separation of concerns  
✅ **Centralized configuration** via AudioConstants for easy customization  

## Customization

Key parameters can be adjusted in `AudioConstants.swift`:

### Audio Processing
- **Sample Rate**: 48000 Hz (matches modern iOS hardware)
- **Buffer Size**: 4096 samples for FFT processing
- **Format**: Mono Float32 for optimal performance

### Peak Detection
- **Threshold**: -60dB minimum peak height
- **Distance**: 5 bins minimum between peaks
- **Count**: Maximum 10 peaks per frame
- **Fade Time**: 3 seconds for constellation persistence

### Visualization
- **Max Stars**: 1000 rendered simultaneously
- **Star Size**: 0.01 to 0.03 normalized units
- **Color Mapping**: Frequency-based color palette

## Troubleshooting

### Common Issues

1. **No microphone permission**: 
   - Check Settings → Privacy & Security → Microphone → Constellation
   - Ensure the app has microphone access enabled

2. **No stars appearing**: 
   - Ensure audio input is loud enough (above -60dB)
   - Try speaking loudly or playing music
   - Check that microphone is not muted

3. **Performance issues**: 
   - Reduce `maxStars` in AudioConstants.Visualization
   - Lower `bufferSize` in AudioConstants.Format
   - Close other apps that might be using audio resources

4. **Format mismatch warnings**:
   - The app automatically adapts to hardware sample rate
   - Warnings are logged but don't affect functionality

### Debug Information

The app displays real-time statistics in the bottom-right corner:
- **Recording status**: Red "Recording" indicator when active
- **Peaks**: Current number of peaks detected in this frame
- **Constellation**: Total number of stars currently visible

For detailed debugging information, see `docs/debugging.md`.

## Next Steps

Once you have the app running:

1. **Experiment with different audio sources** - music, voice, instruments
2. **Observe how different sounds create different constellation patterns**
3. **Try the customization options** in AudioConstants.swift
4. **Explore the documentation** in the `docs/` directory for technical details

The visualization demonstrates the core concepts behind audio fingerprinting technology like Shazam uses - each unique audio input creates a distinctive pattern of frequency peaks that form a "constellation" in frequency-time space. 