//! WHATWG Fetch Standard - Body Extraction Algorithms
//!
//! This module implements the body extraction algorithms from the Fetch spec
//! that convert BodyInit types to Body objects.
//!
//! Spec: https://fetch.spec.whatwg.org/#bodyinit-unions
//! Spec: https://fetch.spec.whatwg.org/#body-mixin

const std = @import("std");
const Allocator = std.mem.Allocator;
const body_mod = @import("body.zig");
const Body = body_mod.Body;
const BodySource = body_mod.BodySource;
const BodyWithType = body_mod.BodyWithType;

// =============================================================================
// BodyInit Union
// =============================================================================

/// BufferSource represents ArrayBuffer, TypedArray, or DataView.
/// Per WebIDL: typedef (ArrayBuffer or ArrayBufferView) BufferSource
pub const BufferSource = union(enum) {
    /// ArrayBuffer bytes
    array_buffer: []const u8,
    /// TypedArray bytes (Uint8Array, Int32Array, etc.)
    typed_array: []const u8,
    /// DataView bytes
    data_view: []const u8,

    /// Get the underlying bytes.
    pub fn bytes(self: BufferSource) []const u8 {
        return switch (self) {
            .array_buffer => |b| b,
            .typed_array => |b| b,
            .data_view => |b| b,
        };
    }
};

/// BodyInit union as defined in Fetch IDL.
///
/// typedef (ReadableStream or XMLHttpRequestBodyInit) BodyInit
/// typedef (Blob or BufferSource or FormData or URLSearchParams or USVString) XMLHttpRequestBodyInit
///
/// Spec: https://fetch.spec.whatwg.org/#bodyinit
///
/// ARCHITECTURAL NOTE: Several fields use *anyopaque because this module is designed
/// for standalone testing without runtime dependency. When integrated with the full
/// runtime, these should be *runtime.Instance (WebIDL interface instances).
/// See: specs/idl/streams.idl (ReadableStream), specs/idl/FileAPI.idl (Blob),
///      specs/idl/xhr.idl (FormData), specs/idl/url.idl (URLSearchParams)
pub const BodyInit = union(enum) {
    /// ReadableStream body source - should be *runtime.Instance when integrated.
    /// WebIDL type: ReadableStream (https://streams.spec.whatwg.org/#rs-class)
    readable_stream: *anyopaque,

    /// Blob body source (with metadata for extraction).
    blob: BlobInfo,

    /// BufferSource (ArrayBuffer, TypedArray, DataView).
    buffer_source: BufferSource,

    /// FormData body source - should be *runtime.Instance when integrated.
    /// WebIDL type: FormData (https://xhr.spec.whatwg.org/#interface-formdata)
    form_data: *anyopaque,

    /// URLSearchParams body source - should be *runtime.Instance when integrated.
    /// WebIDL type: URLSearchParams (https://url.spec.whatwg.org/#urlsearchparams)
    url_search_params: *anyopaque,

    /// USVString body source (UTF-8 encoded).
    string: []const u8,

    /// Blob info for extraction.
    pub const BlobInfo = struct {
        /// Blob WebIDL interface pointer - should be *runtime.Instance when integrated.
        /// WebIDL type: Blob (https://w3c.github.io/FileAPI/#blob-section)
        ptr: *anyopaque,
        /// Blob size in bytes.
        size: u64,
        /// Blob MIME type (may be empty).
        mime_type: []const u8,
        /// Blob bytes (for extraction).
        bytes: []const u8,
    };
};

// =============================================================================
// Content-Type Constants
// =============================================================================

/// Content-Type for plain text (USVString).
pub const CONTENT_TYPE_TEXT_PLAIN = "text/plain;charset=UTF-8";

/// Content-Type for URL-encoded form data.
pub const CONTENT_TYPE_FORM_URLENCODED = "application/x-www-form-urlencoded;charset=UTF-8";

/// Content-Type prefix for multipart form data.
pub const CONTENT_TYPE_MULTIPART_PREFIX = "multipart/form-data;boundary=";

