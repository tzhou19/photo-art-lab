#!/usr/bin/env swift
import AVFoundation
import AppKit
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LivePhotoError: Error, CustomStringConvertible {
    let description: String
}

func fail(_ message: String) -> Never {
    fputs("Error: \(message)\n", stderr)
    exit(1)
}

func writePairedJPEG(from inputURL: URL, to outputURL: URL, identifier: String) throws {
    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw LivePhotoError(description: "Could not read the still image or create the JPEG output.") }

    var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    properties[kCGImagePropertyMakerAppleDictionary] = ["17": identifier]
    properties[kCGImageDestinationLossyCompressionQuality] = 1.0
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw LivePhotoError(description: "ImageIO could not finalize the paired JPEG.")
    }
}

func quickTimeItem(key: String, value: Any, type: String) -> AVMutableMetadataItem {
    let item = AVMutableMetadataItem()
    item.key = key as NSString
    item.keySpace = AVMetadataKeySpace(rawValue: "mdta")
    item.value = value as? (NSCopying & NSObjectProtocol)
    item.dataType = type
    return item
}

func writePairedMOV(from inputURL: URL, to outputURL: URL, identifier: String) throws {
    let asset = AVURLAsset(url: inputURL)
    guard let sourceTrack = asset.tracks(withMediaType: .video).first,
          let formatDescription = sourceTrack.formatDescriptions.first
    else { throw LivePhotoError(description: "The input video has no readable video track.") }
    let format = formatDescription as! CMFormatDescription

    let reader = try AVAssetReader(asset: asset)
    let readerOutput = AVAssetReaderTrackOutput(track: sourceTrack, outputSettings: nil)
    guard reader.canAdd(readerOutput) else { throw LivePhotoError(description: "Could not add the video reader track.") }
    reader.add(readerOutput)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
    videoInput.transform = sourceTrack.preferredTransform
    videoInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(videoInput) else { throw LivePhotoError(description: "Could not add the passthrough video track.") }
    writer.add(videoInput)

    writer.metadata = [quickTimeItem(
        key: "com.apple.quicktime.content.identifier",
        value: identifier,
        type: "com.apple.metadata.datatype.UTF-8"
    )]

    let metadataSpec: NSDictionary = [
        kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
            "mdta/com.apple.quicktime.still-image-time",
        kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
            "com.apple.metadata.datatype.int8"
    ]
    var metadataFormat: CMMetadataFormatDescription?
    let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
        allocator: kCFAllocatorDefault,
        metadataType: kCMMetadataFormatType_Boxed,
        metadataSpecifications: [metadataSpec] as CFArray,
        formatDescriptionOut: &metadataFormat
    )
    guard status == noErr, let metadataFormat else {
        throw LivePhotoError(description: "Could not create the Live Photo timed metadata format (\(status)).")
    }

    let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metadataFormat)
    metadataInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(metadataInput) else { throw LivePhotoError(description: "Could not add the still-image-time track.") }
    writer.add(metadataInput)
    let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

    guard writer.startWriting() else { throw writer.error ?? LivePhotoError(description: "Could not start the MOV writer.") }
    guard reader.startReading() else { throw reader.error ?? LivePhotoError(description: "Could not start reading the source video.") }
    writer.startSession(atSourceTime: .zero)

    let stillTime = quickTimeItem(
        key: "com.apple.quicktime.still-image-time",
        value: Int8(-1),
        type: "com.apple.metadata.datatype.int8"
    )
    let markerDuration = CMTime(value: 1, timescale: 30)
    guard metadataAdaptor.append(AVTimedMetadataGroup(
        items: [stillTime],
        timeRange: CMTimeRange(start: .zero, duration: markerDuration)
    )) else { throw writer.error ?? LivePhotoError(description: "Could not write the still-image-time marker.") }
    metadataInput.markAsFinished()

    while let sample = readerOutput.copyNextSampleBuffer() {
        while !videoInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        guard videoInput.append(sample) else {
            reader.cancelReading()
            writer.cancelWriting()
            throw writer.error ?? LivePhotoError(description: "Could not copy a video sample into the paired MOV.")
        }
    }
    guard reader.status == .completed else {
        writer.cancelWriting()
        throw reader.error ?? LivePhotoError(description: "The source video reader did not complete.")
    }
    videoInput.markAsFinished()

    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    finished.wait()
    guard writer.status == .completed else {
        throw writer.error ?? LivePhotoError(description: "The paired MOV writer did not complete.")
    }
}

func makerNoteIdentifier(in imageURL: URL) -> String? {
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let makerApple = properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any]
    else { return nil }
    return makerApple["17"] as? String
}

guard CommandLine.arguments.count == 4 else {
    fail("Usage: make_live_photo.swift <still.png> <animation.mp4> <output-base-without-extension>")
}
let stillURL = URL(fileURLWithPath: CommandLine.arguments[1])
let motionURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputBase = URL(fileURLWithPath: CommandLine.arguments[3])
let imageURL = outputBase.appendingPathExtension("jpg")
let videoURL = outputBase.appendingPathExtension("mov")
let identifier = UUID().uuidString
let fileManager = FileManager.default

guard !fileManager.fileExists(atPath: imageURL.path), !fileManager.fileExists(atPath: videoURL.path) else {
    fail("At least one output already exists. Choose a new versioned output base to avoid overwriting it.")
}

do {
    try writePairedJPEG(from: stillURL, to: imageURL, identifier: identifier)
    try writePairedMOV(from: motionURL, to: videoURL, identifier: identifier)
    guard makerNoteIdentifier(in: imageURL) == identifier else {
        throw LivePhotoError(description: "The JPEG MakerNote identifier did not round-trip correctly.")
    }
    print("Wrote \(imageURL.path)")
    print("Wrote \(videoURL.path)")
    print("Pair identifier: \(identifier)")
    print("JPEG Apple MakerNote identifier matches: yes")
    print("MOV carries the matching QuickTime identifier and still-image-time track.")
} catch {
    try? fileManager.removeItem(at: imageURL)
    try? fileManager.removeItem(at: videoURL)
    fail(error.localizedDescription)
}
