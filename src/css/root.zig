//! CSS Property Value Parser
//!
//! Implements CSS Syntax Module Level 3 tokenization, value parsing for CSS
//! property values, and finding a style sheet's @import rules. Supports quirks mode for hashless hex colors
//! and unitless lengths.
//!
//! ## WHATWG/W3C Specifications
//!
//! - CSS Syntax Module Level 3: https://drafts.csswg.org/css-syntax-3/
//! - CSS Color Level 4: https://drafts.csswg.org/css-color-4/
//! - CSS Values and Units Level 4: https://drafts.csswg.org/css-values-4/
//! - WHATWG Quirks Mode: https://quirks.spec.whatwg.org/
//!
//! ## Scope
//!
//! This module provides property value parsing, and a style sheet's @import
//! rules:
//! - CSS tokenizer (CSS Syntax 4.3, every token type)
//! - Color value parser (hex, rgb, named colors)
//! - Length value parser (px, em, %, etc.)
//! - Property parser framework for routing
//! - The @import rules a style sheet starts with (import_rules)
//! - A style sheet's rules, as "parse a stylesheet's contents" gives them
//!   (rules), for the CSSOM objects that wrap them (src/dom/cssom.zig)
//!
//! This module does NOT include:
//! - Selector parsing (see src/selector/)
//! - The grammar of at-rules other than @import
//! - Cascade/inheritance
//! - The CSSOM objects themselves (src/dom/cssom.zig, the CSS* impls)
//!
//! ## Quirks Mode Support
//!
//! Per WHATWG Quirks spec:
//! - §3.1 Hashless Hex Color: `color: ffffff` → `#ffffff`
//! - §3.2 Unitless Length: `width: 100` → `100px`
//!
//! ## Usage
//!
//! ```zig
//! const css = @import("css");
//!
//! // Create parser context with quirks mode
//! const ctx = css.ParserContext.init(allocator, .quirks);
//! defer ctx.deinit();
//!
//! // Parse a color value
//! const color = try css.ColorParser.parse(&tokenizer, "color", &ctx);
//!
//! // Parse a length value
//! const length = try css.LengthParser.parse(&tokenizer, "width", &ctx);
//! ```

const std = @import("std");

// ============================================================================
// Public Exports
// ============================================================================

/// CSS tokenizer for property values.
pub const tokenizer = @import("tokenizer.zig");
pub const Tokenizer = tokenizer.Tokenizer;
pub const Token = tokenizer.Token;
pub const TokenType = tokenizer.TokenType;

/// Parser context with quirks mode support.
pub const context = @import("context.zig");
pub const ParserContext = context.ParserContext;

/// Color value parser.
pub const color = @import("values/color.zig");
pub const Color = color.Color;
pub const ColorParser = color.ColorParser;

/// Length value parser.
pub const length = @import("values/length.zig");
pub const Length = length.Length;
pub const LengthUnit = length.LengthUnit;
pub const LengthParser = length.LengthParser;

/// Property value parser framework.
pub const property_parser = @import("property_parser.zig");
pub const PropertyParser = property_parser.PropertyParser;
pub const PropertyValue = property_parser.PropertyValue;
pub const PropertyType = property_parser.PropertyType;
pub const PropertyParseError = property_parser.PropertyParseError;
pub const Keyword = property_parser.Keyword;

/// The @import rules a style sheet starts with: its critical subresources.
pub const import_rules = @import("import_rules.zig");
pub const rules = @import("rules.zig");

/// CSS.supports(): the supports() functions of CSS Conditional 3.
pub const supports = @import("supports.zig");

/// CSSOM serializing idioms: serialize an identifier (CSS.escape()).
pub const serialize = @import("serialize.zig");

// Geometry Interfaces 1: the abstract point, rectangle and matrix algorithms the
// DOMPoint, DOMRect and DOMMatrix interfaces share.
pub const geometry = @import("geometry.zig");

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}
