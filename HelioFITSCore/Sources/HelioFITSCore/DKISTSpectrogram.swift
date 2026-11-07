//
//  DKISTSpectrogram.swift: the label and wavelength ticks for a DKIST spectrograph frame
//  (Spec-214 L1 FITS, e.g. CryoNIRSP SP: one slit position, wavelength along axis 1).
//
//  Everything comes from the file's own header: INSTRUME, DSETID, DATE-BEG, WAVEBAND,
//  WAVEMIN/WAVEMAX and the axis-1 WCS (CTYPE1 AWAV*, CUNIT1 nm, CRPIX1, CRVAL1, CDELT1).
//  The ticks use the linear WCS term only: AWAV-GRA is a grating relation, so a tick is
//  exact at CRPIX1 and approximate away from it; over a few nm the error is about a pixel
//  (checked against WAVEMIN/WAVEMAX in the tests). No tick rather than a wrong one: `make`
//  returns nil unless the axis is a nm wavelength axis with a usable scale.
//

import Foundation
import CoreGraphics
import CoreText
import CFITSIO

public struct DKISTSpectrogram: Equatable {

    public struct Tick: Equatable {
        /// Position across the image, 0 (left edge) to 1 (right edge).
        public let t: Double
        public let label: String
    }

    public let instrument: String
    public let datasetID: String
    /// "YYYY-MM-DD HH:MM:SS UT" from DATE-BEG, else nil.
    public let start: String?
    public let waveband: String?
    public let waveMinNM: Double?
    public let waveMaxNM: Double?
    public let ticks: [Tick]

    /// Longest tick list drawn: keeps the overlay cheap and the text legible.
    static let maxTicks = 8

    /// nil unless the HDU's cards describe a DKIST wavelength-along-x frame `width` pixels wide.
    public static func make(cards: String, width: Int) -> DKISTSpectrogram? {
        guard width > 0, let dset = FITSRenderer.cardVal(cards, "DSETID"),
              let ctype = FITSRenderer.cardVal(cards, "CTYPE1"), ctype.hasPrefix("AWAV"),
              FITSRenderer.cardVal(cards, "CUNIT1")?.lowercased() == "nm",
              let crpix = FITSRenderer.cardNum(cards, "CRPIX1"), let crval = FITSRenderer.cardNum(cards, "CRVAL1"),
              let cdelt = FITSRenderer.cardNum(cards, "CDELT1"),
              crpix.isFinite, crval.isFinite, cdelt.isFinite, cdelt != 0 else { return nil }
        // FITS pixel f is centred on integer f, so the image spans f = 0.5 ... width + 0.5.
        func nm(atFraction u: Double) -> Double { crval + (u * Double(width) + 0.5 - crpix) * cdelt }
        let a = nm(atFraction: 0), b = nm(atFraction: 1)
        let (lo, hi) = (min(a, b), max(a, b))
        let step = niceStep(span: hi - lo)
        var ticks: [Tick] = []
        var v = (lo / step).rounded(.up) * step
        while v <= hi, ticks.count < maxTicks {
            ticks.append(Tick(t: (v - a) / (b - a), label: label(v, step: step)))
            v += step
        }
        let beg = FITSRenderer.cardVal(cards, "DATE-BEG").map {
            String($0.replacingOccurrences(of: "T", with: " ").prefix(19)) + " UT"
        }
        return DKISTSpectrogram(
            instrument: FITSRenderer.cardVal(cards, "INSTRUME") ?? "DKIST", datasetID: dset, start: beg,
            waveband: FITSRenderer.cardVal(cards, "WAVEBAND"),
            waveMinNM: FITSRenderer.cardNum(cards, "WAVEMIN"), waveMaxNM: FITSRenderer.cardNum(cards, "WAVEMAX"),
            ticks: ticks)
    }