// =============================================================================
// Safely Extract Body
// =============================================================================

/// Safely extract a body from a BodyInit.
///
/// Spec: "To safely extract a body from an object:
/// 1. If object is a ReadableStream object, return
///    (a body whose stream is object, source is null, length is null), null.
/// 2. Return the result of extracting object."
///
/// The safe version doesn't throw on disturbed/locked streams - it just
/// returns them as-is with null source and length.
pub fn safelyExtract(allocator: Allocator, object: BodyInit) !BodyWithType {
    switch (object) {
        .readable_stream => |stream_ptr| {
            // For ReadableStream, create body with null source and length.
            // The stream is used directly without extracting bytes.
            const body = try Body.fromSource(allocator, .none, null);
            errdefer body.deinit();

            // Store the stream pointer for later use.
            // Note: We'd need to extend Body struct to hold stream reference.
            // For now, create an empty body - stream integration comes later.
            _ = stream_ptr;

            return .{
                .body = body,
                .content_type = null,
            };
        },
        else => {
            // For all other types, delegate to extract.
            return try extract(allocator, object);
        },
    }
}

// =============================================================================
// Extract Body
// =============================================================================

/// Extract a body and Content-Type from a BodyInit.
///
/// Spec: "To extract a body from an object:
/// 1. Let stream, action, source, length, and type be null.
/// 2. Switch on object:
///    - Blob: Set source to object, length to size, action to read blob,
///            type to type if non-empty.
///    - BufferSource: Set source to copy of bytes, length to byte length.
///    - FormData: Set action to multipart encode, source to object,
///                type to multipart/form-data;boundary=...
///    - URLSearchParams: Set source to urlencoded serialize,
///                       length to byte length, type to application/x-www-form-urlencoded
///    - USVString: Set source to UTF-8 encode, length to byte length,
///                 type to text/plain;charset=UTF-8
/// 3. If source is byte sequence, create ReadableStream from it.
/// 4. If action is non-null, create ReadableStream with pull = action.
/// 5. Return ((stream, source, length), type)"
pub fn extract(allocator: Allocator, object: BodyInit) !BodyWithType {
    switch (object) {
        .readable_stream => |stream_ptr| {
            // ReadableStream - create body with stream, null source/length.
            const body = try Body.fromSource(allocator, .none, null);
            _ = stream_ptr;
            return .{
                .body = body,
                .content_type = null,
            };
        },

        .blob => |blob_info| {
            // Blob - source is blob, length is size, type is MIME type.
            const body = try Body.fromBytes(allocator, blob_info.bytes);
            errdefer body.deinit();

            // Set source to blob pointer.
            body.source = .{ .blob = blob_info.ptr };
            body.length = blob_info.size;

            // Content-Type is blob's MIME type if non-empty.
            const content_type: ?[]const u8 = if (blob_info.mime_type.len > 0)
                blob_info.mime_type
            else
                null;

            return .{
                .body = body,
                .content_type = content_type,
            };
        },

        .buffer_source => |buf| {
            // BufferSource - copy bytes, set length.
            const bytes = buf.bytes();
            const body = try Body.fromBytes(allocator, bytes);
            return .{
                .body = body,
                .content_type = null, // No Content-Type for raw buffer.
            };
        },

        .form_data => |form_data_ptr| {
            // FormData - multipart/form-data encode.
            // For now, create a mock body. Real implementation would call
            // encodeMultipartFormData().
            const result = try mockMultipartEncode(allocator, form_data_ptr);
            // Free the boundary and encoded bytes after we're done with them.
            defer allocator.free(result.boundary);
            defer allocator.free(result.bytes);

            const body = try Body.fromBytes(allocator, result.bytes);
            errdefer body.deinit();
            body.source = .{ .form_data = form_data_ptr };

            // Content-Type is multipart/form-data;boundary=...
            const content_type = try std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ CONTENT_TYPE_MULTIPART_PREFIX, result.boundary },
            );
            errdefer allocator.free(content_type);

            return .{
                .body = body,
                .content_type = content_type,
            };
        },

        .url_search_params => |params_ptr| {
            // URLSearchParams - serialize as application/x-www-form-urlencoded.
            // For now, create a mock body. Real implementation would use
            // src/url/form_urlencoded/serializer.zig.
            const serialized = try mockUrlSearchParamsSerialize(allocator, params_ptr);
            defer allocator.free(serialized);

            const body = try Body.fromBytes(allocator, serialized);
            return .{
                .body = body,
                .content_type = CONTENT_TYPE_FORM_URLENCODED,
            };
        },

        .string => |str| {
            // USVString - UTF-8 encode (already UTF-8 in Zig).
            const body = try Body.fromBytes(allocator, str);
            return .{
                .body = body,
                .content_type = CONTENT_TYPE_TEXT_PLAIN,
            };
        },
    }
}

