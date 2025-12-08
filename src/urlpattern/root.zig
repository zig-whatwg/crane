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
pub const regex_generator = @import("regex_generator.zig");

// Middle layer - canonicalization and construction (Agent 2)
pub const canonicalize = @import("canonicalize.zig");
pub const constructor_string_parser = @import("constructor_string_parser.zig");
pub const constructor = @import("constructor.zig");

// TODO: Matcher - to be implemented
// pub const matcher = @import("matcher.zig");

// Re-export tokenizer types
pub const Token = tokenizer.Token;
pub const TokenType = tokenizer.TokenType;
pub const Tokenizer = tokenizer.Tokenizer;
pub const TokenizePolicy = tokenizer.TokenizePolicy;
pub const TokenizeResult = tokenizer.TokenizeResult;
pub const tokenize = tokenizer.tokenize;

// Re-export parser types
pub const Part = parser.Part;
pub const PartType = parser.PartType;
pub const PartModifier = parser.PartModifier;
pub const PatternParser = parser.PatternParser;
pub const Options = parser.Options;
pub const ParseResult = parser.ParseResult;
pub const parsePatternString = parser.parsePatternString;
pub const identityEncoding = parser.identityEncoding;

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

// Re-export constructor string parser types
pub const URLPatternInit = constructor_string_parser.URLPatternInit;
pub const ConstructorStringParser = constructor_string_parser.ConstructorStringParser;
pub const parseConstructorString = constructor_string_parser.parse;

// Re-export PCRE2 types
pub const Regex = pcre2_ffi.Regex;
pub const Match = pcre2_ffi.Match;
pub const CompileOptions = pcre2_ffi.CompileOptions;

// Re-export regex generator types
pub const RegexGenerationResult = regex_generator.RegexGenerationResult;
pub const generateRegexAndNameList = regex_generator.generateRegexAndNameList;
pub const escapeRegexpString = regex_generator.escapeRegexpString;
pub const generateSegmentWildcardRegexp = regex_generator.generateSegmentWildcardRegexp;
pub const full_wildcard_regexp = regex_generator.full_wildcard_regexp;

// Re-export constructor types
pub const URLPattern = constructor.URLPattern;
pub const Component = constructor.Component;
pub const Input = constructor.Input;
pub const URLPatternOptions = constructor.URLPatternOptions;
pub const ConstructorError = constructor.ConstructorError;

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
