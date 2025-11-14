//! Tests for console.dirxml() - DOM tree representation logging
//!
//! WHATWG Console Standard: console.dirxml()
//! https://console.spec.whatwg.org/#dirxml

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");
const mock_runtime = @import("mock_runtime.zig");

const console = console_mod.console;
const JSValue = webidl.JSValue;

test "dirxml - without runtime - logs simple values" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const data: []const JSValue = &.{
        .{ .string = "test" },
        .{ .number = 42.0 },
        .{ .boolean = true },
    };

    // Should log values as-is without runtime
    c.call_dirxml(data);
    // Note: No assertions since logging output is implementation-specific
    // Main goal is to ensure no crashes or memory leaks
}

test "dirxml - with runtime - converts DOM nodes" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    // Configure mock to treat string as DOM node
    mock_runtime.setTestDOMNode(runtime, true);
    mock_runtime.setTestDOMHTML(runtime, "<div>Hello World</div>");

    const data: []const JSValue = &.{
        .{ .string = "dom_node" },
    };

    // Should convert DOM node to HTML representation
    c.call_dirxml(data);
    // Note: No assertions since logging output is implementation-specific
    // Main goal is to ensure no crashes or memory leaks
}

test "dirxml - with runtime - formats non-DOM values" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    // Configure mock to NOT treat values as DOM nodes
    mock_runtime.setTestDOMNode(runtime, false);

    const data: []const JSValue = &.{
        .{ .string = "not a dom node" },
        .{ .number = 123.0 },
        .{ .boolean = false },
    };

    // Should apply optimal formatting via toString
    c.call_dirxml(data);
    // Note: No assertions since logging output is implementation-specific
    // Main goal is to ensure no crashes or memory leaks
}

test "dirxml - with runtime - mixed DOM and non-DOM" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    // Test with mixed data where some items are DOM nodes
    // In real implementation, isDOMNode would check each value individually
    // For this test, we'll just verify no crashes
    mock_runtime.setTestDOMNode(runtime, false);
    mock_runtime.setTestDOMHTML(runtime, "<p>Paragraph</p>");

    const data: []const JSValue = &.{
        .{ .string = "text" },
        .{ .number = 456.0 },
    };

    c.call_dirxml(data);
    // Note: No assertions since logging output is implementation-specific
    // Main goal is to ensure no crashes or memory leaks
}

test "dirxml - empty data" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const data: []const JSValue = &.{};

    // Should handle empty data gracefully
    c.call_dirxml(data);
}

test "dirxml - with runtime - empty data" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    const data: []const JSValue = &.{};

    // Should handle empty data gracefully with runtime
    c.call_dirxml(data);
}

test "dirxml - null and undefined values" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    const data: []const JSValue = &.{
        .null,
        .undefined,
    };

    // Should handle null/undefined values
    c.call_dirxml(data);
}

test "dirxml - large DOM tree representation" {
    const allocator = std.testing.allocator;

    var c = try console_mod.console.console.init(allocator);
    defer c.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    c.runtime = runtime;

    // Configure mock with a large HTML structure
    mock_runtime.setTestDOMNode(runtime, true);
    const large_html =
        \\<div id="container">
        \\  <header>
        \\    <h1>Title</h1>
        \\    <nav>
        \\      <ul>
        \\        <li><a href="#">Link 1</a></li>
        \\        <li><a href="#">Link 2</a></li>
        \\      </ul>
        \\    </nav>
        \\  </header>
        \\  <main>
        \\    <p>Content goes here.</p>
        \\  </main>
        \\</div>
    ;
    mock_runtime.setTestDOMHTML(runtime, large_html);

    const data: []const JSValue = &.{
        .{ .string = "dom_tree" },
    };

    // Should handle large DOM structures
    c.call_dirxml(data);
}
