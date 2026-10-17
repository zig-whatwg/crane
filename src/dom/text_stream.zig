//! UTF-8 text streams shared by File API and Fetch.
//! File API §3.3.6; Fetch §5.3 textStream(); Encoding §7.5.

const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// Pipe an unlocked byte stream through a UTF-8 decoder in the receiver's
/// relevant realm. The existing source supplies chunks; this helper makes
/// no whole-Blob copy.
pub fn decode(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    // File API 2–3 / Fetch 4–5: a new decoder, set up with UTF-8,
    // fatal=false and ignoreBOM=false (the constructor defaults).
    const decoder = try interfaces.TextDecoderStream.call_constructor(ctx, .notPassed(), .notPassed());
    const generation = runtime.SlabAllocator.generationOf(decoder);
    // The transform controller owns the codec; this temporary wrapper is
    // not exposed to script. Its existing destructor leaves the graph alive.
    defer decoder.releaseIfUnwrapped(generation);

    // File API 4 / Fetch 6. Streams' internal "pipe through" asserts that
    // neither side is locked; the IDL operation checks the same conditions.
    // Blob supplies a fresh stream and Body has already checked unusable.
    // Both operations mark the pipe promise handled and return the readable.
    return interfaces.ReadableStream.call_pipeThrough(stream, .{
        .readable = try interfaces.TextDecoderStream.get_readable(decoder),
        .writable = try interfaces.TextDecoderStream.get_writable(decoder),
    }, .notPassed());
}
