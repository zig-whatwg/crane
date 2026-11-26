//! UTF-8 text streams shared by File API and Fetch, and the TextDecoderStream
//! property hook for the TextDecoderCommon mixin.
//! File API §3.3.6; Fetch §5.3 textStream(); Encoding §7.5.
//!
//! lint-impls: hook for TextDecoderStream

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const Hook = @import("hook.zig").Hook;

/// Immutable TextDecoderCommon properties of a TextDecoderStream instance.
pub const DecoderProps = struct {
    whatwg_name: []const u8,
    fatal: bool,
    ignore_bom: bool,
};

pub const PropsGetter = *const fn (instance: *runtime.Instance) ?DecoderProps;

var decoder_stream_props: Hook(?PropsGetter) = .init(null);

/// Installed by TextDecoderStream.installHooks() at process start.
pub fn installDecoderStreamProps(getter: PropsGetter) void {
    decoder_stream_props.install(getter);
}

/// Read TextDecoderCommon properties from a TextDecoderStream instance.
pub fn decoderStreamProps(instance: *runtime.Instance) ?DecoderProps {
    const getter = decoder_stream_props.get() orelse return null;
    return getter(instance);
}

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
