# Encoded bodies for fetch.loopback-gzip and fetch.loopback-br

`text-1m.html.gz` (145,201 bytes) and `text-1m.html.br` (107,126 bytes) are one generated
text, 1,048,583 bytes decoded (SHA-256 `e7e6571c0b7d6613f4cbd0659a83f3f5f4d7ad8fa93bf7a1ab8c266c86d84d18`),
encoded with `gzip -n -9` (Apple gzip 487.0.1) and `brotli -q 11` (brotli 1.2.0). The
benchmark server sends each as it is stored, with `Content-Encoding` from the extension
(`.gz`: gzip, `.br`: br; tools/perf_bench/server.zig), so every engine decodes it.

The text is generated, not taken from anywhere (no copyright): 12,486 lines of HTML-shaped list
items, line `i` (from 0) being

    <li class="row r{i mod 10}"><a href="/items/{i}">{w} {w} {w}</a><span>{(7 i) mod 1000}</span></li>

where each `{w}` is the next word from a linear congruential choice - `s = (s * 1103515245 +
12345) mod 2^31`, starting at `s = 1`, word `(s >> 16) mod 64` - over this list:

    alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar
    papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu red orange yellow green
    blue indigo violet black white grey silver gold copper iron tin lead zinc nickel cobalt carbon
    oxygen helium neon argon radon xenon krypton north south east west up down left right fast
    slow near

and lines are added until the text reaches 1 MiB (the line that crosses it included). It
compresses as an HTML page does (about 7x with gzip, 10x with Brotli), which keeps these
files small while each read still decodes a megabyte (lane quick1 b3, 2026-11-12).
