//
//  HFRecordReportTests.swift: the Swift port of pyHelioFITS report.py against its own output.
//
//  Each golden file in HelioFITSCore/Tests/hfrecord/ is the stdout of
//  `python -m heliofits.core record show <fixture> --format <fmt> [--full]` (README.md there).
//  A diff names the first line that differs, so a layout drift is easy to place.
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import HelioFITSCore

@Suite("hfrecord report")
struct HFRecordReportTests {

    static let dir = "HelioFITSCore/Tests/hfrecord/"
    static let fixtures = ["example-studio-connect-still", "stress"]

    static func record(_ name: String) throws -> HFRecord {
        try HFRecord(contentsOf: RepoPaths.url(dir + name + ".hfrec.json"))
    }

    static func golden(_ name: String, _ kind: String) throws -> String {
        try String(contentsOf: RepoPaths.url(dir + "\(name).\(kind).txt"), encoding: .utf8)
    }

    /// The first differing line, or nil when equal.
    static func firstDiff(_ got: String, _ want: String) -> String? {
        if got == want { return nil }
        let g = got.components(separatedBy: "\n"), w = want.components(separatedBy: "\n")
        for i in 0..<max(g.count, w.count) {
            let a = i < g.count ? g[i] : "<end>", b = i < w.count ? w[i] : "<end>"
            if a != b { return "line \(i + 1)\n  swift:  \(a)\n  python: \(b)" }
        }
        return "same lines, different bytes"
    }

    @Test("text, full text, methods, tex and python match report.py", arguments: fixtures)
    func goldens(_ name: String) throws {
        let r = try Self.record(name)
        for (kind, got) in [("text", r.text()), ("full", r.text(full: true)), ("methods", r.methodsText()),
                            ("tex", r.texText()), ("python", r.pythonText())] {
            let d = Self.firstDiff(got, try Self.golden(name, kind))
            #expect(d == nil, "\(name).\(kind): \(d ?? "")")
        }
    }

    @Test("a stored report wins over the generated one")
    func storedReport() throws {
        let r = try HFRecord(data: Data(#"{"hfrecord": "1.0", "report": ["line one", 3, "line two"], "layers": []}"#.utf8))
        #expect(r.reportLines == ["line one", "line two"])
        let gen = try Self.record("stress")
        #expect(gen.reportLines == gen.text().components(separatedBy: "\n").dropLast())
    }

    @Test("facts for the header strip, thumbnail and Spotlight")
    func facts() throws {
        let r = try Self.record("example-studio-connect-still")
        #expect(r.outputFileName == "connect_20250921T2032_aia-aspiics-punch.png")
        #expect(r.layerCount == 3)
        #expect(r.instruments == ["SDO AIA", "Proba-3 ASPIICS", "PUNCH WFI+NFI Mosaic"])
        #expect(r.date == "2025-09-21T20:32:00Z")
        #expect(r.program == "HelioFITS Studio <VERSION>")
        #expect(r.timeRange?.start == "2025-09-21T20:31:11.394")
        #expect(r.sourceFileNames.count == 3)
    }

    @Test("Python spellings of values")
    func spellings() throws {
        #expect(HFJSON.floatRepr(530) == "530.0")
        #expect(HFJSON.floatRepr(0.45454545454545453) == "0.45454545454545453")
        #expect(HFJSON.floatRepr(1e-5) == "1e-05")
        #expect(HFJSON.floatRepr(1e16) == "1e+16")
        #expect(HFJSON.floatRepr(1e15) == "1000000000000000.0")
        #expect(HFJSON.floatRepr(0.0001) == "0.0001")
        #expect(HFJSON.floatRepr(-2.5e-7) == "-2.5e-07")
        #expect(HFJSON.reprString("it's") == #""it's""#)
        #expect(HFJSON.reprString("a\\b") == #"'a\\b'"#)
        #expect(HFRecord.varName("193 Å L1") == "layer_193_å_l1")
        #expect(HFRecord.isHeading("LAYERS (3, top layer first)") && HFRecord.isHeading("12. SDO AIA"))
        #expect(!HFRecord.isHeading("    Files:") && !HFRecord.isHeading("Made by:   x"))
        #expect(throws: (any Error).self) { try HFRecord(data: Data("[1, 2]".utf8)) }
        #expect(throws: (any Error).self) { try HFRecord(data: Data("{\"a\": }".utf8)) }
    }

    @Test("the thumbnail card draws its band and text")
    func card() throws {
        let r = try Self.record("example-studio-connect-still")
        #expect(r.cardLines.instruments == ["SDO AIA", "Proba-3 ASPIICS", "PUNCH WFI+NFI Mosaic"])
        #expect(r.cardLines.date == "2025-09-21 20:32")
        let n = 256
        let ctx = try #require(CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        r.drawCard(in: ctx, pixels: CGSize(width: n, height: n))
        let px = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        func rgb(_ x: Int, _ yFromTop: Int) -> (Int, Int, Int) {
            let o = (yFromTop * n + x) * 4
            return (Int(px[o]), Int(px[o + 1]), Int(px[o + 2]))
        }
        let band = rgb(n - 8, n / 10)
        #expect(band.0 > 200 && band.2 < 120, "gold band at the top, got \(band)")
        // Some light text pixels in the instrument rows below the band.
        var light = 0
        for y in (n / 4)..<(n / 2) { for x in 0..<n where rgb(x, y).0 > 180 { light += 1 } }
        #expect(light > 50)
        if let out = ProcessInfo.processInfo.environment["HFREC_CARD_PNG"], let img = ctx.makeImage(),
           let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, img, nil)
            CGImageDestinationFinalize(dest)
        }
    }

