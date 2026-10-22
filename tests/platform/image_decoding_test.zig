//! Image decoding through the platform protocol (decisions 19 and 19a;
//! docs/platform-protocol.md 6.10.5): `platform.decodeImage` turns one
//! complete resource's bytes into straight-alpha RGBA8, behind the
//! `image_decoding` capability. The testing platform decodes PNG, BMP and GIF in
//! Zig, so these run against it; a platform without the capability takes
//! the unsupported path (every image is broken).
//!
//! The PNG cases are PngSuite (Willem van Schaik; its licence grants use for
//! any purpose), as WPT carries it at tests/wpt/css/css-ui/support/PTS/. The
//! expected pixels are SHA-256s of RGBA8 from a scratch reference decoder
//! that was checked file by file against PIL 12.0: exactly for samples of 8
//! bits and fewer (PIL's tRNS handling for sub-8-bit grey is wrong -
//! tbbn0g04 compares the raw 4-bit value 15 with PIL's rescaled samples - so
//! there ImageMagick 7.1.2's alpha was the reference), and for 16-bit
//! samples within one step of PIL's high-byte truncation, since Crane
//! rescales as PNG 13.12's "most accurate" equation does: round(v / 257).
//! No colour management: gAMA, cHRM, sRGB, iCCP and cICP are ignored, so the
//! g*, c* and similar files decode to their stored samples (decision 19:
//! sRGB conversion only where a spec requires it).

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

/// Generous limits: nothing in these files comes near them.
const limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 24 };

const suite_dir = "tests/wpt/css/css-ui/support/PTS/";

fn readSuite(comptime name: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, suite_dir ++ name, testing.allocator, .limited(1 << 20));
}

fn decode(mime: []const u8, bytes: []const u8) platform.ImageError!platform.DecodedImage {
    return platform.decodeImage(testing.allocator, platform.Str.from(mime), platform.Bytes.from(bytes), limits);
}

fn free(image: platform.DecodedImage) void {
    testing.allocator.free(image.pixels.slice());
}

fn hexDigest(pixels: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(pixels, &digest, .{});
    var hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
    return hex;
}

