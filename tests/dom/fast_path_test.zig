//! Tests for querySelector Fast Path Detection
//! Per WHATWG DOM Standard - querySelector optimization
//!
//! These tests verify the optimization logic for common selector patterns.

const std = @import("std");

// Import the fast_path module directly from source
// This allows testing internal implementation details
const fast_path = @import("../../src/dom/fast_path.zig");

const FastPathType = fast_path.FastPathType;
const detectFastPath = fast_path.detectFastPath;
const extractIdentifier = fast_path.extractIdentifier;

test "detectFastPath: simple ID selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.simple_id, detectFastPath("#main"));
    try testing.expectEqual(FastPathType.simple_id, detectFastPath("#main-content"));
    try testing.expectEqual(FastPathType.simple_id, detectFastPath("  #header  ")); // Trimmed
    try testing.expectEqual(FastPathType.simple_id, detectFastPath("#_private"));
}

test "detectFastPath: simple class selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.simple_class, detectFastPath(".container"));
    try testing.expectEqual(FastPathType.simple_class, detectFastPath(".btn-primary"));
    try testing.expectEqual(FastPathType.simple_class, detectFastPath("  .active  ")); // Trimmed
}

test "detectFastPath: simple tag selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.simple_tag, detectFastPath("div"));
    try testing.expectEqual(FastPathType.simple_tag, detectFastPath("span"));
    try testing.expectEqual(FastPathType.simple_tag, detectFastPath("custom-element"));
    try testing.expectEqual(FastPathType.simple_tag, detectFastPath("  p  ")); // Trimmed
}

test "detectFastPath: ID filtered selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.id_filtered, detectFastPath("article#main .content"));
    try testing.expectEqual(FastPathType.id_filtered, detectFastPath("div#container > p"));
}

test "detectFastPath: generic complex selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.generic, detectFastPath("div > p"));
    try testing.expectEqual(FastPathType.generic, detectFastPath("div.container"));
    try testing.expectEqual(FastPathType.generic, detectFastPath("p:first-child"));
    try testing.expectEqual(FastPathType.generic, detectFastPath("[href]"));
    try testing.expectEqual(FastPathType.generic, detectFastPath(""));
}

test "extractIdentifier: ID selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("main", extractIdentifier("#main"));
    try testing.expectEqualStrings("header-nav", extractIdentifier("#header-nav"));
}

test "extractIdentifier: class selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("container", extractIdentifier(".container"));
    try testing.expectEqualStrings("btn-primary", extractIdentifier(".btn-primary"));
}

test "extractIdentifier: tag selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("div", extractIdentifier("div"));
    try testing.expectEqualStrings("custom-element", extractIdentifier("custom-element"));
}
