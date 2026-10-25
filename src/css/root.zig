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
//!   (rules), for the rule tree the CSSOM objects wrap (src/dom/style/rules.zig)
//!
//! - The style system's pure layer: values (style_values), the supported
//!   properties (properties), declaration blocks (declarations), the
//!   cascade and computed values (cascade, computed_style), media queries
//!   (media_queries)
//!
//! This module does NOT include:
//! - Selector parsing or matching (see src/selector/, src/dom/selector_matching.zig)
//! - The style engine that matches rules against the DOM (src/dom/style/)
//! - The CSSOM objects themselves (src/dom/style, the CSS* impls)
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
pub const syntax_definitions = @import("syntax_definitions.zig");
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

// The style system's pure layer (tmp/plans/style-design.md section 3.1):
// values, the supported properties, declaration blocks.
pub const style_values = @import("style_values.zig");
pub const math_values = @import("math_values.zig");
pub const properties = @import("properties.zig");
pub const declarations = @import("declarations.zig");
pub const media_queries = @import("media_queries.zig");
pub const computed_style = @import("computed_style.zig");
pub const cascade = @import("cascade.zig");
pub const text_transform = @import("text_transform.zig");
pub const color_scheme = @import("color_scheme.zig");
pub const resolved_urls = @import("resolved_urls.zig");
pub const svg_presentation = @import("svg_presentation.zig");
pub const image_layers = @import("image_layers.zig");
pub const image_values = @import("image_values.zig");
pub const font_style = @import("font_style.zig");
pub const font_width = @import("font_width.zig");
pub const font_settings = @import("font_settings.zig");
pub const font_variants = @import("font_variants.zig");
pub const font_values = @import("font_values.zig");
pub const font_support = @import("font_support.zig");
pub const font_family = @import("font_family.zig");
pub const font_request = @import("font_request.zig");
pub const font_shorthand = @import("font_shorthand.zig");
pub const font_size_adjust = @import("font_size_adjust.zig");
pub const font_system = @import("font_system.zig");

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}

pub const grid_tracks = @import("grid_tracks.zig");
pub const ui_values = @import("ui_values.zig");

pub const keyframe_values = @import("keyframe_values.zig");

pub const animation_values = @import("animation_values.zig");
pub const easing_values = @import("easing_values.zig");
pub const numeric_values = @import("numeric_values.zig");

pub const color_values = @import("color_values.zig");
pub const color_spaces = @import("color_spaces.zig");
pub const random_values = @import("random_values.zig");