/// Every PngSuite file that is a valid PNG: name, width, height, SHA-256 of
/// the expected RGBA8 (see the file comment for where the values come from).
const pngsuite = [_]struct { []const u8, u32, u32, []const u8 }{
    .{ "basi0g01.png", 32, 32, "661985e83f94a569510ded43e65edb11f4ced1121c611209f7abe9a9c40c71a8" },
    .{ "basi0g02.png", 32, 32, "166bd68377b119b5e93e73ef554e35de7471bdd2fc3bc2070f0f7bd5be82ae97" },
    .{ "basi0g04.png", 32, 32, "b05a4bc8e7079c8aa0e491086ccb156dd4bdbc67e57bb8c9d803d7e75778da9e" },
    .{ "basi0g08.png", 32, 32, "982faa277e83f73ca15b491e67eb41fa25526418ed23e057a9986c4f620eb158" },
    .{ "basi0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "basi2c08.png", 32, 32, "23a53c674ec50d5a5eb9c3f679b6b19ba5304ae99dff76801bec4939e0f0c99e" },
    .{ "basi2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "basi3p01.png", 32, 32, "614996feb597f62b913614a57be5ce64eea97efc57cd55bbba535d2f61716833" },
    .{ "basi3p02.png", 32, 32, "a383497791948d8b7ae8f9158fb7b4e9fead4693814ee758a97bc426dc9a27cf" },
    .{ "basi3p04.png", 32, 32, "a7abc212cf1a44c85df377773f3722dc118f0c4159df89fdac2dfe6911abe378" },
    .{ "basi3p08.png", 32, 32, "b1c3302eceae6738c36edafa98c8054824d9440f3ba53a3f17cc81d29acc32cc" },
    .{ "basi4a08.png", 32, 32, "76b94a71d3c183a362c2cf6a46ebb50adc9d3a25a89bc0afc46fda6dbb002509" },
    .{ "basi4a16.png", 32, 32, "e071c0ea344f34b0070c2402329ec5f165c33566b082440aa8268ac69fa86e6d" },
    .{ "basi6a08.png", 32, 32, "2eb6a2cb3166e9c188add371157e9f81caa18fdf34d218844ed930b53b7431d2" },
    .{ "basi6a16.png", 32, 32, "3daad02ebc3eb86835c0acee955564e7fd62d2a9f37dd6230632f7655f8f8c1b" },
    .{ "basn0g01.png", 32, 32, "661985e83f94a569510ded43e65edb11f4ced1121c611209f7abe9a9c40c71a8" },
    .{ "basn0g02.png", 32, 32, "166bd68377b119b5e93e73ef554e35de7471bdd2fc3bc2070f0f7bd5be82ae97" },
    .{ "basn0g04.png", 32, 32, "b05a4bc8e7079c8aa0e491086ccb156dd4bdbc67e57bb8c9d803d7e75778da9e" },
    .{ "basn0g08.png", 32, 32, "982faa277e83f73ca15b491e67eb41fa25526418ed23e057a9986c4f620eb158" },
    .{ "basn0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "basn2c08.png", 32, 32, "23a53c674ec50d5a5eb9c3f679b6b19ba5304ae99dff76801bec4939e0f0c99e" },
    .{ "basn2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "basn3p01.png", 32, 32, "614996feb597f62b913614a57be5ce64eea97efc57cd55bbba535d2f61716833" },
    .{ "basn3p02.png", 32, 32, "a383497791948d8b7ae8f9158fb7b4e9fead4693814ee758a97bc426dc9a27cf" },
    .{ "basn3p04.png", 32, 32, "a7abc212cf1a44c85df377773f3722dc118f0c4159df89fdac2dfe6911abe378" },
    .{ "basn3p08.png", 32, 32, "b1c3302eceae6738c36edafa98c8054824d9440f3ba53a3f17cc81d29acc32cc" },
    .{ "basn4a08.png", 32, 32, "76b94a71d3c183a362c2cf6a46ebb50adc9d3a25a89bc0afc46fda6dbb002509" },
    .{ "basn4a16.png", 32, 32, "e071c0ea344f34b0070c2402329ec5f165c33566b082440aa8268ac69fa86e6d" },
    .{ "basn6a08.png", 32, 32, "2eb6a2cb3166e9c188add371157e9f81caa18fdf34d218844ed930b53b7431d2" },
    .{ "basn6a16.png", 32, 32, "3daad02ebc3eb86835c0acee955564e7fd62d2a9f37dd6230632f7655f8f8c1b" },
    .{ "bgai4a08.png", 32, 32, "76b94a71d3c183a362c2cf6a46ebb50adc9d3a25a89bc0afc46fda6dbb002509" },
    .{ "bgai4a16.png", 32, 32, "e071c0ea344f34b0070c2402329ec5f165c33566b082440aa8268ac69fa86e6d" },
    .{ "bgan6a08.png", 32, 32, "2eb6a2cb3166e9c188add371157e9f81caa18fdf34d218844ed930b53b7431d2" },
    .{ "bgan6a16.png", 32, 32, "3daad02ebc3eb86835c0acee955564e7fd62d2a9f37dd6230632f7655f8f8c1b" },
    .{ "bgbn4a08.png", 32, 32, "76b94a71d3c183a362c2cf6a46ebb50adc9d3a25a89bc0afc46fda6dbb002509" },
    .{ "bggn4a16.png", 32, 32, "e071c0ea344f34b0070c2402329ec5f165c33566b082440aa8268ac69fa86e6d" },
    .{ "bgwn6a08.png", 32, 32, "2eb6a2cb3166e9c188add371157e9f81caa18fdf34d218844ed930b53b7431d2" },
    .{ "bgyn6a16.png", 32, 32, "3daad02ebc3eb86835c0acee955564e7fd62d2a9f37dd6230632f7655f8f8c1b" },
    .{ "ccwn2c08.png", 32, 32, "bc422fa9f11c0315ae0593545eac7aa7459451526c0534f3337d5fb7b6ae9899" },
    .{ "ccwn3p08.png", 32, 32, "f5ce30c914c5711c5ca9a2f5bf0bf39559d7181d9bfab1780d9b003e9562a5b1" },
    .{ "cdfn2c08.png", 8, 32, "815fb59caaab5ef5c788bc7198aaa3b458890c578184516ea422fd0c1728b0f8" },
    .{ "cdhn2c08.png", 32, 8, "388f8a4723dea94614f3eebcae2807991af35ff26fe499e56f299de3f938b9cf" },
    .{ "cdsn2c08.png", 8, 8, "8b5fc5314d220ab75f6ef902c9d39a7c745b7800c16699d58992f35683c90b3a" },
    .{ "cdun2c08.png", 32, 32, "9da678559f83e9009a8a7bcb6516afe3bd505bd1bd764a0527d6970fdb61ef83" },
    .{ "ch1n3p04.png", 32, 32, "a7abc212cf1a44c85df377773f3722dc118f0c4159df89fdac2dfe6911abe378" },
    .{ "ch2n3p08.png", 32, 32, "b1c3302eceae6738c36edafa98c8054824d9440f3ba53a3f17cc81d29acc32cc" },
    .{ "cm0n0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "cm7n0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "cm9n0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "cs3n2c16.png", 32, 32, "65efd3f83c0a354596956359442825d698889ba0d99877604b67caed235e420d" },
    .{ "cs3n3p08.png", 32, 32, "07a07fc7df3a91066828d62d8884e1b54fc5df9984152f7b57f1fd43ad86f838" },
    .{ "cs5n2c08.png", 32, 32, "800210fbc8d405a39844210b626eb90323674e47137ce41b3f781e25db9a6848" },
    .{ "cs5n3p08.png", 32, 32, "800210fbc8d405a39844210b626eb90323674e47137ce41b3f781e25db9a6848" },
    .{ "cs8n2c08.png", 32, 32, "cff1a5bc26fcf09cc6ff654f5b167ac5a91cb64926639b7f6dc337f4b4774718" },
    .{ "cs8n3p08.png", 32, 32, "cff1a5bc26fcf09cc6ff654f5b167ac5a91cb64926639b7f6dc337f4b4774718" },
    .{ "ct0n0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "ct1n0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "cten0g04.png", 32, 32, "32afeec673e42a3ccbbcb4d42a0f98017f07a29273376434765c34c480036324" },
    .{ "ctfn0g04.png", 32, 32, "1f52aa2bbc3f87480fe9673457956d416c0e4d9fb697adb00ef3dc93427cbfc3" },
    .{ "ctgn0g04.png", 32, 32, "81836a3be909468b7274c1ca2d26bc06ccb10df7d767c50d94c2a0349baaa64f" },
    .{ "cthn0g04.png", 32, 32, "94872eef156163ecb0f0e79385c2f8dfbbf24864a02426135a3fa610ed839074" },
    .{ "ctjn0g04.png", 32, 32, "a6bf95f7cfab1cf76df223f514d2ce540c2463507fd713e1a555638bae59e41d" },
    .{ "ctzn0g04.png", 32, 32, "8c96f73081edd12a3a9b3295432bc1538a60a938a9bdb501f27637eb476d39c5" },
    .{ "f00n0g08.png", 32, 32, "2eb1702c9180b67735e5c10fae189319e818617b4267ec4bbc7de199cc59a655" },
    .{ "f00n2c08.png", 32, 32, "3018fcbef930279cb017dedf15ec0b768dcba02438f476aecfa53e0f7bac801c" },
    .{ "f01n0g08.png", 32, 32, "868c9fbd8731be65fd1014e82961322b994b8b255b62a3b1a7eb67b213327310" },
    .{ "f01n2c08.png", 32, 32, "731b37d789db80124b87861ed04dd27beb6704fe0e31b468b6c43d62246f6e85" },
    .{ "f02n0g08.png", 32, 32, "d2db1dddb835474f517f9678ff6d037b068196e4d949b60a53bfa7a64588f131" },
    .{ "f02n2c08.png", 32, 32, "c3d32f80e0f95fab11535ea922ec3a750b8c56b0a1b72f0e14b064da3bed2773" },
    .{ "f03n0g08.png", 32, 32, "17564083371d831690365f4d33129573b96cf8ffa1db40cdd8fbf97f6c663425" },
    .{ "f03n2c08.png", 32, 32, "7e0d024ebfc4481c7e35cfb67ab36ff5877373128050f9160f979d7e5a319211" },
    .{ "f04n0g08.png", 32, 32, "6e3b8f42dd1874135800552ca024f063d3e90afc9d262627b056dd74ecfdaef1" },
    .{ "f04n2c08.png", 32, 32, "c13eeb551ab25b0ed841ec1dec22b84d327ecd984ac17ea3961f68e63755e6ec" },
    .{ "f99n0g04.png", 32, 32, "f91ed72018b9f1722ccfabed08ca52e36f0929fd8d5064b689dbdc09a24dc9fd" },
    .{ "g03n0g16.png", 32, 32, "74f9b82c164049909aac7cddf4580576b044c80b664437444f3b1bbb44aa0da2" },
    .{ "g03n2c08.png", 32, 32, "a00ab529a405d73ee1beaa1052d368d5e75469bae9ac1c2227d4bf55faf2feec" },
    .{ "g03n3p04.png", 32, 32, "8be999b17057966b8f40c0af0a452dbdd361399a0f7c11045fa9d5194a80a097" },
    .{ "g04n0g16.png", 32, 32, "faa7f9b4194e7c0be9fc0a53658381851b4d01b96adce00963c03b39155755a9" },
    .{ "g04n2c08.png", 32, 32, "44dc1f3da1c0914d58cb64923d2c49ba9d532a8e716fefe1cd9f327105d37eaa" },
    .{ "g04n3p04.png", 32, 32, "da72a13be8b610124bc9f9b59ab6ef610e80dcd636d687d02f5e134bc066af48" },
    .{ "g05n0g16.png", 32, 32, "959325d5578783bd1252f9b1ab7e10e675ec6e8da2660b7a1e0eae3e1a4152da" },
    .{ "g05n2c08.png", 32, 32, "bb790622927bd3d7cdc6c99766a3b79e197ce9df4bb2ad791f801512a84f604b" },
    .{ "g05n3p04.png", 32, 32, "0b7a436c2219986b088137fcb018dbe8c7638328b27013dde6256baf48635669" },
    .{ "g07n0g16.png", 32, 32, "f3ab7e17e8e16399eabebc89cd2a03e575164f282868b3e4283da468b48a8348" },
    .{ "g07n2c08.png", 32, 32, "5f4dad8d889f2893241313958e75197a388e4d4da9eb38c99ce38b907bd18892" },
    .{ "g07n3p04.png", 32, 32, "e6ca27d388f8f9608a3975124130e8c9ced16d7bc75383777b672030d9a758e0" },
    .{ "g10n0g16.png", 32, 32, "e08e946a882f3055d2df28c04d686a31176c5b2f2949a3868df9f332c4d29eca" },
    .{ "g10n2c08.png", 32, 32, "a4f3db3f0a619fe36947b2350d4269a3ce5c45711aacd00d16263760da86fc3f" },
    .{ "g10n3p04.png", 32, 32, "5907a065c5958cd8be616eebe17401aa7ecfa0c68c08a341a0959fde7491c7cc" },
    .{ "g25n0g16.png", 32, 32, "fd383dbece98c7fe7be34a7fbe101af6635aee3c7c81d71c0d89bb5e1a135ea6" },
    .{ "g25n2c08.png", 32, 32, "246692cd887c6d0d9b17a5f0780176a330de6f7c13a8699686c396a3918747a9" },
    .{ "g25n3p04.png", 32, 32, "c9470418388abae5fbcd0f46c0e16eea09a5739ae8a106f25343be76f4eea506" },
    .{ "oi1n0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "oi1n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "oi2n0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "oi2n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "oi4n0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "oi4n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "oi9n0g16.png", 32, 32, "f17fa71e5e62a73b92827381f39e2702752ced03372d568b853ae1914b9dd047" },
    .{ "oi9n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "pp0n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "pp0n6a08.png", 32, 32, "1acf3e2efa38d117e9b1d917edb8894af1e97701d635871e8ece690a542979e9" },
    .{ "ps1n0g08.png", 32, 32, "982faa277e83f73ca15b491e67eb41fa25526418ed23e057a9986c4f620eb158" },
    .{ "ps1n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "ps2n0g08.png", 32, 32, "982faa277e83f73ca15b491e67eb41fa25526418ed23e057a9986c4f620eb158" },
    .{ "ps2n2c16.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "s01i3p01.png", 1, 1, "b7d1b3a1104cc86b1cea310793cf777002db0517281d135a02de079b0ea87c23" },
    .{ "s01n3p01.png", 1, 1, "b7d1b3a1104cc86b1cea310793cf777002db0517281d135a02de079b0ea87c23" },
    .{ "s02i3p01.png", 2, 2, "08274fcbf16434ef7ba8dbd2b4ed78e750c54b128d4dea3555b5469de7cfdfc7" },
    .{ "s02n3p01.png", 2, 2, "08274fcbf16434ef7ba8dbd2b4ed78e750c54b128d4dea3555b5469de7cfdfc7" },
    .{ "s03i3p01.png", 3, 3, "96e10f0e04a3297122d201c9a36c5eef0258823877a669870d2a68c13bdfa45f" },
    .{ "s03n3p01.png", 3, 3, "96e10f0e04a3297122d201c9a36c5eef0258823877a669870d2a68c13bdfa45f" },
    .{ "s04i3p01.png", 4, 4, "81aa0cf71b99f21785130998c229f190f4939fc1f7e8625c92e633cbe5dfbb08" },
    .{ "s04n3p01.png", 4, 4, "81aa0cf71b99f21785130998c229f190f4939fc1f7e8625c92e633cbe5dfbb08" },
    .{ "s05i3p02.png", 5, 5, "45c8a7d20ee395780378b4c5c5fdf28f64d2a5926cff64fdb58942b9bc199599" },
    .{ "s05n3p02.png", 5, 5, "45c8a7d20ee395780378b4c5c5fdf28f64d2a5926cff64fdb58942b9bc199599" },
    .{ "s06i3p02.png", 6, 6, "b2fdc763255f71b71f025eb8902c44c59d21e8c9ad6d6a023e01ebc01919a6ab" },
    .{ "s06n3p02.png", 6, 6, "b2fdc763255f71b71f025eb8902c44c59d21e8c9ad6d6a023e01ebc01919a6ab" },
    .{ "s07i3p02.png", 7, 7, "718ccf8019aea657658edae16e8d611e3ac5491e64133aa90fc2149a75df9390" },
    .{ "s07n3p02.png", 7, 7, "718ccf8019aea657658edae16e8d611e3ac5491e64133aa90fc2149a75df9390" },
    .{ "s08i3p02.png", 8, 8, "09e756bf48fa50eb2ff89fdf75045ac9c74ac0d27fc1aad1718b4f1de3ccb8d9" },
    .{ "s08n3p02.png", 8, 8, "09e756bf48fa50eb2ff89fdf75045ac9c74ac0d27fc1aad1718b4f1de3ccb8d9" },
    .{ "s09i3p02.png", 9, 9, "6ec2074e36de7915abf97990d75400925be8b300c1882a36c0cc759ff0e4e456" },
    .{ "s09n3p02.png", 9, 9, "6ec2074e36de7915abf97990d75400925be8b300c1882a36c0cc759ff0e4e456" },
    .{ "s32i3p04.png", 32, 32, "abdd1328123792f4ba8acc663ca557d5e2837914617f526204b7623507373f51" },
    .{ "s32n3p04.png", 32, 32, "abdd1328123792f4ba8acc663ca557d5e2837914617f526204b7623507373f51" },
    .{ "s33i3p04.png", 33, 33, "8a0c1de07c37eb774446787f62da09b846eb8f8a0b6736769866ce095d33f68e" },
    .{ "s33n3p04.png", 33, 33, "8a0c1de07c37eb774446787f62da09b846eb8f8a0b6736769866ce095d33f68e" },
    .{ "s34i3p04.png", 34, 34, "69c45969982b3a6589fdca9845ab8b3b98bbe41d35a7b30444b54aa609056154" },
    .{ "s34n3p04.png", 34, 34, "69c45969982b3a6589fdca9845ab8b3b98bbe41d35a7b30444b54aa609056154" },
    .{ "s35i3p04.png", 35, 35, "052dbe580106ed33a8d2fda4543a4b6ddca43bc4a410d21c2bebc2ce9e553a2a" },
    .{ "s35n3p04.png", 35, 35, "052dbe580106ed33a8d2fda4543a4b6ddca43bc4a410d21c2bebc2ce9e553a2a" },
    .{ "s36i3p04.png", 36, 36, "e87205a17e1531cc2ed9c430fddecaa82131d37322cc19ae39fa02a64c00e1a3" },
    .{ "s36n3p04.png", 36, 36, "e87205a17e1531cc2ed9c430fddecaa82131d37322cc19ae39fa02a64c00e1a3" },
    .{ "s37i3p04.png", 37, 37, "fc8e983c728f51d63e670f56cfc3e10268b4a9ae8947471c3278d764e7932d87" },
    .{ "s37n3p04.png", 37, 37, "fc8e983c728f51d63e670f56cfc3e10268b4a9ae8947471c3278d764e7932d87" },
    .{ "s38i3p04.png", 38, 38, "5ac74b3b3fd55acf60dc739f60a5a2418e19d571b5c8df62db3a3daae3aff42a" },
    .{ "s38n3p04.png", 38, 38, "5ac74b3b3fd55acf60dc739f60a5a2418e19d571b5c8df62db3a3daae3aff42a" },
    .{ "s39i3p04.png", 39, 39, "594defde21b6f4623769d68b3734ccf6b512f33292c90e5110d3c1e7bcc63550" },
    .{ "s39n3p04.png", 39, 39, "594defde21b6f4623769d68b3734ccf6b512f33292c90e5110d3c1e7bcc63550" },
    .{ "s40i3p04.png", 40, 40, "4b2d90414a70b0a7f07fa17e51ea9c80c720dfaeab34d59a38ca73648b8be999" },
    .{ "s40n3p04.png", 40, 40, "4b2d90414a70b0a7f07fa17e51ea9c80c720dfaeab34d59a38ca73648b8be999" },
    .{ "tbbn0g04.png", 32, 32, "1c36e9d46fe44582f94be4db7d79d58ea259b0b2a59c7f3328974d0222bfaa97" },
    .{ "tbbn2c16.png", 32, 32, "053eb9d28b7ac85c3639b5169a175df61856cef7ffdaa7ad218cafdde9646d08" },
    .{ "tbbn3p08.png", 32, 32, "444403e441924fcd036c85bac271d92d399859bbba3dceb82f29ff90811fb138" },
    .{ "tbgn2c16.png", 32, 32, "053eb9d28b7ac85c3639b5169a175df61856cef7ffdaa7ad218cafdde9646d08" },
    .{ "tbgn3p08.png", 32, 32, "444403e441924fcd036c85bac271d92d399859bbba3dceb82f29ff90811fb138" },
    .{ "tbrn2c08.png", 32, 32, "053eb9d28b7ac85c3639b5169a175df61856cef7ffdaa7ad218cafdde9646d08" },
    .{ "tbwn0g16.png", 32, 32, "09955bf2743754d1ad36a26e03d07b18be2e1875ff75d23e8fd1905b4dfe0599" },
    .{ "tbwn3p08.png", 32, 32, "444403e441924fcd036c85bac271d92d399859bbba3dceb82f29ff90811fb138" },
    .{ "tbyn3p08.png", 32, 32, "444403e441924fcd036c85bac271d92d399859bbba3dceb82f29ff90811fb138" },
    .{ "tm3n3p02.png", 32, 32, "9d08928c6d9fefddadc97f2a6b33e3691075d36d3c78b917e19dd29236cae822" },
    .{ "tp0n0g08.png", 32, 32, "6930bf323b5f045b6977f99ce52c2082b781bc067aac66e53dad71a627784e0b" },
    .{ "tp0n2c08.png", 32, 32, "13421e1c169afaeb1e1170ed5c1dd26dee7d37a38d14c427f89171bb0a80bb3f" },
    .{ "tp0n3p08.png", 32, 32, "fcfd3c6af7fcfc3f3bcca2fed5f85c8b2ff9ee495a5190d20110141b4250eb2e" },
    .{ "tp1n3p08.png", 32, 32, "444403e441924fcd036c85bac271d92d399859bbba3dceb82f29ff90811fb138" },
    .{ "z00n2c08.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "z03n2c08.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "z06n2c08.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
    .{ "z09n2c08.png", 32, 32, "a9dff6085fe81eea37100681e299a0504206137521dc59d592d87fa73b18c917" },
};

test "image decoding: every valid PngSuite file decodes to the reference pixels" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (pngsuite) |case| {
        const bytes = try readSuite(case[0]);
        defer testing.allocator.free(bytes);
        const image = decode("image/png", bytes) catch |err| {
            std.debug.print("{s}: {s}\n", .{ case[0], @errorName(err) });
            return err;
        };
        defer free(image);
        testing.expectEqual(case[1], image.width) catch |err| {
            std.debug.print("{s}: width\n", .{case[0]});
            return err;
        };
        try testing.expectEqual(case[2], image.height);
        try testing.expectEqual(@as(usize, case[1]) * case[2] * 4, image.pixels.len);
        const digest = hexDigest(image.pixels.slice());
        testing.expectEqualStrings(case[3], &digest) catch |err| {
            std.debug.print("{s}: pixels differ from the reference\n", .{case[0]});
            return err;
        };
        try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
        try testing.expect(!image.empty);
    }
}

test "image decoding: the corrupt PngSuite files (x*) are corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const corrupt = .{
        "xc1n0g08.png", // colour type 1
        "xc9n2c08.png", // colour type 9
        "xcrn0g04.png", // CR bytes added: the signature is wrong
        // (xcsn0g01.png, an IDAT CRC mismatch, is past its dimensions: a
        // partial image - image_decoding_partial_test.zig.)
        "xd0n2c08.png", // bit depth 0
        "xd3n2c08.png", // bit depth 3
        "xd9n2c08.png", // bit depth 99
        "xdtn0g01.png", // no IDAT
        "xhdn0g08.png", // an IHDR CRC mismatch
        "xlfn0g04.png", // LF bytes added
        "xs1n0g01.png", // signature byte 1's high bit cleared
        "xs2n0g01.png", // signature byte 2 'Q'
        "xs4n0g01.png", // signature byte 4 lowercase
        "xs7n0g01.png", // signature byte 7 a space
    };
    inline for (corrupt) |name| {
        const bytes = try readSuite(name);
        defer testing.allocator.free(bytes);
        testing.expectError(error.Corrupt, decode("image/png", bytes)) catch |err| {
            std.debug.print("{s}: not reported corrupt\n", .{name});
            return err;
        };
    }
}

test "image decoding: an image larger than the limits is refused before its pixels" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readSuite("basn6a08.png");
    defer testing.allocator.free(bytes);
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, platform.Str.from("image/png"), platform.Bytes.from(bytes), .{ .max_dimension = 31, .max_pixels = 1 << 24 }));
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, platform.Str.from("image/png"), platform.Bytes.from(bytes), .{ .max_dimension = 1 << 15, .max_pixels = 32 * 32 - 1 }));
    // At the limits exactly, it decodes.
    const image = try platform.decodeImage(testing.allocator, platform.Str.from("image/png"), platform.Bytes.from(bytes), .{ .max_dimension = 32, .max_pixels = 32 * 32 });
    free(image);
}

