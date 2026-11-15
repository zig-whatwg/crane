# Architecture: A pull decoder fed in pieces needs whole parts, or calls sized to the input left

**Date**: 2026-11-12
**Lesson**: Zig's std decoders (flate, zstd) pull from a Reader and cannot stop mid-symbol when the input runs out; to feed one a body as it arrives, hand it whole parts where the format says how long they are (zstd), and where it does not (DEFLATE) bound each call by what the input left can surely make, rolling back the rare call that runs short.

**Why**: A content coding is decoded as the body arrives (Fetch's "handle content codings" per chunk; Chromium's filter streams), but std.compress.flate.Decompress and std.compress.zstd.Decompress read from a std.Io.Reader and treat its end as the stream's end. Given a chunk that stops inside a Huffman symbol or a block, they fail with their state half-advanced.

**What Happened**: Lane quick1 b3 moved content decoding from libcurl into Fetch (src/fetch/content_coding). src/compression/root.zig already drove the flate inflater for Compression Streams with eight bytes of zero lookahead, a checkpoint copy of the inflater, and calls bounded to 258 bytes of output, rolled back when they ran out of input or read into the lookahead. A 258-byte call for every 258 bytes of a megabyte body copies the ~4 KB inflater state about 4,000 times. A first version started each call at 32 KiB and shrank on a miss: near every chunk's end the large call ran out and was redone - about 40% of each 16 KB chunk's output decoded twice.

**Fix**:
- zstd frames itself (RFC 8878 3.1.1): the Frame_Header_Descriptor gives the header's length, each Block_Header the block's. Read the framing yourself, wait until a whole part is buffered (the magic, header and first block; then each block, with the checksum after the last), and give the decoder exactly that (`self.input = .fixed(bytes[0..unit])`, one `readVec`). It never meets its input's end and nothing is rolled back; check afterwards that it consumed exactly the part.
- DEFLATE does not: size each call from the input left - at most about two input bytes per output byte (a 15-bit literal code), times the stream's ratio so far, less a margin for a dynamic block header (~300 bytes) - so a call seldom runs out, and only the last few hundred bytes of a chunk go in 258-byte calls (`flate.zig` `stepFor`).
- Keep the room a call may use at twice its limit: Zig's inflater can return up to twice its limit when a stored block follows compressed output in one call.
- Prove it with every truncation and every one-byte corruption of a sample stream: none may crash the decoder (tests/fetch/quick1b3_content_coding_test.zig).

**Takeaway**: **Feed a pull decoder whole parts when the format sizes them, and calls sized to the input left when it does not - never a fixed tiny step and never a fixed large one.**
