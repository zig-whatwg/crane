# Spec Compliance: Safari's image decoder runs on this Mac - probe it

**Date**: 2026-10-12
**Lesson**: WebKit decodes images through ImageIO on Apple platforms, which is closed source but installed on every Mac: a 60-line C probe gives Safari's behaviour for any byte string, where reading WebKit's own image-decoders would give the GTK port's.

**Why**: Golden rule 2 needs the majority of Chrome, Firefox and Safari, and image decoding is decided in each engine's decoder, not its DOM code. Blink's and Gecko's decoders are readable (Skia codecs, libpng, Wuffs, image/decoders/), but Safari's is ImageIO: WebKit's `Source/WebCore/platform/image-decoders/` (libpng and friends) is what WPE and GTK use, and `ImageDecoderCG` only maps ImageIO's status to WebKit's. Reading that tree for "what Safari does" answers the wrong browser.

**What Happened**: Lane imgpart had to decide, per format and per kind of damage, when a truncated or corrupt image still fires `load`, what is drawn and whether `decode()` resolves. Blink and Gecko came from source (ImageResourceContent::UpdateImage, SkiaImageDecoderBase, Decoder::CompleteDecode, nsGIFDecoder2::BeginGIF). For Safari, a probe (`CGImageSourceCreateIncremental` + `CGImageSourceUpdateData(final)`, then `CGImageSourceGetStatus`, the pixel size from `CGImageSourceCopyPropertiesAtIndex`, `CGImageSourceCreateImageAtIndex`, and the drawn pixels compared row by row with the whole image) over WPT images cut at many lengths showed things no source reading would have: ImageIO reports `Complete` for every cut once it has a size; it needs a PNG's first IDAT chunk header for the size (as libpng does) but a GIF's whole first frame (unlike Gecko and Wuffs); it ignores PNG CRCs and even a bad filter byte; it decodes a PNG only chunk by chunk (a cut inside the one IDAT draws nothing, a cut between IDATs draws the earlier rows); and it returns an image for WPT's undecodable.png, which is why Safari fails createImageBitmap-invalid-args' "available but undecodable" subtest on wpt.fyi. Three of those decided majorities.

**Fix**:
1. Write the probe in the lane's scratch directory (C, `clang -framework ImageIO -framework CoreFoundation -framework CoreGraphics`); feed it the real WPT image and cuts or flips of it (a scratch script makes the variants).
2. Map ImageIO's answer through WebKit's own code: `ImageDecoderCG::encodedDataStatus` (UnexpectedEOF/InvalidData with all data = Error; Incomplete with a size = SizeAvailable), `CachedImage::finishLoading` (error only on Error or nothing to draw), `ImageLoader::decode` (rejects only when the native image is missing).
3. Cite the probe and the macOS version in the code comment beside the engine files read for the other two.

**Takeaway**: **For Safari's image (and other CoreGraphics/ImageIO-backed) behaviour, measure ImageIO on this machine instead of reading WebKit's non-Apple decoders - and check the result against Safari's wpt.fyi runs where a test exists.**