test "image decoding: a type the platform does not decode is unsupported, whatever the bytes" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readSuite("basn6a08.png");
    defer testing.allocator.free(bytes);
    // The MIME type Crane determined decides (MIME Sniffing's image rules run
    // above the protocol); the platform does not sniff.
    // SVG is now decoded, but PNG bytes are not a valid SVG document.
    try testing.expectError(error.Corrupt, decode("image/svg+xml", bytes));
    try testing.expectError(error.UnsupportedFormat, decode("text/html", bytes));
    try testing.expectError(error.UnsupportedFormat, decode("", bytes));
}

test "image decoding: every truncation of a PNG is corrupt before its image data, and a partial image after" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (.{ "basn3p08.png", "basi6a16.png", "tbbn0g04.png", "oi9n2c16.png" }) |name| {
        const bytes = try readSuite(name);
        defer testing.allocator.free(bytes);
        const whole = try decode("image/png", bytes);
        defer free(whole);
        const idat = std.mem.indexOf(u8, bytes, "IDAT").? + 4;
        for (0..bytes.len) |len| {
            const image = decode("image/png", bytes[0..len]) catch |err| {
                // The dimensions are known once the first IDAT chunk begins.
                try testing.expectEqual(error.Corrupt, err);
                try testing.expect(len < idat);
                continue;
            };
            defer free(image);
            try testing.expect(len >= idat);
            // Every pixel is the whole image's, or not reached: transparent
            // black; a complete decode has them all.
            var i: usize = 0;
            while (i < image.pixels.len) : (i += 4) {
                const pixel = image.pixels.slice()[i..][0..4];
                if (std.mem.eql(u8, pixel, whole.pixels.slice()[i..][0..4])) continue;
                try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, pixel);
                try testing.expect(image.status != .complete);
            }
        }
    }
}

