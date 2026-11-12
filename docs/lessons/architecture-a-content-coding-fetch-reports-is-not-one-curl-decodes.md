# Architecture: A content coding Fetch reports is not one curl decodes

**Date**: 2026-11-12
**Lesson**: Crane's response bodies are decoded inside libcurl (CURLOPT_ACCEPT_ENCODING ""), so a coding is supported only if the linked curl was BUILT with it - a list in Fetch's code that names it proves nothing.

**Why**: Two places answer "does this user agent decode coding X?". HTTP-network fetch's
`filteredContentCoding` (src/fetch/algorithms/http_fetch.zig) and the HTTP cache's
transaction list both name `zstd` as supported, but build.zig builds curl with `.zstd = false`.
curl meets an encoding it was not built with by failing the transfer
(CURLE_BAD_CONTENT_ENCODING), which Fetch turns into a network error.

**What Happened**: Lane quick1 b2 triaged fetch/content-encoding/zstd/* (3 files, gate-blocking;
Chrome 157, Firefox 160 and Safari 27.2 pass all of them): every case was `TypeError: network
error`, though Fetch's own list says zstd is decoded. The
integrator ruled the fix (2026-11-12): Fetch decodes content codings itself - curl's decoding off
(CURLOPT_HTTP_CONTENT_DECODING 0), gzip/deflate through std.compress.flate or kit/inflate, br
through kit/brotli, zstd through std.compress.zstd - Chromium's architecture (the network
service's GzipSourceStream / BrotliSourceStream / ZstdSourceStream filters), with no new C
dependency, as its own batch with a perf pair (quick1 batch 3).

**Fix**: Until that batch lands, treat curl's build options (build.zig `buildStaticLibcurl`) as
the list of decodable codings. After it, the decoders and the reported list must be one table.

**Takeaway**: **A capability is what the linked library does, not what a list in our code says:
read the dependency's build options before trusting a "supported" table, and keep the table and
the decoder the same object.**
