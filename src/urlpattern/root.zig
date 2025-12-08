//! WHATWG URLPattern Implementation
//!
//! This module implements the WHATWG URLPattern Standard which provides
//! URL matching and pattern extraction capabilities.
//!
//! See: https://urlpattern.spec.whatwg.org/
//!
//! ## Architecture
//!
//! The implementation is organized into several components:
//!
//! - **tokenizer** - Lexes pattern strings into tokens
//! - **parser** - Parses tokens into parts (TODO: Agent 1)
//! - **regex_generator** - Generates regex from parts (TODO: Agent 1)
//! - **canonicalize** - 8 component canonicalizers
//! - **constructor_string_parser** - Parses shorthand URL patterns (TODO)
//! - **constructor** - URLPattern construction (TODO)
//! - **matcher** - Pattern matching (test/exec) (TODO)
//! - **pcre2_ffi** - PCRE2 regex library bindings
//!
//! ## Usage
//!
//! ```zig
//! const urlpattern = @import("urlpattern");
//!
//! // Canonicalize a protocol
//! const protocol = try urlpattern.canonicalizeProtocol(allocator, "HTTPS");
//! defer allocator.free(protocol);
//! // protocol == "https"
//! ```

const std = @import("std");

// Core modules - Foundational layer (Agent 1)
pub const tokenizer = @import("tokenizer.zig");
pub const parser = @import("parser.zig");
pub const pcre2_ffi = @import("pcre2_ffi.zig");

// Middle layer - canonicalization and construction (Agent 2)
pub const canonicalize = @import("canonicalize.zig");

// TODO: regex_generator (Agent 1)
// pub const regex_generator = @import("regex_generator.zig");

// TODO: Middle layer - to be implemented
// pub const constructor_string_parser = @import("constructor_string_parser.zig");
// pub const constructor = @import("constructor.zig");
// pub const matcher = @import("matcher.zig");

// Re-export tokenizer types
pub const Token = tokenizer.Token;
pub const TokenType = tokenizer.TokenType;
pub const Tokenizer = tokenizer.Tokenizer;
pub const TokenizePolicy = tokenizer.TokenizePolicy;

// Re-export parser types
pub const Part = parser.Part;
pub const PartType = parser.PartType;
pub const PartModifier = parser.PartModifier;
pub const PatternParser = parser.PatternParser;
pub const Options = parser.Options;

// Re-export canonicalization functions
pub const canonicalizeProtocol = canonicalize.canonicalizeProtocol;
pub const canonicalizeUsername = canonicalize.canonicalizeUsername;
pub const canonicalizePassword = canonicalize.canonicalizePassword;
pub const canonicalizeHostname = canonicalize.canonicalizeHostname;
pub const canonicalizeIPv6Hostname = canonicalize.canonicalizeIPv6Hostname;
pub const canonicalizePort = canonicalize.canonicalizePort;
pub const canonicalizePathname = canonicalize.canonicalizePathname;
pub const canonicalizeOpaquePathname = canonicalize.canonicalizeOpaquePathname;
pub const canonicalizeSearch = canonicalize.canonicalizeSearch;
pub const canonicalizeHash = canonicalize.canonicalizeHash;

// Re-export error types
pub const CanonicalizationError = canonicalize.CanonicalizationError;

// Re-export PCRE2 types
pub const Regex = pcre2_ffi.Regex;
pub const Match = pcre2_ffi.Match;
pub const CompileOptions = pcre2_ffi.CompileOptions;

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