test "image decoding: a flipped byte anywhere never crashes or leaks" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (.{ "basn0g01.png", "basi3p02.png", "s01i3p01.png" }) |name| {
        const original = try readSuite(name);
        defer testing.allocator.free(original);
        const bytes = try testing.allocator.dupe(u8, original);
        defer testing.allocator.free(bytes);
        for (0..bytes.len) |i| {
            for ([_]u8{ 0x01, 0x80, 0xff }) |mask| {
                bytes[i] = original[i] ^ mask;
                defer bytes[i] = original[i];
                if (decode("image/png", bytes)) |image| free(image) else |_| {}
            }
        }
    }
}

/// `bytes` with chunk `name`'s data replaced by `data` and its CRC
/// recomputed; OWNED.
fn replaceChunk(bytes: []const u8, comptime name: []const u8, data: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    try out.appendSlice(testing.allocator, bytes[0..8]);
    var pos: usize = 8;
    while (pos + 12 <= bytes.len) {
        const len = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        const kind = bytes[pos + 4 ..][0..4];
        const body = if (std.mem.eql(u8, kind, name)) data else bytes[pos + 8 ..][0..len];
        var header: [8]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], @intCast(body.len), .big);
        @memcpy(header[4..8], kind);
        try out.appendSlice(testing.allocator, &header);
        try out.appendSlice(testing.allocator, body);
        var crc: std.hash.Crc32 = .init();
        crc.update(kind);
        crc.update(body);
        var tail: [4]u8 = undefined;
        std.mem.writeInt(u32, &tail, crc.final(), .big);
        try out.appendSlice(testing.allocator, &tail);
        pos += 12 + len;
    }
    return out.toOwnedSlice(testing.allocator);
}

