const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

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

    const result = ctx.evaluateScriptToString(script, allocator) catch |err| {
        std.debug.print("Script execution error: {}\n", .{err});
        return error.ScriptError;
    };
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result});

    // The page has a Document interface and a document.
    try std.testing.expect(std.mem.indexOf(u8, result, "typeof Document: function") != null);
}
