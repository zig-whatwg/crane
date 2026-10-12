# Workflow: Check what a WPT resource serves before choosing what to support

**Date**: 2026-10-12
**Lesson**: The 89 security-features img-tag files read their request headers back from image pixels - and the image is a BMP, not the PNG the plan assumed.

**Why**: Decision 19 chose a PNG-only test decoder for the WPT runner, reasoning from "images on the web". The tests that motivated the work load `/common/security-features/subresource/image.py`, whose `encode_string_as_bmp_image` writes an uncompressed 24-bit BMP and answers `Content-Type: image/bmp`.

**What Happened**: Lane imgdec read image.py before writing a decoder, found the BMP, and asked; the user amended the decision (19a) to add a Zig BMP decoder beside the PNG one. Had the PNG decoder landed alone, none of the 89 files would have moved, with no error to say why: an undecodable image is simply broken, and the tests reject.

**Fix**: Before choosing formats, encodings or protocols to support for a set of WPT files, open the server-side handler or resource they load (`*.py`, `*.headers`, the file itself) and record what it actually serves. The test decoder's fixtures now include image.py's own output (tests/platform/fixtures/image-py-{28,29}.bmp).

**Takeaway**: **Read the resource the tests load, not the tests' description of it: a WPT handler's real output decides what Crane must support.**
