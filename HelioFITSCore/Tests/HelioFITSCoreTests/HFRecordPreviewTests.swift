//
//  HFRecordPreviewTests.swift: the `preview` a processing record carries (HFRecordPreview.swift),
//  the export beside it as a fallback, and the thumbnail drawn from either. Fixture:
//  HelioFITSCore/Tests/hfrecord/example-preview.hfrec.json (README.md there).
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import HelioFITSCore

@Suite("hfrecord preview")
struct HFRecordPreviewTests {

    static func fixture() throws -> HFRecord {
        try HFRecord(contentsOf: RepoPaths.url(HFRecordReportTests.dir + "example-preview.hfrec.json"))
    }

    /// The fixture's PNG bytes.
    static func png() throws -> Data { try #require(try fixture().preview).data }

    /// A record of the example with `preview` set to the JSON text given.
    static func record(preview: String) throws -> HFRecord {
        try HFRecord(data: Data(#"{"hfrecord": "1.0", "layers": [], "preview": \#(preview)}"#.utf8))
    }

    static func preview(_ type: String, _ w: Any, _ h: Any, _ bytes: Data) throws -> HFRecord {
        try record(preview: #"{"media_type": "\#(type)", "width": \#(w), "height": \#(h), "data": "\#(bytes.base64EncodedString())"}"#)
    }

    static func jpeg(_ img: CGImage) throws -> Data {
        let out = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, img, nil)
        #expect(CGImageDestinationFinalize(dest))
        return out as Data
    }

    @Test("the fixture's preview decodes to its 64 x 64 PNG")
    func fixturePreview() throws {
        let p = try #require(try Self.fixture().preview)
        #expect(p.mediaType == "image/png" && p.width == 64 && p.height == 64 && p.frame == nil)
        #expect(p.data.count <= 2048)
        let img = try #require(p.image)
        #expect(img.width == 64 && img.height == 64)
    }

    @Test("the report ignores the preview: same goldens as the record without it")
    func reportIgnoresPreview() throws {
        let r = try Self.fixture()
        let name = "example-studio-connect-still"
        for (kind, got) in [("text", r.text()), ("full", r.text(full: true)), ("methods", r.methodsText()),
                            ("tex", r.texText()), ("python", r.pythonText())] {
            let d = HFRecordReportTests.firstDiff(got, try HFRecordReportTests.golden(name, kind))
            #expect(d == nil, "\(kind): \(d ?? "")")
        }
        #expect(r.reportLines == (try HFRecordReportTests.record(name)).reportLines)
    }

    @Test("a JPEG preview is accepted")
    func jpegAccepted() throws {
        let img = try #require(try Self.fixture().preview?.image)
        let r = try Self.preview("image/jpeg", 64, 64, try Self.jpeg(img))
        let decoded = try #require(r.preview?.image)
        #expect(decoded.width == 64 && decoded.height == 64)
    }

    @Test("an off-spec preview is no preview, and the record still reads")
    func rejected() throws {
        let png = try Self.png()
        let jpg = try Self.jpeg(try #require(try Self.fixture().preview?.image))
        let tooBig = png + Data(count: HFRecordPreview.maxBytes)
        let cases: [(String, HFRecord)] = [
            ("gif", try Self.preview("image/gif", 64, 64, png)),
            ("svg", try Self.preview("image/svg+xml", 64, 64, png)),
            ("width 0", try Self.preview("image/png", 0, 64, png)),
            ("width 321", try Self.preview("image/png", 321, 64, png)),
            ("height huge", try Self.preview("image/png", 64, 100000000, png)),
            ("width float", try Self.preview("image/png", 64.0, 64, png)),
            ("width string", try Self.preview("image/png", "\"64\"", 64, png)),
            ("over 64 KB", try Self.preview("image/png", 64, 64, tooBig)),
            ("JPEG bytes said PNG", try Self.preview("image/png", 64, 64, jpg)),
            ("PNG bytes said JPEG", try Self.preview("image/jpeg", 64, 64, png)),
            ("empty data", try Self.preview("image/png", 64, 64, Data())),
            ("not base64", try Self.record(preview: #"{"media_type": "image/png", "width": 1, "height": 1, "data": "%%%"}"#)),
            ("data a number", try Self.record(preview: #"{"media_type": "image/png", "width": 1, "height": 1, "data": 7}"#)),
            ("no data", try Self.record(preview: #"{"media_type": "image/png", "width": 1, "height": 1}"#)),
            ("a string", try Self.record(preview: #""iVBORw0KGgo=""#)),
            ("null", try Self.record(preview: "null")),
            ("an array", try Self.record(preview: "[1, 2]")),
        ]
        for (label, r) in cases {
            #expect(r.preview == nil, "\(label)")
            #expect(r.previewImage(sidecar: nil) == nil, "\(label)")
            #expect(!r.text().isEmpty, "\(label)")
        }
        // Base64 with line breaks (as some encoders wrap it) still decodes.
        let wrapped = png.base64EncodedString(options: .lineLength64Characters)
            .replacingOccurrences(of: "\r\n", with: "\\n")
        let r = try Self.record(preview: #"{"media_type": "image/png", "width": 64, "height": 64, "data": "\#(wrapped)"}"#)
        #expect(r.preview?.image != nil)
    }

    @Test("a PNG that passes the checks but cannot be decoded, or claims a huge raster, gives no image")
    func undecodable() throws {
        func chunk(_ kind: String, _ body: [UInt8]) -> [UInt8] {
            let n = UInt32(body.count)
            return [UInt8(n >> 24), UInt8(n >> 16 & 255), UInt8(n >> 8 & 255), UInt8(n & 255)] + Array(kind.utf8) + body
                + [0, 0, 0, 0]   // a wrong CRC: ImageIO may reject it either way
        }
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        // IHDR claiming 100000 x 100000 pixels, 8-bit RGB.
        let huge = sig + chunk("IHDR", [0, 1, 0x86, 0xA0, 0, 1, 0x86, 0xA0, 8, 2, 0, 0, 0]) + chunk("IEND", [])
        let garbage = sig + Array(repeating: 0x41, count: 200)
        for (label, bytes) in [("huge", Data(huge)), ("garbage", Data(garbage))] {
            let r = try Self.preview("image/png", 64, 64, bytes)
            #expect(r.preview != nil, "\(label): passes the cheap checks")
            #expect(r.preview?.image == nil, "\(label)")
        }
        // A truncated PNG: ImageIO may hand back a partly decoded picture. It must not crash or grow.
        let cut = try Self.preview("image/png", 64, 64, try Self.png().prefix(60))
        if let img = cut.preview?.image {
            #expect(img.width == 64 && img.height == 64)
            _ = try Self.render(cut, 64, image: img).makeImage()
        }
    }

    @Test("a record with a long preview string parses quickly")
    func longStringParses() throws {
        let b64 = String(repeating: "QUJD", count: 24_000)   // 96 KB, past the 64 KB cap on purpose
        let text = #"{"hfrecord": "1.0", "note": "a\"b\\cé", "preview": {"media_type": "image/png", "width": 1, "height": 1, "data": "\#(b64)"}}"#
        let t0 = Date()
        let r = try HFRecord(data: Data(text.utf8))
        #expect(Date().timeIntervalSince(t0) < 1)
        #expect(r.root["note"]?.stringValue == "a\"b\\c\u{e9}")
        #expect(r.root["preview"]?["data"]?.stringValue?.count == b64.count)
        #expect(r.preview == nil)   // too long for the 64 KB cap
    }

    @Test("without a preview, the PNG or JPEG named in output.file_name beside the record")
    func sibling() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hfrec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let side = dir.appendingPathComponent("x.png.hfrec")
        let r = try HFRecord(data: Data(#"{"hfrecord": "1.0", "output": {"file_name": "x.png"}}"#.utf8))
        #expect(r.previewImage(sidecar: side) == nil)                      // missing: nil, no throw
        try Data("not a png".utf8).write(to: dir.appendingPathComponent("x.png"))
        #expect(r.previewImage(sidecar: side) == nil)                      // unreadable: nil
        try Self.png().write(to: dir.appendingPathComponent("x.png"))
        let img = try #require(r.previewImage(sidecar: side))
        #expect(img.width == 64 && img.height == 64)
        #expect(r.previewImage(sidecar: side, maxSide: 16)?.width == 16)   // scaled down
        // A movie export has no picture to read.
        let mp4 = try HFRecord(data: Data(#"{"hfrecord": "1.0", "output": {"file_name": "x.png.mp4"}}"#.utf8))
        try Self.png().write(to: dir.appendingPathComponent("x.png.mp4"))
        #expect(mp4.previewImage(sidecar: side) == nil)
        // The embedded preview wins over the file beside it.
        try Self.jpeg(try #require(img.cropping(to: CGRect(x: 0, y: 0, width: 10, height: 10))))
            .write(to: dir.appendingPathComponent("connect_20250921T2032_aia-aspiics-punch.png"))
        #expect(try Self.fixture().previewImage(sidecar: side)?.width == 64)
    }

    static func render(_ r: HFRecord, _ n: Int, image: CGImage?) throws -> CGContext {
        let ctx = try #require(CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        r.drawThumbnail(in: ctx, pixels: CGSize(width: n, height: n), image: image)
        return ctx
    }

    @Test("the thumbnail: the preview above a caption strip, else the plain card")
    func thumbnail() throws {
        let r = try Self.fixture()
        let img = try #require(r.preview?.image)
        let n = 256
        let ctx = try Self.render(r, n, image: img)
        let out = try #require(ctx.makeImage())
        #expect(out.width == n && out.height == n)
        let px = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        func rgb(_ x: Int, _ yFromTop: Int) -> (Int, Int, Int) {
            let o = (yFromTop * n + x) * 4
            return (Int(px[o]), Int(px[o + 1]), Int(px[o + 2]))
        }
        // The disk's centre (gold) sits in the picture area above the strip.
        let strip = Int(Double(n) * 0.075 * 3.2)
        let centre = rgb(n / 2, (n - strip) / 2)
        #expect(centre.0 > 200 && centre.1 > 140 && centre.2 < 90, "disk centre, got \(centre)")
        // Light caption text in the strip.
        var light = 0
        for y in (n - strip)..<n { for x in 0..<n where rgb(x, y).0 > 180 && rgb(x, y).2 > 180 { light += 1 } }
        #expect(light > 50, "caption text pixels: \(light)")
        #expect(r.captionInstruments == "SDO AIA + Proba-3 ASPIICS + PUNCH WFI+NFI Mosaic")

        // No image: byte for byte the plain card.
        let plain = try Self.render(r, n, image: nil)
        let card = try #require(CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        r.drawCard(in: card, pixels: CGSize(width: n, height: n))
        #expect(memcmp(try #require(plain.data), try #require(card.data), n * n * 4) == 0)

        // Tiny sizes: the picture alone, no crash.
        let tiny = try Self.render(r, 16, image: img)
        #expect(tiny.makeImage()?.width == 16)

        if let path = ProcessInfo.processInfo.environment["HFREC_THUMB_PNG"],
           let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, out, nil)
            CGImageDestinationFinalize(dest)
        }
    }
}
