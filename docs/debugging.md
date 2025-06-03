# Debugging Guide for Constellation

## Structured Logging System

### Subsystems and Categories
The app uses structured logging via `os.log` with the following organization:

1. Audio Processing (`com.constellation.audio`)
   - Category: `AudioProcessor`
     - Audio session initialization
     - Buffer processing status
     - Input/output configuration
   - Category: `PeakFinder`
     - Peak detection statistics
     - Constellation management
     - Peak cleanup and history

2. Graphics (`com.constellation.graphics`)
   - Category: `Renderer`
     - Metal setup and validation
     - Vertex buffer updates
     - Frame rendering statistics
     - Resource management

### Log Levels
- `error`: Critical failures (Metal setup, audio session failures)
- `info`: Important state changes and initialization
- `debug`: General processing information and statistics
- `trace`: Detailed per-vertex/peak data

### Viewing Logs

#### System-Level Logging
To view system-level logs from a physical iOS device:

```bash
# Install libimobiledevice
brew install libimobiledevice

# View device logs filtered for Constellation app
idevicesyslog | grep -i "Constellation"
```

#### Filtered Logging Examples
```bash
# View all Constellation logs
xcrun simctl spawn booted log stream --predicate 'subsystem contains "com.constellation"'

# View only audio processing logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.constellation.audio"'

# View only error logs
xcrun simctl spawn booted log stream --predicate 'subsystem contains "com.constellation" AND level == "error"'

# View specific category logs
xcrun simctl spawn booted log stream --predicate 'category == "PeakFinder"'
```

### App-Specific Logging
For simulator debugging:
```bash
xcrun simctl spawn booted log stream --predicate 'process == "Constellation"' --level debug
```

Note: This command only works with the iOS Simulator, not physical devices.

### Debug Log Categories

The app includes detailed logging for the following components:

1. Audio Processing
   - Audio input levels
   - FFT spectrum analysis
   - Buffer processing status
   - Peak detection statistics
   - Constellation management

2. Peak Detection
   - Peak frequencies
   - Amplitude thresholds
   - Constellation point generation
   - History management
   - Cleanup operations

3. Metal Rendering
   - Shader compilation
   - Vertex buffer updates
   - Frame rendering stats
   - Resource allocation
   - Drawing operations

### Common Issues

1. Audio Session Setup
   - Check logs for "AVAudioSession" entries
   - Verify microphone permissions
   - Monitor audio input/output configuration

2. Metal Validation
   - Look for "Metal API Validation" messages
   - Check shader compilation errors
   - Monitor vertex buffer updates

3. Performance
   - Watch for "Performance Diagnostics" messages
   - Monitor main thread I/O operations
   - Check for interprocess communication delays

### Best Practices

1. Always check both system and app-specific logs
2. Filter logs based on specific components when debugging
3. Pay attention to initialization sequences
4. Monitor audio session state changes
5. Watch for Metal validation warnings
6. Use appropriate log levels for different types of information
7. Include relevant context in log messages

### Xcode Integration

For more detailed debugging:
1. Open project in Xcode
2. Use Window > Devices and Simulators
3. Select your device
4. Click "Open Console" to view real-time logs 