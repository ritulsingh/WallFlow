import AVFoundation
import Foundation
import ImageIO

enum MediaImportError: LocalizedError {
    case unreadableGIF
    case needsFFmpeg(String)
    case conversionFailed(String)
    case invalidURL
    case unsupportedDownload
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .unreadableGIF:
            return "WallFlow couldn’t read that GIF."
        case .needsFFmpeg(let ext):
            return ".\(ext) files need ffmpeg to import. Install it with “brew install ffmpeg”, then try again."
        case .conversionFailed(let detail):
            return "WallFlow couldn’t convert that video. \(detail)"
        case .invalidURL:
            return "Enter a direct http(s) link to a video file."
        case .unsupportedDownload:
            return "That link isn’t a supported video (MP4, MOV, M4V, GIF, WebM, or MKV)."
        case .badResponse(let code):
            return "The server responded with an error (\(code))."
        }
    }
}

enum MediaConverter {
    static let nativeExtensions: Set<String> = ["mp4", "mov", "m4v"]
    static let convertibleExtensions: Set<String> = ["gif", "webm", "mkv", "avi"]
    static var supportedExtensions: Set<String> { nativeExtensions.union(convertibleExtensions) }

    static func needsConversion(_ ext: String) -> Bool {
        convertibleExtensions.contains(ext.lowercased())
    }

    static func convert(_ source: URL, to destination: URL) throws {
        let ext = source.pathExtension.lowercased()
        if ext == "gif" {
            try convertGIF(source, to: destination)
        } else {
            try transcodeWithFFmpeg(source, to: destination)
        }
    }

    // MARK: GIF

    private static func convertGIF(_ source: URL, to destination: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw MediaImportError.unreadableGIF
        }
        let frameCount = CGImageSourceGetCount(imageSource)
        guard frameCount > 0, let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw MediaImportError.unreadableGIF
        }

        let width = max(2, firstFrame.width & ~1)
        let height = max(2, firstFrame.height & ~1)

        try? FileManager.default.removeItem(at: destination)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(input) else { throw MediaImportError.unreadableGIF }
        writer.add(input)
        guard writer.startWriting() else {
            throw MediaImportError.conversionFailed(writer.error?.localizedDescription ?? "")
        }
        writer.startSession(atSourceTime: .zero)

        var elapsed = 0.0
        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(imageSource, index, nil),
                  let buffer = pixelBuffer(from: frame, width: width, height: height)
            else {
                continue
            }
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(seconds: elapsed, preferredTimescale: 600))
            elapsed += frameDelay(imageSource, index: index)
        }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: elapsed, preferredTimescale: 600))

        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()

        guard writer.status == .completed else {
            throw MediaImportError.conversionFailed(writer.error?.localizedDescription ?? "")
        }
    }

    private static func frameDelay(_ source: CGImageSource, index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }

    private static func pixelBuffer(from image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        guard CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer
        ) == kCVReturnSuccess, let buffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    // MARK: ffmpeg (WebM, MKV, AVI)

    static func ffmpegURL() -> URL? {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    private static func transcodeWithFFmpeg(_ source: URL, to destination: URL) throws {
        let ext = source.pathExtension.lowercased()
        guard let ffmpeg = ffmpegURL() else { throw MediaImportError.needsFFmpeg(ext) }

        // Copy into our own temp folder so the child process never depends on the source's sandbox access.
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallflow-convert-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }
        let input = workDirectory.appendingPathComponent("input.\(ext)")
        try FileManager.default.copyItem(at: source, to: input)

        let encoders: [[String]] = [
            ["-c:v", "libx264", "-preset", "medium", "-crf", "18"],
            ["-c:v", "h264_videotoolbox", "-b:v", "16M"]
        ]

        var lastMessage = ""
        for encoder in encoders {
            try? FileManager.default.removeItem(at: destination)
            let arguments = [
                "-y", "-nostdin", "-loglevel", "error",
                "-i", input.path,
                "-map", "0:v:0", "-map", "0:a:0?"
            ] + encoder + [
                "-pix_fmt", "yuv420p",
                "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
                "-c:a", "aac", "-b:a", "160k",
                "-movflags", "+faststart",
                destination.path
            ]

            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = arguments
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw MediaImportError.conversionFailed("ffmpeg couldn’t be started (\(error.localizedDescription)).")
            }
            let output = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if process.terminationStatus == 0, FileManager.default.fileExists(atPath: destination.path) {
                return
            }
            lastMessage = String(data: output, encoding: .utf8)?
                .split(separator: "\n").last.map(String.init) ?? ""
        }
        try? FileManager.default.removeItem(at: destination)
        throw MediaImportError.conversionFailed(lastMessage)
    }
}
