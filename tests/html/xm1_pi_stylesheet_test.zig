//! CSSOM 6.3.4: a PI owns a fetched sheet, with ordinary owner teardown.
const std = @import("std");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

fn openXml(browser: *browser_mod.Browser, source: []const u8) !void {
    const encoder = std.base64.standard.Encoder;
    const data = try std.testing.allocator.alloc(u8, encoder.calcSize(source.len));
    defer std.testing.allocator.free(data);
    _ = encoder.encode(data, source);
    const url = try std.fmt.allocPrint(std.testing.allocator, "data:application/xhtml+xml;base64,{s}", .{data});
    defer std.testing.allocator.free(url);
    try browser.navigate(url, .window);
}

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try openXml(browser,
        \\<?xml version="1.0"?>
        \\<?xml-stylesheet href="data:text/css,%3Aroot%7Bz-index%3A3%7D" type="text/css"?>
        \\<html xmlns="http://www.w3.org/1999/xhtml"><head/><body/></html>
    );
    _ = try browser.runEventLoopBlocking(200);
    try browser.current_context.?.runScript(
        \\globalThis.pi = document.firstChild;
        \\globalThis.oldSheet = pi.sheet;
        \\if (!oldSheet || oldSheet.ownerNode !== pi || document.styleSheets[0] !== oldSheet) throw new Error('PI sheet ownership');
        \\if (getComputedStyle(document.documentElement).zIndex !== '3') throw new Error('PI sheet not applied');
        \\pi.data = 'href="data:text/css,%3Aroot%7Bz-index%3A7%7D" type="text/css"';
        \\if (oldSheet.ownerNode !== null) throw new Error('old PI sheet still attached');
    );
    _ = try browser.runEventLoopBlocking(200);
    try browser.current_context.?.runScript(
        \\if (!pi.sheet || pi.sheet === oldSheet || getComputedStyle(document.documentElement).zIndex !== '7') throw new Error('PI data change');
        \\globalThis.retainedSheet = pi.sheet;
        \\pi.remove();
        \\if (pi.sheet !== null || retainedSheet.ownerNode !== null || document.styleSheets.length !== 0) throw new Error('PI removal');
        \\// A retained sheet stays usable after its owner is removed and collected.
        \\pi = null; TestUtils.gc();
        \\if (retainedSheet.cssRules.length !== 1) throw new Error('retained PI sheet lost');
        \\const pending = document.createProcessingInstruction('xml-stylesheet', 'href="data:text/css,%3Aroot%7Bz-index%3A9%7D"');
        \\document.insertBefore(pending, document.documentElement);
        \\pending.remove();
    );
    _ = try browser.runEventLoopBlocking(200);
    try browser.current_context.?.runScript(
        \\if (document.styleSheets.length !== 0) throw new Error('removed pending PI delivered a sheet');
    );
    // Teardown while the next PI still has an outstanding fetch.
    try openXml(browser,
        \\<?xml-stylesheet href="data:text/css,%3Aroot%7Bz-index%3A1%7D"?>
        \\<r/>
    );
}

test "PI stylesheets apply, replace, detach and cancel through the existing loader" {
    try helpers.onFreshThread(exercise);
}
