# /frameworks/'s social card

`card.zig` renders `card.png` (1200x630, og:image and twitter:image of `frameworks/index.html`) by
compositing the pass rates onto `base.png` with the WPT site's own digit atlas
(`tools/wpt_site/card/atlas.png`, its cuts and advances in `tools/wpt_site/card.zig`): one atlas for
the progress, performance and frameworks cards, so they cannot drift apart. The rates use the atlas's
400/60px cut; the atlas has no decimal point, so `base.png` carries each rate's point and "%" at the
place `card.zig` computes (`right - digit - period`), and the rates are always written with one
decimal.

| File | What it is |
|------|------------|
| `base.png` | 1200x630: the card without its rates - title, the scope line, the Crane and Chrome column heads, the four rows (Angular, htmx, jQuery, TodoMVC apps) with each rate's point and "%", the line naming the frameworks that wait (React, Svelte, Vue), footer |
| `marks.png` | 120x80: ">" and "<" in the rates' cut, black on white, one per cell laid out as the WPT atlas's `of` row - the atlas has neither, and a rate such as 13,164 of 13,165 is written ">99.9%" on the page and the card alike (`rateOf`) |
| `source.html` | the page both are drawn from (`?part=base`, `?part=marks`), in the WPT site's faces (`../../wpt_site/assets/fonts/`), and the advances of ".", ">" and "<" (`?part=metrics`) |

The rows and the waiting line are the page's chart rows as they stood when `base.png` was drawn.
`card.zig`'s `row_titles` and `waiting_titles` name them; when the page's rows change (a framework
starts to run, another is added), `render` refuses with `error.CardOutOfDate` until `base.png` is
remade with the new `ROWS` and `WAITING`. The positions in `source.html` (`COLUMN_RIGHT`,
`ROW_BASELINE`) are `column_right` and `row_baseline` in `card.zig`, and the measured point advance
is `period`, the marks' `mark_advance` (marks.png made 2026-11-14 7:05 PM ET the same way): change them together. `zig build fw-matrix-test` checks that each rate lands in its cell
and that the base's cells hold only the point and the "%".

## Remaking it

Made 2026-11-14 with Chrome for Testing 157.0.8103.78 on the pool host chat2 (lane fw1 b8), device
scale factor 1, headless, never on the Mac. Wait for the page server to answer before Chrome loads
the page. From `tools/`:

```bash
python3 -m http.server 8743 --bind 127.0.0.1 &          # fonts do not load from file://
C=".../Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
F="--headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=5000"
perl -e 'alarm 40; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof --window-size=1200,630 \
  --screenshot=fw_matrix/card/base.png "http://127.0.0.1:8743/fw_matrix/card/source.html?part=base"
# Headless Chrome keeps its window wider than 120 px: take 600x80, keep the left 120x80.
perl -e 'alarm 40; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof --window-size=600,80 \
  --screenshot=../tmp/marks-wide.png "http://127.0.0.1:8743/fw_matrix/card/source.html?part=marks"
magick ../tmp/marks-wide.png -crop 120x80+0+0 +repage -strip -define png:color-type=2 fw_matrix/card/marks.png
perl -e 'alarm 40; exec @ARGV' "$C" $F --user-data-dir=../tmp/card-prof \
  --dump-dom "http://127.0.0.1:8743/fw_matrix/card/source.html?part=metrics" | grep -o '<pre id="metrics">[^<]*'
kill %1; rm -rf ../tmp/card-prof
```

Open the image before committing it: a capture taken before the fonts load shows a fallback face.
