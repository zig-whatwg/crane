//! HTML 2.5.6: nonce slots own their value, independently of attributes.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html_ns = "http://www.w3.org/1999/xhtml";
const svg_ns = "http://www.w3.org/2000/svg";

fn expectNonce(comptime I: type, element: *runtime.Instance, expected: []const u8) !void {
    var nonce = try I.get_nonce(element);
    defer nonce.deinit(element.ctx.allocator);
    try testing.expectEqualStrings(expected, nonce.asSlice());
}

fn attribute(element: *runtime.Instance, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("nonce"), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn exercise(comptime svg: bool, comptime oom: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var failing = testing.FailingAllocator.init(testing.allocator, .{});
    const allocator = failing.allocator();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer dom.node_creation.destroyUninserted(document);
    if (svg) {
        // A native caller must not reinterpret an ordinary Element's state
        // as SVGElement. Rejection happens before copying any nonce bytes.
        const other = try interfaces.Element.init(allocator, &ctx);
        defer dom.node_creation.destroyUninserted(other);
        try testing.expectError(error.InvalidStateError, interfaces.SVGElement.set_nonce(other, runtime.DOMString.initInterned("no SVG slot")));
    }
    const original = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(if (svg) svg_ns else html_ns), runtime.DOMString.initInterned(if (svg) "script" else "div"), .notPassed());
    defer dom.node_creation.destroyUninserted(original);
    const I = if (svg) interfaces.SVGElement else interfaces.HTMLElement;
    try expectNonce(I, original, "");
    try I.set_nonce(original, runtime.DOMString.initInterned("private"));
    try expectNonce(I, original, "private");
    try testing.expect(!(try interfaces.Element.call_hasAttribute(original, runtime.DOMString.initInterned("nonce"))));

    if (oom) {
        const copy = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(if (svg) svg_ns else html_ns), runtime.DOMString.initInterned(if (svg) "script" else "div"), .notPassed());
        defer dom.node_creation.destroyUninserted(copy);
        try I.set_nonce(copy, runtime.DOMString.initInterned("previous"));
        failing.fail_index = failing.alloc_index;
        defer failing.fail_index = std.math.maxInt(usize);
        const borrowed = dom.attribute_change_steps.readForAttribute(original, if (svg) svg_ns else html_ns, "nonce") orelse return error.MissingNonceHook;
        try testing.expectEqualStrings("private", borrowed);
        // The cloning hook's owned copy fails without dropping the old slot
        // or aliasing the source. Normal cloneNode is exercised below.
        try testing.expectError(error.OutOfMemory, dom.cloning_steps.run(original, copy, false));
        try testing.expectError(error.OutOfMemory, I.set_nonce(original, runtime.DOMString.initInterned("replacement")));
        try testing.expectError(error.OutOfMemory, I.get_nonce(original));
        failing.fail_index = std.math.maxInt(usize);
        try expectNonce(I, original, "private");
        try expectNonce(I, copy, "previous");
        failing.fail_index = failing.alloc_index;
        try I.set_nonce(original, runtime.DOMString.initEmpty());
        failing.fail_index = std.math.maxInt(usize);
        try expectNonce(I, original, "");
        return;
    }

    try attribute(original, "attribute");
    try expectNonce(I, original, "attribute");
    var input = try runtime.DOMString.initDupe(allocator, "owned value");
    defer input.deinit(allocator);
    try I.set_nonce(original, input);
    input.owned[0] = 'X';
    try expectNonce(I, original, "owned value");
    var retained = try I.get_nonce(original);
    defer retained.deinit(allocator);
    var content = (try interfaces.Element.call_getAttribute(original, runtime.DOMString.initInterned("nonce"))).?;
    defer content.deinit(allocator);
    try testing.expectEqualStrings("attribute", content.asSlice());

    const copy = try interfaces.Node.call_cloneNode(original, .{ .was_passed = true, .value = true });
    defer dom.node_creation.destroyUninserted(copy);
    try expectNonce(I, copy, "owned value");
    try I.set_nonce(original, runtime.DOMString.initInterned("different"));
    try testing.expectEqualStrings("owned value", retained.asSlice());
    try expectNonce(I, copy, "owned value");
    try interfaces.Element.call_removeAttribute(original, runtime.DOMString.initInterned("nonce"));
    try expectNonce(I, original, "");
    try interfaces.Element.call_setAttributeNS(original, runtime.DOMString.initInterned("urn:cn"), runtime.DOMString.initInterned("x:nonce"), .{ .domstring = runtime.DOMString.initInterned("namespaced") });
    try expectNonce(I, original, "");
    // Both slots still own buffers at teardown, checked by testing.allocator.
    try I.set_nonce(original, runtime.DOMString.initInterned("freed by deinit"));
}

fn onFreshThread(comptime svg: bool, comptime oom: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(svg, oom) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "HTML nonce set, attribute change, remove, clone and teardown" {
    try onFreshThread(false, false);
}

test "SVG nonce set, attribute change, remove, clone and teardown" {
    try onFreshThread(true, false);
}

test "HTML nonce copies preserve old slots on allocation failure" {
    try onFreshThread(false, true);
}

test "SVG nonce copies preserve old slots on allocation failure" {
    try onFreshThread(true, true);
}

test "unwrapped SVG nonce slots are swept at Browser teardown" {
    const Run = struct {
        fn exerciseOrphan() !void {
            const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML("<!doctype html><body><div id=host><svg><script type=application/json nonce=owned></script></svg></div>", .{ .base_url = "about:blank" });
            const result = try browser.evaluateScript("document.getElementById('host').innerHTML = ''; true");
            defer result.release();
        }
        fn run(result: *?anyerror) void {
            exerciseOrphan() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
