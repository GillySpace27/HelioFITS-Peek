//
//  DKISTSlitTests.swift: slit position from the header WCS and the locator drawing. The cards are
//  values copied from the header text of a real CryoNIRSP L1 frame (read with `heliofits --header`);
//  no DKIST data is committed.
//

import Testing
import Foundation
import CoreGraphics
@testable import HelioFITSCore

@Suite("DKIST slit locator")
struct DKISTSlitTests {

    static let cards: [(String, String)] = [
        ("CTYPE1", "'AWAV-GRA'"), ("CTYPE2", "'HPLT-TAN'"), ("CTYPE3", "'HPLN-TAN'"),
        ("CUNIT1", "'nm'"), ("CUNIT2", "'arcsec'"), ("CUNIT3", "'arcsec'"),
        ("CRPIX1", "452"), ("CRPIX2", "957.0"), ("CRPIX3", "0.03352093333346602"),
        ("CRVAL1", "1074.5005109811143"), ("CRVAL2", "-180.6113551495524"), ("CRVAL3", "1140.332729052273"),
        ("CDELT1", "0.004380915360283906"), ("CDELT2", "0.12"), ("CDELT3", "0.12"),
        ("PC1_1", "1.0"), ("PC2_2", "-0.15646628804333093"), ("PC2_3", "0.149740099690369"),
        ("PC3_2", "0.9882122776793049"), ("PC3_3", "-1.1675146565408134"),
    ]

    static func text(_ extra: [(String, String)] = [], drop: Set<String> = []) -> String {
        (cards.filter { !drop.contains($0.0) } + extra).map { TestFITS.card($0.0, $0.1) }.joined(separator: "\n")
    }

    @Test("DRMSEL: slit ends, length and position angle")
    func geometry() throws {
        let s = try #require(DKISTSlit.make(cards: Self.text(), alongPixels: 1915))
        #expect(abs(s.start.tx - 1026.8) < 0.1 && abs(s.start.ty + 162.6) < 0.1)
        #expect(abs(s.end.tx - 1253.8) < 0.1 && abs(s.end.ty + 198.6) < 0.1)
        // Dataset inventory boundingBox corner: (1253.8, -198.58).
        #expect(abs(s.end.tx - 1253.8) < 0.05 && abs(s.end.ty + 198.58) < 0.05)
        #expect(abs(s.lengthArcsec - 229.8) < 0.1)
        #expect(abs(s.positionAngleDegrees - 261.1) < 0.2)
    }

    @Test("radius: nominal and labelled without a header radius, the header's when there is one")
    func radius() throws {
        let a = try #require(DKISTSlit.make(cards: Self.text(), alongPixels: 1915))
        #expect(a.rsunArcsec == DKISTSlit.nominalRSunArcsec && a.rsunIsNominal)
        let b = try #require(DKISTSlit.make(cards: Self.text([("RSUN_ARC", "961.5")]), alongPixels: 1915))
        #expect(b.rsunArcsec == 961.5 && !b.rsunIsNominal)
    }

    @Test("axes are found by CTYPE: swapped axis order and degrees give the same slit")
    func byCType() throws {
        // Same geometry with lat and lon exchanged between axes 2 and 3 (PC rows and keys swapped) and Ty, Tx in deg.
        let swapped: [(String, String)] = [
            ("CTYPE2", "'HPLN-TAN'"), ("CTYPE3", "'HPLT-TAN'"),
            ("CRVAL2", "\(1140.332729052273 / 3600)"), ("CRVAL3", "\(-180.6113551495524 / 3600)"),
            ("CDELT2", "\(0.12 / 3600)"), ("CDELT3", "\(0.12 / 3600)"),
            ("CUNIT2", "'deg'"), ("CUNIT3", "'deg'"),
            ("PC2_2", "0.9882122776793049"), ("PC2_3", "-1.1675146565408134"),
            ("PC3_2", "-0.15646628804333093"), ("PC3_3", "0.149740099690369"),
        ]
        let drop: Set<String> = Set(swapped.map(\.0))
        let a = try #require(DKISTSlit.make(cards: Self.text(), alongPixels: 1915))
        let b = try #require(DKISTSlit.make(cards: Self.text(swapped, drop: drop), alongPixels: 1915))
        #expect(abs(a.start.tx - b.start.tx) < 1e-6 && abs(a.end.ty - b.end.ty) < 1e-6)
    }

    @Test("no slit without both celestial axes, a known unit, or a spectral first axis")
    func refusals() {
        #expect(DKISTSlit.make(cards: Self.text([("CTYPE3", "'WAVE'")], drop: ["CTYPE3"]), alongPixels: 1915) == nil)
        #expect(DKISTSlit.make(cards: Self.text([("CUNIT2", "'pix'")], drop: ["CUNIT2"]), alongPixels: 1915) == nil)
        #expect(DKISTSlit.make(cards: Self.text([("CTYPE1", "'HPLN-TAN'")], drop: ["CTYPE1"]), alongPixels: 1915) == nil)
        #expect(DKISTSlit.make(cards: Self.text(drop: ["CRVAL3"]), alongPixels: 1915) == nil)
        #expect(DKISTSlit.make(cards: Self.text(), alongPixels: 1) == nil)
        #expect(DKISTSlit.make(cards: "", alongPixels: 1915) == nil)
    }

    /// Non-black pixel count in the upper-right quadrant after drawing the inset on a black context.
    static func lit(side: Int) throws -> Int {
        let s = try #require(DKISTSlit.make(cards: text(), alongPixels: 1915))
        let ctx = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        FITSRenderer.drawSlitInset(ctx, slit: s)
        let px = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: side * side * 4)
        var n = 0
        // Row 0 is the top of the bitmap; the inset sits in the top-right half.
        for y in 0..<(side / 2) { for x in (side / 2)..<side where px[(y * side + x) * 4] > 8 { n += 1 } }
        return n
    }

    @Test("the locator draws in the upper right of a thumbnail, and not on a tiny one")
    func drawing() throws {
        #expect(try Self.lit(side: 256) > 100)
        #expect(try Self.lit(side: 96) == 0)
    }

    @Test("end to end: a synthetic file gives a slit; a plain fixture gives none")
    func fileRoundTrip() throws {
        let extra: [(String, String)] = Self.cards + [("DSETID", "'DRMSEL'")]
        let path = try TestFITS.write(width: 902, height: 8, cards: extra) { x, _, _ in Float(x) }
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(FITSRenderer.dkistSlit(path: path, alongPixels: 1915) != nil)
        #expect(FITSRenderer.dkistSlit(path: RepoPaths.fixture("synthetic_disk.fits").path, alongPixels: 256) == nil)
    }
}
