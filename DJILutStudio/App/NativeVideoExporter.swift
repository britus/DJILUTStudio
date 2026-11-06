import Foundation
internal import AVFoundation
internal import CoreImage
internal import CoreGraphics

enum NativeVideoExporter {
    enum ExportError: LocalizedError {
        case missingVideoTrack
        case unsupportedPreset
        case missingCubeData
        case filterFailed
        case writerFailed

        var errorDescription: String? {
            switch self {
            case .missingVideoTrack: return String(localized: "The selected file does not contain a video track.")
            case .unsupportedPreset: return String(localized: "This video cannot be exported with the selected Apple encoder.")
            case .missingCubeData: return String(localized: "The selected LUT could not be loaded.")
            case .filterFailed: return String(localized: "Core Image could not apply the selected color grade.")
            case .writerFailed: return String(localized: "Apple VideoToolbox could not write the ProRes HQ export.")
            }
        }
    }

    @MainActor
    static func export(
        videoURL: URL,
        lutURL: URL,
        outputFolder: URL,
        codec: String,
        sharpen: Bool,
        look: String,
        progress: @MainActor @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw ExportError.missingVideoTrack
        }

        let lut = try loadCube(at: lutURL)
        let videoComposition = try await AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            var image = request.sourceImage

            let range = lut.domainMaximum - lut.domainMinimum
            guard let domainTransform = CIFilter(name: "CIColorMatrix") else {
                request.finish(with: ExportError.filterFailed)
                return
            }
            domainTransform.setValue(image, forKey: kCIInputImageKey)
            domainTransform.setValue(CIVector(x: CGFloat(1 / range.x), y: 0, z: 0, w: 0), forKey: "inputRVector")
            domainTransform.setValue(CIVector(x: 0, y: CGFloat(1 / range.y), z: 0, w: 0), forKey: "inputGVector")
            domainTransform.setValue(CIVector(x: 0, y: 0, z: CGFloat(1 / range.z), w: 0), forKey: "inputBVector")
            domainTransform.setValue(CIVector(x: CGFloat(-lut.domainMinimum.x / range.x), y: CGFloat(-lut.domainMinimum.y / range.y), z: CGFloat(-lut.domainMinimum.z / range.z), w: 0), forKey: "inputBiasVector")
            guard let domainAdjustedImage = domainTransform.outputImage else {
                request.finish(with: ExportError.filterFailed)
                return
            }
            image = domainAdjustedImage

            guard let cubeFilter = CIFilter(name: "CIColorCubeWithColorSpace"),
                  let lutColorSpace = CGColorSpace(name: CGColorSpace.itur_709) else {
                request.finish(with: ExportError.filterFailed)
                return
            }
            cubeFilter.setValue(image, forKey: kCIInputImageKey)
            cubeFilter.setValue(lut.dimension, forKey: "inputCubeDimension")
            cubeFilter.setValue(lut.data, forKey: "inputCubeData")
            cubeFilter.setValue(lutColorSpace, forKey: "inputColorSpace")
            guard let cubeOutput = cubeFilter.outputImage else {
                request.finish(with: ExportError.filterFailed)
                return
            }
            image = cubeOutput

            image = applyLook(look, to: image)
            if sharpen, let filter = CIFilter(name: "CIUnsharpMask") {
                filter.setValue(image, forKey: kCIInputImageKey)
                filter.setValue(2.0, forKey: kCIInputRadiusKey)
                filter.setValue(0.35, forKey: kCIInputIntensityKey)
                if let output = filter.outputImage { image = output }
            }

