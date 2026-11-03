# The platform

Moved verbatim from AGENTS.md (2026-11-03). The core keeps the rule as one line and points here.

## The platform boundary

**Everything platform-specific goes through the `platform` protocol** (the user, 2026-10-09):
OS services (clocks, randomness, network, files, threads), page capabilities (permissions, dialogs,
pickers, media decoding, camera, clipboard...), the storage engine, crypto primitives and layout.
It is bound at build time like the engine (`-Dplatform=darwin|linux|testing`,
`-Dplatform-module=<path>` for a third-party platform, `-Dplatform-without=<capability>` to compile
one out). The contract is [docs/platform-protocol.md](../../docs/platform-protocol.md); the migration
steps are [docs/platform-protocol-recipes.md](../../docs/platform-protocol-recipes.md); the user's
decisions are in tmp/plans/platform-decisions.md.

- No new OS access outside `src/platform/` (std.fs, std.time clock reads, std.process, curl,
  sqlite, mbedtls, getenv, randomness). **Checked by `zig build lint-platform`** (part of
  `zig build test`) against `tools/platform_boundary_baseline.txt`, which only goes down.
- Old platform code stays until the migration step that replaces it retires it.
