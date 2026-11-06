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
        v.show(r, sidecarName: "x.png.hfrec.json", lines: r.reportLines)
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

    @Test("without an output file name the header uses the sidecar's name")
    func headerFallback() throws {
        let r = try HFRecord(data: Data(#"{"hfrecord": "1.0", "layers": [{}]}"#.utf8))
        #expect(HFRecordReportView.headerText(r, sidecarName: "movie.mp4.hfrec.json") == "movie.mp4, 1 layer")
    }
}
