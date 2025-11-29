//! WebIDL typedef: HeadersInit
//!
//! Manually implemented to handle:
//! - sequence<sequence<ByteString>> (array of [key, value] pairs)
//! - record<ByteString, ByteString> (object with string keys/values)
//! - Headers (existing Headers object)

const runtime = @import("runtime");

/// HeadersInit represents the initialization data for Headers constructor
/// Per Fetch spec: typedef (sequence<sequence<ByteString>> or record<ByteString, ByteString>) HeadersInit;
pub const HeadersInit = union(enum) {
    /// Array of [name, value] pairs: [["Content-Type", "text/html"], ...]
    pairs: []const [2][]const u8,
    /// Object with header names as keys: { "Content-Type": "text/html", ... }
    record: []const HeaderEntry,
    /// Existing Headers object (clone its entries)
    headers_ptr: *const anyopaque,
    /// Raw V8 value for fallback parsing
    v8_value: *const anyopaque,
};

/// A single header entry (name, value pair)
pub const HeaderEntry = struct {
    name: []const u8,
    value: []const u8,
};