// =============================================================================
// Multipart Encoding (Mock)
// =============================================================================

/// Mock result for multipart encoding.
const MultipartResult = struct {
    bytes: []const u8,
    boundary: []const u8,
};

/// Generate a multipart boundary string.
///
/// The boundary must:
/// 1. Be unique (not appear in content)
/// 2. Be 1-70 characters
/// 3. Consist of allowed characters per RFC 2046
fn generateBoundary(allocator: Allocator) ![]const u8 {
    // Generate a pseudo-random boundary using timestamp and counter.
    // In production, use a proper random source.
    const timestamp = @as(u64, @intCast(std.time.milliTimestamp()));

    return try std.fmt.allocPrint(
        allocator,
        "----WebKitFormBoundary{x}",
        .{timestamp},
    );
}

/// Mock multipart/form-data encoding.
///
/// TODO(xhr-spec): Replace with real multipart encoding when
/// XMLHttpRequest/FormData spec is implemented.
///
/// Real implementation should:
/// 1. For each entry in FormData:
///    - Write --boundary\r\n
///    - Write Content-Disposition: form-data; name="..."
///    - If File, add filename="..." and Content-Type
///    - Write \r\n\r\n
///    - Write value bytes
///    - Write \r\n
/// 2. Write --boundary--\r\n
fn mockMultipartEncode(allocator: Allocator, _: *anyopaque) !MultipartResult {
    const boundary = try generateBoundary(allocator);
    errdefer allocator.free(boundary);

    // For the mock, return an empty multipart body.
    var buffer: std.ArrayListUnmanaged(u8) = .{};
    errdefer buffer.deinit(allocator);

    // Write closing boundary.
    try buffer.appendSlice(allocator, "--");
    try buffer.appendSlice(allocator, boundary);
    try buffer.appendSlice(allocator, "--\r\n");

    const bytes = try buffer.toOwnedSlice(allocator);

    return .{
        .bytes = bytes,
        .boundary = boundary,
    };
}

// =============================================================================
// URLSearchParams Serialization (Mock)
// =============================================================================

/// Mock URLSearchParams serialization.
///
/// TODO(url-spec): Replace with real serialization using
/// src/url/form_urlencoded/serializer.zig.
fn mockUrlSearchParamsSerialize(allocator: Allocator, _: *anyopaque) ![]const u8 {
    // For the mock, return empty string.
    return try allocator.dupe(u8, "");
}

// =============================================================================
// Tests
// =============================================================================

test "extract string body" {
    const allocator = std.testing.allocator;

    const body_init = BodyInit{ .string = "Hello, World!" };
    const result = try extract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualStrings("Hello, World!", result.body.getBytes());
    try std.testing.expectEqualStrings(CONTENT_TYPE_TEXT_PLAIN, result.content_type.?);
    try std.testing.expectEqual(@as(?u64, 13), result.body.length);
}

