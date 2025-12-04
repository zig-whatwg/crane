//! Formatting Commands Implementation
//!
//! Implements formatting-related execCommand operations:
//! - Inline formatting (bold, italic, underline, strikethrough, sub/superscript)
//! - Font commands (fontName, fontSize, foreColor, backColor, hiliteColor)
//! - Alignment commands (justifyLeft, justifyCenter, justifyRight, justifyFull)
//! - removeFormat (strip all formatting)
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//!
//! These commands require DOM manipulation through the editing host.
//! Current implementation validates input and returns success - actual DOM
//! manipulation requires integration with the DOM layer.

const std = @import("std");
const commands = @import("commands.zig");
const executor = @import("executor.zig");

pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const DocumentHandle = executor.DocumentHandle;

/// Text alignment options
pub const Alignment = enum {
    left,
    center,
    right,
    full,

    pub fn toCssValue(self: Alignment) []const u8 {
        return switch (self) {
            .left => "left",
            .center => "center",
            .right => "right",
            .full => "justify",
        };
    }
};

// =============================================================================
// Formatting Toggle Commands
// =============================================================================

/// Execute bold command
/// Wraps selection in <b> or <strong> (or removes if already bold)
pub fn executeBold(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .bold);
}

/// Execute italic command
/// Wraps selection in <i> or <em> (or removes if already italic)
pub fn executeItalic(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .italic);
}

/// Execute underline command
/// Wraps selection in <u> (or removes if already underlined)
pub fn executeUnderline(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .underline);
}

/// Execute strikethrough command
/// Wraps selection in <s> or <strike> (or removes if already struck)
pub fn executeStrikeThrough(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .strikeThrough);
}

/// Execute subscript command
/// Wraps selection in <sub> (or removes if already subscript)
pub fn executeSubscript(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .subscript);
}

/// Execute superscript command
/// Wraps selection in <sup> (or removes if already superscript)
pub fn executeSuperscript(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeInlineFormat(allocator, document, .superscript);
}

/// Generic inline formatting execution
fn executeInlineFormat(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) !CommandResult {
    _ = allocator;
    _ = document;

    // Implementation outline:
    // 1. Get current selection from document
    // 2. Check if selection already has this formatting
    // 3. If yes, remove the formatting elements
    // 4. If no, wrap selection in appropriate element
    // 5. Create undo entry

    const tag = switch (command) {
        .bold => "b",
        .italic => "i",
        .underline => "u",
        .strikeThrough => "s",
        .subscript => "sub",
        .superscript => "sup",
        else => return .{ .success = false },
    };
    _ = tag;

    // TODO: Implement actual DOM manipulation
    // For now, return success as placeholder
    return .{ .success = true };
}

/// Execute removeFormat command
/// Removes all formatting from selection
pub fn executeRemoveFormat(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Implementation outline:
    // 1. Get current selection
    // 2. Find all formatting elements within selection
    // 3. Replace formatting elements with their contents
    // 4. Create undo entry

    return .{ .success = true };
}

// =============================================================================
// Font Commands
// =============================================================================

/// Execute fontName command
/// Sets font family for selection
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
///
/// Algorithm:
/// 1. If value is empty string, return false
/// 2. Delete selection contents if not collapsed
/// 3. Get effective command value at selection boundary
/// 4. If styleWithCSS is true:
///    a. Wrap selection in <span style="font-family: [value]">
/// 5. Otherwise:
///    a. Wrap selection in <font face="[value]">
/// 6. Create undo entry
pub fn executeFontName(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const font_name = value orelse return .{
        .success = false,
        .error_message = "fontName requires a value",
    };

    // Empty font name is invalid
    if (font_name.len == 0) {
        return .{ .success = false, .error_message = "fontName cannot be empty" };
    }

    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. If collapsed, formatting applies to next typed character
    // 3. Otherwise wrap selection in <span> or <font>
    // 4. If styleWithCSS: <span style="font-family: [font_name]">
    // 5. Otherwise: <font face="[font_name]">
    // 6. Record undo entry

    return .{ .success = true };
}

/// Execute fontSize command
/// Sets font size for selection (1-7 scale or CSS size)
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-fontsize-command
///
/// Algorithm:
/// 1. Parse value as integer 1-7 (legacy HTML sizes) or CSS size
/// 2. Convert legacy sizes to CSS:
///    - 1 = x-small (10px)
///    - 2 = small (13px)
///    - 3 = medium (16px) - default
///    - 4 = large (18px)
///    - 5 = x-large (24px)
///    - 6 = xx-large (32px)
///    - 7 = xxx-large (48px)
/// 3. Delete selection contents if not collapsed
/// 4. If styleWithCSS is true:
///    a. Wrap selection in <span style="font-size: [css-size]">
/// 5. Otherwise:
///    a. Wrap selection in <font size="[1-7]">
/// 6. Create undo entry
pub fn executeFontSize(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const size_str = value orelse return .{
        .success = false,
        .error_message = "fontSize requires a value",
    };
    _ = allocator;
    _ = document;

    // Parse size (1-7 or CSS value)
    const size = std.fmt.parseInt(u8, size_str, 10) catch {
        // Not a number, might be CSS size (e.g., "12px", "1em", "large")
        // CSS sizes are passed through to style attribute
        return .{ .success = true };
    };

    // Legacy HTML font sizes must be 1-7
    if (size < 1 or size > 7) {
        return .{ .success = false, .error_message = "fontSize must be 1-7" };
    }

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. Map size 1-7 to CSS sizes if using styleWithCSS
    // 3. Wrap selection in <span style="font-size: ..."> or <font size="...">
    // 4. Record undo entry

    return .{ .success = true };
}

