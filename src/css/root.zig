//! CSS Property Value Parser
//!
//! Implements CSS Syntax Module Level 3 tokenization and value parsing
//! for CSS property values. Supports quirks mode for hashless hex colors
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
//! This module provides ONLY property value parsing:
//! - CSS tokenizer for property values
//! - Color value parser (hex, rgb, named colors)
//! - Length value parser (px, em, %, etc.)
//! - Property parser framework for routing
//!
//! This module does NOT include:
//! - Selector parsing (see src/selector/)
//! - At-rules parsing
//! - Cascade/inheritance
//! - CSSOM
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

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}
