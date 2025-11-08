//! WHATWG MIME Sniffing Standard Implementation
//!
//! Spec: https://mimesniff.spec.whatwg.org/
//!
//! This library implements the WHATWG MIME Sniffing Standard, providing
//! algorithms for determining MIME types from byte patterns and parsing
//! Content-Type headers.

const std = @import("std");

// Re-export sub-modules
pub const constants = @import("constants.zig");
pub const mime_type = @import("mime_type.zig");

// Re-export common types and functions
pub const MimeType = mime_type.MimeType;
pub const parseMimeType = mime_type.parseMimeType;
pub const parseMimeTypeFromString = mime_type.parseMimeTypeFromString;
pub const serializeMimeType = mime_type.serializeMimeType;
pub const serializeMimeTypeToBytes = mime_type.serializeMimeTypeToBytes;
pub const minimizeSupportedMimeType = mime_type.minimizeSupportedMimeType;
pub const isValidMimeTypeString = mime_type.isValidMimeTypeString;
pub const isValidMimeTypeWithNoParameters = mime_type.isValidMimeTypeWithNoParameters;

// Phase 2: Pattern Matching
pub const pattern_matching = @import("pattern_matching.zig");

// Phase 3: MIME Type Predicates
pub const predicates = @import("predicates.zig");

// Phase 4: Resource Handling and Sniffing
pub const resource = @import("resource.zig");
pub const sniffing = @import("sniffing.zig");

// Re-export commonly used functions
pub const Resource = resource.Resource;
pub const determineSuppliedMimeType = resource.determineSuppliedMimeType;
pub const determineSuppliedMimeTypeFromPath = resource.determineSuppliedMimeTypeFromPath;
pub const readResourceHeader = resource.readResourceHeader;

// Sniffing functions
pub const sniffMimeType = sniffing.sniffMimeType;
pub const sniffInBrowsingContext = sniffing.sniffInBrowsingContext;
pub const sniffInImageContext = sniffing.sniffInImageContext;
pub const sniffInAudioOrVideoContext = sniffing.sniffInAudioOrVideoContext;
pub const sniffInFontContext = sniffing.sniffInFontContext;
pub const sniffInPluginContext = sniffing.sniffInPluginContext;
pub const sniffInStyleContext = sniffing.sniffInStyleContext;
pub const sniffInScriptContext = sniffing.sniffInScriptContext;
pub const sniffInTextTrackContext = sniffing.sniffInTextTrackContext;
pub const sniffInCacheManifestContext = sniffing.sniffInCacheManifestContext;
pub const identifyUnknownMimeType = sniffing.identifyUnknownMimeType;
pub const distinguishTextOrBinary = sniffing.distinguishTextOrBinary;

test {
    std.testing.refAllDecls(@This());
}
