# /performance/'s social card

`card.zig` renders `card.png` (1200x630, og:image and twitter:image of `performance/index.html`) by
compositing this round's figures onto `base.png` with the WPT site's own digit atlas
(`tools/wpt_site/card/atlas.png`, its cuts and advances in `tools/wpt_site/card.zig`): one atlas
for both cards, so they cannot drift apart.

| File | What it is |
|------|------------|
| `base.png` | 1200x630: the card without its numbers - title, "Round", the progress line ("Since round 0:", time and memory, their `%` signs), the four browser columns, the two rows and their `%` signs, footer |
| `source.html` | the page it is drawn from, in the WPT site's faces (`../../wpt_site/assets/fonts/`) |

The positions in `source.html` (`COLUMN_RIGHT`, `TIME_BASELINE`, `MEMORY_BASELINE`,
`SINCE_TIME_RIGHT`, `SINCE_MEMORY_RIGHT`, `ROUND_BASELINE` and "Round"'s end) are `column_right`,
`time_baseline`, `memory_baseline`, `since_time_right`, `since_memory_right`, `round_baseline` and
`round_x` in `card.zig`: change them together. `zig build test` checks that each figure lands where its cell is.

## Remaking it

Made 2026-11-05 with Google Chrome 156 on macOS, device scale factor 1, headless (it takes no
focus); remade 2026-11-06 (lane perfr1, the progress line) with Google Chrome 156.0.8078.49 on the
pool host chat2, never on the Mac (wait for the page server to answer before Chrome loads the page:
a Chrome started first fails the load and leaves base.png as it was). From `tools/`:

```bash
python3 -m http.server 8742 --bind 127.0.0.1 &          # fonts do not load from file://
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
perl -e 'alarm 40; exec @ARGV' "$C" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --virtual-time-budget=5000 --user-data-dir=../tmp/card-prof \
  --window-size=1200,630 --screenshot=perf_bench/card/base.png \
  "http://127.0.0.1:8742/perf_bench/card/source.html"
kill %1; rm -rf ../tmp/card-prof
```

Open the image before committing it: a capture taken before the fonts load shows a fallback face.
