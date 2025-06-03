# Audio Context and Debugging Notes

## Format Mismatch Issue (2024-03-XX)

### Error Description
```
AVAudioIONodeImpl.mm:1334  Format mismatch: input hw <AVAudioFormat 0x114d7d630:  1 ch,  48000 Hz, Float32>, client format <AVAudioFormat 0x1141dc7d0:  1 ch,  44100 Hz, Float32>
```

### Analysis
- **Hardware Format**: 48000 Hz (48 kHz), 1 channel, Float32
- **Client Format**: 44100 Hz (44.1 kHz), 1 channel, Float32
- **Issue**: The app is attempting to use 44.1 kHz while the hardware is running at 48 kHz

### Found Issues
1. Hardcoded 44.1 kHz sample rate in multiple files:
   - `AudioProcessor.swift`: Initial `sampleRate` value
   - `PeakFinder.swift`: Fallback calculations using 44.1 kHz
   - `README.md`: Documentation showing 44.1 kHz

### Fix Implementation Status
1. Updated `AudioProcessor.swift`:
   - Changed default `sampleRate` to 48000 Hz ✅
   - Added more debug logging ✅
   - Ensure hardware format is used consistently ✅
   - Double-check sample rate after getting hardware format ✅

2. Updated `PeakFinder.swift`:
   - Removed hardcoded 44.1 kHz references ✅
   - Use actual sample rate from AudioProcessor ✅
   - Default to 48 kHz if AudioProcessor is not available ✅

3. Added detailed logging:
   ```swift
   print("Hardware sample rate: \(sampleRate) Hz")
   print("Hardware format: \(hardwareFormat)")
   ```

### Remaining Issue
The format mismatch persists despite our changes. This suggests there might be another place where the format is being set, possibly:

1. In the AVAudioEngine configuration
2. In the audio session setup
3. In a format conversion node we haven't found
4. In the way the tap is being installed

### Next Steps
1. Add more debug logging in `AudioProcessor.swift`:
   ```swift
   // In setupAudioSession
   print("Audio session category: \(audioSession.category)")
   print("Audio session mode: \(audioSession.mode)")
   print("Audio session sample rate: \(audioSession.sampleRate)")
   
   // In startRecording
   print("Input node format: \(inputNode.inputFormat(forBus: 0))")
   print("Output node format: \(inputNode.outputFormat(forBus: 0))")
   ```

2. Check if there are any format converters in the audio processing chain:
   - Look for instances of `AVAudioConverter`
   - Check for any format conversion nodes
   - Verify all connections in the audio engine

3. Consider forcing the hardware format:
   ```swift
   try audioSession.setPreferredSampleRate(48000)
   ```

4. Update documentation in README.md to reflect the actual sample rate being used

### References
- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html)
- [AVAudioConverter Documentation](https://developer.apple.com/documentation/avfaudio/avaudioconverter) 