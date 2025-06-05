# Audio Constellation Visualizer

A real-time audio visualization iOS/iPadOS app that creates star constellation displays from audio input, inspired by Shazam's audio fingerprinting approach. The app uses advanced signal processing and high-performance Metal rendering to visualize audio frequency peaks as beautiful, animated star constellations.

## Overview

This app demonstrates the concept behind audio fingerprinting by visualizing frequency-time peaks as star constellations. Just like Shazam identifies music by creating a "constellation map" of audio peaks, this app shows you that constellation in real-time as beautiful, fading star patterns.

## Features

- **Real-time Audio Processing**: Uses AVAudioEngine for low-latency microphone input
- **High-Performance FFT**: Leverages Apple's Accelerate framework for efficient frequency analysis
- **Smart Peak Detection**: Advanced algorithms to identify local maxima in frequency spectrum
- **Metal Rendering**: GPU-accelerated star constellation visualization with fade effects
- **Thread-Safe Architecture**: Proper use of @MainActor and async updates for smooth performance
- **Modular Design**: Clean separation of concerns across dedicated components

## Architecture

The app is built with a modular architecture following best practices:

### Core Components

1. **AudioProcessor.swift** - Handles microphone input and FFT analysis
   - AVAudioEngine setup and audio session management
   - Real-time FFT processing using Accelerate framework
   - Windowing and magnitude spectrum calculation
   - Thread-safe data passing to peak detection

2. **PeakFinder.swift** - Extracts frequency peaks for constellation mapping
   - Local maxima detection with configurable parameters
   - Adaptive thresholding based on local noise floor
   - Time-based peak management with fade effects
   - Fingerprint-ready peak extraction

3. **ConstellationRenderer.swift** - Metal-based high-performance rendering
   - Custom Metal shaders for star-like point rendering
   - Real-time vertex buffer updates
   - Color-coded frequency mapping (low=red, high=blue)
   - Smooth animations and particle effects

4. **ConstellationApp.swift** - Main app entry point and SwiftUI coordination
   - App lifecycle management
   - Component initialization and wiring

5. **ContentView.swift** - Main SwiftUI interface (AudioVisualizerView)
   - Permission handling and UI coordination
   - Thread-safe component wiring
   - Real-time statistics display

6. **AudioConstants.swift** - Centralized configuration and constants
   - Audio format and processing parameters
   - Peak detection thresholds and settings
   - Visualization configuration constants

7. **ConstellationShaders.metal** - Custom Metal shaders
   - Vertex and fragment shaders for star rendering
   - Distance field effects and color mapping

## Technical Implementation

### Audio Processing Pipeline

1. **Microphone Input**: 48 kHz, mono, 4096-sample buffers
2. **Windowing**: Hann window for better frequency resolution
3. **FFT**: Real-to-complex FFT using vDSP
4. **Magnitude**: Logarithmic scale (dB) conversion
5. **Peak Detection**: Local maxima with minimum distance constraints

### Peak Detection Algorithm

The peak finder uses several sophisticated techniques:

- **Local Maxima**: Sliding window comparison with configurable distance
- **Adaptive Thresholding**: Dynamic threshold based on local noise floor
- **Magnitude Filtering**: Only peaks above -60dB threshold
- **Frequency Limiting**: Focus on human-audible range (300Hz - 8kHz)
- **Temporal Management**: 3-second fade with constellation history

### Metal Rendering

Custom shaders create star-like visualizations:

- **Vertex Shader**: Position mapping and pulsing effects
- **Fragment Shader**: Distance field star shapes with glow
- **Color Mapping**: Frequency-based color palette
- **Alpha Blending**: Smooth fade effects for aging peaks

## Requirements

- iOS 15.0+ / iPadOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- Metal-compatible device (A7+ processor)
- Microphone access permission

## Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/Constellation.git
   cd Constellation
   ```

2. **Open in Xcode**:
   ```bash
   open Constellation.xcodeproj
   ```

3. **Microphone Permission** (Already Configured):
   The project is already configured with microphone permission. The `NSMicrophoneUsageDescription` is set to:
   > "This app uses the microphone to create real-time audio visualizations showing frequency patterns as star constellations, similar to how audio fingerprinting works in apps like Shazam."

4. **Build and Run**:
   - Select your target device or simulator
   - Press Cmd+R to build and run
   - Grant microphone permission when prompted

## Usage

1. **Launch the app** and grant microphone permission when prompted
2. **Audio recording starts automatically** once permission is granted
3. **Play music or make sounds** - you'll see star constellations appear
4. **Watch the patterns** - peaks fade over 3 seconds creating beautiful trails
5. **Observe the colors** - different frequencies show as different colors

### Understanding the Visualization

- **X-axis (horizontal)**: Frequency (logarithmic scale, low to high)
- **Y-axis (vertical)**: Magnitude/Volume (dB scale)
- **Colors**: Blue (high freq) → Yellow → Orange → Red (low freq)
- **Size**: Larger stars = louder/stronger peaks
- **Fading**: Stars fade over 3 seconds, creating constellation trails

## How It Relates to Shazam

This visualization demonstrates the core concept behind Shazam's audio fingerprinting:

1. **Audio → FFT**: Convert audio to frequency spectrum
2. **Peak Extraction**: Find prominent frequency peaks
3. **Constellation Mapping**: Plot peaks in frequency-time space
4. **Pattern Matching**: Compare constellations (not implemented here)

The "stars" you see are the same type of frequency peaks that Shazam uses to identify songs. Each song creates a unique constellation pattern that can be matched against a database.

## Performance Considerations

- **Real-time Processing**: ~85ms latency (4096 samples at 48kHz)
- **Memory Efficient**: Fixed-size buffers with circular management
- **GPU Rendering**: Metal handles 1000+ stars at 60fps
- **Battery Optimized**: Efficient algorithms and minimal allocations

## Customization

Key parameters you can adjust in `AudioConstants.swift`:

### Audio Processing
```swift
// Format configuration
static let defaultSampleRate: Double = 48000.0
static let bufferSize: Int = 4096
```

### Peak Detection
```swift
// Peak detection thresholds
static let minPeakHeight: Float = -60.0      // dB threshold
static let minPeakDistance: Int = 5          // Min bins between peaks
static let maxPeaksPerFrame: Int = 10        // Peaks per analysis
static let peakFadeTime: Double = 3.0        // Fade duration
```

### Visual Effects
```swift
// Visualization settings
static let maxStars: Int = 1000              // Max rendered stars
static let minStarSize: Float = 0.01         // Minimum star size
static let maxStarSize: Float = 0.03         // Maximum star size
```

## Project Structure

```
Constellation/
├── ConstellationApp.swift          # App entry point
├── ContentView.swift               # Main SwiftUI interface
├── AudioProcessor.swift            # Real-time audio processing
├── PeakFinder.swift               # Peak detection algorithms
├── ConstellationRenderer.swift    # Metal rendering engine
├── AudioConstants.swift           # Configuration constants
├── ConstellationShaders.metal     # Metal shaders
└── Assets.xcassets/               # App assets
```

## Troubleshooting

### Common Issues

1. **No microphone permission**: Check Settings → Privacy & Security → Microphone
2. **No stars appearing**: Ensure audio is loud enough (>-60dB)
3. **Performance issues**: Reduce `maxStars` or `bufferSize` in AudioConstants
4. **Metal not supported**: Requires A7+ processor (iPhone 5s+)
5. **Format mismatch warnings**: Check that sample rate matches hardware (48kHz default)

### Debug Information

The app displays real-time statistics in the bottom-right corner:
- **Recording status**: Shows when actively recording
- **Peaks**: Current frame peak count
- **Constellation**: Total stars in current constellation

For detailed debugging, see `docs/debugging.md` for structured logging information.

## Contributing

Contributions are welcome! Areas for improvement:

- [ ] Additional peak detection algorithms
- [ ] Configurable color palettes
- [ ] Export constellation patterns
- [ ] Audio file input support
- [ ] Pattern matching/recognition features

## Documentation

Additional documentation is available in the `docs/` directory:
- `debugging.md` - Structured logging and debugging guide
- `audio-context.md` - Audio processing implementation notes
- `metal-context.md` - Metal rendering implementation details
- `shader-context.md` - Custom shader documentation
- `improvement-tasks.md` - Project improvement tracking

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Inspired by Shazam's audio fingerprinting technology
- Built with Apple's Accelerate and Metal frameworks
- Uses modern SwiftUI and Combine patterns

---

**Note**: This is an educational/demonstration project showing audio fingerprinting concepts. It's not intended for commercial music recognition use. 