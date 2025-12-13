//! BCP 47 Locale Parsing and Negotiation
//!
//! Implements RFC 5646 (BCP 47) language tag parsing and ECMA-402 §9.2
//! locale negotiation algorithms.
//!
//! ## References
//! - RFC 5646: Tags for Identifying Languages
//! - UTS 35: Unicode Locale Data Markup Language
//! - ECMA-402 §6.2: Language Tags
//! - ECMA-402 §9.2: Locale and Parameter Negotiation

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const parser = @import("parser.zig");
pub const extensions = @import("extensions.zig");
pub const negotiation = @import("negotiation.zig");

// Re-export main types
pub const Locale = parser.Locale;
pub const HourCycle = extensions.HourCycle;
pub const UnicodeExtensions = extensions.UnicodeExtensions;
pub const TransformExtensions = extensions.TransformExtensions;
pub const LocaleMatcher = negotiation.LocaleMatcher;
pub const ResolvedLocale = negotiation.ResolvedLocale;
pub const bestAvailableLocale = negotiation.bestAvailableLocale;

test {
    _ = parser;
    _ = extensions;
    _ = negotiation;
}
