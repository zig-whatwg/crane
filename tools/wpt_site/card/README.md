# The social card's images

`card.zig` renders the site's og:image (`card.png`, 1200x630) by compositing the headline numbers
onto `base.png` from the glyphs in `atlas.png`. Both images are drawn from `source.html` in the
site's own faces (`../assets/fonts/`), once, by headless Chrome, and committed. Nothing in the build
runs Chrome; the generator only decodes these two PNGs (`png.zig`).

| File | What it is |
|------|------------|
| `atlas.png` | 1210x306: Source Serif 4 tabular digits and comma in three cuts (600/132px, 400/60px, 600/40px), with slash and space in the two smaller ones, black on white, one glyph per cell at a fixed origin |
| `base.png` | 1200x630: the card without its numbers - title, labels, rules, footer |
| `source.html` | the page both are rendered from (`?part=atlas`, `?part=base`), and the advances (`?part=metrics`) |

## Remaking them

Made 2026-09-30 with Google Chrome 151 on macOS, device scale factor 1. From `tools/wpt_site/`:

```bash
python3 -m http.server 8731 --bind 127.0.0.1 &          # fonts do not load from file://
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
F="--headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=5000"
perl -e 'alarm 30; exec @ARGV' "$C" $F --user-data-dir=/tmp/card-prof --window-size=1210,306 \
  --screenshot=card/atlas.png "http://127.0.0.1:8731/card/source.html?part=atlas"
perl -e 'alarm 30; exec @ARGV' "$C" $F --user-data-dir=/tmp/card-prof --window-size=1200,630 \
  --screenshot=card/base.png "http://127.0.0.1:8731/card/source.html?part=base"
perl -e 'alarm 30; exec @ARGV' "$C" --headless=new --disable-gpu --user-data-dir=/tmp/card-prof \
  --virtual-time-budget=5000 --dump-dom "http://127.0.0.1:8731/card/source.html?part=metrics" | grep -o '<pre id="metrics">[^<]*'
kill %1; rm -rf /tmp/card-prof
```

Chrome 151 wrote the screenshot and then did not exit, hence the `alarm`. Open both images before
committing them - a capture taken before the fonts load shows a fallback face.

The metrics pass prints each glyph's advance (`getComputedTextLength`). They are the `digit`,
`comma`, `slash` and `space` fields of the three `Cut`s in `card.zig`, and the cell geometry
(`cell_w`, `cell_h`, `ox`, `baseline`, `row_y`) is `SETS` in `source.html`. The placements
(`left`, `headline_baseline`, `counts_baseline`, `column_step`) match the labels `?part=base` draws.
Change a size, a weight or a position in one place and change it in the other; `zig build test`
checks that every glyph cell the card uses has ink and that the numbers land under their labels.