test "image decoding: an out-of-range palette index is opaque black (PNG 13.1)" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readSuite("basn3p02.png");
    defer testing.allocator.free(bytes);
    const whole = try decode("image/png", bytes);
    defer free(whole);
    // Keep only the first palette entry: indexes 1-3 are out of range.
    var plte: [3]u8 = undefined;
    const at = std.mem.indexOf(u8, bytes, "PLTE").?;
    @memcpy(&plte, bytes[at + 4 ..][0..3]);
    const short = try replaceChunk(bytes, "PLTE", &plte);
    defer testing.allocator.free(short);
    const image = try decode("image/png", short);
    defer free(image);
    var saw_black = false;
    var i: usize = 0;
    while (i < image.pixels.len) : (i += 4) {
        const pixel = image.pixels.slice()[i..][0..4];
        if (std.mem.eql(u8, pixel, whole.pixels.slice()[i..][0..4])) continue;
        try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255 }, pixel);
        saw_black = true;
    }
    try testing.expect(saw_black);
}

test "image decoding: an indexed image without a palette, or a zero width, is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readSuite("basn3p02.png");
    defer testing.allocator.free(bytes);
    const empty_palette = try replaceChunk(bytes, "PLTE", "");
    defer testing.allocator.free(empty_palette);
    try testing.expectError(error.Corrupt, decode("image/png", empty_palette));
    var header: [13]u8 = undefined;
    const at = std.mem.indexOf(u8, bytes, "IHDR").?;
    @memcpy(&header, bytes[at + 4 ..][0..13]);
    std.mem.writeInt(u32, header[0..4], 0, .big);
    const zero_width = try replaceChunk(bytes, "IHDR", &header);
    defer testing.allocator.free(zero_width);
    try testing.expectError(error.Corrupt, decode("image/png", zero_width));
}

