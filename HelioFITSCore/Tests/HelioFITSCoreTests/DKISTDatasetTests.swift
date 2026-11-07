//
//  DKISTDatasetTests.swift: the dataset ASDF card. The ASDF files here are synthetic: the
//  inventory keys and layout follow a real CryoNIRSP dataset file, the values are made up
//  or copied from header text only; no DKIST data is committed.
//

import Testing
import Foundation
import CoreGraphics
@testable import HelioFITSCore

@Suite("DKIST dataset ASDF card")
struct DKISTDatasetTests {

    static let yaml = """
    #ASDF 1.0.0
    #ASDF_STANDARD 1.5.0
    %YAML 1.1
    --- !core/asdf-1.1.0
    dataset:
      other:
        inventory_not: 1
      inventory:
          aoLocked: 0
          averageDatasetTemporalSampling: 0.9081463306863303
          datasetId: DRMSEL
          endTime: '2025-03-25T20:44:37.523443'
          frameCount: 5290
          gosStatus: {closed: null, open: 5290}
          instrumentName: CRYO-NIRSP
          spectralLines: [Fe XIII (1074.7 nm)]
          startTime: '2025-03-25T19:24:34.337500'
          stokesParameters: I
          targetTypes: [activecorona]
          wavelengthMax: 1076.4675419778816
          wavelengthMin: 1072.520337238266
      afterwards: 3
    """

    static func write(_ text: String, tail: [UInt8] = []) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).asdf")
        try (Data(text.utf8) + Data(tail)).write(to: url)
        return url
    }

    @Test("inventory map: ids, times, counts, lists and the wavelength range")
    func parses() throws {
        let d = try #require(DKISTDataset.parse(yaml: Self.yaml))
        #expect(d.datasetID == "DRMSEL")
        #expect(d.instrument == "CRYO-NIRSP")
        #expect(d.frameCount == 5290)
        #expect(d.spectralLines == ["Fe XIII (1074.7 nm)"])
        #expect(d.stokes == ["I"])
        #expect(d.targets == ["activecorona"])
        #expect(d.waveMinNM == 1072.520337238266)
        #expect(d.lines == ["2025-03-25 19:24\u{2013}20:44 UT", "5290 frames at 0.91 s", "duration 1h 20m 03s", "Fe XIII (1074.7 nm)",
                            "Stokes I", "activecorona", "1072.52 to 1076.47 nm"])
        #expect(d.title == "CRYO-NIRSP DRMSEL")
    }

    @Test("a file without an inventory, or without a datasetId, gives nothing")
    func refusals() {
        #expect(DKISTDataset.parse(yaml: "#ASDF 1.0.0\nfoo: 1\n") == nil)
        #expect(DKISTDataset.parse(yaml: "inventory:\n  frameCount: 3\n") == nil)
    }

    @Test("read stops at the first binary block and ignores what follows it")
    func readStopsAtBlock() throws {
        // A second inventory with a different id sits after the block marker: it must not be read.
        let url = try Self.write(Self.yaml + "\n", tail: [0xD3, 0x42, 0x4C, 0x4B] + Array("\ninventory:\n  datasetId: WRONG\n".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(DKISTDataset.read(url: url)?.datasetID == "DRMSEL")
    }

    @Test("not an ASDF, or unreadable: nil")
    func notASDF() throws {
        let url = try Self.write("SIMPLE  = T\n" + Self.yaml)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(DKISTDataset.read(url: url) == nil)
        #expect(DKISTDataset.read(url: URL(fileURLWithPath: "/nonexistent/x.asdf")) == nil)
    }

    @Test("name test is case-insensitive")
    func names() {
        #expect(DKISTDataset.isASDFName("A_metadata.ASDF"))
        #expect(!DKISTDataset.isASDFName("a.fits"))
    }

    @Test("the card draws, and a tiny one is just the band")
    func drawing() throws {
        let d = try #require(DKISTDataset.parse(yaml: Self.yaml))
        func lit(_ side: Int) throws -> Int {
            let ctx = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            d.drawCard(in: ctx, pixels: CGSize(width: side, height: side))
            let px = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: side * side * 4)
            // Light text pixels: the card is charcoal, the band gold; text is grey above 150 in all channels.
            return (0..<(side * side)).filter { px[$0 * 4] > 150 && px[$0 * 4 + 2] > 150 }.count
        }
        #expect(try lit(256) > 100)
        #expect(try lit(24) == 0)
    }
}
