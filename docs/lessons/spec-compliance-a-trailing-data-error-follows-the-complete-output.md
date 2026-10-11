# Spec Compliance: A trailing-data error follows the complete output

**Date**: 2026-10-10
**Lesson**: Decompression must enqueue the complete stream's output before reporting extra trailing bytes in that same chunk.

**Why**: Compression's "decompress and enqueue a chunk" step 5 enqueues the output, and step 6 then rejects unconsumed trailing data. A pending read can therefore receive valid output while the write and a later read reject.

**What Happened**: The first pure-Zig codec validated all container checksums and rejected extra bytes, but returned only InvalidData for a valid stream followed by junk. Its stack-local output was freed on that error. All six DEFLATE-format subtests in decompression-extra-input.any.js failed: the pending reader received a TypeError instead of the valid prefix. Blink's InflateTransformer::Inflate enqueues its accumulated buffers before reporting junk after Z_STREAM_END.

**Fix**: At that specific trailing-data check, transfer the completed output into an owned prefix on the failed codec. The native transformer takes the prefix, enqueues it, and then rejects. Codec destruction frees a prefix that nobody takes. Header, checksum and incomplete-stream errors still follow their own error path. A native allocator test pins both the error and the retained bytes; sa-decompression-trailing-output.html pins the ordering visible to script.

**Takeaway**: **An error return cannot express both earlier output and a later failure unless ownership of that output is explicit. Preserve the specification's ordering.**
