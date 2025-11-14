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

    try testing.expectEqual(FastPathType.simple_id, dom.detectFastPath("#main"));
    try testing.expectEqual(FastPathType.simple_id, dom.detectFastPath("#main-content"));
    try testing.expectEqual(FastPathType.simple_id, dom.detectFastPath("  #header  ")); // Trimmed
    try testing.expectEqual(FastPathType.simple_id, dom.detectFastPath("#_private"));
}

test "detectFastPath: simple class selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.simple_class, dom.detectFastPath(".container"));
    try testing.expectEqual(FastPathType.simple_class, dom.detectFastPath(".btn-primary"));
    try testing.expectEqual(FastPathType.simple_class, dom.detectFastPath("  .active  ")); // Trimmed
}

test "detectFastPath: simple tag selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.simple_tag, dom.detectFastPath("div"));
    try testing.expectEqual(FastPathType.simple_tag, dom.detectFastPath("span"));
    try testing.expectEqual(FastPathType.simple_tag, dom.detectFastPath("custom-element"));
    try testing.expectEqual(FastPathType.simple_tag, dom.detectFastPath("  p  ")); // Trimmed
}

test "detectFastPath: ID filtered selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.id_filtered, dom.detectFastPath("article#main .content"));
    try testing.expectEqual(FastPathType.id_filtered, dom.detectFastPath("div#container > p"));
}

test "detectFastPath: generic complex selectors" {
    const testing = std.testing;

    try testing.expectEqual(FastPathType.generic, dom.detectFastPath("div > p"));
    try testing.expectEqual(FastPathType.generic, dom.detectFastPath("div.container"));
    try testing.expectEqual(FastPathType.generic, dom.detectFastPath("p:first-child"));
    try testing.expectEqual(FastPathType.generic, dom.detectFastPath("[href]"));
    try testing.expectEqual(FastPathType.generic, dom.detectFastPath(""));
}

test "extractIdentifier: ID selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("main", dom.extractIdentifier("#main"));
    try testing.expectEqualStrings("header-nav", dom.extractIdentifier("#header-nav"));
}

test "extractIdentifier: class selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("container", dom.extractIdentifier(".container"));
    try testing.expectEqualStrings("btn-primary", dom.extractIdentifier(".btn-primary"));
}

test "extractIdentifier: tag selectors" {
    const testing = std.testing;

    try testing.expectEqualStrings("div", dom.extractIdentifier("div"));
    try testing.expectEqualStrings("custom-element", dom.extractIdentifier("custom-element"));
}
