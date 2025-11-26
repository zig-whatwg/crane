//! Quirks Mode Constants
//!
//! Property allowlists for CSS quirks per WHATWG Quirks Mode Standard.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard: https://quirks.spec.whatwg.org/
//! - §3.1 Hashless Hex Color Quirk
//! - §3.2 Unitless Length Quirk
//!
//! ## Design
//!
//! CSS quirks only apply to specific properties. These allowlists define
//! which properties support which quirks. The lists are based on browser
//! implementations (Chrome, Firefox, WebKit) and the WHATWG spec.

const std = @import("std");

// ============================================================================
// Hashless Hex Color Quirk
// ============================================================================

/// Properties that allow hashless hex colors in quirks mode.
///
/// Per WHATWG Quirks spec §3.1, in quirks mode, CSS color values
/// that look like hex colors (3 or 6 hex digits) can be used without
/// the leading `#` for specific properties.
///
/// Example (quirks mode only):
/// ```css
/// color: ffffff;        /* → #ffffff */
/// background-color: fff; /* → #fff */
/// ```
///
/// This quirk does NOT apply to:
/// - CSS gradients (e.g., `linear-gradient(fff, 000)`)
/// - SVG properties
/// - Modern CSS features
pub const hashless_hex_color_properties = [_][]const u8{
    "color",
    "background-color",
    "border-color",
    "border-top-color",
    "border-right-color",
    "border-bottom-color",
    "border-left-color",
};

