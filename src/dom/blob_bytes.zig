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

const runtime = @import("runtime");

pub const Steps = struct {
    /// `blob`'s bytes, borrowed (see above), or null when `blob` has no
    /// Blob state.
    bytes_of: *const fn (blob: *runtime.Instance) ?[]const u8,
};

threadlocal var steps: ?Steps = null;

/// Called by Blob. Idempotent. Every caller holds a Blob already, so it is
/// installed before anyone can ask.
pub fn install(s: Steps) void {
    steps = s;
}

/// `blob`'s bytes, borrowed: copy what you keep. Null when Blob has
/// installed nothing, or `blob` is no Blob.
pub fn bytesOf(blob: *runtime.Instance) ?[]const u8 {
    const s = steps orelse return null;
    return s.bytes_of(blob);
}
