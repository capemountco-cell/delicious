import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct MediaInfo: Equatable, Sendable {
    public var isPlayable: Bool
    public var duration: Double
    public var hasVideo: Bool
    public var width: Double
    public var height: Double

    public var aspect: VideoAspect {
        guard width > 0, height > 0 else { return .landscape }
        let r = width / height
        if r > 1.15 { return .landscape }
        if r < 0.87 { return .portrait }
        return .square
    }
}

/// Inspects direct video files (mp4/mov/m3u8) that the phone plays itself.
public enum MediaProbe {
    public static func probe(_ url: URL) async -> MediaInfo? {
        let asset = AVURLAsset(url: url)
        do {
            let (playable, duration) = try await asset.load(.isPlayable, .duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            var width = 0.0
            var height = 0.0
            if let track = tracks.first {
                let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                let rect = CGRect(origin: .zero, size: size).applying(transform)
                width = abs(rect.width)
                height = abs(rect.height)
            }
            let seconds = duration.seconds.isFinite ? duration.seconds : 0
            return MediaInfo(isPlayable: playable, duration: seconds, hasVideo: !tracks.isEmpty, width: width, height: height)
        } catch {
            return nil
        }
    }

    /// Grabs one frame to use as a thumbnail.
    public static func thumbnail(for url: URL, at seconds: Double = 0.5, maxDimension: CGFloat = 720) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        do {
            let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            return image
        } catch {
            return nil
        }
    }

    @discardableResult
    public static func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.8) -> Bool {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}
