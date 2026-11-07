//
//  DKISTSpectrogramTests.swift: label and wavelength ticks for a DKIST spectrograph frame.
//  Header values are copied from the keywords of a real CryoNIRSP L1 frame header (read with
//  `heliofits --header`); the file here is synthetic, no DKIST data is committed.
//

import Testing
import Foundation
import CoreGraphics
@testable import HelioFITSCore

@Suite("DKIST spectrogram label and ticks")
struct DKISTSpectrogramTests {

    static let cards: [(String, String)] = [
        ("INSTRUME", "'CRYO-NIRSP'"), ("DSETID", "'DRMSEL'"), ("DATE-BEG", "'2025-03-25T19:24:33.975000'"),
        ("WAVEBAND", "'Fe XIII (1074.7 nm)'"), ("WAVEMIN", "1072.520337238266"), ("WAVEMAX", "1076.471922893242"),
        ("CTYPE1", "'AWAV-GRA'"), ("CUNIT1", "'nm'"), ("CRPIX1", "452"),
        ("CRVAL1", "1074.5005109811143"), ("CDELT1", "0.004380915360283906"),
    ]

    static func cardText(_ extra: [(String, String)] = [], drop: Set<String> = []) -> String {
        (cards.filter { !drop.contains($0.0) } + extra).map { TestFITS.card($0.0, $0.1) }.joined(separator: "\n")
    }

    @Test("ticks: 1 nm steps across 902 px, positions follow CRPIX1/CRVAL1/CDELT1")
    func ticks() throws {
        let d = try #require(DKISTSpectrogram.make(cards: Self.cardText(), width: 902))
        #expect(d.ticks.map(\.label) == ["1073", "1074", "1075", "1076"])
        // 1074 nm is (1074 - 1074.5005109811143) / 0.004380915360283906 = -114.27 px from FITS pixel 452,
        // so f = 337.73 and u = (337.73 - 0.5) / 902 (computed here by hand from the cards).
        #expect(abs(d.ticks[1].t - 0.37385) < 1e-4)
        // WCS span agrees with WAVEMIN/WAVEMAX to one pixel (0.0044 nm), the AWAV-GRA nonlinearity bound.
        let lo = d.ticks[0], hi = d.ticks[3]
        let nmPerUnit = 902 * 0.004380915360283906
        #expect(abs((hi.t - lo.t) * nmPerUnit - 3.0) < 1e-9)
        let crval: Double = 1074.5005109811143, cdelt: Double = 0.004380915360283906
        let leftEdge: Double = crval + (0.5 - 452.0) * cdelt
        let wavemin: Double = 1072.520337238266
        #expect(abs(wavemin - leftEdge) < 0.0044)
    }

    @Test("caption and thumbnail label repeat the header")
    func labels() throws {
        let d = try #require(DKISTSpectrogram.make(cards: Self.cardText(), width: 902))
        #expect(d.caption == "CRYO-NIRSP DRMSEL  ·  2025-03-25 19:24:33 UT  ·  Fe XIII (1074.7 nm)  ·  1072.52 to 1076.47 nm")
        #expect(d.thumbnailLabel == "CRYO-NIRSP DRMSEL")
    }

    @Test("no DKIST frame, no overlay: missing DSETID, non-wavelength axis, wrong unit, zero scale")
    func refusals() {
        #expect(DKISTSpectrogram.make(cards: Self.cardText(drop: ["DSETID"]), width: 902) == nil)
        #expect(DKISTSpectrogram.make(cards: Self.cardText(drop: ["CTYPE1"]), width: 902) == nil)
        #expect(DKISTSpectrogram.make(cards: Self.cardText([("CTYPE1", "'HPLN-TAN'")], drop: ["CTYPE1"]), width: 902) == nil)
        #expect(DKISTSpectrogram.make(cards: Self.cardText([("CUNIT1", "'um'")], drop: ["CUNIT1"]), width: 902) == nil)
        #expect(DKISTSpectrogram.make(cards: Self.cardText([("CDELT1", "0")], drop: ["CDELT1"]), width: 902) == nil)
        #expect(DKISTSpectrogram.make(cards: Self.cardText(), width: 0) == nil)
        #expect(DKISTSpectrogram.make(cards: "", width: 902) == nil)
    }

    @Test("a decreasing wavelength axis puts the ticks the right way round")
    func descending() throws {
        let c = Self.cardText([("CDELT1", "-0.004380915360283906")], drop: ["CDELT1"])
        let d = try #require(DKISTSpectrogram.make(cards: c, width: 902))
        #expect(d.ticks.map(\.label) == ["1073", "1074", "1075", "1076"])
        #expect(d.ticks[0].t > d.ticks[3].t)
    }

    @Test("end to end: a synthetic file gives a caption part and ticks; a plain fixture gives none")
    func fileRoundTrip() throws {
        let path = try TestFITS.write(width: 902, height: 8, cards: Self.cards) { x, _, _ in Float(x) }
        defer { try? FileManager.default.removeItem(atPath: path) }
        let d = try #require(FITSRenderer.dkistSpectrogram(path: path, width: 902))
        #expect(d.ticks.count == 4)
        let r = try FITSRenderer.render(path: path, maxSide: 256)
        let cap = FITSRenderer.caption(res: r, cards: FITSRenderer.cards(path: path, hdu: 0) ?? "", index: 1, of: 1)
        #expect(cap.contains("CRYO-NIRSP DRMSEL"))
        let plain = RepoPaths.fixture("synthetic_disk.fits").path
        #expect(FITSRenderer.dkistSpectrogram(path: plain, width: 256) == nil)
    }

    /// Count of non-black pixels after drawing the ticks on a black context.
    static func lit(side: Int, ticks: [DKISTSpectrogram.Tick]) throws -> Int {
        let ctx = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                         bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        FITSRenderer.drawSpectralTicks(ctx, ticks: ticks)
        let px = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: side * side * 4)
        return (0..<(side * side)).filter { px[$0 * 4] > 8 }.count
    }

    @Test("ticks draw on a thumbnail, and not on a tiny one or with no ticks")
    func drawing() throws {
        let d = try #require(DKISTSpectrogram.make(cards: Self.cardText(), width: 902))
        #expect(try Self.lit(side: 256, ticks: d.ticks) > 50)
        #expect(try Self.lit(side: 64, ticks: d.ticks) == 0)
        #expect(try Self.lit(side: 256, ticks: []) == 0)
    }
}
