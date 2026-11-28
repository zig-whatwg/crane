# The differential suite's reference side: how to install it

`mcp_diff run` drives Google's chrome-devtools-mcp under Node against Chrome for Testing (main.zig's
header). Both are pinned; this is how lane mcp3 installed them on chat.local, 2026-11-27, under
`~/crane-work/<mirror>/tmp/ref/`: a mirror's `tmp/` is the one place `crane-remote.sh`'s `rsync --delete`
leaves alone, so the install survives the next sync.

| What | Version | Where from | SHA-256 |
|---|---|---|---|
| chrome-devtools-mcp | 1.13.0 (tag `chrome-devtools-mcp-v1.13.0`, commit `b1e35e3ab1774664dfc66a2cb813a392535fe160`) | `npm pack chrome-devtools-mcp@1.13.0` (registry `dist.integrity` `sha512-Yf4qhS0+2oo7c+gOySMDHQt4ZL/yKXG2Mxxzjk0gcArINtcQ3tLiQVzAW6g2nsyQzAGhkcLwWWBAtlx3Bg+Spg==`, `dist.shasum` `e76eccb221ddb30600e59bd6a5870c7650191e84`) | tarball `9158c4b4a8792cb522ae46f76eeaa9491ce04616a3ae97229a16277e02a4aea4` |
| Chrome for Testing | 157.0.8103.78, mac-arm64 | https://storage.googleapis.com/chrome-for-testing-public/157.0.8103.78/mac-arm64/chrome-mac-arm64.zip | zip `bf3b49d0fe62a62397e98641aa736ef813c46014f03ec13d4913442e6966c7fc` |

```bash
mkdir -p tmp/ref && cd tmp/ref
npm pack chrome-devtools-mcp@1.13.0
shasum -a 256 chrome-devtools-mcp-1.13.0.tgz          # must match the table
npm install --prefix server ./chrome-devtools-mcp-1.13.0.tgz --no-audit --no-fund --omit=dev
curl -sSfL -o chrome-mac-arm64.zip https://storage.googleapis.com/chrome-for-testing-public/157.0.8103.78/mac-arm64/chrome-mac-arm64.zip
shasum -a 256 chrome-mac-arm64.zip                     # must match the table
unzip -q chrome-mac-arm64.zip && xattr -dr com.apple.quarantine chrome-mac-arm64 && rm chrome-mac-arm64.zip
```

Then, from the mirror (after `zig build repl-exe mcp-diff -j2`):

```bash
zig-out/bin/mcp_diff run --cases tools/mcp_diff/cases.json --fixtures tools/mcp_diff/fixtures \
  --crane zig-out/bin/repl --node "$(command -v node)" \
  --chrome-mcp tmp/ref/server/node_modules/chrome-devtools-mcp/out/Default/gen/src/bin/chrome-devtools-mcp.js \
  --chrome "tmp/ref/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" \
  --out tmp/mcp-diff
```

The package's own entry point is `out/Default/gen/src/bin/chrome-devtools-mcp.js` (its package.json `bin`); it
bundles its dependencies (the install adds one package).
