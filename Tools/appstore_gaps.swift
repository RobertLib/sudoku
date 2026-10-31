//
//  appstore_gaps.swift
//  Sudoku tools
//
//  Fails a raw simulator take that stands still for too long inside its cut —
//  the one way a take goes wrong that nothing after it notices.
//
//      swift Tools/appstore_gaps.swift <clip.mp4>[:<in>:<out>] [<limit-seconds>]
//
//  `simctl io recordVideo` writes a frame only when the screen changes, so a
//  take is variable frame rate and a still stretch in it is simply one long
//  frame. In the demo something is always moving: a number goes in every 0.4 s,
//  the clock ticks once a second while the hint is read, and the result card
//  comes up 1.3 s after the last number, with the wave in between. Measured on
//  the four good takes of the last two runs, the longest still stretch inside
//  the cut was 1.30 s. A take in which the simulator stalled differs by that
//  alone: one en-US iPhone take stood still for 2.21 s at 14.4 s while the game
//  went on behind it, so everything after came late and the preview ran out
//  before the result card — and the cut, the encode and the length check all
//  reported success. So anything longer than 1.5 s fails, naming the clip and
//  the stretch, and the take has to be recorded again.
//
//  The whole stretch counts once any of it is inside the cut, because a stall
//  just before the cut shifts everything in it too. So does the stretch from a
//  take's last frame to the end of the cut, which appstore_video.swift fills by
//  holding that frame: a few frames of a result card the confetti has settled
//  on are fine, a take that stopped seconds early is not.
//
//  Without a range the whole take is checked, which is also how to look at a
//  finished preview: at a constant 30 fps its longest frame is 0.03 s.
//
//  Used by Tools/appstore_media.sh before every cut; see AppStore/screenshots.md.
//
import AVFoundation
import CoreMedia
import Foundation

let argv = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write(Data(
        "usage: appstore_gaps <clip.mp4>[:<in>:<out>] [<limit-seconds>]\n".utf8))
    exit(2)
}
guard argv.count == 2 || argv.count == 3 else { usage() }

// The clip and the range in the form appstore_video.swift takes them, so
// appstore_media.sh hands both tools the same argument.
let parts = argv[1].split(separator: ":", omittingEmptySubsequences: false)
let clipURL: URL
var range: (start: Double, end: Double)?
switch parts.count {
case 1:
    clipURL = URL(fileURLWithPath: argv[1])
case 3:
    guard let start = Double(parts[1]), let end = Double(parts[2]), start < end else { usage() }
    clipURL = URL(fileURLWithPath: String(parts[0]))
    range = (start, end)
default:
    usage()
}
let limit = argv.count == 3 ? Double(argv[2]) ?? -1 : 1.5
guard limit > 0 else { usage() }

let done = DispatchSemaphore(value: 0)

Task {
    do {
        // AVFoundation's own word for a missing file is "The operation could not
        // be completed".
        guard FileManager.default.fileExists(atPath: clipURL.path) else {
            throw NSError(domain: "appstore_gaps", code: 5, userInfo:
                            [NSLocalizedDescriptionKey: "no such file: \(clipURL.path)"])
        }
        let asset = AVURLAsset(url: clipURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "appstore_gaps", code: 1, userInfo:
                            [NSLocalizedDescriptionKey: "no video track in \(clipURL.lastPathComponent)"])
        }
        let takeEnd = try await track.load(.timeRange).end.seconds

        // The samples as they are stored, nothing decoded: only the timestamps
        // are wanted, and a whole take reads in well under a second.
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "appstore_gaps", code: 2, userInfo:
                                            [NSLocalizedDescriptionKey: "could not read \(clipURL.lastPathComponent)"])
        }
        var frames: [Double] = []
        while let buffer = output.copyNextSampleBuffer() {
            let count = CMSampleBufferGetNumSamples(buffer)
            guard count > 0 else { continue }
            var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
            CMSampleBufferGetOutputSampleTimingInfoArray(
                buffer, entryCount: count, arrayToFill: &timing, entriesNeededOut: nil)
            frames += timing.map(\.presentationTimeStamp).filter(\.isValid).map(\.seconds)
        }
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "appstore_gaps", code: 3, userInfo:
                                            [NSLocalizedDescriptionKey: "could not read \(clipURL.lastPathComponent)"])
        }
        guard !frames.isEmpty else {
            throw NSError(domain: "appstore_gaps", code: 4, userInfo:
                            [NSLocalizedDescriptionKey: "no frames in \(clipURL.lastPathComponent)"])
        }
        frames.sort()

        // Each frame stands until the next one; the last until the take ends, or
        // until the cut does if the cut runs on past it (the held frame).
        let window = range ?? (frames[0], takeEnd)
        let edges = frames + [max(takeEnd, window.end)]
        var longest = (start: 0.0, length: 0.0)
        var stalls: [(start: Double, length: Double)] = []
        for i in 0..<frames.count {
            let start = edges[i], end = edges[i + 1]
            guard start < window.end, end > window.start else { continue }
            let length = end - start
            if length > longest.length { longest = (start, length) }
            if length > limit { stalls.append((start, length)) }
        }

        let name = clipURL.lastPathComponent as NSString
        let span = String(format: "%.2f→%.2f", window.start, window.end)
        let place = range == nil ? "in the take" : "inside the cut \(span)"
        guard stalls.isEmpty else {
            for stall in stalls {
                let what = stall.start + stall.length > takeEnd + 0.001
                    ? String(format: "ends at %.2fs, so its last frame would stand still for %.2fs",
                             takeEnd, stall.length)
                    : String(format: "stands still for %.2fs from %.2fs", stall.length, stall.start)
                FileHandle.standardError.write(Data(String(
                    format: "  !! %@ %@, %@ (the limit is %.2fs)\n",
                    name, what, place, limit).utf8))
            }
            FileHandle.standardError.write(Data(
                "     the take stalled — record it again (Tools/appstore_media.sh video)\n".utf8))
            exit(1)
        }
        print(String(format: "  %@  %@  still at most %.2fs (at %.2fs)  take ends %.2fs",
                     name, span, longest.length, longest.start, takeEnd))
    } catch {
        FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
    done.signal()
}

done.wait()
