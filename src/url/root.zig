//! WHATWG URL Standard Implementation for Zig
//!
//! This library provides a complete implementation of the WHATWG URL Standard.
//!
//! ## Modules
//!
//! - `validation` - Validation error types (40+ error types)
//! - More modules coming in Phase 1-8...
//!
//! ## Usage
//!
//! ```zig
//! const url = @import("url");
//! ```

const std = @import("std");

// Dependencies
pub const infra = @import("infra");
pub const encoding = @import("encoding");
pub const webidl = @import("webidl");

// Phase 1: Foundation modules
pub const validation = @import("validation");
pub const special_schemes = @import("special_schemes");
pub const windows_drive = @import("windows_drive");
pub const encode_sets = @import("encode_sets");
pub const percent_encoding = @import("percent_encoding");

// Phase 2: IDNA modules (Phase 2B: Full UTS46 implementation complete ✅)
pub const punycode = @import("idna/punycode.zig");
pub const idna = @import("idna/root.zig");
pub const idna_normalization = @import("idna/normalization.zig");
pub const idna_mapping = @import("idna/mapping.zig");
pub const idna_bidi = @import("idna/bidi.zig");
pub const idna_context = @import("idna/context.zig");
pub const idna_validation = @import("idna/validation.zig");

// Phase 3: Host parsing modules
pub const host = @import("host");
pub const ipv4_parser = @import("ipv4_parser");
pub const ipv6_parser = @import("ipv6_parser");
pub const host_parser = @import("parser/host_parser.zig");

// Phase 3: Host serialization modules
pub const ipv4_serializer = @import("ipv4_serializer");
pub const ipv6_serializer = @import("ipv6_serializer");
pub const host_serializer = @import("host_serializer");

// Phase 6: Additional features
pub const public_suffix = @import("public_suffix.zig");
pub const origin = @import("origin");
pub const blob_url = @import("blob_url");
pub const equivalence = @import("equivalence");

// Phase 7: Public WebIDL API (WebIDL-generated classes)
// Note: URL and URLSearchParams are separate modules in build.zig
// They import this module, so we can't import them here (circular dependency)
// Users should import them directly via build.zig module system:
//   const URL = @import("url").URL;  // This works from external code
//   const URLSearchParams = @import("url_search_params").URLSearchParams;

// Test helpers
pub const test_helpers = @import("test_helpers.zig");
pub const helpers = test_helpers; // Alias for benchmark compatibility

// Internal modules (exposed for benchmarking)
pub const internal = struct {
    pub const url_record = @import("url_record");
};

pub const parser = struct {
    pub const basic_url_parser = @import("basic_parser");
    pub const parser_state = @import("parser_state");
};

test "can import dependencies" {
    // Verify dependencies are accessible
    _ = infra;
    _ = encoding;
    _ = webidl;
}

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
