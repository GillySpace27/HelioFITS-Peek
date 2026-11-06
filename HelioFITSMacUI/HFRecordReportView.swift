//
//  HFRecordReportView.swift: a processing record (.hfrec.json) as its readable report, shared by
//  the Quick Look preview and the viewer app's record window.
//
//  A header strip names the exported file and its layer count; below it the report, monospaced
//  and selectable, with the section titles and layer titles set bold. The report text comes
//  from HFRecord (HelioFITSCore), the Swift port of pyHelioFITS report.py.
//

import AppKit
import HelioFITSCore

final class HFRecordReportView: NSView {

    let header = NSTextField(labelWithString: "")
    let textView = NSTextView()
    let scroll = NSScrollView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.color(Palette.headerBackground).cgColor

        header.font = Theme.bold(13)
        header.textColor = Theme.color(Palette.captionInk)
        header.lineBreakMode = .byTruncatingMiddle
        header.isSelectable = true
        header.translatesAutoresizingMaskIntoConstraints = false
        header.setAccessibilityLabel("Exported file and layer count")
        addSubview(header)

        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        // Lines stay as the report lays them out (100 columns): scroll sideways, never rewrap.
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.height]
        textView.setAccessibilityLabel("Processing record report")
        scroll.documentView = textView
        addSubview(scroll)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// "connect.png, 3 layers": the exported file (else the sidecar's own name) and the layer count.
    static func headerText(_ record: HFRecord, sidecarName: String) -> String {
        var name = record.outputFileName ?? sidecarName
        if record.outputFileName == nil, let r = name.range(of: ".hfrec", options: [.caseInsensitive, .backwards]) {
            name = String(name[..<r.lowerBound])
        }
        let n = record.layerCount
        return "\(name), \(n) layer\(n == 1 ? "" : "s")"
    }

    static func attributed(_ lines: [String]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: Theme.mono(11), .foregroundColor: Theme.color(Palette.headerText)]
        let head: [NSAttributedString.Key: Any] = [.font: Theme.mono(12, .bold),
                                                    .foregroundColor: Theme.color(Palette.captionInk)]
        for (i, line) in lines.enumerated() {
            out.append(NSAttributedString(string: line + (i + 1 < lines.count ? "\n" : ""),
                                          attributes: HFRecord.isHeading(line) ? head : body))
        }
        return out
    }

    func show(_ record: HFRecord, sidecarName: String, lines: [String]) {
        header.stringValue = Self.headerText(record, sidecarName: sidecarName)
        textView.textStorage?.setAttributedString(Self.attributed(lines))
        textView.scroll(.zero)
    }
}
