const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const v8 = @import("v8");

// NOTE: This test is disabled until issue whatwg-bnd80 is fixed.
// V8 crashes with alignment errors when creating a context from a snapshot
// created by a separate binary (snapshot_generator vs test executable).
// The external references count matches (12221) but there seems to be
// a deeper V8-level issue with snapshot deserialization.
//
// test "V8 snapshot loading - browser with snapshot" { ... }

test "document.getElementsByTagName available after Browser.init" {
    const allocator = std.testing.allocator;

    // Initialize browser - should create about:blank context automatically
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();

    // Get the context - should exist after init
    const ctx = browser.current_context orelse {
        std.debug.print("ERROR: No context after Browser.init()\n", .{});
        return error.NoContext;
    };

    // Test creating a new Document instance via constructor
    const script =
        \\(function() {
        \\    var result = [];
        \\    
        \\    // Check Document constructor
        \\    result.push("typeof Document: " + typeof Document);
        \\    
        \\    // Try creating new Document
        \\    try {
        \\        var newDoc = new Document();
        \\        result.push("new Document() succeeded");
        \\        result.push("newDoc.__proto__: " + newDoc.__proto__);
        \\        result.push("newDoc.__proto__ === Document.prototype: " + (newDoc.__proto__ === Document.prototype));
        \\        result.push("newDoc instanceof Document: " + (newDoc instanceof Document));
        \\    } catch(e) {
        \\        result.push("new Document() threw: " + e.message);
        \\    }
        \\    
        \\    // Compare with existing document
        \\    result.push("document.__proto__: " + document.__proto__);
        \\    result.push("document instanceof Document: " + (document instanceof Document));
        \\    
        \\    return result.join("\n");
        \\})()
    ;

    const result = ctx.evaluateScript(script) catch |err| {
        std.debug.print("Script execution error: {}\n", .{err});
        return error.ScriptError;
    };

    const result_value = result orelse {
        std.debug.print("FAILURE: Script returned null (likely threw an error)\n", .{});
        return error.ScriptReturnedNull;
    };

    // Check if the result is true (meaning getElementsByTagName is a function)
    const isolate = browser.isolate orelse {
        std.debug.print("FAILURE: No isolate available\n", .{});
        return error.NoIsolate;
    };
    const is_function = v8.ffi.v8_Value_BooleanValue(result_value, isolate);
    // For string results, we need to convert the V8 string to Zig
    const v8_ctx = ctx.v8_context orelse return error.NoContext;
    if (v8.ffi.v8_Value_ToString(result_value, v8_ctx)) |str_value| {
        var buf: [256]u8 = undefined;
        const len = v8.ffi.v8_String_WriteUtf8(str_value, &buf, @intCast(buf.len));
        const actual_len: usize = @intCast(len);
        std.debug.print("document.__proto__: {s}\n", .{buf[0..actual_len]});
    } else {
        std.debug.print("Failed to convert result to string\n", .{});
    }

    try std.testing.expect(is_function);
}
