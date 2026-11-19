import AVFoundation

/// Converts one source's CMSampleBuffers to 48 kHz interleaved stereo Float32.
/// Keeps a resampler per source so rate conversion stays continuous. One queue only.
final class AudioNormalizer {
  static let sampleRate: Double = 48_000

  private var inputFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var converterOutput: AVAudioFormat?

  /// Returns interleaved stereo samples, or nil for buffers that aren't PCM.
  func convert(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
    guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
    let format = AVAudioFormat(cmAudioFormatDescription: description)
    let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
    guard frames > 0, let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
    else { return nil }
    input.frameLength = frames
    guard
      CMSampleBufferCopyPCMDataIntoAudioBufferList(
        sampleBuffer, at: 0, frameCount: Int32(frames), into: input.mutableAudioBufferList)
        == noErr
    else { return nil }
    return convert(input)
  }

  func convert(_ input: AVAudioPCMBuffer) -> [Float]? {
    let format = input.format
    let channels = min(format.channelCount, 2)
    let ready =
      format.commonFormat == .pcmFormatFloat32 && format.sampleRate == Self.sampleRate
      && format.channelCount <= 2

    let buffer: AVAudioPCMBuffer
    if ready {
      buffer = input
    } else {
      guard let converted = resample(input, channels: channels) else { return nil }
      buffer = converted
    }
    return Self.interleavedStereo(buffer)
  }

  /// Converts sample rate/format, keeping 1 or 2 channels (more are downmixed to 2).
  private func resample(_ input: AVAudioPCMBuffer, channels: AVAudioChannelCount)
    -> AVAudioPCMBuffer?
  {
    if converter == nil || inputFormat != input.format {
      guard
        let output = AVAudioFormat(
          commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: channels,
          interleaved: false),
        let newConverter = AVAudioConverter(from: input.format, to: output)
      else { return nil }
      newConverter.downmix = input.format.channelCount > 2
      converter = newConverter
      converterOutput = output
      inputFormat = input.format
    }
    guard let converter, let converterOutput else { return nil }

    let ratio = Self.sampleRate / input.format.sampleRate
    let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 64
    guard let output = AVAudioPCMBuffer(pcmFormat: converterOutput, frameCapacity: capacity)
    else { return nil }

    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return input
    }
    guard status != .error, error == nil else { return nil }
    return output
  }

  /// Float32 buffer (interleaved or not, 1–2 channels) to interleaved stereo; mono is duplicated.
  private static func interleavedStereo(_ buffer: AVAudioPCMBuffer) -> [Float]? {
    guard let data = buffer.floatChannelData else { return nil }
    let frames = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)
    var out = [Float](repeating: 0, count: frames * 2)

    if buffer.format.isInterleaved {
      let samples = data[0]
      for f in 0..<frames {
        let left = samples[f * channels]
        out[f * 2] = left
        out[f * 2 + 1] = channels > 1 ? samples[f * channels + 1] : left
      }
    } else {
      let left = data[0]
      let right = channels > 1 ? data[1] : data[0]
      for f in 0..<frames {
        out[f * 2] = left[f]
        out[f * 2 + 1] = right[f]
      }
    }
    return out
  }
}