test "image decoding: an unknown critical chunk is corrupt, an unknown ancillary chunk is ignored" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readSuite("basn0g08.png");
    defer testing.allocator.free(bytes);
    const whole = try decode("image/png", bytes);
    defer free(whole);
    // Insert a chunk after IHDR (8 + 25 bytes).
    inline for (.{ .{ "abCd", true }, .{ "AbCd", false } }) |case| {
        var with: std.ArrayList(u8) = .empty;
        defer with.deinit(testing.allocator);
        try with.appendSlice(testing.allocator, bytes[0..33]);
        var chunk = [_]u8{ 0, 0, 0, 1 } ++ case[0].* ++ [_]u8{ 'x', 0, 0, 0, 0 };
        var crc: std.hash.Crc32 = .init();
        crc.update(chunk[4..9]);
        std.mem.writeInt(u32, chunk[9..13], crc.final(), .big);
        try with.appendSlice(testing.allocator, &chunk);
        try with.appendSlice(testing.allocator, bytes[33..]);
        if (case[1]) {
            const image = try decode("image/png", with.items);
            defer free(image);
            try testing.expectEqualSlices(u8, whole.pixels.slice(), image.pixels.slice());
        } else {
            try testing.expectError(error.Corrupt, decode("image/png", with.items));
        }
    }
}

test "image decoding: an APNG decodes to its default image" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/images/apng.png", testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(bytes);
    const image = try decode("image/png", bytes);
    defer free(image);
    try testing.expect(image.width > 0 and image.height > 0);
}

test "image decoding: without the capability every image is broken" {
    if (platform.capabilities.image_decoding != .unsupported) return;
    // HTML "update the image data": an image that cannot be decoded is
    // broken - the img element fires error. Nothing to call.
    try testing.expect(true);
}
