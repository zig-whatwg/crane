# /frameworks/'s social card

`card.zig` renders `card.png` (1200x630, og:image and twitter:image of `frameworks/index.html`). It composes the card from three drawn parts and draws nothing new per run:

- **`base.png`** is the frame.
- **The WPT site's digit atlas** (`tools/wpt_site/card/atlas.png`, its cuts and advances in `tools/wpt_site/card.zig`) supplies each rate's digits. One atlas serves the progress, performance and frameworks cards, so they cannot drift apart.
- **`marks.png`** is the glyph sheet: every glyph the card writes that the atlas lacks.

The card has one row per chart row: the frameworks Crane runs, TodoMVC's apps, then the frameworks that cannot run yet ("can't run yet" where the others have their meter). The rows go between the frame's two rules, in the largest size they fit (`card.zig` `sizeFor`):

- **60px:** the atlas's `of` cut, 62px apart, up to five rows.
- **40px:** the atlas's `small` cut, the progress card's counts, 44px apart, up to seven rows.

A chart with more rows than that, or a row title with a character the sheet lacks, gets no card. `render` returns `error.CardOutOfDate` and logs why (`outOfDate`). A new framework is just another row until the card is full.

| File | What it is |
|------|------------|
| `base.png` | 1200x630: title, scope line, the Crane and Chrome column heads, the rules above and below the rows (`rows_top` 232, `rows_bottom` 572), footer. The rows' area is paper. |
| `marks.png` | 1280x472, black on white, one glyph per cell, 32 cells to a row, face by face: ">", "<" and "." in each rate size, each size's "%", and printable ASCII in the labels' two sizes (Public Sans 500, 28px and 22px). Each face's cells, origin and baseline are `card.zig`'s `Face`s. |
| `source.html` | The page all three are drawn from (`?part=base`, `?part=sheet`), in the WPT site's faces (`../../wpt_site/assets/fonts/`), and each face's advances (`?part=metrics`), which `card.zig` holds as `*_advances`. |

`source.html`'s `FACES`, `PER_ROW`, `COLUMN_RIGHT`, `RULE_TOP` and `RULE_BOTTOM` and `card.zig`'s faces, `column_right`, `rows_top` and `rows_bottom` change together. `zig build fw-matrix-test` checks these:

- every face's glyph has ink in its cell;
- the frame is paper between its rules;
- each rate lands in its cell at both sizes;
- the meters;
- the marks;
- the waiting rows;
- the refusals and their reasons.

## Remaking it

Made 2026-11-22 with Chrome for Testing 157.0.8103.78 on the pool host chat2 (lane fw2), headless at device scale factor 1, never on the Mac. Wait for the page server to answer before Chrome loads the page.

Both images are captured in a taller window and cropped to their size. At exactly the page's own height, headless Chrome's capture lost the bottom 30-odd px: the sheet's last face, the base's footer. Where the sheet lost its rows, the page's first row showed again. The crop needs ImageMagick, on the Mac, as an image step, not a build.

From `tools/`:

```bash
python3 -m http.server 8743 --bind 127.0.0.1 &          # fonts do not load from file://
C=".../Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
F="--headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=5000"
U=http://127.0.0.1:8743/fw_matrix/card/source.html
perl -e 'alarm 60; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof --window-size=1200,720 \
  --screenshot=../tmp/base-tall.png "$U?part=base"
perl -e 'alarm 60; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof --window-size=1280,560 \
  --screenshot=../tmp/marks-tall.png "$U?part=sheet"
perl -e 'alarm 60; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof --dump-dom "$U?part=metrics" \
  | grep -o '<pre id="metrics">[^<]*'                   # -> card.zig's *_advances
kill %1; rm -rf ../tmp/card-prof
# then, on the Mac:
magick base-tall.png -crop 1200x630+0+0 +repage -strip -define png:color-type=2 fw_matrix/card/base.png
magick marks-tall.png -crop 1280x472+0+0 +repage -strip -define png:color-type=2 fw_matrix/card/marks.png
```

Open both images before committing them. A capture taken before the fonts load shows a fallback face, and a face whose last row is missing fails the sheet test.
