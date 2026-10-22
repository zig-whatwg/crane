# Testing image codecs

These dependencies follow Crane's nghttp2 source-package pattern: exact URLs
and content hashes in build.zig.zon, C sources compiled by build.zig. No tools
or test corpus are copied into the repository. The source packages are
unmodified; this directory contains only Crane's adapters and licence texts.

| Dependency | Version / commit | Licence |
|---|---|---|
| libjpeg-turbo | 3.1.3 / af9c1c268520a29adf98cad5138dafe612b3d318 | IJG and BSD-style; see licenses/libjpeg-turbo-LICENSE.md and licenses/README.ijg |
| NanoSVG | 239e102ec2c691f2902e20ace2ed36ee4a35cfe6 | zlib; licenses/nanosvg-LICENSE.txt |
| Expat | 2.9.0 / a76b1174c1ea52abb639a4c69d52b630a8a106a2 | MIT; licenses/expat-LICENSE.txt |

This software is based in part on the work of the Independent JPEG Group.

JPEG uses libjpeg-turbo's scalar C decoder on every target. No assembler,
CPU-detection global, system libjpeg, or native-code test corpus is required.
All sample-precision variants are compiled; static linking discards unused
encoder objects. The C adapter scopes its error manager, suspension source,
progress monitor, scanline and decoder to one call. It retains completed rows
and leaves unreached pixels transparent on truncated input. Its design follows
[Blink's JPEGImageReader and OutputRows](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/image-decoders/jpeg/jpeg_image_decoder.cc),
independently implemented. No browser source is copied.

SVG uses Expat's namespace-aware parser to feed NanoSVG's pinned private parser
entry points, followed by its rasterizer. Malformed XML and a non-SVG root fail.
It supports NanoSVG's paths, shapes, fills, strokes, transforms and gradients;
text, filters, masks, embedded images, animation and full CSS/layout are not a
complete SVG browser renderer. Scripts never execute and external resources
never load. Intrinsic/default sizing follows SVG2 8.12 and CSS Images 3 4.3.
The interface currently supplies no host viewport, so the fallback is 300x150.
NanoSVG uses signed fixed-point raster edges. Coordinates or flattened edge
slopes outside that representation return a corrupt, transparent partial
image with its known dimensions; they never reach its float-to-int conversion.

Native library contexts use their own malloc/free and are destroyed on every
return; the returned RGBA8 storage uses the platform caller's allocator. Tests
check size limits before pixel allocation and cleanup when that allocation
fails. Native allocations additionally require `leaks --atExit` verification.

Only the testing adapter selects these decoders. Darwin and Linux retain their
existing image-decoding choices. `zig build platform-image-codecs -j2` builds
the static dependencies alone; add `-Dtarget=aarch64-ios` to cross-compile them.
