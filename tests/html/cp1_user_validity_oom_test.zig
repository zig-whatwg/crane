//! User-validity allocation failure must not suppress committed input events.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const controls = dom.form_controls;
const html = @import("html");
const Browser = @import("browser").Browser;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn validityEvents(comptime select: bool) !void {
    const a = std.testing.allocator;
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context.?;
    try page.loadHTML(if (select)
        "<!doctype html><body><select id=control><option selected>a</option><option>b</option></select>"
    else
        "<!doctype html><body><textarea id=control>before</textarea>", .{ .base_url = "about:blank" });
    try page.runScript(
        \\globalThis.events = [];
        \\globalThis.control = document.getElementById('control');
        \\for (const type of ['input', 'change']) control.addEventListener(type, () => events.push(type));
        \\getComputedStyle(control).appearance;
        \\control.focus();
    );
    const document = page.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("control"))).?;
    if (!select) {
        // Preserve the lazy textarea state: its clean value follows text
        // content. Record the user-edit boundary before changing that text.
        html.focus.willEditByUser(element);
        try interfaces.Node.set_textContent(element, runtime.DOMString.initInterned("after"));
    }
    if (select) {
        // Select insertion and selectedness eagerly create its owner state
        // before moveSelection reaches setUserValidity (Q155). Preserve the
        // real keyboard notifications without claiming a lazy-state OOM.
        var keyboard: html.user_input.Keyboard = .{};
        html.user_input.keyDown(&keyboard, document, .{ .key = "ArrowDown" }, .{});
        try std.testing.expectEqual(@as(i32, 1), try interfaces.HTMLSelectElement.get_selectedIndex(element));
        try std.testing.expect(controls.userValidity(element));
    } else {
        const slot = &browser.scope.tables[@intFromEnum(runtime.BrowserScope.Table.textarea_states)];
        try std.testing.expect(slot.load(.acquire) == null);
        // Fail only the new Browser side table. The realm allocator and
        // existing event/listener tables remain available for dispatch.
        const original = browser.scope.allocator;
        var failing = std.testing.FailingAllocator.init(original, .{ .fail_index = 0 });
        browser.scope.allocator = failing.allocator();
        defer browser.scope.allocator = original;
        html.focus.unfocusingSteps(element);
        browser.scope.allocator = original;
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expect(slot.load(.acquire) == null);
        try std.testing.expect(!controls.userValidity(element));
    }
    const events = try page.evaluateScriptToString("events.join(',')", a);
    defer a.free(events);
    try std.testing.expectEqualStrings(if (select) "input,change" else "change", events);
}

fn textareaOomEvents() !void {
    try validityEvents(false);
}

fn selectEvents() !void {
    try validityEvents(true);
}

test "a textarea validity allocation failure preserves its committed change event" {
    try onThread(textareaOomEvents);
}

test "a select keyboard change marks validity and fires input then change" {
    try onThread(selectEvents);
}
