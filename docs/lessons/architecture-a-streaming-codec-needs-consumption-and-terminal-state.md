# Architecture: A streaming codec needs consumption and terminal state

**Date**: 2026-10-20

**Lesson**: A platform codec must expose consumed input, produced output and terminal state independently.

**Why**: A caller cannot distinguish an incomplete stream, a full output buffer and a complete stream with trailing bytes from an output slice alone. Those cases have different Compression Streams behavior.

**What Happened**: Brotli was present in Crane's generated IDL but both stream constructors rejected it. Wiring curl's Brotli feature alone would only repair HTTP decoding. A platform interface was also needed for script's incremental encoder and decoder, with errors and allocation lifetimes visible to native tests.

**Fix**: Give each codec an owned context and bounded, borrowed buffers. Return consumed/produced counts plus need_input, need_output or finished. Keep RFC 7932 decoding in the platform and the stricter trailing-data/flush policy in src/compression. Route Google's C allocation callbacks through the supplied Zig allocator, retaining the exact allocated size in an aligned header. Test tiny buffers, split input, trailing data, invalid streams and every allocation failure. That last test caught Google's encoder defaulting to process termination on OOM: compile it with BROTLI_ENCODER_CLEANUP_ON_OOM so allocation failure returns through the protocol. Bind disabled adapters to typed headless stubs so whole-operation conformance checks need no codec headers or symbols.

**Takeaway**: **The codec reports what it consumed and whether it ended; the web algorithm decides what that means.**

Design reference: [Chromium BrotliSourceStream](https://github.com/chromium/chromium/blob/main/net/filter/brotli_source_stream.cc). Crane's implementation and ownership model are independent; no Chromium code was copied.
