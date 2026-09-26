//! Fetch "extract a body" (§5.2 BodyInit unions), for the Request and
//! Response constructors.
//!
//! The binding has already sorted a BodyInit by what the value is (WebIDL
//! §3.2.24, `conv.convertBodyInit`); this takes each kind's bytes and type:
//!
//!   ReadableStream   the stream itself is the body; no type
//!   Blob             its bytes; its type, if not empty
//!   BufferSource     a copy of its bytes; no type
//!   FormData         its multipart/form-data encoding; multipart/form-data
//!                    with the boundary
//!   URLSearchParams  its application/x-www-form-urlencoded serialization
//!   USVString        its UTF-8 encoding; text/plain;charset=UTF-8
//!
//! Every kind but a stream becomes a body of bytes here - the spec's stream
//! of them is made when script asks for it (`Response.body`), from those
//! bytes, which is the same stream: nothing can read or disturb it before.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const fetch = @import("fetch");
const blob_bytes = @import("dom").blob_bytes;
const srd = @import("streams_readable.zig");

pub const Error = error{ TypeError, OutOfMemory };

/// A body with type: the body, and the value for Content-Type, if any.
pub const Extracted = struct {
    allocator: std.mem.Allocator,
    /// The body's bytes, for every kind but a ReadableStream. Owned until
    /// taken.
    body: ?*fetch.internal.Body = null,
    /// The ReadableStream object given as the body: the body's stream IS
    /// this object. Not owned - the caller's wrapper holds it.
    stream: ?*runtime.Instance = null,
    /// The body's type, owned, or null.
    content_type: ?[]u8 = null,

    pub fn deinit(self: *Extracted) void {
        if (self.body) |b| b.deinit();
        if (self.content_type) |t| self.allocator.free(t);
        self.* = undefined;
    }

    /// The body, which is the caller's from here.
    pub fn takeBody(self: *Extracted) ?*fetch.internal.Body {
        const b = self.body;
        self.body = null;
        return b;
    }
};

/// Fetch "extract a body" from `object`, with `keepalive` (default false).
pub fn extract(allocator: std.mem.Allocator, object: typedefs.BodyInit, keepalive: bool) Error!Extracted {
    var result: Extracted = .{ .allocator = allocator };
    errdefer result.deinit();
    switch (object) {
        // ReadableStream: if keepalive is true, throw a TypeError; if object
        // is disturbed or locked, throw a TypeError. The body's stream is
        // object.
        .readable_stream => |stream| {
            if (keepalive) return error.TypeError;
            const slots = srd.streamOf(stream) orelse return error.TypeError;
            if (slots.disturbed or srd.isLocked(slots)) return error.TypeError;
            result.stream = stream;
            result.body = try fetch.internal.Body.fromSource(allocator, .none, null);
        },
        .xmlhttp_request_body_init => |inner| switch (inner) {
            // Blob: source is object, length its size, type its type if not
            // empty.
            .blob => |blob| {
                const bytes = blob_bytes.bytesOf(blob) orelse &.{};
                result.body = try fetch.internal.Body.fromBytes(allocator, bytes);
                var blob_type = interfaces.Blob.get_type(blob) catch return error.OutOfMemory;
                defer blob_type.deinit(blob.ctx.allocator);
                const type_bytes = blob_type.asSlice();
                if (type_bytes.len > 0) result.content_type = try allocator.dupe(u8, type_bytes);
            },
            // BufferSource: source is a copy of the bytes held by object. The
            // binding copied them (convertBodyInit); this is the copy the
            // body keeps.
            .buffer_source => |source| {
                const bytes = source.asBytes() catch &[_]u8{};
                result.body = try fetch.internal.Body.fromBytes(allocator, bytes);
            },
            // FormData: its multipart/form-data encoding, and that type with
            // the boundary the encoding used.
            .form_data => |form| {
                const boundary = multipartBoundary();
                const encoded = try encodeMultipart(allocator, form, &boundary);
                defer allocator.free(encoded);
                result.body = try fetch.internal.Body.fromBytes(allocator, encoded);
                result.content_type = try std.fmt.allocPrint(allocator, "multipart/form-data; boundary={s}", .{&boundary});
            },
            // URLSearchParams: the application/x-www-form-urlencoded
            // serializer over its list.
            .urlsearch_params => |params| {
                const serialized = interfaces.URLSearchParams.serialize(params) catch return error.OutOfMemory;
                defer if (serialized.len > 0) params.ctx.allocator.free(serialized);
                result.body = try fetch.internal.Body.fromBytes(allocator, serialized);
                result.content_type = try allocator.dupe(u8, "application/x-www-form-urlencoded;charset=UTF-8");
            },
            // Scalar value string: its UTF-8 encoding.
            .usvstring => |text| {
                result.body = try fetch.internal.Body.fromBytes(allocator, text);
                result.content_type = try allocator.dupe(u8, "text/plain;charset=UTF-8");
            },
        },
    }
    return result;
}

