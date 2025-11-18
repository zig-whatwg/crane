//! WHATWG Standards Implementation in Zig
//!
//! This library provides Zig implementations of WHATWG specifications:
//! - Infra (common primitives)
//! - WebIDL (type system)
//! - Runtime (WebIDL runtime infrastructure)
//! - DOM (Document Object Model)
//! - Encoding (text encoding/decoding)
//! - URL (URL parsing and manipulation)
//! - Console (console APIs)
//! - Streams (streaming data)
//! - MIME Sniff (MIME type detection)

const std = @import("std");

// Export all spec modules
pub const infra = @import("infra");
pub const webidl = @import("webidl");
pub const runtime = @import("runtime");
pub const dom = @import("dom");
pub const encoding = @import("encoding");
pub const url = @import("url");
pub const console = @import("console");
pub const streams = @import("streams");
pub const mimesniff = @import("mimesniff");
pub const interfaces = @import("interfaces");
pub const impls = @import("impls");

test {
    // Import all submodule tests
    _ = infra;
    _ = webidl;
    _ = runtime;
    _ = dom;
    _ = encoding;
    _ = url;
    _ = console;
    _ = streams;
    _ = mimesniff;
    _ = interfaces;
    _ = impls;
}
