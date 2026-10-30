//! HTML user validity is owner state; CSS selectors only read it.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const controls = dom.form_controls;

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

fn ownerFlags() !void {
    const a = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(a, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    inline for (.{ "input", "select", "textarea" }) |name| {
        const element = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
        defer runtime.Instance.deinit(element);
        try std.testing.expect(!controls.userValidity(element));
        try controls.setUserValidity(element, true);
        try std.testing.expect(controls.userValidity(element));
        const clone = try interfaces.Node.call_cloneNode(element, .passed(true));
        defer runtime.Instance.deinit(clone);
        try std.testing.expect(!controls.userValidity(clone));
        controls.reset(element);
        try std.testing.expect(!controls.userValidity(element));
    }
    inline for (.{ "form", "fieldset" }) |name| {
        const element = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
        defer runtime.Instance.deinit(element);
        try controls.setUserValidity(element, true);
        try std.testing.expect(!controls.userValidity(element));
        try std.testing.expect(!dom.html_pseudo_classes.matches(element, .user_valid));
        try std.testing.expect(!dom.html_pseudo_classes.matches(element, .user_invalid));
    }
}

test "user validity is initially false, resettable and never copied by cloning" {
    try onThread(ownerFlags);
}

fn lazyWrites(a: std.mem.Allocator) !void {
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    var context = try runtime.ContextData.init(a, .{});
    context.browser_scope = &scope;
    defer context.deinit();
    inline for (.{ interfaces.HTMLSelectElement, interfaces.HTMLTextAreaElement }) |T| {
        const element = try T.init(a, &context);
        defer T.deinit(element);
        // False writes are a pin: a reset must not allocate lazy state.
        try controls.setUserValidity(element, false);
        try std.testing.expect(!controls.userValidity(element));
        try controls.setUserValidity(element, true);
        try std.testing.expect(controls.userValidity(element));
        try controls.setUserValidity(element, false);
        try std.testing.expect(!controls.userValidity(element));
    }
}

fn failedAllocations() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, lazyWrites, .{});
}

test "lazy select and textarea user-validity writes unwind every allocation failure" {
    try onThread(failedAllocations);
}

fn mediaReads() !void {
    const a = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const video = try interfaces.HTMLVideoElement.init(a, &context);
    defer interfaces.HTMLVideoElement.deinit(video);
    const snapshot = dom.media_elements.selectorState(video).?;
    try std.testing.expect(snapshot.paused);
    try std.testing.expect(!snapshot.seeking and !snapshot.stalled and !snapshot.muted and !snapshot.volume_locked);
    // These are preservation pins: media playback/sound selectors already
    // read their default states correctly before this snapshot integration.
    try std.testing.expect(dom.html_pseudo_classes.matches(video, .paused));
    inline for (.{ .playing, .seeking, .buffering, .stalled, .muted, .volume_locked }) |kind|
        try std.testing.expect(!dom.html_pseudo_classes.matches(video, kind));
    // Q39 browser controls (2026-10-27): explicit/default mute, unlike
    // volume zero, belongs to the muted concept. Rate-based mute belongs
    // to the routed media-owner capability work, not a selector threshold.
    try interfaces.HTMLMediaElement.set_defaultMuted(video, true);
    try std.testing.expect(dom.media_elements.selectorState(video).?.muted);
    try std.testing.expect(dom.html_pseudo_classes.matches(video, .muted));
    try interfaces.HTMLMediaElement.set_defaultMuted(video, false);
    try std.testing.expect(!dom.html_pseudo_classes.matches(video, .muted));
    // Explicit mute and volume setters queue rooted events, so their
    // preservation cases use the real Browser host in tests/html.
    const div = try interfaces.HTMLElement.init(a, &context);
    defer interfaces.HTMLElement.deinit(div);
    try std.testing.expect(dom.media_elements.selectorState(div) == null);
    try std.testing.expect(!dom.html_pseudo_classes.matches(div, .paused));
}

test "media selector reads preserve default state and reject non-media elements" {
    try onThread(mediaReads);
}

fn focusReads() !void {
    const a = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(a, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const parent = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(document, parent);
    const target = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("button"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(parent, target);
    var ast = try dom.selector_matching.parse(a, ":focus-visible");
    defer ast.deinit();
    var reads: dom.selector_matching.StateReads = .{};
    var matcher = dom.selector_matching.StyleMatcher.init(target, &reads).?;
    // Preservation pin: the universal UA rule must not make every element
    // volatile. A later focus change is already in the style cache key.
    try std.testing.expect(!matcher.matches(target, &ast.selectors[0], null));
    try std.testing.expect(!reads.@"volatile");
    dom.focused_area.set(document, target);
    defer dom.focused_area.set(document, null);
    try std.testing.expect(matcher.matches(target, &ast.selectors[0], null));
    try std.testing.expect(reads.@"volatile");
    reads = .{};
    var has = try dom.selector_matching.parse(a, ":has(:focus-visible)");
    defer has.deinit();
    var ancestor_matcher = dom.selector_matching.StyleMatcher.init(parent, &reads).?;
    try std.testing.expect(ancestor_matcher.matches(parent, &has.selectors[0], null));
    try std.testing.expect(reads.@"volatile");
}

test "focus-visible style reads are volatile only for focused elements and their dependencies" {
    try onThread(focusReads);
}
