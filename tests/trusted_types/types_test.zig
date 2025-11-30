//! Trusted Types - Core Type Tests
//!
//! Tests for TrustedHTML, TrustedScript, TrustedScriptURL, and TrustedType union.
//! Covers creation, stringification, immutability, and memory management.

const std = @import("std");
const testing = std.testing;
const trusted_types = @import("trusted_types");

// ============================================================================
// TrustedHTML Tests
// ============================================================================

test "TrustedHTML - creation and stringification" {
    const allocator = testing.allocator;

    var html = try trusted_types.TrustedHTML.create(allocator, "<div>Hello</div>");
    defer html.deinit();

    try testing.expectEqualStrings("<div>Hello</div>", html.toString());
    try testing.expectEqualStrings("<div>Hello</div>", html.toJSON());
}

test "TrustedHTML - empty string" {
    const allocator = testing.allocator;

    var html = try trusted_types.TrustedHTML.create(allocator, "");
    defer html.deinit();

    try testing.expectEqualStrings("", html.toString());
    try testing.expectEqualStrings("", html.toJSON());
}

test "TrustedHTML - unmanaged memory" {
    const static_html = "<p>Static content</p>";
    const html = trusted_types.TrustedHTML.createUnmanaged(static_html);
    // No deinit needed - unmanaged doesn't own memory

    try testing.expectEqualStrings("<p>Static content</p>", html.toString());
}

test "TrustedHTML - special characters" {
    const allocator = testing.allocator;

    var html = try trusted_types.TrustedHTML.create(allocator, "<div class=\"foo\" data-x='bar'>Content &amp; more</div>");
    defer html.deinit();

    try testing.expectEqualStrings("<div class=\"foo\" data-x='bar'>Content &amp; more</div>", html.toString());
}

test "TrustedHTML - unicode content" {
    const allocator = testing.allocator;

    var html = try trusted_types.TrustedHTML.create(allocator, "<div>Hello 世界 🌍</div>");
    defer html.deinit();

    try testing.expectEqualStrings("<div>Hello 世界 🌍</div>", html.toString());
}

// ============================================================================
// TrustedScript Tests
// ============================================================================

test "TrustedScript - creation and stringification" {
    const allocator = testing.allocator;

    var script = try trusted_types.TrustedScript.create(allocator, "console.log('test')");
    defer script.deinit();

    try testing.expectEqualStrings("console.log('test')", script.toString());
    try testing.expectEqualStrings("console.log('test')", script.toJSON());
}

test "TrustedScript - empty string" {
    const allocator = testing.allocator;

    var script = try trusted_types.TrustedScript.create(allocator, "");
    defer script.deinit();

    try testing.expectEqualStrings("", script.toString());
}

test "TrustedScript - multiline script" {
    const allocator = testing.allocator;

    const multiline =
        \\function foo() {
        \\  return 42;
        \\}
    ;

    var script = try trusted_types.TrustedScript.create(allocator, multiline);
    defer script.deinit();

    try testing.expectEqualStrings(multiline, script.toString());
}

test "TrustedScript - unmanaged memory" {
    const static_script = "alert('hello')";
    const script = trusted_types.TrustedScript.createUnmanaged(static_script);

    try testing.expectEqualStrings("alert('hello')", script.toString());
}

// ============================================================================
// TrustedScriptURL Tests
// ============================================================================

test "TrustedScriptURL - creation and stringification" {
    const allocator = testing.allocator;

    var url = try trusted_types.TrustedScriptURL.create(allocator, "https://example.com/script.js");
    defer url.deinit();

    try testing.expectEqualStrings("https://example.com/script.js", url.toString());
    try testing.expectEqualStrings("https://example.com/script.js", url.toJSON());
}

test "TrustedScriptURL - empty string" {
    const allocator = testing.allocator;

    var url = try trusted_types.TrustedScriptURL.create(allocator, "");
    defer url.deinit();

    try testing.expectEqualStrings("", url.toString());
}

test "TrustedScriptURL - with query and fragment" {
    const allocator = testing.allocator;

    var url = try trusted_types.TrustedScriptURL.create(allocator, "https://cdn.example.com/app.js?v=1.2.3#module");
    defer url.deinit();

    try testing.expectEqualStrings("https://cdn.example.com/app.js?v=1.2.3#module", url.toString());
}

test "TrustedScriptURL - data URL" {
    const allocator = testing.allocator;

    var url = try trusted_types.TrustedScriptURL.create(allocator, "data:text/javascript,console.log('hello')");
    defer url.deinit();

    try testing.expectEqualStrings("data:text/javascript,console.log('hello')", url.toString());
}

test "TrustedScriptURL - unmanaged memory" {
    const static_url = "https://trusted.example.com/lib.js";
    const url = trusted_types.TrustedScriptURL.createUnmanaged(static_url);

    try testing.expectEqualStrings("https://trusted.example.com/lib.js", url.toString());
}

// ============================================================================
// TrustedType Union Tests
// ============================================================================

test "TrustedType union - html variant" {
    const allocator = testing.allocator;

    const html = try trusted_types.TrustedHTML.create(allocator, "<span>test</span>");
    var trusted: trusted_types.TrustedType = .{ .html = html };
    defer trusted.deinit();

    try testing.expectEqualStrings("<span>test</span>", trusted.toString());
}

test "TrustedType union - script variant" {
    const allocator = testing.allocator;

    const script = try trusted_types.TrustedScript.create(allocator, "return 42;");
    var trusted: trusted_types.TrustedType = .{ .script = script };
    defer trusted.deinit();

    try testing.expectEqualStrings("return 42;", trusted.toString());
}

test "TrustedType union - script_url variant" {
    const allocator = testing.allocator;

    const url = try trusted_types.TrustedScriptURL.create(allocator, "https://example.com/main.js");
    var trusted: trusted_types.TrustedType = .{ .script_url = url };
    defer trusted.deinit();

    try testing.expectEqualStrings("https://example.com/main.js", trusted.toString());
}

// ============================================================================
// Memory Safety Tests
// ============================================================================

test "TrustedHTML - double deinit safety" {
    const allocator = testing.allocator;

    var html = try trusted_types.TrustedHTML.create(allocator, "<p>test</p>");
    html.deinit();
    html.deinit(); // Should be safe

    try testing.expectEqualStrings("", html.toString());
}

test "TrustedScript - double deinit safety" {
    const allocator = testing.allocator;

    var script = try trusted_types.TrustedScript.create(allocator, "test()");
    script.deinit();
    script.deinit(); // Should be safe

    try testing.expectEqualStrings("", script.toString());
}

test "TrustedScriptURL - double deinit safety" {
    const allocator = testing.allocator;

    var url = try trusted_types.TrustedScriptURL.create(allocator, "https://example.com");
    url.deinit();
    url.deinit(); // Should be safe

    try testing.expectEqualStrings("", url.toString());
}
