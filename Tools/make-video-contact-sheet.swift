#!/usr/bin/env swift

import AppKit
import AVFoundation
import Foundation

guard CommandLine.arguments.count == 4,
      let interval = Double(CommandLine.arguments[3]),
      interval > 0
else {
    FileHandle.standardError.write(
        Data("Usage: make-video-contact-sheet.swift INPUT OUTPUT INTERVAL_SECONDS\n".utf8)
    )
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: inputURL)
let duration = CMTimeGetSeconds(asset.duration)
guard duration.isFinite, duration > 0 else {
    FileHandle.standardError.write(Data("Could not read video duration.\n".utf8))
    exit(3)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)

var times: [Double] = []
var time = 0.0
while time < duration {
    times.append(time)
    time += interval
}

let columns = min(5, max(1, times.count))
let rows = Int(ceil(Double(times.count) / Double(columns)))
let thumbnailSize = NSSize(width: 241, height: 524)
let labelHeight = 30.0
let canvasSize = NSSize(
    width: thumbnailSize.width * Double(columns),
    height: (thumbnailSize.height + labelHeight) * Double(rows)
)

let canvas = NSImage(size: canvasSize)
canvas.lockFocus()
NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.09, alpha: 1).setFill()
NSRect(origin: .zero, size: canvasSize).fill()

let labelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.white,
]

for (index, seconds) in times.enumerated() {
    let column = index % columns
    let row = index / columns
    let x = Double(column) * thumbnailSize.width
    let y = canvasSize.height - Double(row + 1) * (thumbnailSize.height + labelHeight)
    let requestedTime = CMTime(seconds: seconds, preferredTimescale: 600)

    do {
        let cgImage = try generator.copyCGImage(at: requestedTime, actualTime: nil)
        let image = NSImage(cgImage: cgImage, size: thumbnailSize)
        image.draw(
            in: NSRect(x: x, y: y, width: thumbnailSize.width, height: thumbnailSize.height),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
    } catch {
        NSColor.darkGray.setFill()
        NSRect(x: x, y: y, width: thumbnailSize.width, height: thumbnailSize.height).fill()
    }

    let minutes = Int(seconds) / 60
    let remainingSeconds = seconds - Double(minutes * 60)
    let label = String(format: "%02d:%04.1f", minutes, remainingSeconds)
    label.draw(
        at: NSPoint(x: x + 8, y: y + thumbnailSize.height + 4),
        withAttributes: labelAttributes
    )
}

canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Could not render contact sheet.\n".utf8))
    exit(4)
}

try png.write(to: outputURL, options: .atomic)
let formattedDuration = String(format: "%.2f", duration)
print("Wrote \(outputURL.path) with \(times.count) frames from \(formattedDuration) seconds.")
