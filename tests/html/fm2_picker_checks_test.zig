//! showPicker exceptions and ordering, with real activation state.
const std = @import("std");
const clock = @import("clock");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const browser_mod = @import("browser");
const activation = @import("html").user_activation;
const loop_settle = @import("loop_settle.zig");
const testing = std.testing;

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, condition: []const u8) !void {
    const start = clock.monotonicMillis();
    while (clock.monotonicMillis() - start < loop_settle.bound_ms) {
        const value = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><input id=picker><select id=select><option>x</select>", .{ .base_url = "http://example.test/picker" });
    const document = page.document_instance orelse return error.NoDocument;
    const window = (try interfaces.Document.get_defaultView(document)).?;
    const input = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("picker"))).?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("select"))).?;
    activation.consume(window);
    try testing.expectError(error.NotAllowedError, interfaces.HTMLInputElement.call_showPicker(input));
    try testing.expectError(error.NotAllowedError, interfaces.HTMLSelectElement.call_showPicker(select));
    try interfaces.HTMLInputElement.set_disabled(input, true);
    try interfaces.HTMLSelectElement.set_disabled(select, true);
    try testing.expectError(error.InvalidStateError, interfaces.HTMLInputElement.call_showPicker(input));
    try testing.expectError(error.InvalidStateError, interfaces.HTMLSelectElement.call_showPicker(select));
    try interfaces.HTMLInputElement.set_disabled(input, false);
    try interfaces.HTMLSelectElement.set_disabled(select, false);
    try interfaces.HTMLInputElement.set_readOnly(input, true);
    activation.notifyActivation(document);
    try testing.expectError(error.InvalidStateError, interfaces.HTMLInputElement.call_showPicker(input));
    try testing.expect(activation.hasTransientActivation(window));
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("button"));
    try interfaces.HTMLInputElement.call_showPicker(input);
    try testing.expect(!activation.hasTransientActivation(window));
    try interfaces.Element.call_setAttribute(select, runtime.DOMString.initInterned("hidden"), .{ .domstring = runtime.DOMString.initInterned("") });
    try testing.expectError(error.NotAllowedError, interfaces.HTMLSelectElement.call_showPicker(select));
    activation.notifyActivation(document);
    try testing.expectError(error.NotSupportedError, interfaces.HTMLSelectElement.call_showPicker(select));
    try testing.expect(activation.hasTransientActivation(window));
    try interfaces.Element.call_removeAttribute(select, runtime.DOMString.initInterned("hidden"));
    try interfaces.HTMLSelectElement.call_showPicker(select);
    try testing.expect(!activation.hasTransientActivation(window));

    try page.runScript("globalThis.crossLoaded = false; const frame = document.createElement('iframe'); frame.id = 'cross'; frame.sandbox = 'allow-scripts'; frame.addEventListener('load', () => { globalThis.crossLoaded = true; }); frame.srcdoc = '<input id=picker><select id=select><option>x</select>'; document.body.append(frame);");
    try runUntil(browser, page, "String(globalThis.crossLoaded === true)");
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("cross"))).?;
    const child_window = (try interfaces.HTMLIFrameElement.get_contentWindow(frame)).?;
    const child_document = try interfaces.Window.get_document(child_window);
    const child_input = (try interfaces.Document.call_getElementById(child_document, runtime.DOMString.initInterned("picker"))).?;
    const child_select = (try interfaces.Document.call_getElementById(child_document, runtime.DOMString.initInterned("select"))).?;
    activation.consume(child_window);
    try testing.expectError(error.SecurityError, interfaces.HTMLInputElement.call_showPicker(child_input));
    try testing.expectError(error.SecurityError, interfaces.HTMLSelectElement.call_showPicker(child_select));
    try interfaces.HTMLInputElement.set_disabled(child_input, true);
    try testing.expectError(error.InvalidStateError, interfaces.HTMLInputElement.call_showPicker(child_input));
    try interfaces.HTMLInputElement.set_disabled(child_input, false);
    for ([_][]const u8{ "file", "color" }) |kind| {
        try interfaces.HTMLInputElement.set_type(child_input, runtime.DOMString.initInterned(kind));
        try testing.expectError(error.NotAllowedError, interfaces.HTMLInputElement.call_showPicker(child_input));
    }
    activation.notifyActivation(child_document);
    try interfaces.HTMLInputElement.call_showPicker(child_input);
    try testing.expect(!activation.hasTransientActivation(child_window));
}

test "showPicker checks mutability before activation and rendering after activation" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
