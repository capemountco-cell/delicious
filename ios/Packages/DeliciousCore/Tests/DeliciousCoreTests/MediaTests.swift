import AVFoundation
import CoreVideo
import ImageIO
import XCTest
@testable import DeliciousCore

/// Plays/inspects REAL video files that are generated during the test.
final class MediaTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("media-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testProbesGeneratedLandscapeVideo() async throws {
        let url = tempDir.appendingPathComponent("beach_day.mp4")
        try await TestVideo.write(to: url, width: 320, height: 180, seconds: 2)

        let probed = await MediaProbe.probe(url)
        let info = try XCTUnwrap(probed)
        XCTAssertTrue(info.isPlayable)
        XCTAssertTrue(info.hasVideo)
        XCTAssertEqual(info.duration, 2, accuracy: 0.15)
        XCTAssertEqual(info.width, 320)
        XCTAssertEqual(info.height, 180)
        XCTAssertEqual(info.aspect, .landscape)
    }

    func testPlayerActuallyLoadsGeneratedVideo() async throws {
        let url = tempDir.appendingPathComponent("clip.mov")
        try await TestVideo.write(to: url, width: 240, height: 240, seconds: 1, fileType: .mov)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        let deadline = Date().addingTimeInterval(10)
        while item.status == .unknown, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(item.status, .readyToPlay, String(describing: item.error))
        XCTAssertEqual(item.duration.seconds, 1, accuracy: 0.15)
        player.pause()
    }

    func testThumbnailFromGeneratedPortraitVideo() async throws {
        let url = tempDir.appendingPathComponent("vertical.mp4")
        try await TestVideo.write(to: url, width: 180, height: 320, seconds: 1)

        let thumbnail = await MediaProbe.thumbnail(for: url, at: 0.5)
        let image = try XCTUnwrap(thumbnail)
        XCTAssertEqual(image.width, 180)
        XCTAssertEqual(image.height, 320)

        let jpeg = tempDir.appendingPathComponent("thumbs/vertical.jpg")
        XCTAssertTrue(MediaProbe.writeJPEG(image, to: jpeg))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(jpeg as CFURL, nil))
        let reloaded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(reloaded.width, 180)
        XCTAssertEqual(reloaded.height, 320)

        let probed = await MediaProbe.probe(url)
        let info = try XCTUnwrap(probed)
        XCTAssertEqual(info.aspect, .portrait)
    }

    func testCorruptFileIsNotPlayable() async throws {
        let url = tempDir.appendingPathComponent("broken.mp4")
        try Data((0..<4096).map { UInt8($0 % 251) }).write(to: url)
        let info = await MediaProbe.probe(url)
        XCTAssertFalse(info?.isPlayable == true && info?.hasVideo == true)
        let thumb = await MediaProbe.thumbnail(for: url)
        XCTAssertNil(thumb)
    }

    func testEnricherHandlesDirectVideoFile() async throws {
        let url = tempDir.appendingPathComponent("skate-park_clip.mp4")
        try await TestVideo.write(to: url, width: 320, height: 180, seconds: 1)
        let thumbs = tempDir.appendingPathComponent("thumbs", isDirectory: true)

        let parsed = LinkParser.parse(url)
        XCTAssertEqual(parsed.provider, .directFile)
        XCTAssertEqual(EmbedBuilder.source(for: VideoLink(parsed: parsed, originalURL: url)), .native(url))

        let http = StubHTTP()
        http.failAll = true
        let enriched = await Enricher(http: http, tidyEndpoint: nil, thumbnailDirectory: thumbs)
            .enrich(VideoLink(parsed: parsed, originalURL: url))
        XCTAssertEqual(enriched.duration ?? 0, 1, accuracy: 0.15)
        XCTAssertEqual(enriched.aspect, .landscape)
        XCTAssertEqual(enriched.displayTitle, "skate park clip")
        let name = try XCTUnwrap(enriched.localThumbnailName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbs.appendingPathComponent(name).path))
    }
}

/// Writes a short H.264 test video with a moving colour gradient.
enum TestVideo {
    struct WriteError: Error, CustomStringConvertible {
        let description: String
    }

    static func write(to url: URL, width: Int, height: Int, seconds: Int, fps: Int32 = 24, fileType: AVFileType = .mp4) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw WriteError(description: "cannot add video input") }
        writer.add(input)
        guard writer.startWriting() else { throw WriteError(description: "startWriting failed: \(String(describing: writer.error))") }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(fps) * seconds
        for frame in 0..<frameCount {
            var waited = 0
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
                waited += 1
                if waited > 2000 { throw WriteError(description: "writer stalled") }
            }
            guard let pool = adaptor.pixelBufferPool else { throw WriteError(description: "no pixel buffer pool") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw WriteError(description: "no pixel buffer") }
            fill(buffer, frame: frame, width: width, height: height)
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw WriteError(description: "append failed: \(String(describing: writer.error))")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw WriteError(description: "finish failed: \(String(describing: writer.error))")
        }
    }

    private static func fill(_ buffer: CVPixelBuffer, frame: Int, width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                pixels[i] = UInt8((x + frame * 4) % 256) // B
                pixels[i + 1] = UInt8((y + frame * 2) % 256) // G
                pixels[i + 2] = UInt8((frame * 8) % 256) // R
                pixels[i + 3] = 255
            }
        }
    }
}
