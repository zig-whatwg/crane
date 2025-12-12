//! # Pure Zig Internationalization Library
//!
//! A pure Zig implementation of ECMA-402 Internationalization APIs,
//! designed to replace V8's ICU dependency.
//!
//! ## Architecture Overview
//!
//! This library implements WHATWG/ECMA-402 internationalization standards:
//! - BCP 47 locale parsing and negotiation (RFC 5646, UTS 35)
//! - Intl.DateTimeFormat (ECMA-402 §11)
//! - Intl.NumberFormat (ECMA-402 §12)
//! - Intl.Collator (ECMA-402 §8)
//! - Intl.PluralRules (ECMA-402 §13)
//! - Intl.Locale (ECMA-402 §10)
//! - Intl.ListFormat (ECMA-402 §15)
//! - Intl.RelativeTimeFormat (ECMA-402 §14)
//! - Intl.Segmenter (ECMA-402 §16)
//! - Intl.DisplayNames (ECMA-402 §17)
//!
//! ## Design Principles
//!
//! ### Memory Management
//! - All types take an allocator parameter (standard Zig pattern)
//! - No global caches (critical: ICU's global cache causes OOM)
//! - Per-instance state with proper cleanup via deinit()
//! - Use defer for cleanup immediately after allocation
//! - Test with std.testing.allocator to detect leaks
//!
//! ### Data Strategy
//! - Hybrid approach: compile-time embed Tier 1 locales (~2MB)
//! - Runtime loading for Tier 2 locales from binary files
//! - CLDR data processed at build time into optimized binary format
//! - Lazy loading of locale data to minimize startup cost
//!
//! ### Error Handling
//! - Use error unions consistently
//! - Specific error types per module (ParseError, FormatError, etc.)
//! - Match ECMA-402 error semantics for V8 integration
//!
//! ### V8 Integration
//! - C-compatible API exported for FFI
//! - Opaque handles for Zig objects
//! - Explicit memory management (create/destroy pairs)
//! - Thread-safe design (no global mutable state)
//!
//! ## Module Structure
//!
//! ```
//! src/intl/
//! ├── root.zig              # Public API exports (this file)
//! ├── locale/               # BCP 47 locale parsing and negotiation
//! │   ├── root.zig          # Locale type and parser
//! │   ├── parser.zig        # BCP 47 tag parser
//! │   ├── extensions.zig    # Unicode/Transform extensions
//! │   └── negotiation.zig   # Locale matching algorithms
//! ├── cldr/                 # CLDR data loading and access
//! │   ├── root.zig          # Data loading API
//! │   ├── loader.zig        # Runtime data loader
//! │   └── data.zig          # Embedded Tier 1 locale data
//! ├── datetime/             # DateTimeFormat implementation
//! ├── number/               # NumberFormat implementation
//! ├── collator/             # Collator implementation
//! ├── plural/               # PluralRules implementation
//! ├── segmenter/            # Segmenter implementation
//! └── list/                 # ListFormat implementation
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Locale Module - BCP 47 parsing and negotiation
// ============================================================================

pub const locale = @import("locale/root.zig");

/// Parsed BCP 47 language tag
pub const Locale = locale.Locale;

/// Unicode locale extensions (-u-)
pub const UnicodeExtensions = locale.UnicodeExtensions;

/// Transform extensions (-t-)
pub const TransformExtensions = locale.TransformExtensions;

/// Hour cycle preference
pub const HourCycle = locale.HourCycle;

/// Locale negotiation algorithms
pub const LocaleMatcher = locale.LocaleMatcher;

/// Result of locale resolution
pub const ResolvedLocale = locale.ResolvedLocale;

// ============================================================================
// CLDR Data Module
// ============================================================================

// pub const cldr = @import("cldr/root.zig");

// ============================================================================
// DateTime Module - Intl.DateTimeFormat
// ============================================================================

// TODO: datetime module needs Zig 0.15 API updates (std.fmt.formatIntBuf removed)
// Temporarily disabled until those updates are made.
// pub const datetime = @import("datetime/root.zig");
//
// /// Core DateTime type for date/time representation
// pub const DateTime = datetime.DateTime;
//
// /// Pattern-based formatting engine
// pub const pattern = datetime.pattern;
//
// /// Pattern token from parsed CLDR pattern
// pub const PatternToken = datetime.PatternToken;
//
// /// Locale-specific data for formatting (month names, weekdays, etc.)
// pub const LocaleData = datetime.LocaleData;
//
// /// Parse a CLDR/ICU pattern string into tokens
// pub const parsePattern = datetime.parsePattern;
//
// /// Format a DateTime using parsed pattern tokens
// pub const formatDateTime = datetime.formatDateTime;
//
// /// Format a DateTime to parts (for Intl.DateTimeFormat.formatToParts)
// pub const formatToParts = datetime.formatToParts;
//
// /// Free pattern tokens
// pub const freeTokens = datetime.freeTokens;
//
// /// Free parts array
// pub const freeParts = datetime.freeParts;
//
// /// Part from formatToParts output
// pub const Part = datetime.Part;
//
// /// Part type enum
// pub const PartType = datetime.PartType;

// ============================================================================
// Number Module - Intl.NumberFormat
// ============================================================================

// pub const number = @import("number/root.zig");
// pub const NumberFormat = number.NumberFormat;

// ============================================================================
// Collator Module - Intl.Collator
// ============================================================================

// pub const collator = @import("collator/root.zig");
// pub const Collator = collator.Collator;

// ============================================================================
// Plural Module - Intl.PluralRules
// ============================================================================

// pub const plural = @import("plural/root.zig");
// pub const PluralRules = plural.PluralRules;

// ============================================================================
// Common Types
// ============================================================================

/// Errors that can occur during locale parsing
pub const LocaleParseError = error{
    /// The locale tag is malformed
    InvalidTag,
    /// A subtag has invalid format
    InvalidSubtag,
    /// A subtag is too long
    SubtagTooLong,
    /// A subtag is too short
    SubtagTooShort,
    /// Invalid character in subtag
    InvalidCharacter,
    /// Duplicate extension singleton
    DuplicateExtension,
    /// Invalid extension format
    InvalidExtension,
    /// Memory allocation failed
    OutOfMemory,
};

/// Errors that can occur during formatting
pub const FormatError = error{
    /// Invalid option value
    InvalidOption,
    /// Unsupported locale
    UnsupportedLocale,
    /// Invalid date/time value
    InvalidValue,
    /// Memory allocation failed
    OutOfMemory,
};

// ============================================================================
// Tests
// ============================================================================

test {
    // Import all test modules
    _ = locale;
    // TODO: Re-enable datetime tests after Zig 0.15 API updates
    // _ = datetime;
}