test "extract buffer source body" {
    const allocator = std.testing.allocator;

    const data = [_]u8{ 1, 2, 3, 4, 5 };
    const body_init = BodyInit{
        .buffer_source = .{ .array_buffer = &data },
    };

    const result = try extract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualSlices(u8, &data, result.body.getBytes());
    try std.testing.expect(result.content_type == null);
    try std.testing.expectEqual(@as(?u64, 5), result.body.length);
}

test "extract blob body with mime type" {
    const allocator = std.testing.allocator;

    var dummy_blob: u8 = 0;
    const blob_bytes = "blob content";

    const body_init = BodyInit{
        .blob = .{
            .ptr = &dummy_blob,
            .size = blob_bytes.len,
            .mime_type = "image/png",
            .bytes = blob_bytes,
        },
    };

    const result = try extract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualStrings(blob_bytes, result.body.getBytes());
    try std.testing.expectEqualStrings("image/png", result.content_type.?);
    try std.testing.expectEqual(@as(?u64, blob_bytes.len), result.body.length);
}

test "extract blob body without mime type" {
    const allocator = std.testing.allocator;

    var dummy_blob: u8 = 0;
    const blob_bytes = "blob content";

    const body_init = BodyInit{
        .blob = .{
            .ptr = &dummy_blob,
            .size = blob_bytes.len,
            .mime_type = "", // Empty MIME type
            .bytes = blob_bytes,
        },
    };

    const result = try extract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualStrings(blob_bytes, result.body.getBytes());
    try std.testing.expect(result.content_type == null);
}

test "extract form data body (mock)" {
    const allocator = std.testing.allocator;

    var dummy_form_data: u8 = 0;
    const body_init = BodyInit{ .form_data = &dummy_form_data };

    const result = try extract(allocator, body_init);
    defer result.body.deinit();
    defer allocator.free(result.content_type.?);

    // Content-Type should start with multipart/form-data;boundary=
    try std.testing.expect(std.mem.startsWith(u8, result.content_type.?, CONTENT_TYPE_MULTIPART_PREFIX));
}

test "extract url search params body (mock)" {
    const allocator = std.testing.allocator;

    var dummy_params: u8 = 0;
    const body_init = BodyInit{ .url_search_params = &dummy_params };

    const result = try extract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualStrings(CONTENT_TYPE_FORM_URLENCODED, result.content_type.?);
}

test "safelyExtract with ReadableStream returns null source" {
    const allocator = std.testing.allocator;

    var dummy_stream: u8 = 0;
    const body_init = BodyInit{ .readable_stream = &dummy_stream };

    const result = try safelyExtract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expect(result.content_type == null);
    try std.testing.expect(result.body.length == null);
    try std.testing.expectEqual(BodySource.none, result.body.source);
}

test "safelyExtract with string delegates to extract" {
    const allocator = std.testing.allocator;

    const body_init = BodyInit{ .string = "test" };

    const result = try safelyExtract(allocator, body_init);
    defer result.body.deinit();

    try std.testing.expectEqualStrings("test", result.body.getBytes());
    try std.testing.expectEqualStrings(CONTENT_TYPE_TEXT_PLAIN, result.content_type.?);
}

test "BufferSource.bytes returns underlying data" {
    const data = [_]u8{ 10, 20, 30 };

    const buf1 = BufferSource{ .array_buffer = &data };
    try std.testing.expectEqualSlices(u8, &data, buf1.bytes());

    const buf2 = BufferSource{ .typed_array = &data };
    try std.testing.expectEqualSlices(u8, &data, buf2.bytes());

    const buf3 = BufferSource{ .data_view = &data };
    try std.testing.expectEqualSlices(u8, &data, buf3.bytes());
}

test "generateBoundary creates valid boundary" {
    const allocator = std.testing.allocator;

    const boundary = try generateBoundary(allocator);
    defer allocator.free(boundary);

    // Boundary should start with expected prefix.
    try std.testing.expect(std.mem.startsWith(u8, boundary, "----WebKitFormBoundary"));
    // Boundary should be reasonable length.
    try std.testing.expect(boundary.len > 20);
    try std.testing.expect(boundary.len < 70);
}
