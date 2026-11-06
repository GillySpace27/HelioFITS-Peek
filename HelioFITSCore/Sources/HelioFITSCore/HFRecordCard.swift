//
//  HFRecordCard.swift: the Finder thumbnail of a processing record (.hfrec): a small card
//  with the layers' instruments (top layer first), the scene date and the program that made
//  the export, instead of a generic JSON icon. Same charcoal card and gold band as the
//  "FITS table" placeholder (FITSRenderer.drawTablePlaceholder).
//

import Foundation
import CoreGraphics
import CoreText

extension HFRecord {

    /// The card's lines, top to bottom: up to four instrument names ("+N more" after them),
    /// the date as "YYYY-MM-DD HH:MM", and the program.
    public var cardLines: (instruments: [String], date: String?, program: String?) {
        var inst = instruments
        if inst.count > 4 { inst = Array(inst.prefix(3)) + ["+\(inst.count - 3) more"] }
        let date = self.date.map { d -> String in
            String(d.prefix(16)).replacingOccurrences(of: "T", with: " ")
        }
        return (inst, date, program)
    }

    /// Draw the card filling `pixels` of `ctx` (CoreGraphics, y up).
    public func drawCard(in ctx: CGContext, pixels: CGSize) {
        let w = pixels.width, h = pixels.height, s = min(w, h)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let card = CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                          cornerWidth: s * 0.12, cornerHeight: s * 0.12, transform: nil)
        ctx.addPath(card)
        ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        ctx.fillPath()
        ctx.addPath(card)
        ctx.clip()
        let band = h * 0.2
        ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.75, blue: 0.20, alpha: 1))
        ctx.fill(CGRect(x: 0, y: h - band, width: w, height: band))

        let size = s * 0.075
        guard size >= 4 else { return }   // too small to read: the band and card say enough
        let pad = s * 0.08
        func draw(_ text: String, y: CGFloat, size: CGFloat, color: CGColor, bold: Bool = false) {
            Self.drawLine(text, in: ctx, x: pad, y: y, width: w - 2 * pad, size: size, color: color, bold: bold)
        }
        let ink = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
        draw("PROCESSING RECORD", y: h - band + (band - size) / 2 + size * 0.15, size: size * 0.9, color: ink, bold: true)
        let lines = cardLines
        var y = h - band - pad - size
        let light = CGColor(gray: 0.92, alpha: 1), dim = CGColor(gray: 0.62, alpha: 1)
        for name in lines.instruments where y > pad {
            draw(name, y: y, size: size * 1.1, color: light, bold: true)
            y -= size * 1.55
        }
        var foot = pad
        if let p = lines.program { draw(p, y: foot, size: size * 0.85, color: dim); foot += size * 1.3 }
        if let d = lines.date, foot < y + size { draw(d, y: foot, size: size * 0.95, color: light) }
    }

    /// One line of text at (x, y), truncated with an ellipsis to `width`.
    static func drawLine(_ text: String, in ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat,
                         size: CGFloat, color: CGColor, bold: Bool = false) {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2026}", attributes: attrs))
        let fit = CTLineCreateTruncatedLine(line, Double(width), .end, ellipsis) ?? line
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(fit, ctx)
    }

    /// The caption under a preview: the instruments, top layer first, joined with " + ".
    public var captionInstruments: String {
        let i = cardLines.instruments
        return i.isEmpty ? "Processing record" : i.joined(separator: " + ")
    }

    /// The thumbnail for a record with a picture: the image fitted above a caption strip with the
    /// instruments and the date. Without an image it is the plain card (drawCard).
    public func drawThumbnail(in ctx: CGContext, pixels: CGSize, image: CGImage?) {
        guard let image, image.width > 0, image.height > 0 else { drawCard(in: ctx, pixels: pixels); return }
        let w = pixels.width, h = pixels.height, s = min(w, h)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let card = CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                          cornerWidth: s * 0.06, cornerHeight: s * 0.06, transform: nil)
        ctx.addPath(card)
        ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        ctx.fillPath()
        ctx.addPath(card)
        ctx.clip()

        let size = s * 0.075
        let readable = size >= 4
        let strip = readable ? size * 3.2 : 0
        let area = CGRect(x: 0, y: strip, width: w, height: h - strip)
        let k = min(area.width / CGFloat(image.width), area.height / CGFloat(image.height))
        let iw = CGFloat(image.width) * k, ih = CGFloat(image.height) * k
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: area.midX - iw / 2, y: area.midY - ih / 2, width: iw, height: ih))
        guard readable else { return }
        // A gold rule between picture and caption, the gold of the card's band.
        ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.75, blue: 0.20, alpha: 1))
        ctx.fill(CGRect(x: 0, y: strip - max(1, s * 0.01), width: w, height: max(1, s * 0.01)))
        let pad = s * 0.06
        let light = CGColor(gray: 0.92, alpha: 1), dim = CGColor(gray: 0.70, alpha: 1)
        Self.drawLine(captionInstruments, in: ctx, x: pad, y: size * 1.75, width: w - 2 * pad,
                      size: size * 1.05, color: light, bold: true)
        if let d = cardLines.date {
            Self.drawLine(d, in: ctx, x: pad, y: size * 0.55, width: w - 2 * pad, size: size * 0.95, color: dim)
        }
    }
}
