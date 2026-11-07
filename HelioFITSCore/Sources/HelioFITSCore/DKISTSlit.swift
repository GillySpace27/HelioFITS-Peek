//
//  DKISTSlit.swift: where the slit of a DKIST spectrograph frame sits on the Sun, and the small
//  locator drawn from it on a Finder thumbnail: the solar disk, N and W marks, the slit as a line.
//
//  Geometry is the frame header's own WCS (Spec-214 L1: axis 1 wavelength, axis 2 along the slit,
//  axis 3 the scan position). The axes are found by CTYPE (HPLT, HPLN), not by index, and their units
//  are read from CUNIT (arcsec, arcmin or deg; anything else draws nothing). The slit ends are the
//  world coordinates at along-slit pixel 1 and NAXIS2, at scan pixel 1 (the frame's plane), by
//  world = CRVAL + CDELT * sum(PC * (pixel - CRPIX)). That is the linear term only, taken as offsets
//  in Tx, Ty: for a slit a few hundred arcsec long the TAN-projection correction is below 0.1 arcsec.
//
//  The disk radius is RSUN_ARC (or RSUN_OBS) when the header has one. DKIST L1 headers carry no
//  DSUN_OBS, so otherwise the circle is a nominal radius (`nominalRSunArcsec`, an estimate for late
//  March, not read from the file) and is labelled "R nominal".
//

import Foundation
import CoreGraphics
import CoreText

public struct DKISTSlit: Equatable {

    public struct Point: Equatable { public let tx: Double; public let ty: Double }

    /// Helioprojective (Tx, Ty) in arcsec at along-slit pixel 1 and at the last one.
    public let start: Point
    public let end: Point
    /// Solar radius in arcsec, and whether it is the nominal estimate rather than a header value.
    public let rsunArcsec: Double
    public let rsunIsNominal: Bool

    /// ESTIMATE, not from the file: the apparent photospheric radius in late March. Replace with
    /// the header radius when a file carries RSUN_ARC.
    public static let nominalRSunArcsec = 963.0

    public var lengthArcsec: Double { hypot(end.tx - start.tx, end.ty - start.ty) }

    /// Direction start to end as a position angle, degrees counterclockwise from solar north
    /// through east (east is -Tx), 0 to 360.
    public var positionAngleDegrees: Double {
        let pa = atan2(-(end.tx - start.tx), end.ty - start.ty) * 180 / .pi
        return pa < 0 ? pa + 360 : pa
    }

    /// nil unless the cards describe a DKIST wavelength-along-x frame whose axes include HPLT and HPLN
    /// in a known angular unit, with `alongPixels` (NAXIS2) pixels along the slit.
    public static func make(cards: String, alongPixels n: Int) -> DKISTSlit? {
        guard n > 1, FITSRenderer.cardVal(cards, "CTYPE1")?.hasPrefix("AWAV") == true else { return nil }
        var lat: Int?, lon: Int?, axes = 0
        for a in 1...4 {
            guard let t = FITSRenderer.cardVal(cards, "CTYPE\(a)") else { continue }
            axes = a
            if t.hasPrefix("HPLT") { lat = a } else if t.hasPrefix("HPLN") { lon = a }
        }
        guard let lat, let lon else { return nil }

        func arcsecPerUnit(_ a: Int) -> Double? {
            switch FITSRenderer.cardVal(cards, "CUNIT\(a)")?.lowercased() {
            case "arcsec": return 1
            case "arcmin": return 60
            case "deg": return 3600
            default: return nil
            }
        }
        func world(_ a: Int, alongPixel p2: Double) -> Double? {
            guard let crval = FITSRenderer.cardNum(cards, "CRVAL\(a)"), let cdelt = FITSRenderer.cardNum(cards, "CDELT\(a)"),
                  let unit = arcsecPerUnit(a) else { return nil }
            var sum = 0.0
            for b in 1...axes {
                let crpix = FITSRenderer.cardNum(cards, "CRPIX\(b)") ?? 0
                // Axis 1 (wavelength) at its reference pixel, axis 2 along the slit, axis 3 at scan pixel 1.
                let p = b == 2 ? p2 : (b == 1 ? crpix : 1)
                sum += (FITSRenderer.cardNum(cards, "PC\(a)_\(b)") ?? (a == b ? 1 : 0)) * (p - crpix)
            }
            let v = (crval + cdelt * sum) * unit
            return v.isFinite ? v : nil
        }
        guard let tx0 = world(lon, alongPixel: 1), let ty0 = world(lat, alongPixel: 1),
              let tx1 = world(lon, alongPixel: Double(n)), let ty1 = world(lat, alongPixel: Double(n)) else { return nil }
        let header = FITSRenderer.cardNum(cards, "RSUN_ARC") ?? FITSRenderer.cardNum(cards, "RSUN_OBS")
        let r = (header ?? 0) > 0 ? header! : nominalRSunArcsec
        return DKISTSlit(start: Point(tx: tx0, ty: ty0), end: Point(tx: tx1, ty: ty1),
                         rsunArcsec: r, rsunIsNominal: !((header ?? 0) > 0))
    }
}

