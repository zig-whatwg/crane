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
//! - Trusted Types (W3C Trusted Types for DOM XSS prevention)
//! - CSP (W3C Content Security Policy Level 3)
//! - HR-Time (W3C High Resolution Time)

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
pub const trusted_types = @import("trusted_types");
pub const csp = @import("csp");
pub const hr_time = @import("hr_time");

// Export WebIDL infrastructure modules
pub const v8 = @import("v8");
pub const js_bindings = @import("js_bindings");
pub const codegen = @import("codegen");

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
    _ = trusted_types;
    _ = csp;
    _ = v8;
    _ = js_bindings;
    _ = codegen;
}
