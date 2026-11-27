# Architecture: A wake that stays woken serves one wait - make one per wait, and free the holder with the step that ends it

**Date**: 2026-11-27
**Lesson**: The platform's DevtoolsWake is a latch (one byte written, never read), so a long-lived waiter that reuses one wake either never hears a second event or spins; and an object a list holds must be freed by the step that unlists it, not only at shutdown.

**Why**: kit/posix `devtoolsWake` writes a byte to a pipe and never reads it back: "the read end stays readable, so every wait on it - this one and any later one - returns at once". That is right for its first use - a shutdown, which every later wait must also see - and wrong for a stream that waits for one message after another. A wake per session also costs two descriptors for as long as the session lives.

**What Happened**: Audit report C, H1, against the MCP server's Streamable HTTP transport (src/devtools/mcp/http.zig, lane mcp-http1). Each legacy `initialize` created a session with its own wake pipe. DELETE only marked the session deleted, release only decremented its count, and sessions were destroyed only in `stop()`. The `crane` daemon serves HTTP MCP on 9223 by default, so about 120 sessions exhausted the descriptor limit. Lane mcp3's red test ran 300 initialize cycles with 4 connection slots and read "312 sessions (cap 8), descriptors 31 -> 631, live bytes 247926 -> 365854". The same latch hid a second bug. A server message queued while the session's GET stream waited never woke the stream, because nothing woke it. Had something woken it, the stream would have spun, since a woken wake stays woken. The red test "a server message queued while the session's stream waits reaches it" timed out.

**Fix**:
1. Reference-count the session under the list's lock. The list holds one reference while the session is listed, and each request or stream holds one more. DELETE, idle expiry, eviction and stop unlist it, and the last release frees it. Bound the list with a cap and evict the least recently used session that nothing holds.
2. Give the waiter a fresh wake for each wait. Under the lock, if nothing is queued, make a wake if there is none and wait on it. A poster appends and wakes under the same lock. Once the wake has fired, the waiter closes it and sets it to null. A session then holds a descriptor only while its stream is actually waiting.
3. Pin it with counts: descriptors (F_GETFD over 0..4095), live bytes (DebugAllocator `enable_memory_limit`, `total_requested_bytes`) and listed sessions, taken after a warm-up past the cap and again after hundreds of cycles.

**Takeaway**: **Before reusing a wake or an event across waits, read whether it resets: a latch serves one wait. And the step that unlists an object (DELETE, expiry, eviction) must be the step that can free it - "freed at shutdown" is a leak for a server that runs for days.**