            request.finish(with: image.cropped(to: request.sourceImage.extent), context: nil)
        })

        if codec == "ProRes HQ" {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)
            let outputURL = uniqueOutputURL(in: outputFolder, baseName: videoURL.deletingPathExtension().lastPathComponent, extension: "mov")
            let pipeline = try ProResHQPipeline(
                asset: asset,
                videoTracks: videoTracks,
                audioTracks: audioTracks,
                videoComposition: videoComposition,
                outputURL: outputURL,
                renderSize: videoComposition.renderSize,
                duration: duration
            )
            return try await Task.detached(priority: .userInitiated) {
                try await pipeline.export(progress: progress)
            }.value
        }

        let preset = presetName(for: codec)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ExportError.unsupportedPreset
        }

        let fileType: AVFileType = codec == "ProRes" || codec == "ProRes HQ" ? .mov : .mp4
        let fileExtension = fileType == .mov ? "mov" : "mp4"
        let outputURL = uniqueOutputURL(in: outputFolder, baseName: videoURL.deletingPathExtension().lastPathComponent, extension: fileExtension)
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                let value = Double(session.progress)
                progress(value.isFinite ? min(max(value, 0), 1) : 0)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        defer { progressTask.cancel() }

        do {
            try await session.export(to: outputURL, as: fileType)
            progress(1)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func presetName(for codec: String) -> String {
        switch codec {
        case "H.264": AVAssetExportPresetHighestQuality
        case "ProRes": AVAssetExportPresetAppleProRes422LPCM
        case "ProRes HQ": AVAssetExportPresetAppleProRes422LPCM
        default: AVAssetExportPresetHEVCHighestQuality
        }
    }

    private static func uniqueOutputURL(in folder: URL, baseName: String, extension fileExtension: String) -> URL {
        let fileManager = FileManager.default
        var candidate = folder.appending(path: "\(baseName)_graded.\(fileExtension)")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(baseName)_graded_\(suffix).\(fileExtension)")
            suffix += 1
        }
        return candidate
    }

    private struct Cube {
        var dimension: Int
        var data: Data
        var domainMinimum: SIMD3<Float>
        var domainMaximum: SIMD3<Float>
    }

    private static func loadCube(at url: URL) throws -> Cube {
        let text = try String(contentsOf: url, encoding: .utf8)
        var dimension: Int?
        var domainMinimum = SIMD3<Float>(repeating: 0)
        var domainMaximum = SIMD3<Float>(repeating: 1)
        var entries: [SIMD3<Float>] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !line.isEmpty else { continue }
            let fields = line.split(whereSeparator: \Character.isWhitespace)

            if fields.first == "LUT_3D_SIZE", fields.count == 2 {
                dimension = Int(fields[1])
            } else if fields.first == "DOMAIN_MIN", fields.count == 4,
                      let r = Float(fields[1]), let g = Float(fields[2]), let b = Float(fields[3]) {
                domainMinimum = SIMD3(r, g, b)
            } else if fields.first == "DOMAIN_MAX", fields.count == 4,
                      let r = Float(fields[1]), let g = Float(fields[2]), let b = Float(fields[3]) {
                domainMaximum = SIMD3(r, g, b)
            } else if fields.count == 3,
                      let r = Float(fields[0]), let g = Float(fields[1]), let b = Float(fields[2]) {
                entries.append(SIMD3(r, g, b))
            }
        }

        guard let dimension, dimension > 1,
              entries.count == dimension * dimension * dimension,
              domainMaximum.x > domainMinimum.x,
              domainMaximum.y > domainMinimum.y,
              domainMaximum.z > domainMinimum.z else {
            throw ExportError.missingCubeData
        }

        // CIColorCube interpolates trilinearly. Densify the LUT with FFmpeg's
        // default tetrahedral interpolation so the remaining difference is small.
        let cubeDimension = 64
        var rgba = [Float]()
        rgba.reserveCapacity(cubeDimension * cubeDimension * cubeDimension * 4)
        for blue in 0..<cubeDimension {
            for green in 0..<cubeDimension {
                for red in 0..<cubeDimension {
                    let value = tetrahedralSample(
                        entries,
                        dimension: dimension,
                        red: Float(red) / Float(cubeDimension - 1),
                        green: Float(green) / Float(cubeDimension - 1),
                        blue: Float(blue) / Float(cubeDimension - 1)
                    )
                    rgba.append(value.x)
                    rgba.append(value.y)
                    rgba.append(value.z)
                    rgba.append(1)
                }
            }
        }
        return Cube(dimension: cubeDimension, data: rgba.withUnsafeBufferPointer { Data(buffer: $0) }, domainMinimum: domainMinimum, domainMaximum: domainMaximum)
    }

    private static func tetrahedralSample(_ cube: [SIMD3<Float>], dimension: Int, red: Float, green: Float, blue: Float) -> SIMD3<Float> {
        let scale = Float(dimension - 1)
        let scaledRed = min(max(red, 0), 1) * scale
        let scaledGreen = min(max(green, 0), 1) * scale
        let scaledBlue = min(max(blue, 0), 1) * scale
        let r0 = min(Int(scaledRed), dimension - 2)
        let g0 = min(Int(scaledGreen), dimension - 2)
        let b0 = min(Int(scaledBlue), dimension - 2)
        let r = scaledRed - Float(r0)
        let g = scaledGreen - Float(g0)
        let b = scaledBlue - Float(b0)
        func corner(_ red: Int, _ green: Int, _ blue: Int) -> SIMD3<Float> {
            cube[red + green * dimension + blue * dimension * dimension]
        }
        func advance(_ value: SIMD3<Float>, _ from: SIMD3<Float>, _ amount: Float) -> SIMD3<Float> {
            value + (from - value) * SIMD3<Float>(repeating: amount)
        }

        let c000 = corner(r0, g0, b0)
        let c100 = corner(r0 + 1, g0, b0)
        let c010 = corner(r0, g0 + 1, b0)
        let c001 = corner(r0, g0, b0 + 1)
        let c110 = corner(r0 + 1, g0 + 1, b0)
        let c101 = corner(r0 + 1, g0, b0 + 1)
        let c011 = corner(r0, g0 + 1, b0 + 1)
        let c111 = corner(r0 + 1, g0 + 1, b0 + 1)

        if r >= g {
            if g >= b { return advance(advance(advance(c000, c100, r), c110, g), c111, b) }
            if r >= b { return advance(advance(advance(c000, c100, r), c101, b), c111, g) }
            return advance(advance(advance(c000, c001, b), c101, r), c111, g)
        }
        if r >= b { return advance(advance(advance(c000, c010, g), c110, r), c111, b) }
        if g >= b { return advance(advance(advance(c000, c010, g), c011, b), c111, r) }
        return advance(advance(advance(c000, c001, b), c011, g), c111, r)
    }

    private static func applyLook(_ look: String, to image: CIImage) -> CIImage {
        let saturation: CGFloat
        let contrast: CGFloat
        let brightness: CGFloat
        var bias = CIVector(x: 0, y: 0, z: 0, w: 0)

        switch look {
        case "Vibrant Pop": saturation = 1.18; contrast = 1.04; brightness = 0
        case "Cinematic Film": saturation = 0.88; contrast = 1.07; brightness = -0.015
        case "Golden Hour":
            saturation = 1; contrast = 1; brightness = 0
            bias = CIVector(x: 0.06, y: 0.015, z: -0.035, w: 0)
        case "Teal & Orange":
            saturation = 1; contrast = 1; brightness = 0
            bias = CIVector(x: 0.04, y: -0.015, z: 0.04, w: 0)
        case "Moody Noir B&W": saturation = 0; contrast = 1.18; brightness = -0.025
        default: saturation = 1; contrast = 1; brightness = 0
        }

        guard let controls = CIFilter(name: "CIColorControls") else { return image }
        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(saturation, forKey: kCIInputSaturationKey)
        controls.setValue(contrast, forKey: kCIInputContrastKey)
        controls.setValue(brightness, forKey: kCIInputBrightnessKey)
        guard let controlledImage = controls.outputImage else { return image }
        guard bias != CIVector(x: 0, y: 0, z: 0, w: 0), let matrix = CIFilter(name: "CIColorMatrix") else { return controlledImage }
        matrix.setValue(controlledImage, forKey: kCIInputImageKey)
        matrix.setValue(bias, forKey: "inputBiasVector")
        return matrix.outputImage ?? controlledImage
    }
}