/// Execute foreColor command
/// Sets text color for selection
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
///
/// Algorithm:
/// 1. Parse value as CSS color (hex, rgb, named color, etc.)
/// 2. Normalize to 6-digit hex (#rrggbb) for consistency
/// 3. Delete selection contents if not collapsed
/// 4. If styleWithCSS is true:
///    a. Wrap selection in <span style="color: [value]">
/// 5. Otherwise:
///    a. Wrap selection in <font color="[value]">
/// 6. Create undo entry
///
/// Color formats accepted:
/// - Named colors: "red", "blue", "transparent"
/// - Hex: "#rgb", "#rrggbb", "#rrggbbaa"
/// - RGB: "rgb(r, g, b)", "rgba(r, g, b, a)"
/// - HSL: "hsl(h, s%, l%)", "hsla(h, s%, l%, a)"
pub fn executeForeColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const color = value orelse return .{
        .success = false,
        .error_message = "foreColor requires a value",
    };

    // Empty color is invalid
    if (color.len == 0) {
        return .{ .success = false, .error_message = "foreColor cannot be empty" };
    }

    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. Parse and validate color value
    // 3. Wrap selection in <span style="color: [color]"> or <font color="[color]">
    // 4. Record undo entry

    return .{ .success = true };
}

/// Execute backColor command
/// Sets background color for selection
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
///
/// Algorithm:
/// 1. Parse value as CSS color (same formats as foreColor)
/// 2. Delete selection contents if not collapsed
/// 3. Wrap selection in <span style="background-color: [value]">
///    (No legacy <font> equivalent exists for background color)
/// 4. Create undo entry
///
/// Note: backColor applies background to inline content. For block
/// background, use formatBlock with appropriate styling.
pub fn executeBackColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    const color = value orelse return .{
        .success = false,
        .error_message = "backColor requires a value",
    };

    // Empty color is invalid
    if (color.len == 0) {
        return .{ .success = false, .error_message = "backColor cannot be empty" };
    }

    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. Parse and validate color value
    // 3. Wrap selection in <span style="background-color: [color]">
    // 4. Record undo entry

    return .{ .success = true };
}

/// Execute hiliteColor command
/// Alias for backColor in most browsers
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-hilitecolor-command
///
/// Note: hiliteColor is effectively an alias for backColor in all modern
/// browsers. The distinction was historically that hiliteColor was meant
/// for text highlighting (like a highlighter pen) while backColor was for
/// general background color, but they are now equivalent.
pub fn executeHiliteColor(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    value: ?[]const u8,
) !CommandResult {
    return executeBackColor(allocator, document, value);
}

// =============================================================================
// Alignment Commands
// =============================================================================

/// Execute justify command
/// Sets text alignment for block containing selection
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
///
/// Algorithm:
/// 1. Find all block elements containing the selection
/// 2. For each block element:
///    a. If styleWithCSS is true:
///       - Set style="text-align: [left|center|right|justify]"
///    b. Otherwise:
///       - Set align="[left|center|right|justify]" attribute
/// 3. Create undo entry
///
/// Note: justifyLeft, justifyCenter, justifyRight, justifyFull all use
/// this common implementation with different alignment values.
pub fn executeJustify(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    alignment: Alignment,
) !CommandResult {
    _ = allocator;
    _ = document;

    const css_value = alignment.toCssValue();
    _ = css_value;

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. Find all block-level ancestors
    // 3. For each block:
    //    a. If styleWithCSS: set style.textAlign = alignment
    //    b. Otherwise: set align attribute
    // 4. Record undo entry

    return .{ .success = true };
}

/// Execute justifyLeft command
/// Aligns block to left
pub fn executeJustifyLeft(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .left);
}

/// Execute justifyCenter command
/// Centers block
pub fn executeJustifyCenter(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .center);
}

/// Execute justifyRight command
/// Aligns block to right
pub fn executeJustifyRight(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .right);
}

/// Execute justifyFull command
/// Justifies block (full width alignment)
pub fn executeJustifyFull(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .full);
}

// =============================================================================
// Query Functions
// =============================================================================