// =============================================================================
// multipart/form-data (HTML § 4.10.21.8)
// =============================================================================

const boundary_len = 38;

extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;
threadlocal var boundary_counter: u64 = 0;

/// A multipart/form-data boundary string: "----formdata-crane-" and 19
/// random alphanumerics. HTML leaves the string to the user agent; it must
/// not occur in the parts, which random bytes of this length do not.
fn multipartBoundary() [boundary_len]u8 {
    const prefix = "----formdata-crane-";
    const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var out: [boundary_len]u8 = undefined;
    @memcpy(out[0..prefix.len], prefix);
    // getentropy(2): std.crypto.random needs an Io in Zig 0.16. A boundary
    // only has to be unlikely to occur in the parts, so the counter below
    // is enough if it fails.
    var random: [boundary_len - prefix.len]u8 = undefined;
    if (getentropy(&random, random.len) != 0) {
        boundary_counter +%= 0x9E3779B97F4A7C15;
        var fallback = std.Random.DefaultPrng.init(boundary_counter);
        fallback.random().bytes(&random);
    }
    for (out[prefix.len..], random) |*c, r| c.* = alphabet[r % alphabet.len];
    return out;
}

/// The multipart/form-data encoding algorithm over `form`'s entry list, with
/// UTF-8. Owned.
fn encodeMultipart(allocator: std.mem.Allocator, form: *runtime.Instance, boundary: []const u8) Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    const entries = interfaces.FormData.getEntriesForIterable(form) orelse &.{};
    for (entries) |entry| {
        try out.appendSlice(allocator, "--");
        try out.appendSlice(allocator, boundary);
        try out.appendSlice(allocator, "\r\nContent-Disposition: form-data; name=\"");
        try appendEscapedName(allocator, &out, entry.name);
        try out.append(allocator, '"');
        switch (entry.value) {
            .usvstring => |value| {
                try out.appendSlice(allocator, "\r\n\r\n");
                try appendNormalizedNewlines(allocator, &out, value);
            },
            .file => |blob| {
                // A Blob in an entry list is a File named "blob" (XHR
                // "create an entry").
                try out.appendSlice(allocator, "; filename=\"");
                if (blob.stateAs(interfaces.File.State) != null) {
                    var name = interfaces.File.get_name(blob) catch return error.OutOfMemory;
                    defer name.deinit(blob.ctx.allocator);
                    try appendEscapedName(allocator, &out, name.asSlice());
                } else {
                    try out.appendSlice(allocator, "blob");
                }
                try out.appendSlice(allocator, "\"\r\nContent-Type: ");
                var blob_type = interfaces.Blob.get_type(blob) catch return error.OutOfMemory;
                defer blob_type.deinit(blob.ctx.allocator);
                const type_bytes = blob_type.asSlice();
                try out.appendSlice(allocator, if (type_bytes.len > 0) type_bytes else "application/octet-stream");
                try out.appendSlice(allocator, "\r\n\r\n");
                try out.appendSlice(allocator, blob_bytes.bytesOf(blob) orelse &.{});
            },
        }
        try out.appendSlice(allocator, "\r\n");
    }
    try out.appendSlice(allocator, "--");
    try out.appendSlice(allocator, boundary);
    try out.appendSlice(allocator, "--\r\n");
    return out.toOwnedSlice(allocator);
}

/// A field name or filename, escaped: LF as %0A, CR as %0D, " as %22. A
/// name's newlines are normalized to CRLF first ("convert to a list of
/// name-value pairs"), so a lone CR or LF is escaped as the pair.
fn appendEscapedName(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), name: []const u8) Error!void {
    var normalized: std.ArrayListUnmanaged(u8) = .empty;
    defer normalized.deinit(allocator);
    try appendNormalizedNewlines(allocator, &normalized, name);
    for (normalized.items) |c| switch (c) {
        '\n' => try out.appendSlice(allocator, "%0A"),
        '\r' => try out.appendSlice(allocator, "%0D"),
        '"' => try out.appendSlice(allocator, "%22"),
        else => try out.append(allocator, c),
    };
}

/// Every CR not followed by LF, and every LF not preceded by CR, as CRLF.
fn appendNormalizedNewlines(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), text: []const u8) Error!void {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\r') {
            try out.appendSlice(allocator, "\r\n");
            if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
        } else if (c == '\n') {
            try out.appendSlice(allocator, "\r\n");
        } else {
            try out.append(allocator, c);
        }
    }
}
