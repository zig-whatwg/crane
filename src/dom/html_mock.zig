//! HTML Mock - Minimal HTML functionality needed for DOM
//!
//! This module provides basic HTML-related functionality needed by DOM
//! without implementing the full HTML specification.
//!
//! Currently provides:
//! - Class name parsing for getElementsByClassName

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

/// Ordered set parser per DOM §3.1
/// Takes a string input and returns an ordered set of tokens.
/// Used for parsing space-separated class names.
///
/// Algorithm:
/// 1. Let inputTokens be the result of splitting input on ASCII whitespace
/// 2. Let tokens be a new ordered set
/// 3. For each token of inputTokens, append token to tokens
/// 4. Return tokens
///
/// Spec: https://dom.spec.whatwg.org/#ordered-sets
pub fn parseOrderedSet(allocator: Allocator, input: []const u8) !infra.List([]const u8) {
    var tokens = infra.List([]const u8).init(allocator);
    errdefer tokens.deinit();

    // Step 1: Split input on ASCII whitespace
    var iter = std.mem.tokenizeAny(u8, input, " \t\n\r\x0C"); // ASCII whitespace

    // Steps 2-3: For each token, append to ordered set (no duplicates)
    while (iter.next()) |token| {
        // Check if already in set (to maintain "ordered set" property)
        var already_exists = false;
        for (tokens.items()) |existing| {
            if (std.mem.eql(u8, existing, token)) {
                already_exists = true;
                break;
            }
        }

        if (!already_exists) {
            try tokens.append(token);
        }
    }

    // Step 4: Return tokens
    return tokens;
}

/// Check if an element has all classes in the given set
/// Used by getElementsByClassName to filter elements
///
/// classNames: Space-separated class names to check for
/// elementClass: The element's class attribute value
/// quirksMode: If true, use ASCII case-insensitive comparison
pub fn hasAllClasses(
    allocator: Allocator,
    classNames: []const u8,
    elementClass: []const u8,
    quirksMode: bool,
) !bool {
    // Parse both class lists
    var required_classes = try parseOrderedSet(allocator, classNames);
    defer required_classes.deinit();

    var element_classes = try parseOrderedSet(allocator, elementClass);
    defer element_classes.deinit();

    // Check if element has all required classes
    for (required_classes.items()) |required| {
        var found = false;
        for (element_classes.items()) |elem_class| {
            const matches = if (quirksMode)
                std.ascii.eqlIgnoreCase(required, elem_class)
            else
                std.mem.eql(u8, required, elem_class);

            if (matches) {
                found = true;
                break;
            }
        }

        if (!found) return false;
    }

    return true;
}

// ============================================================================
// Tests
// ============================================================================















