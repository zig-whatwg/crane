//! Lane mcp3 batch B, audit M7 (main's ruling (a), 2026-11-27 7:59 PM ET):
//! element input waits as Puppeteer's locator does. chrome-devtools-mcp's
//! click and fill act through `handle.asLocator()` (puppeteer-core 25.17.0
//! api/locators/locators.ts): the locator waits for a native form control to
//! lose its `disabled` attribute, and any failure of the action (a read-only
//! field, an element that cannot be filled) is tried again every 100 ms
//! (RETRY_DELAY) until the page's default timeout - DEFAULT_TIMEOUT, 5 s, times
//! the CPU throttling rate (McpPage.updateTimeouts) - ends it with a
//! TimeoutError, which handleActionError words as "The element did not become
//! interactive within the configured timeout."

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const Harness = @import("mcp1_harness.zig").Harness;

fn navigate(h: *Harness, a: std.mem.Allocator, url: []const u8) !void {
    const r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":{f}}}", .{std.json.fmt(url, .{})}));
    try testing.expect(!r.is_error);
}

fn uidOf(text: []const u8, needle: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, needle) == null) continue;
        const at = std.mem.indexOf(u8, line, "uid=") orelse return error.NoUid;
        const rest = line[at + "uid=".len ..];
        return rest[0 .. std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len];
    }
    std.debug.print("no line with {s} in:\n{s}\n", .{ needle, text });
    return error.NoLine;
}

fn expectResult(text: []const u8, json: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    const want = try std.fmt.bufPrint(&buffer, "Script ran on page and returned:\n```json\n{s}\n```", .{json});
    try testing.expectEqualStrings(want, text);
}

fn timeoutText(a: std.mem.Allocator, uid: []const u8) ![]const u8 {
    return std.fmt.allocPrint(a, "Error: Failed to interact with the element with uid {s}. The element did not become interactive within the configured timeout.", .{uid});
}

/// A tools/call and how long it took (ms).
fn timed(h: *Harness, name: []const u8, arguments: []const u8) !struct { text: []const u8, is_error: bool, ms: i64 } {
    const start = platform.monotonicMillis();
    const r = try h.tool(name, arguments);
    return .{ .text = r.text, .is_error = r.is_error, .ms = platform.monotonicMillis() - start };
}

test "click waits as Puppeteer's locator does: a disabled control is clicked once enabled, the timeout text if it never is" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    try navigate(&h, a,
        \\data:text/html,<!doctype html><title>Disabled</title>
        \\<button id=late disabled>Late</button>
        \\<button id=never disabled>Never</button>
        \\<fieldset disabled><button id=fs>Fieldset</button></fieldset>
        \\<select id=sel aria-label=Pick><option value=a>Alpha</option><option value=b disabled>Beta</option></select>
        \\<script>
        \\window.clicks = [];
        \\document.addEventListener('click', e => clicks.push(e.target.id + ':' + e.isTrusted), true);
        \\</script>
    );
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const late = try a.dupe(u8, try uidOf(snap, "button \"Late\""));
    const never = try a.dupe(u8, try uidOf(snap, "button \"Never\""));
    const fs = try a.dupe(u8, try uidOf(snap, "button \"Fieldset\""));
    const beta = try a.dupe(u8, try uidOf(snap, "option \"Beta\""));

    // Enabled 300 ms from now: the click waits for it, then clicks.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { setTimeout(() => { document.getElementById('late').disabled = false; document.querySelector('option[value=b]').disabled = false; }, 300); }\"}");
    try testing.expect(!r.is_error);
    var t = try timed(&h, "click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{late}));
    try testing.expectEqualStrings("Successfully clicked on the element", t.text);
    if (t.ms < 200) std.debug.print("the click came {d} ms after the call, before the button was enabled\n", .{t.ms});
    try testing.expect(t.ms >= 200);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => clicks.join(',')\"}");
    try expectResult(r.text, "\"late:true\"");

    // A native option (selectNativeSelectOption falls back to the locator for a disabled one): selected once enabled.
    t = try timed(&h, "click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{beta}));
    try testing.expectEqualStrings("Successfully clicked on the element", t.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => document.getElementById('sel').value\"}");
    try expectResult(r.text, "\"b\"");

    // Never enabled: Puppeteer's TimeoutError after DEFAULT_TIMEOUT (5 s at no throttling).
    t = try timed(&h, "click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{never}));
    try testing.expect(t.is_error);
    try testing.expectEqualStrings(try timeoutText(a, never), t.text);
    if (t.ms < 4900 or t.ms > 9000) std.debug.print("the timeout came after {d} ms, not 5,000\n", .{t.ms});
    try testing.expect(t.ms >= 4900 and t.ms <= 9000);

    // Disabled by its fieldset: Puppeteer's condition reads the control's own
    // attribute, so the click is sent at once - and HTML's disabled form
    // control swallows it (no click event).
    t = try timed(&h, "click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{fs}));
    try testing.expectEqualStrings("Successfully clicked on the element", t.text);
    try testing.expect(t.ms < 1500);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => clicks.join(',')\"}");
    try expectResult(r.text, "\"late:true\"");
}

test "fill waits as Puppeteer's locator does: a read-only field is filled once writable; what cannot be filled ends in the timeout text" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    try navigate(&h, a,
        \\data:text/html,<!doctype html><title>Read-only</title>
        \\<input id=late readonly value=fixed aria-label=Late>
        \\<input id=never readonly value=fixed aria-label=Never>
        \\<input id=btn type=button value=Label>
        \\<button id=plain>Plain</button>
    );
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const late = try a.dupe(u8, try uidOf(snap, "textbox \"Late\""));
    const never = try a.dupe(u8, try uidOf(snap, "textbox \"Never\""));
    const btn = try a.dupe(u8, try uidOf(snap, "button \"Label\""));
    const plain = try a.dupe(u8, try uidOf(snap, "button \"Plain\""));

    // Writable 300 ms from now: the fill is tried again until it is.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { setTimeout(() => { document.getElementById('late').readOnly = false; }, 300); }\"}");
    try testing.expect(!r.is_error);
    var t = try timed(&h, "fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"changed\"}}", .{late}));
    try testing.expectEqualStrings("Successfully filled out the element", t.text);
    if (t.ms < 200) std.debug.print("the fill came {d} ms after the call, before the field was writable\n", .{t.ms});
    try testing.expect(t.ms >= 200);

    // Never writable: the timeout text after DEFAULT_TIMEOUT + 10 ms a character (fillFormElements).
    t = try timed(&h, "fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"changed\"}}", .{never}));
    try testing.expect(t.is_error);
    try testing.expectEqualStrings(try timeoutText(a, never), t.text);
    if (t.ms < 4900 or t.ms > 9000) std.debug.print("the timeout came after {d} ms, not 5,070\n", .{t.ms});
    try testing.expect(t.ms >= 4900 and t.ms <= 9000);

    // An <input type=button> is an 'other-input' to Puppeteer: its value is set directly.
    t = try timed(&h, "fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"Pressed\"}}", .{btn}));
    try testing.expectEqualStrings("Successfully filled out the element", t.text);
    try testing.expect(t.ms < 1500);

    // A <button> cannot be filled ('unknown'): tried until the timeout, then its text.
    t = try timed(&h, "fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"x\"}}", .{plain}));
    try testing.expect(t.is_error);
    try testing.expectEqualStrings(try timeoutText(a, plain), t.text);

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('late').value, document.getElementById('never').value, document.getElementById('btn').value]\"}");
    try expectResult(r.text, "[\"changed\",\"fixed\",\"Pressed\"]");
}
