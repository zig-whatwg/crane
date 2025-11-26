//! WHATWG Quirks Mode Standard Implementation
//!
//! Implements the WHATWG Quirks Mode Standard for CSS parsing, selector matching,
//! and layout calculations in legacy compatibility modes.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//!
//! ## Overview
//!
//! Web browsers have three rendering modes:
//!
//! - **No-Quirks Mode** (standards mode): Modern rendering, proper DOCTYPE present
//! - **Quirks Mode**: Legacy compatibility for old documents without proper DOCTYPE
//! - **Limited-Quirks Mode**: Partial quirks (mainly table-related line height)
//!
//! ## Quirks Implemented
//!
//! ### CSS Value Quirks (Quirks Mode Only)
//!
//! - **Hashless Hex Color**: `color: ffffff` → `#ffffff` for specific properties
//! - **Unitless Length**: `width: 100` → `100px` for specific properties
//!
//! ### Selector Quirks (Quirks Mode Only)
//!
//! - **:active/:hover Quirk**: These pseudo-classes only match links when alone
//!
//! ### Layout Quirks (Quirks Mode and Limited-Quirks Mode)
//!
//! - **Line Height Calculation Quirk**: Empty inline boxes act as zero height
//! - **Blocks Ignore Line-Height Quirk**: No "strut" in line boxes
//!
//! ## Usage
//!
//! ```zig
//! const quirks = @import("quirks");
//!
//! // Check mode capabilities
//! const mode = quirks.QuirksMode.quirks;
//! if (mode.hasCssValueQuirks()) {
//!     // Apply CSS value quirks
//! }
//!
//! // Use context for parsing
//! const ctx = quirks.QuirksModeContext.init(.quirks);
//! if (ctx.allowsHashlessHexColor("color")) {
//!     // Parse "ffffff" as "#ffffff"
//! }
//!
//! // Check selector quirks
//! if (quirks.activeHoverQuirkApplies(.quirks, selectors, pseudo_types)) {
//!     // Only match if element is a link
//! }
//! ```
//!
//! ## Integration
//!
//! This module integrates with:
//! - **DOM**: Document stores quirks mode, set during HTML parsing
//! - **CSS Parser**: Uses context to apply value quirks
//! - **Selector Matcher**: Uses context to apply selector quirks
//! - **Layout Engine**: Uses mode to apply layout quirks

const std = @import("std");

// ============================================================================
// Public Exports
// ============================================================================

/// Quirks mode enumeration.
pub const mode = @import("mode.zig");
pub const QuirksMode = mode.QuirksMode;

/// Quirks mode context for threading through parsers.
pub const context = @import("context.zig");
pub const QuirksModeContext = context.QuirksModeContext;

/// Property allowlists for CSS quirks.
pub const constants = @import("constants.zig");

// Re-export commonly used functions
pub const isHashlessHexColorProperty = constants.isHashlessHexColorProperty;
pub const isUnitlessLengthProperty = constants.isUnitlessLengthProperty;
pub const isColorProperty = constants.isColorProperty;
pub const isLengthProperty = constants.isLengthProperty;

/// Selector quirk implementations.
pub const selector_quirks = @import("selector_quirks.zig");
pub const ActiveHoverQuirkAnalysis = selector_quirks.ActiveHoverQuirkAnalysis;
pub const PseudoClassType = selector_quirks.PseudoClassType;
pub const SimpleSelectorType = selector_quirks.SimpleSelectorType;
pub const analyzeCompoundSelector = selector_quirks.analyzeCompoundSelector;
pub const activeHoverQuirkApplies = selector_quirks.activeHoverQuirkApplies;

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}

test "quirks module integration" {
    // Test that all exports work together

    // Create context
    const ctx = QuirksModeContext.init(.quirks);

    // Check mode
    try std.testing.expect(ctx.isQuirksMode());
    try std.testing.expectEqual(QuirksMode.quirks, ctx.getMode());

    // Check CSS value quirks
    try std.testing.expect(ctx.allowsHashlessHexColor("color"));
    try std.testing.expect(ctx.allowsUnitlessLength("width"));

    // Check selector quirks
    try std.testing.expect(ctx.hasSelectorQuirks());

    // Check property helpers
    try std.testing.expect(isHashlessHexColorProperty("color"));
    try std.testing.expect(isUnitlessLengthProperty("width"));
    try std.testing.expect(isColorProperty("color"));
    try std.testing.expect(isLengthProperty("width"));

    // Check selector analysis
    const analysis = analyzeCompoundSelector(
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    );
    try std.testing.expect(analysis.quirkApplies());

    // Check full quirk check
    try std.testing.expect(activeHoverQuirkApplies(
        .quirks,
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    ));
}
