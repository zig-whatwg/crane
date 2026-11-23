# Testing: Headless Chrome loses the bottom of a capture taken at the page's own height

**Date**: 2026-11-22
**Lesson**: A `--screenshot` whose `--window-size` height equals the page's own height can come back with its bottom 30-odd px wrong. The capture there is blank, or shows the page's first rows again. Capture in a taller window and crop.

**Why**: Headless Chrome's capture at an exact window height does not reliably raster the last strip of the viewport (Chrome for Testing 157.0.8103.78, `--headless=new`, device scale factor 1, on chat2). Which strip goes depends on the page: a 3800x312 sheet kept only its first three cells in its last row. At 1280x472 the same sheet lost its whole last row and showed its first row's glyph tops in its place. The 1200x630 card frame lost its footer on one capture and not on another.

**What Happened**: Lane fw2 redrew /frameworks/'s card parts (tools/fw_matrix/card/source.html). The glyph sheet's last face came out missing, which the sheet test caught. Then a re-captured base.png clipped the card's footer, which only looking at the rendered card caught: the base test checks the rows' area, not the footer.

**Fix**: Capture each part in a window taller than the page (1200x720 for a 1200x630 page, 1280x560 for 1280x472), then crop to its size on the Mac: `magick in.png -crop WxH+0+0 +repage -strip -define png:color-type=2 out.png`. That is an image step, not a build. Open every image before committing it. tools/fw_matrix/card/README.md has the commands.

**Takeaway**: **Never take a headless Chrome screenshot at exactly the page's height: capture taller, crop to size, and look at the bottom edge.**