    @Test("the export beside a sidecar")
    func exportBeside() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hfrec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let side = dir.appendingPathComponent("movie.mp4.hfrec.json")
        try Data(#"{"hfrecord": "1.0", "output": {"file_name": "other.png"}}"#.utf8).write(to: side)
        let r = try HFRecord(contentsOf: side)
        #expect(r.exportBeside(sidecar: side) == nil)
        try Data().write(to: dir.appendingPathComponent("movie.mp4"))
        #expect(r.exportBeside(sidecar: side)?.lastPathComponent == "movie.mp4")
        try Data().write(to: dir.appendingPathComponent("other.png"))
        #expect(r.exportBeside(sidecar: side)?.lastPathComponent == "other.png")
    }

    @Test("frame.png.hfrec and frame.png.hfrec.json both find frame.png", arguments: ["frame.png.hfrec", "frame.png.hfrec.json"])
    func exportBesideBothNames(_ sidecarName: String) throws {
        #expect(HFRecord.isRecordName(sidecarName))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hfrec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let side = dir.appendingPathComponent(sidecarName)
        try Data().write(to: dir.appendingPathComponent("frame.png"))
        // By the stripped name, with no output.file_name.
        try Data(#"{"hfrecord": "1.0"}"#.utf8).write(to: side)
        #expect(try HFRecord(contentsOf: side).exportBeside(sidecar: side)?.lastPathComponent == "frame.png")
        // output.file_name wins over the stripped name when that file exists.
        try Data(#"{"hfrecord": "1.0", "output": {"file_name": "renamed.png"}}"#.utf8).write(to: side)
        try Data().write(to: dir.appendingPathComponent("renamed.png"))
        #expect(try HFRecord(contentsOf: side).exportBeside(sidecar: side)?.lastPathComponent == "renamed.png")
    }

    @Test("record names: .hfrec and legacy .hfrec.json, nothing else")
    func recordNames() {
        for n in ["a.png.hfrec", "A.PNG.HFREC", "a.mp4.hfrec.json"] { #expect(HFRecord.isRecordName(n), "\(n)") }
        for n in ["a.json", "a.hfrec.txt", "hfrec.png"] { #expect(!HFRecord.isRecordName(n), "\(n)") }
    }
}