/// Query if formatting is active for current selection
pub fn queryFormattingState(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) bool {
    _ = allocator;
    _ = document;

    // Implementation outline:
    // 1. Get current selection
    // 2. Check if entire selection has the formatting
    // 3. Return true only if ALL of selection is formatted

    return switch (command) {
        .bold, .italic, .underline, .strikeThrough, .subscript, .superscript => {
            // TODO: Query DOM for formatting state
            return false;
        },
        .insertOrderedList, .insertUnorderedList => {
            // Check if selection is in a list
            return false;
        },
        else => false,
    };
}

/// Query formatting value for current selection
pub fn queryFormattingValue(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) ?[]const u8 {
    _ = allocator;
    _ = document;

    return switch (command) {
        .fontName => null, // TODO: Query current font
        .fontSize => null, // TODO: Query current size
        .foreColor => null, // TODO: Query current color
        .backColor, .hiliteColor => null, // TODO: Query current background
        .formatBlock => null, // TODO: Query current block type
        else => null,
    };
}

/// Query if formatting is indeterminate (mixed) for current selection
pub fn queryFormattingIndeterm(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) bool {
    _ = allocator;
    _ = document;
    _ = command;

    // Implementation outline:
    // 1. Get current selection
    // 2. Check if some parts have formatting and some don't
    // 3. Return true if mixed

    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "Alignment.toCssValue" {
    try std.testing.expectEqualStrings("left", Alignment.left.toCssValue());
    try std.testing.expectEqualStrings("center", Alignment.center.toCssValue());
    try std.testing.expectEqualStrings("right", Alignment.right.toCssValue());
    try std.testing.expectEqualStrings("justify", Alignment.full.toCssValue());
}

test "fontName requires value" {
    const allocator = std.testing.allocator;
    const result = try executeFontName(allocator, undefined, null);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.error_message != null);
}

test "fontName rejects empty string" {
    const allocator = std.testing.allocator;
    const result = try executeFontName(allocator, undefined, "");
    try std.testing.expect(!result.success);
}

test "fontName accepts valid font" {
    const allocator = std.testing.allocator;
    const result = try executeFontName(allocator, undefined, "Arial");
    try std.testing.expect(result.success);
}

test "fontSize requires value" {
    const allocator = std.testing.allocator;
    const result = try executeFontSize(allocator, undefined, null);
    try std.testing.expect(!result.success);
}

test "fontSize validates 1-7 range" {
    const allocator = std.testing.allocator;

    // Valid sizes
    for ([_][]const u8{ "1", "2", "3", "4", "5", "6", "7" }) |size| {
        const result = try executeFontSize(allocator, undefined, size);
        try std.testing.expect(result.success);
    }

    // Invalid sizes
    const invalid_result = try executeFontSize(allocator, undefined, "0");
    try std.testing.expect(!invalid_result.success);

    const too_large = try executeFontSize(allocator, undefined, "8");
    try std.testing.expect(!too_large.success);
}

test "fontSize accepts CSS values" {
    const allocator = std.testing.allocator;

    // CSS sizes pass through
    const px_result = try executeFontSize(allocator, undefined, "12px");
    try std.testing.expect(px_result.success);

    const em_result = try executeFontSize(allocator, undefined, "1.5em");
    try std.testing.expect(em_result.success);

    const named_result = try executeFontSize(allocator, undefined, "large");
    try std.testing.expect(named_result.success);
}

test "foreColor requires value" {
    const allocator = std.testing.allocator;
    const result = try executeForeColor(allocator, undefined, null);
    try std.testing.expect(!result.success);
}

test "foreColor rejects empty string" {
    const allocator = std.testing.allocator;
    const result = try executeForeColor(allocator, undefined, "");
    try std.testing.expect(!result.success);
}

test "foreColor accepts valid colors" {
    const allocator = std.testing.allocator;

    // Named color
    const named = try executeForeColor(allocator, undefined, "red");
    try std.testing.expect(named.success);

    // Hex color
    const hex = try executeForeColor(allocator, undefined, "#ff0000");
    try std.testing.expect(hex.success);

    // RGB
    const rgb = try executeForeColor(allocator, undefined, "rgb(255, 0, 0)");
    try std.testing.expect(rgb.success);
}

test "backColor requires value" {
    const allocator = std.testing.allocator;
    const result = try executeBackColor(allocator, undefined, null);
    try std.testing.expect(!result.success);
}

test "backColor rejects empty string" {
    const allocator = std.testing.allocator;
    const result = try executeBackColor(allocator, undefined, "");
    try std.testing.expect(!result.success);
}

test "hiliteColor delegates to backColor" {
    const allocator = std.testing.allocator;

    // Both should succeed with same input
    const hilite = try executeHiliteColor(allocator, undefined, "yellow");
    const back = try executeBackColor(allocator, undefined, "yellow");
    try std.testing.expectEqual(hilite.success, back.success);
}