private final class ProResHQPipeline: @unchecked Sendable {
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let videoOutput: AVAssetReaderVideoCompositionOutput
    private let videoInput: AVAssetWriterInput
    private let audioStreams: [(AVAssetReaderTrackOutput, AVAssetWriterInput)]
    private let outputURL: URL
    private let duration: CMTime

    init(
        asset: AVAsset,
        videoTracks: [AVAssetTrack],
        audioTracks: [AVAssetTrack],
        videoComposition: AVVideoComposition,
        outputURL: URL,
        renderSize: CGSize,
        duration: CMTime
    ) throws {
        self.reader = try AVAssetReader(asset: asset)
        self.writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        self.outputURL = outputURL
        self.duration = duration

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else { throw NativeVideoExporter.ExportError.writerFailed }
        reader.add(videoOutput)
        self.videoOutput = videoOutput

        let width = Int(renderSize.width.rounded())
        let height = Int(renderSize.height.rounded())
        self.videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw NativeVideoExporter.ExportError.writerFailed }
        writer.add(videoInput)

        var audioStreams: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = []
        for track in audioTracks {
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            input.expectsMediaDataInRealTime = false
            guard reader.canAdd(output), writer.canAdd(input) else { continue }
            reader.add(output)
            writer.add(input)
            audioStreams.append((output, input))
        }
        self.audioStreams = audioStreams
    }

    func export(progress: @MainActor @Sendable @escaping (Double) -> Void) async throws -> URL {
        guard writer.startWriting() else {
            throw writer.error ?? NativeVideoExporter.ExportError.writerFailed
        }
        guard reader.startReading() else {
            writer.cancelWriting()
            throw reader.error ?? NativeVideoExporter.ExportError.writerFailed
        }
        writer.startSession(atSourceTime: .zero)

        do {
            try await transferAllSamples(progress: progress)

            guard reader.status == .completed else {
                throw reader.error ?? NativeVideoExporter.ExportError.writerFailed
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.writer.finishWriting {
                    if self.writer.status == .completed {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: self.writer.error ?? NativeVideoExporter.ExportError.writerFailed)
                    }
                }
            }
            return outputURL
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private func transferAllSamples(
        progress: @MainActor @Sendable @escaping (Double) -> Void
    ) async throws {
        let streams: [(AVAssetReaderOutput, AVAssetWriterInput)] = [(videoOutput, videoInput)] + audioStreams.map { ($0.0, $0.1) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion = StreamCompletion(count: streams.count, continuation: continuation)
            for (output, input) in streams {
                let queue = DispatchQueue(label: "DJILutStudio.ProResHQ.\(UUID().uuidString)")
                input.requestMediaDataWhenReady(on: queue) {
                    while input.isReadyForMoreMediaData {
                        guard let sample = output.copyNextSampleBuffer() else {
                            input.markAsFinished()
                            completion.finishOne()
                            return
                        }
                        guard input.append(sample) else {
                            let error = self.writer.error ?? NativeVideoExporter.ExportError.writerFailed
                            self.reader.cancelReading()
                            self.writer.cancelWriting()
                            completion.fail(error)
                            return
                        }
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                        let duration = self.duration.seconds
                        let fraction = timestamp.isFinite && duration.isFinite && duration > 0
                            ? min(max(timestamp / duration, 0), 1)
                            : 0
                        Task { @MainActor in progress(fraction) }
                    }
                }
            }
        }
    }
}

private final class StreamCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var remainingStreams: Int
    private var isCompleted = false
    private let continuation: CheckedContinuation<Void, Error>

    init(count: Int, continuation: CheckedContinuation<Void, Error>) {
        self.remainingStreams = count
        self.continuation = continuation
    }

    func finishOne() {
        lock.lock()
        defer { lock.unlock() }
        guard !isCompleted else { return }
        remainingStreams -= 1
        if remainingStreams == 0 {
            isCompleted = true
            continuation.resume()
        }
    }

    func fail(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !isCompleted else { return }
        isCompleted = true
        continuation.resume(throwing: error)
    }
}