    /// 1, 2 or 5 times a power of ten: the smallest that gives five ticks or fewer across `span`.
    static func niceStep(span: Double) -> Double {
        guard span > 0, span.isFinite else { return 1 }
        let p = pow(10, floor(log10(span / 5)))
        for m in [1.0, 2, 5, 10] where span / (m * p) <= 5 { return m * p }
        return 10 * p
    }

    static func label(_ v: Double, step: Double) -> String {
        let decimals = max(0, Int(-floor(log10(step)) + 1e-9))
        return String(format: "%.\(decimals)f", v)
    }

    /// Full line for the Quick Look caption, e.g.
    /// "CRYO-NIRSP DRMSEL  ·  2025-03-25 19:24:33 UT  ·  Fe XIII (1074.7 nm)  ·  1072.52 to 1076.47 nm".
    public var caption: String {
        var parts = ["\(instrument) \(datasetID)"]
        if let start { parts.append(start) }
        if let waveband { parts.append(waveband) }
        if let lo = waveMinNM, let hi = waveMaxNM, hi > lo {
            parts.append(String(format: "%.2f to %.2f nm", lo, hi))
        }
        return parts.joined(separator: "  ·  ")
    }

    /// Short Finder-thumbnail label: instrument and dataset ID.
    public var thumbnailLabel: String { "\(instrument) \(datasetID)" }
}

extension FITSRenderer {

    /// Index of the file's first image HDU, or nil when it has none.
    public static func firstImageHDU(path: String) -> Int? {
        var idx = [Int](repeating: 0, count: maxPagerHDUs)
        return fitsshim_image_hdus(path, &idx, Int32(maxPagerHDUs)) > 0 ? idx[0] : nil
    }

    /// The DKIST spectrogram description for a file's first image HDU, or nil for any other file.
    public static func dkistSpectrogram(path: String, width: Int) -> DKISTSpectrogram? {
        guard let h = firstImageHDU(path: path), let c = cards(path: path, hdu: h) else { return nil }
        return DKISTSpectrogram.make(cards: c, width: width)
    }

    /// Smallest context, in pixels on its short side, that gets tick numbers: below it they
    /// would run together.
    public static let spectralTickMinPixels = 96

    /// Wavelength tick marks and numbers along the top edge of a thumbnail already drawn
    /// into `ctx` (CoreGraphics, y up). Draws nothing for a context under `spectralTickMinPixels`.
    public static func drawSpectralTicks(_ ctx: CGContext, ticks: [DKISTSpectrogram.Tick]) {
        let w = CGFloat(ctx.width), h = CGFloat(ctx.height)
        guard Int(min(w, h)) >= spectralTickMinPixels, !ticks.isEmpty else { return }
        let unit = max(1, min(w, h) / 128)
        let size = 8 * unit
        let font = CTFontCreateUIFontForLanguage(.label, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
        ]
        ctx.saveGState()
        defer { ctx.restoreGState() }
        // A dark band under the ticks so the numbers read over a bright image.
        let band = size + 6 * unit
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.55))
        ctx.fill(CGRect(x: 0, y: h - band, width: w, height: band))
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        ctx.setLineWidth(unit)
        for tick in ticks {
            let x = CGFloat(tick.t) * w
            ctx.move(to: CGPoint(x: x, y: h))
            ctx.addLine(to: CGPoint(x: x, y: h - 3 * unit))
            ctx.strokePath()
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: tick.label, attributes: attrs))
            let tw = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            ctx.textPosition = CGPoint(x: min(max(x - tw / 2, 1), w - tw - 1), y: h - band + 2 * unit)
            CTLineDraw(line, ctx)
        }
    }
}

extension FITSPreviewModel {

    /// The DKIST label and ticks for the displayed page, or nil for any other file.
    public func spectrogram() -> DKISTSpectrogram? {
        guard let p = page, let c = headerCards() else { return nil }
        return DKISTSpectrogram.make(cards: c, width: p.res.natW)
    }
}