/// Check if a property allows hashless hex colors in quirks mode.
///
/// ## Parameters
/// - `property`: CSS property name (case-insensitive comparison)
///
/// ## Returns
/// `true` if the property is in the hashless hex color allowlist.
///
/// ## Example
/// ```zig
/// try std.testing.expect(isHashlessHexColorProperty("color"));
/// try std.testing.expect(isHashlessHexColorProperty("COLOR"));
/// try std.testing.expect(!isHashlessHexColorProperty("background"));
/// ```
pub fn isHashlessHexColorProperty(property: []const u8) bool {
    for (hashless_hex_color_properties) |allowed| {
        if (std.ascii.eqlIgnoreCase(property, allowed)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Unitless Length Quirk
// ============================================================================

/// Properties that allow unitless lengths in quirks mode.
///
/// Per WHATWG Quirks spec §3.2, in quirks mode, CSS length values
/// that are bare numbers (without units) are treated as pixel values
/// for specific properties.
///
/// Example (quirks mode only):
/// ```css
/// width: 100;           /* → 100px */
/// margin-left: 20;      /* → 20px */
/// ```
///
/// Note: The value `0` is always unitless in CSS (even in standards mode).
pub const unitless_length_properties = [_][]const u8{
    // Box model
    "width",
    "height",
    "min-width",
    "min-height",
    "max-width",
    "max-height",

    // Margin
    "margin",
    "margin-top",
    "margin-right",
    "margin-bottom",
    "margin-left",

    // Padding
    "padding",
    "padding-top",
    "padding-right",
    "padding-bottom",
    "padding-left",

    // Border width
    "border-width",
    "border-top-width",
    "border-right-width",
    "border-bottom-width",
    "border-left-width",

    // Typography
    "font-size",
    "line-height",
    "letter-spacing",
    "word-spacing",
    "text-indent",

    // Positioning
    "top",
    "right",
    "bottom",
    "left",

    // Other
    "vertical-align",
    "outline-width",
};

/// Check if a property allows unitless lengths in quirks mode.
///
/// ## Parameters
/// - `property`: CSS property name (case-insensitive comparison)
///
/// ## Returns
/// `true` if the property is in the unitless length allowlist.
///
/// ## Example
/// ```zig
/// try std.testing.expect(isUnitlessLengthProperty("width"));
/// try std.testing.expect(isUnitlessLengthProperty("WIDTH"));
/// try std.testing.expect(!isUnitlessLengthProperty("background"));
/// ```
pub fn isUnitlessLengthProperty(property: []const u8) bool {
    for (unitless_length_properties) |allowed| {
        if (std.ascii.eqlIgnoreCase(property, allowed)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Color Properties (for routing)
// ============================================================================

/// Properties that accept color values.
///
/// Used for property parser routing to determine which value parser to use.
pub const color_properties = [_][]const u8{
    "color",
    "background-color",
    "border-color",
    "border-top-color",
    "border-right-color",
    "border-bottom-color",
    "border-left-color",
    "outline-color",
    "text-decoration-color",
    "caret-color",
};

/// Check if a property accepts color values.
pub fn isColorProperty(property: []const u8) bool {
    for (color_properties) |allowed| {
        if (std.ascii.eqlIgnoreCase(property, allowed)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Length Properties (for routing)
// ============================================================================

/// Properties that accept length values.
///
/// Used for property parser routing to determine which value parser to use.
pub const length_properties = [_][]const u8{
    // Box model
    "width",
    "height",
    "min-width",
    "min-height",
    "max-width",
    "max-height",

    // Margin
    "margin",
    "margin-top",
    "margin-right",
    "margin-bottom",
    "margin-left",

    // Padding
    "padding",
    "padding-top",
    "padding-right",
    "padding-bottom",
    "padding-left",

    // Border width
    "border-width",
    "border-top-width",
    "border-right-width",
    "border-bottom-width",
    "border-left-width",

    // Typography
    "font-size",
    "line-height",
    "letter-spacing",
    "word-spacing",
    "text-indent",

    // Positioning
    "top",
    "right",
    "bottom",
    "left",

    // Other
    "vertical-align",
    "outline-width",
};

/// Check if a property accepts length values.
pub fn isLengthProperty(property: []const u8) bool {
    for (length_properties) |allowed| {
        if (std.ascii.eqlIgnoreCase(property, allowed)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "isHashlessHexColorProperty - allowed properties" {
    try std.testing.expect(isHashlessHexColorProperty("color"));
    try std.testing.expect(isHashlessHexColorProperty("COLOR"));
    try std.testing.expect(isHashlessHexColorProperty("Color"));
    try std.testing.expect(isHashlessHexColorProperty("background-color"));
    try std.testing.expect(isHashlessHexColorProperty("BACKGROUND-COLOR"));
    try std.testing.expect(isHashlessHexColorProperty("border-color"));
    try std.testing.expect(isHashlessHexColorProperty("border-top-color"));
    try std.testing.expect(isHashlessHexColorProperty("border-right-color"));
    try std.testing.expect(isHashlessHexColorProperty("border-bottom-color"));
    try std.testing.expect(isHashlessHexColorProperty("border-left-color"));
}

test "isHashlessHexColorProperty - disallowed properties" {
    try std.testing.expect(!isHashlessHexColorProperty("background"));
    try std.testing.expect(!isHashlessHexColorProperty("border"));
    try std.testing.expect(!isHashlessHexColorProperty("outline-color"));
    try std.testing.expect(!isHashlessHexColorProperty("width"));
    try std.testing.expect(!isHashlessHexColorProperty(""));
}

test "isUnitlessLengthProperty - allowed properties" {
    try std.testing.expect(isUnitlessLengthProperty("width"));
    try std.testing.expect(isUnitlessLengthProperty("WIDTH"));
    try std.testing.expect(isUnitlessLengthProperty("height"));
    try std.testing.expect(isUnitlessLengthProperty("margin"));
    try std.testing.expect(isUnitlessLengthProperty("margin-top"));
    try std.testing.expect(isUnitlessLengthProperty("padding"));
    try std.testing.expect(isUnitlessLengthProperty("border-width"));
    try std.testing.expect(isUnitlessLengthProperty("font-size"));
    try std.testing.expect(isUnitlessLengthProperty("top"));
    try std.testing.expect(isUnitlessLengthProperty("left"));
}

test "isUnitlessLengthProperty - disallowed properties" {
    try std.testing.expect(!isUnitlessLengthProperty("color"));
    try std.testing.expect(!isUnitlessLengthProperty("background"));
    try std.testing.expect(!isUnitlessLengthProperty("display"));
    try std.testing.expect(!isUnitlessLengthProperty(""));
}

test "isColorProperty - color properties" {
    try std.testing.expect(isColorProperty("color"));
    try std.testing.expect(isColorProperty("background-color"));
    try std.testing.expect(isColorProperty("outline-color"));
    try std.testing.expect(!isColorProperty("width"));
}

test "isLengthProperty - length properties" {
    try std.testing.expect(isLengthProperty("width"));
    try std.testing.expect(isLengthProperty("margin-top"));
    try std.testing.expect(isLengthProperty("font-size"));
    try std.testing.expect(!isLengthProperty("color"));
}
