#!/usr/bin/env swift
// Convert Godot's MJPEG + signed PCM AVI directly to H.264/AAC MP4 using macOS.
// This reads the original RIFF chunks without repairing or modifying the AVI.
// Usage: swift -module-cache-path work/swift-cache tools/video_encode.swift input.avi output.mp4
import Foundation
import AVFoundation
import AudioToolbox
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

enum EncodeError: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case .message(let text): return text } }
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw EncodeError.message(message) }
}
let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Usage: video_encode.swift input.avi output.mp4\n", stderr)
    exit(2)
}
let sourceURL = URL(fileURLWithPath: args[1]).standardizedFileURL
let outputURL = URL(fileURLWithPath: args[2]).standardizedFileURL

do {
    let bytes = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
    func tag(_ offset: Int) -> String {
        guard offset >= 0, offset + 4 <= bytes.count else { return "" }
        return String(data: bytes.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
    }
    func u16(_ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset+1]) << 8
    }
    func u32(_ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset+1]) << 8 | Int(bytes[offset+2]) << 16 | Int(bytes[offset+3]) << 24
    }
    try require(tag(0) == "RIFF" && tag(8) == "AVI ", "Expected a RIFF AVI input.")
    var width = 0
    var height = 0
    var fpsScale = 1
    var fpsRate = 60
    var channels = 2
    var sampleRate = 48000
    var bitsPerSample = 16
    var videos: [Range<Int>] = []
    var audios: [Range<Int>] = []
    func visit(_ start: Int, _ end: Int, _ streamType: String = "") throws {
        var offset = start
        var type = streamType
        while offset + 8 <= end {
            let kind = tag(offset)
            let size = u32(offset + 4)
            let payload = offset + 8
            try require(size >= 0 && payload + size <= end, "Malformed AVI chunk at \(offset).")
            if kind == "LIST" || kind == "RIFF" {
                try require(size >= 4, "Empty RIFF list.")
                try visit(payload + 4, payload + size)
            } else if kind == "strh" && size >= 32 {
                type = tag(payload)
                if type == "vids" {
                    try require(tag(payload + 4) == "MJPG", "Only Godot's MJPG video is supported.")
                    fpsScale = u32(payload + 20)
                    fpsRate = u32(payload + 24)
                }
            } else if kind == "strf" {
                if type == "vids" && size >= 40 {
                    width = u32(payload + 4)
                    height = u32(payload + 8)
                } else if type == "auds" && size >= 16 {
                    try require(u16(payload) == 1, "AVI audio must be uncompressed PCM.")
                    channels = u16(payload + 2)
                    sampleRate = u32(payload + 4)
                    bitsPerSample = u16(payload + 14)
                }
            } else if kind.hasSuffix("db") || kind.hasSuffix("dc") {
                videos.append(payload..<payload+size)
            } else if kind.hasSuffix("wb") {
                audios.append(payload..<payload+size)
            }
            offset = payload + size + (size & 1)
        }
    }
    try visit(12, bytes.count)
    try require(width > 0 && height > 0 && fpsScale > 0 && fpsRate > 0 && !videos.isEmpty, "Missing AVI video description or frames.")
    try require(channels == 2 && bitsPerSample == 16 && !audios.isEmpty, "Expected stereo signed 16-bit PCM audio.")
    let bytesPerFrame = channels * bitsPerSample / 8
    let pcmFrames = audios.reduce(0) { $0 + $1.count / bytesPerFrame }
    let fps = Double(fpsRate) / Double(fpsScale)
    print("SOURCE \(width)x\(height), \(videos.count) frames at \(fps) FPS, \(pcmFrames) PCM frames at \(sampleRate) Hz")
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try require(!FileManager.default.fileExists(atPath: outputURL.path), "Output already exists; choose a fresh path or remove the previous generated output explicitly.")
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 10_000_000,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoAllowFrameReorderingKey: false,
        ],
    ])
    videoInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
    ])
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: channels,
        AVEncoderBitRateKey: 192_000,
    ])
    audioInput.expectsMediaDataInRealTime = false
    let canVideo = writer.canAdd(videoInput)
    let canAudio = writer.canAdd(audioInput)
    try require(canVideo && canAudio, "AVAssetWriter rejected inputs: video=\(canVideo), audio=\(canAudio), error=\(String(describing: writer.error)).")
    writer.add(videoInput)
    writer.add(audioInput)
    try require(writer.startWriting(), "Unable to start MP4 writer: \(String(describing: writer.error))")
    writer.startSession(atSourceTime: .zero)
    var asbd = AudioStreamBasicDescription(mSampleRate: Double(sampleRate), mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: UInt32(bytesPerFrame), mFramesPerPacket: 1, mBytesPerFrame: UInt32(bytesPerFrame),
        mChannelsPerFrame: UInt32(channels), mBitsPerChannel: UInt32(bitsPerSample), mReserved: 0)
    var audioFormat: CMAudioFormatDescription?
    try require(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd,
        layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil,
        formatDescriptionOut: &audioFormat) == noErr, "Unable to describe PCM input.")

    let group = DispatchGroup()
    let stateLock = NSLock()
    var failure: String?
    func fail(_ text: String) {
        stateLock.lock()
        if failure == nil { failure = text }
        stateLock.unlock()
    }
    var videoIndex = 0
    var videoDone = false
    group.enter()
    videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "stormwright.video.encode")) {
        if videoDone { return }
        while videoInput.isReadyForMoreMediaData && videoIndex < videos.count {
            let ok: Bool = autoreleasepool {
                guard let pool = adaptor.pixelBufferPool else { fail("No pixel-buffer pool."); return false }
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess, let pixelBuffer = buffer else {
                    fail("Pixel-buffer allocation failed."); return false
                }
                let frameData = bytes.subdata(in: videos[videoIndex])
                guard let source = CGImageSourceCreateWithData(frameData as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    fail("JPEG frame \(videoIndex) could not be decoded."); return false
                }
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
                guard let context = context else {
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, []); fail("Bitmap context failed."); return false
                }
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                let timestamp = CMTime(value: Int64(videoIndex * fpsScale), timescale: Int32(fpsRate))
                guard adaptor.append(pixelBuffer, withPresentationTime: timestamp) else {
                    fail("Video append failed: \(String(describing: writer.error))"); return false
                }
                return true
            }
            if !ok { videoDone = true; videoInput.markAsFinished(); group.leave(); return }
            videoIndex += 1
            if videoIndex % 300 == 0 { print("VIDEO \(videoIndex)/\(videos.count)") }
        }
        if videoIndex == videos.count && !videoDone {
            videoDone = true
            videoInput.markAsFinished()
            group.leave()
        }
    }
    var audioIndex = 0
    var audioFrameOffset: Int64 = 0
    var audioDone = false
    group.enter()
    audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "stormwright.audio.encode")) {
        if audioDone { return }
        while audioInput.isReadyForMoreMediaData && audioIndex < audios.count {
            let ok: Bool = autoreleasepool {
                let range = audios[audioIndex]
                let samples = range.count / bytesPerFrame
                var block: CMBlockBuffer?
                guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                    blockLength: range.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
                    offsetToData: 0, dataLength: range.count, flags: 0, blockBufferOut: &block) == kCMBlockBufferNoErr,
                    let block = block else { fail("PCM block allocation failed."); return false }
                let copied = bytes.withUnsafeBytes { pointer -> OSStatus in
                    CMBlockBufferReplaceDataBytes(with: pointer.baseAddress!.advanced(by: range.lowerBound),
                        blockBuffer: block, offsetIntoDestination: 0, dataLength: range.count)
                }
                guard copied == noErr else { fail("PCM block copy failed."); return false }
                var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(sampleRate)),
                    presentationTimeStamp: CMTime(value: audioFrameOffset, timescale: Int32(sampleRate)), decodeTimeStamp: .invalid)
                var sampleSize = bytesPerFrame
                var sample: CMSampleBuffer?
                guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block,
                    formatDescription: audioFormat, sampleCount: samples, sampleTimingEntryCount: 1,
                    sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
                    sampleBufferOut: &sample) == noErr, let sample = sample else {
                    fail("PCM sample buffer creation failed."); return false
                }
                guard audioInput.append(sample) else {
                    fail("Audio append failed: \(String(describing: writer.error))"); return false
                }
                audioFrameOffset += Int64(samples)
                return true
            }
            if !ok { audioDone = true; audioInput.markAsFinished(); group.leave(); return }
            audioIndex += 1
        }
        if audioIndex == audios.count && !audioDone {
            audioDone = true
            audioInput.markAsFinished()
            group.leave()
        }
    }
    try require(group.wait(timeout: .now() + 180) == .success, "Timed out waiting for encoder inputs.")
    if let failure = failure { throw EncodeError.message(failure) }
    let endTime = CMTime(value: Int64(videos.count * fpsScale), timescale: Int32(fpsRate))
    writer.endSession(atSourceTime: endTime)
    let finish = DispatchSemaphore(value: 0)
    writer.finishWriting { finish.signal() }
    try require(finish.wait(timeout: .now() + 60) == .success && writer.status == .completed,
        "MP4 finalization failed: \(String(describing: writer.error))")

    // Independently read every encoded video frame and decoded audio sample.
    let asset = AVURLAsset(url: outputURL)
    let videoTracks = asset.tracks(withMediaType: .video)
    let audioTracks = asset.tracks(withMediaType: .audio)
    try require(videoTracks.count == 1 && audioTracks.count == 1, "Expected one video and one audio track.")
    let reader = try AVAssetReader(asset: asset)
    let videoOutput = AVAssetReaderTrackOutput(track: videoTracks[0], outputSettings: nil)
    let audioOutput = AVAssetReaderTrackOutput(track: audioTracks[0], outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
    ])
    reader.add(videoOutput)
    reader.add(audioOutput)
    try require(reader.startReading(), "Unable to reopen encoded MP4.")
    var encodedFrames = 0
    while let sample = videoOutput.copyNextSampleBuffer() { encodedFrames += CMSampleBufferGetNumSamples(sample) }
    var decodedAudioFrames = 0
    while let sample = audioOutput.copyNextSampleBuffer() { decodedAudioFrames += CMSampleBufferGetNumSamples(sample) }
    try require(reader.status == .completed, "Encoded MP4 failed full readback: \(String(describing: reader.error))")
    try require(encodedFrames == videos.count, "Video frame count changed: \(encodedFrames) vs \(videos.count).")
    let duration = CMTimeGetSeconds(asset.duration)
    try require(abs(duration - Double(videos.count) / fps) < 0.05, "Unexpected MP4 duration: \(duration)")
    try require(abs(decodedAudioFrames - pcmFrames) <= 2048, "Unexpected decoded AAC sample count.")
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.requestedTimeToleranceBefore = .zero
    imageGenerator.requestedTimeToleranceAfter = .zero
    for (name, second) in [("lance", 0.72), ("cataclysm", 7.85), ("aftershock", 19.1)] {
        let image = try imageGenerator.copyCGImage(at: CMTime(seconds: second, preferredTimescale: 600), actualTime: nil)
        let posterURL = outputURL.deletingPathExtension().appendingPathExtension(name + ".png")
        if let destination = CGImageDestinationCreateWithURL(posterURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
    let result: [String: Any] = [
        "source": sourceURL.path, "output": outputURL.path, "source_unchanged": true,
        "video_codec": "H.264 High", "audio_codec": "AAC 192kbps", "width": width, "height": height,
        "fps": fps, "video_tracks": videoTracks.count, "audio_tracks": audioTracks.count,
        "source_video_frames": videos.count, "encoded_video_frames": encodedFrames,
        "source_pcm_frames": pcmFrames, "decoded_audio_frames": decodedAudioFrames,
        "sample_rate": sampleRate, "channels": channels, "duration_seconds": duration,
        "complete_readback": true,
    ]
    let report = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try report.write(to: outputURL.deletingPathExtension().appendingPathExtension("verification.json"))
    print("ENCODE_VERIFIED " + String(data: report, encoding: .utf8)!)
} catch {
    fputs("ENCODE_ERROR \(error)\n", stderr)
    exit(1)
}
