//! A Blob's bytes, for the specifications that read them without a stream.
//!
//! Fetch's "extract a body" takes a Blob's bytes for a Request or Response
//! body, HTML's multipart/form-data encoding takes a File entry's, and
//! `fetch()` uploads them. No IDL member hands them over synchronously
//! (`bytes()` and `arrayBuffer()` are promises), and those callers may not
//! reach into Blob's impl - so Blob installs the step here, the shape of
//! `fetch_objects.zig`.
//!
//! The bytes are BORROWED and immutable for the Blob's life: a Blob never
//! changes its data (File API: "A Blob object refers to a byte sequence"),
//! which is what lets Gecko's BlobImpl and Blink's BlobDataHandle be read in
//! place. A caller copies what it keeps past the call - a body outlives the
//! Blob it was made from.
//!
//! Spec: https://w3c.github.io/FileAPI/#blob-section
//!
//! lint-impls: hook for Blob
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const interfaces = @import("interfaces");

pub const Steps = struct {
    /// `blob`'s bytes, borrowed (see above), or null when `blob` has no
    /// Blob state.
    bytes_of: *const fn (blob: *runtime.Instance) ?[]const u8,
    /// Give `blob` - new, from `interfaces.Blob.init`, with no bytes yet - a
    /// copy of `bytes`, and `mime_type` as its type (as the File API's
    /// constructors take one: lowercased, or empty when it cannot be one).
    set_bytes: *const fn (blob: *runtime.Instance, bytes: []const u8, mime_type: []const u8) anyerror!void,
};

var steps: ?Steps = null;

/// Called by Blob's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    process_start.assertInstalling();
    steps = s;
}

/// `blob`'s bytes, borrowed: copy what you keep. Null when Blob has
/// installed nothing, or `blob` is no Blob.
pub fn bytesOf(blob: *runtime.Instance) ?[]const u8 {
    const s = steps orelse return null;
    return s.bytes_of(blob);
}

/// A new Blob of `ctx` "representing" `bytes` (copied), with type
/// `mime_type` - XHR's blob response, which no IDL member makes. Unwrapped:
/// the caller wraps or holds it. Making one through Blob's interface installs
/// Blob's steps, so this works before any other Blob exists.
pub fn create(ctx: runtime.Context, bytes: []const u8, mime_type: []const u8) !*runtime.Instance {
    const blob = try interfaces.Blob.init(ctx.allocator, ctx);
    const generation = runtime.SlabAllocator.generationOf(blob);
    errdefer blob.releaseIfUnwrapped(generation);
    const s = steps orelse return error.NotSupported;
    try s.set_bytes(blob, bytes, mime_type);
    return blob;
}
