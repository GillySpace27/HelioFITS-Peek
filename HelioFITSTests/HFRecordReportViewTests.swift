//
//  HFRecordReportViewTests.swift: the report view the Quick Look preview and the record window
//  share. The text is the record's report, selectable and not editable, headings in bold.
//

import Testing
import AppKit
@testable import HelioFITS
@testable import HelioFITSCore

@Suite("Processing record view") @MainActor
struct HFRecordReportViewTests {

    static func record() throws -> HFRecord {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HelioFITSCore/Tests/hfrecord/example-studio-connect-still.hfrec.json")
        return try HFRecord(contentsOf: url)
    }

    @Test("shows the report, a header strip, and bold headings")
    func shows() throws {
        let r = try Self.record()
        let v = HFRecordReportView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        v.show(r, sidecarName: "x.png.hfrec", lines: r.reportLines)
        #expect(v.header.stringValue == "connect_20250921T2032_aia-aspiics-punch.png, 3 layers")
        #expect(v.textView.string == r.reportLines.joined(separator: "\n"))
        #expect(v.textView.isSelectable && !v.textView.isEditable)
        let storage = try #require(v.textView.textStorage)
        func font(at line: String) -> NSFont? {
            let at = (storage.string as NSString).range(of: line).location
            return storage.attribute(.font, at: at, effectiveRange: nil) as? NSFont
        }
        #expect(font(at: "LAYERS (3")?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(font(at: "Made by:")?.fontDescriptor.symbolicTraits.contains(.bold) == false)
        #expect(font(at: "Made by:")?.isFixedPitch == true)
    }

    @Test("the preview picture sits beside the header, and is hidden without one")
    func preview() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HelioFITSCore/Tests/hfrecord/example-preview.hfrec.json")
        let r = try HFRecord(contentsOf: url)
        let img = try #require(r.previewImage(sidecar: url))
        let v = HFRecordReportView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        v.show(r, sidecarName: url.lastPathComponent, lines: r.reportLines, preview: img)
        v.layoutSubtreeIfNeeded()
        #expect(!v.previewView.isHidden && v.previewView.image != nil)
        #expect(v.previewView.frame.size == NSSize(width: HFRecordReportView.previewSide, height: HFRecordReportView.previewSide))
        #expect(v.header.frame.minX > v.previewView.frame.maxX)
        #expect(v.textView.string == r.reportLines.joined(separator: "\n"))
        // HFREC_VIEW_PNG=<name> saves a picture of the view to the test host's (sandboxed) temp folder.
        if let name = ProcessInfo.processInfo.environment["HFREC_VIEW_PNG"],
           let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
            v.cacheDisplay(in: v.bounds, to: rep)
            let out = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? rep.representation(using: .png, properties: [:])?.write(to: out)
            print("HFREC_VIEW_PNG: \(out.path)")
        }
        v.show(r, sidecarName: url.lastPathComponent, lines: r.reportLines)
        #expect(v.previewView.isHidden && v.previewView.image == nil)
    }

    @Test("without an output file name the header uses the sidecar's name")
    func headerFallback() throws {
        let r = try HFRecord(data: Data(#"{"hfrecord": "1.0", "layers": [{}]}"#.utf8))
        #expect(HFRecordReportView.headerText(r, sidecarName: "movie.mp4.hfrec") == "movie.mp4, 1 layer")
        #expect(HFRecordReportView.headerText(r, sidecarName: "movie.mp4.hfrec.json") == "movie.mp4, 1 layer")
    }
}