extension FITSRenderer {

    /// Smallest context, in pixels on its short side, that gets the locator.
    public static let slitInsetMinPixels = 128

    /// The locator in the upper-right corner of a thumbnail drawn into `ctx` (CoreGraphics, y up),
    /// below the wavelength ticks: a dark square with the solar disk (north up, west right), N and W
    /// marks and the slit as a gold line. Draws nothing for a context under `slitInsetMinPixels`.
    public static func drawSlitInset(_ ctx: CGContext, slit: DKISTSlit) {
        let w = CGFloat(ctx.width), h = CGFloat(ctx.height)
        guard Int(min(w, h)) >= slitInsetMinPixels else { return }
        let unit = max(1, min(w, h) / 128)
        let side = min(w, h) * 0.46
        let margin = 4 * unit
        let top = h - (8 + 6) * unit - margin       // under the tick band (drawSpectralTicks)
        let box = CGRect(x: w - side - margin, y: top - side, width: side, height: side)
        // Half field of view: the disk with room around it, widened if the slit reaches further out.
        let reach = max(abs(slit.start.tx), abs(slit.start.ty), abs(slit.end.tx), abs(slit.end.ty))
        let half = max(1.5 * slit.rsunArcsec, 1.1 * reach)
        let k = Double(side) / 2 / half             // points per arcsec
        func pt(_ tx: Double, _ ty: Double) -> CGPoint {
            CGPoint(x: box.midX + CGFloat(tx * k), y: box.midY + CGFloat(ty * k))
        }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.6))
        ctx.addPath(CGPath(roundedRect: box, cornerWidth: 3 * unit, cornerHeight: 3 * unit, transform: nil))
        ctx.fillPath()
        ctx.clip(to: box)
        ctx.setLineWidth(unit)
        ctx.setStrokeColor(CGColor(gray: 0.9, alpha: 0.9))
        let rr = CGFloat(slit.rsunArcsec * k)
        ctx.strokeEllipse(in: CGRect(x: box.midX - rr, y: box.midY - rr, width: 2 * rr, height: 2 * rr))
        ctx.setStrokeColor(CGColor(srgbRed: 0.98, green: 0.75, blue: 0.20, alpha: 1))
        ctx.setLineWidth(2.5 * unit)
        ctx.setLineCap(.round)
        ctx.move(to: pt(slit.start.tx, slit.start.ty))
        ctx.addLine(to: pt(slit.end.tx, slit.end.ty))
        ctx.strokePath()

        let size = 7 * unit
        let font = CTFontCreateUIFontForLanguage(.label, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
        ]
        func text(_ s: String, at p: CGPoint, centered: Bool = true) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
            let tw = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            ctx.textPosition = CGPoint(x: centered ? p.x - tw / 2 : p.x, y: p.y)
            CTLineDraw(line, ctx)
        }
        text("N", at: CGPoint(x: box.midX, y: box.maxY - size - unit))
        // W at the lower right: an off-limb slit on the west side would sit under a W at mid-height.
        text("W", at: CGPoint(x: box.maxX - 5 * unit, y: box.minY + 2 * unit))
        if slit.rsunIsNominal { text("R nominal", at: CGPoint(x: box.minX + 3 * unit, y: box.minY + 2 * unit), centered: false) }
    }
}

extension FITSRenderer {

    /// The slit locator for a file's first image HDU, or nil for any other file.
    public static func dkistSlit(path: String, alongPixels n: Int) -> DKISTSlit? {
        guard let h = firstImageHDU(path: path), let c = cards(path: path, hdu: h) else { return nil }
        return DKISTSlit.make(cards: c, alongPixels: n)
    }
}
