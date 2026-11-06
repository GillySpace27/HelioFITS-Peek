//
//  HFRecordReportView.swift: a processing record (.hfrec, or legacy .hfrec.json) as its readable report, shared by
//  the Quick Look preview and the viewer app's record window.
//
//  A header strip names the exported file and its layer count, with the record's preview picture
//  (HFRecordPreview.swift) beside it when there is one; below them the report, monospaced and
//  selectable, with the section titles and layer titles set bold. The report text comes
//  from HFRecord (HelioFITSCore), the Swift port of pyHelioFITS report.py.
//

import AppKit
import HelioFITSCore

final class HFRecordReportView: NSView {

    let header = NSTextField(labelWithString: "")
    /// The export's picture, at most `previewSide` points on its long side; hidden without one.
    let previewView = NSImageView()
    static let previewSide: CGFloat = 160
    private var previewWidth: NSLayoutConstraint!
    private var previewHeight: NSLayoutConstraint!
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
        header.setAccessibilityLabel("Exported file and layer count")
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.isHidden = true
        previewView.setAccessibilityLabel("Preview of the exported file")
        previewWidth = previewView.widthAnchor.constraint(equalToConstant: Self.previewSide)
        previewHeight = previewView.heightAnchor.constraint(equalToConstant: Self.previewSide)
        // Stack views drop hidden views from the layout, so without a picture the header sits alone.
        let top = NSStackView(views: [previewView, header])
        top.orientation = .horizontal
        top.alignment = .top
        top.spacing = 12
        top.translatesAutoresizingMaskIntoConstraints = false
        addSubview(top)

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
            previewWidth, previewHeight,
            top.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            top.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            top.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 6),
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

    /// `preview` is the record's picture (HFRecord.previewImage(sidecar:)), or nil for none.
    func show(_ record: HFRecord, sidecarName: String, lines: [String], preview: CGImage? = nil) {
        header.stringValue = Self.headerText(record, sidecarName: sidecarName)
        if let img = preview, img.width > 0, img.height > 0 {
            let k = Self.previewSide / CGFloat(max(img.width, img.height))
            previewWidth.constant = max(1, CGFloat(img.width) * k)
            previewHeight.constant = max(1, CGFloat(img.height) * k)
            previewView.image = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
            previewView.isHidden = false
        } else {
            previewView.image = nil
            previewView.isHidden = true
        }
        textView.textStorage?.setAttributedString(Self.attributed(lines))
        textView.scroll(.zero)
    }
}
