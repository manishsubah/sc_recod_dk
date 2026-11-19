import CoreMedia

/// Wraps mixed 48 kHz interleaved stereo Float32 samples in CMSampleBuffers for AVAssetWriter.
enum AudioSampleBuffers {
  private static let format: CMAudioFormatDescription? = {
    var asbd = AudioStreamBasicDescription(
      mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8,
      mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    var description: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(
      allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
      magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
    return description
  }()

  static func make(_ samples: [Float], presentationTime: CMTime) -> CMSampleBuffer? {
    guard let format, !samples.isEmpty else { return nil }
    let byteCount = samples.count * MemoryLayout<Float>.size

    var block: CMBlockBuffer?
    guard
      CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
        blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
        dataLength: byteCount, flags: kCMBlockBufferAssureMemoryNowFlag,
        blockBufferOut: &block) == noErr,
      let block
    else { return nil }

    let copied = samples.withUnsafeBytes { bytes in
      CMBlockBufferReplaceDataBytes(
        with: bytes.baseAddress!, blockBuffer: block, offsetIntoDestination: 0,
        dataLength: byteCount)
    }
    guard copied == noErr else { return nil }

    var sampleBuffer: CMSampleBuffer?
    guard
      CMAudioSampleBufferCreateReadyWithPacketDescriptions(
        allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
        sampleCount: samples.count / AudioMixer.channels,
        presentationTimeStamp: presentationTime, packetDescriptions: nil,
        sampleBufferOut: &sampleBuffer) == noErr
    else { return nil }
    return sampleBuffer
  }
}
