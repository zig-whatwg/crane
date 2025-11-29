//! WebIDL typedef: BodyInit
//!
//! Manually implemented to handle body types:
//! - USVString (text body)
//! - Blob (binary data)
//! - BufferSource (ArrayBuffer, TypedArray, DataView)
//! - FormData
//! - URLSearchParams
//! - ReadableStream
//!
//! Per Fetch spec: typedef (ReadableStream or XMLHttpRequestBodyInit) BodyInit;
//! And: typedef (Blob or BufferSource or FormData or URLSearchParams or USVString) XMLHttpRequestBodyInit;

const runtime = @import("runtime");

/// BodyInit represents the initialization data for Request/Response body
pub const BodyInit = union(enum) {
    /// USVString - text body (most common case)
    string: []const u8,
    /// ArrayBuffer or TypedArray bytes
    buffer: []const u8,
    /// Blob pointer (opaque until Blob integration)
    blob_ptr: *const anyopaque,
    /// FormData pointer (opaque until FormData integration)
    form_data_ptr: *const anyopaque,
    /// URLSearchParams pointer (opaque until URLSearchParams integration)
    url_search_params_ptr: *const anyopaque,
    /// ReadableStream pointer (opaque until ReadableStream integration)
    readable_stream_ptr: *const anyopaque,
    /// Raw V8 value for fallback parsing
    v8_value: *const anyopaque,
};
