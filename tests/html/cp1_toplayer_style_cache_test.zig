//! Q54/Q61: native equivalent of the frozen cp1-toplayer-style-cache fixture.
//! Keep the focused input unchanged while top-layer membership changes.
//! Frozen HTML SHA256:
//! f0196be7e0bce19622cabdcfc19d972f593d2711a88de2c2035668c3267cb96e
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  #container { color: rgb(255, 0, 0); }
        \\  #container:focus-within { color: rgb(0, 128, 0); }
        \\  [popover] { display: block; }
        \\</style>`;
        \\document.body.innerHTML = '<div id="container"><div id="popover" popover="manual"><input id="target"></div></div>';
        \\globalThis.cp1Container = document.getElementById('container');
        \\globalThis.cp1Popover = document.getElementById('popover');
        \\globalThis.cp1Target = document.getElementById('target');
        \\cp1Target.focus();
        \\if (!cp1Target.matches(':focus')) throw new Error('initial focus');
        \\if (getComputedStyle(cp1Container).color !== 'rgb(0, 128, 0)')
        \\  throw new Error('before entering the top layer');
    );
    try page.run(
        \\cp1Popover.showPopover();
        \\if (!cp1Target.matches(':focus')) throw new Error('focus designation changed on show');
        \\if (cp1Container.matches(':focus-within')) throw new Error('ancestor cutoff on show');
        \\if (getComputedStyle(cp1Container).color !== 'rgb(255, 0, 0)')
        \\  throw new Error('cached ancestor style changes on show: ' + getComputedStyle(cp1Container).color);
    );
    try page.run(
        \\cp1Popover.hidePopover();
        \\globalThis.cp1FrameDone = false;
        \\requestAnimationFrame(() => { cp1FrameDone = true; });
    );
    // Page.turn uses the existing Browser event-loop driver. Observe only
    // completion in the callback; assertions remain outside script events.
    for (0..50) |_| {
        try page.turn(); // At most 20 ms per turn, bounded to fifty turns.
        const done = try page.evaluate("String(cp1FrameDone)");
        defer std.testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) break;
    }
    try page.run("if (!cp1FrameDone) throw new Error('animation frame did not run');");
    try page.run(
        \\if (!cp1Target.matches(':focus')) throw new Error('focus designation changed on hide');
        \\if (!cp1Container.matches(':focus-within')) throw new Error('ancestor matches again on hide');
        \\if (getComputedStyle(cp1Container).color !== 'rgb(0, 128, 0)')
        \\  throw new Error('cached ancestor style changes on hide: ' + getComputedStyle(cp1Container).color);
    );
}

test "unchanged focus does not keep an ancestor style cached across top-layer transitions" {
    try helpers.onFreshThread(exercise);
}
// Q66 additions. Concatenated after the unchanged, already-measured case.
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const input = @import("html").user_input;

const LayerKind = enum { popover, modal };
const ActionState = enum { focus_within, hover, active };
const Transition = enum { round_trip, hide_only };

fn pseudo(comptime state: ActionState) []const u8 {
    return switch (state) {
        .focus_within => ":focus-within",
        .hover => ":hover",
        .active => ":active",
    };
}

fn movePointer(pointer: *input.Pointer, target: *runtime.Instance, state: ActionState) void {
    if (state != .focus_within) input.pointerMove(pointer, target, .{});
    if (state == .active) input.pointerDown(pointer, 0, .{});
}

fn releasePointer(pointer: *input.Pointer, state: ActionState) void {
    if (state == .active) input.pointerUp(pointer, 0, .{});
}

fn checkAncestor(page: helpers.Page, comptime state: ActionState, comptime matches: bool) !void {
    const selector = comptime pseudo(state);
    const expected = if (matches) "true" else "false";
    const color = if (matches) "rgb(0, 128, 0)" else "rgb(255, 0, 0)";
    try page.run(
        "if (!cp1Target.matches(':focus')) throw new Error('focus designation changed');" ++
            "if (!cp1Target.matches('" ++ selector ++ "')) throw new Error('target designation changed');" ++
            "if (cp1Container.matches('" ++ selector ++ "') !== " ++ expected ++ ") throw new Error('ancestor matching');" ++
            "if (getComputedStyle(cp1Container).color !== '" ++ color ++ "') throw new Error('ancestor cached color: ' + getComputedStyle(cp1Container).color);",
    );
}

fn finishFrame(page: helpers.Page) !void {
    try page.run("globalThis.cp1CacheFrame = false; requestAnimationFrame(() => { cp1CacheFrame = true; });");
    for (0..50) |_| {
        try page.turn();
        const done = try page.evaluate("String(cp1CacheFrame)");
        defer std.testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) break;
    }
    try page.run("if (!cp1CacheFrame) throw new Error('animation frame did not run');");
}

fn transitionExercise(comptime kind: LayerKind, comptime state: ActionState, comptime direction: Transition) !void {
    const page = try helpers.Page.open();
    defer page.close();
    const selector = comptime pseudo(state);
    const markup = if (kind == .popover)
        "<div id=container><div id=layer popover=manual><button id=target type=button>Target</button></div></div>"
    else
        "<div id=container><dialog id=layer><button id=target type=button>Target</button></dialog></div>";
    const open = if (kind == .popover) "cp1Layer.showPopover();" else "cp1Layer.showModal();";
    const close = if (kind == .popover) "cp1Layer.hidePopover();" else "cp1Layer.close();";
    try page.run("document.head.innerHTML = '<style>#container {color:rgb(255,0,0)} #container" ++ selector ++ " {color:rgb(0,128,0)} #layer {display:block}</style>';" ++
        "document.body.innerHTML = '" ++ markup ++ "';" ++
        "globalThis.cp1Container = document.getElementById('container');" ++
        "globalThis.cp1Layer = document.getElementById('layer');" ++
        "globalThis.cp1Target = document.getElementById('target'); cp1Target.focus();");
    const document = page.browser.current_context.?.document_instance.?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    var pointer: input.Pointer = .{};
    movePointer(&pointer, target, state);
    defer releasePointer(&pointer, state);
    // The independent hide cases prime their cache while already open, so
    // a show regression cannot prevent measuring the hide transition.
    if (direction == .round_trip) {
        try checkAncestor(page, state, true);
        try page.run(open);
        try checkAncestor(page, state, false);
    } else {
        try page.run(open);
        if (kind == .popover and state == .active) {
            // Q71 (2026-10-27): prime this independent hide case AFTER
            // pointerDown's focusability read warmed the closed style.
            // This attribute is inert: the fixture CSS uses only IDs and
            // pseudo-classes, never attribute selectors. No mutation follows
            // the open-cache read; the separate show case stays unchanged.
            try page.run("cp1Container.setAttribute('data-cp1-cache-prime', '');");
        }
        try checkAncestor(page, state, false);
    }
    try page.run(close);
    try finishFrame(page);
    try checkAncestor(page, state, true);
}

fn transitionCase(comptime kind: LayerKind, comptime state: ActionState, comptime direction: Transition) !void {
    const Case = struct {
        fn run() !void {
            try transitionExercise(kind, state, direction);
        }
    };
    try helpers.onFreshThread(Case.run);
}

test "modal focus-within cached ancestor follows show and close" {
    try transitionCase(.modal, .focus_within, .round_trip);
}
test "popover hover cached ancestor follows show and hide" {
    try transitionCase(.popover, .hover, .round_trip);
}
test "modal hover cached ancestor follows show and close" {
    try transitionCase(.modal, .hover, .round_trip);
}
test "popover active cached ancestor follows show and hide" {
    try transitionCase(.popover, .active, .round_trip);
}
test "modal active cached ancestor follows show and close" {
    try transitionCase(.modal, .active, .round_trip);
}
test "popover focus-within cached ancestor independently follows hide" {
    try transitionCase(.popover, .focus_within, .hide_only);
}
test "modal focus-within cached ancestor independently follows close" {
    try transitionCase(.modal, .focus_within, .hide_only);
}
test "popover hover cached ancestor independently follows hide" {
    try transitionCase(.popover, .hover, .hide_only);
}
test "modal hover cached ancestor independently follows close" {
    try transitionCase(.modal, .hover, .hide_only);
}
test "popover active cached ancestor independently follows hide" {
    try transitionCase(.popover, .active, .hide_only);
}
test "modal active cached ancestor independently follows close" {
    try transitionCase(.modal, .active, .hide_only);
}

fn stableCache() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=stable style=\"color:blue\"></div><div id=layer popover=manual>Layer</div>';");
    const document = page.browser.current_context.?.document_instance.?;
    const style_engine = dom.style.hooks.engineOf(document).?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("stable"))).?;
    for (0..2) |phase| {
        if (phase == 1) try page.run("document.getElementById('layer').showPopover();");
        _ = (try dom.style.computedStyle(target, null)).?;
        const before = dom.style.element_style.existingOf(target).?.cached.?.key;
        const generation = style_engine.generation;
        // Pin the same cache-validity predicate as the existing environment
        // revision test, and rule out dynamic-state recomputation as well.
        var ancestor: ?*runtime.Instance = target;
        while (ancestor) |node| {
            const cached = dom.style.element_style.existingOf(node).?.cached.?;
            try std.testing.expect(!cached.@"volatile");
            ancestor = try interfaces.Node.get_parentElement(node);
        }
        for (0..2) |_| {
            _ = (try dom.style.computedStyle(target, null)).?;
            const after = dom.style.element_style.existingOf(target).?.cached.?;
            try std.testing.expectEqual(generation, style_engine.generation);
            try std.testing.expectEqual(generation, after.key.generation);
            try std.testing.expect(before.eql(after.key));
            try std.testing.expect(!after.@"volatile");
        }
    }
}

test "unchanged top layer preserves nonvolatile cached styles" {
    try helpers.onFreshThread(stableCache);
}

fn revisionChanges() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.expectEqual(@as(u64, 0), dom.top_layer.revisionOf(document));
    try std.testing.expect(try dom.top_layer.ofDocument(document, false) == null);
    try page.run("document.body.innerHTML = '<div id=a></div><dialog id=b></dialog>';");
    const first = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const second = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b"))).?;
    var layer = dom.top_layer.State.init(std.testing.allocator, document);
    var cleaned = false;
    defer if (!cleaned) layer.deinit();
    try std.testing.expectEqual(@as(u64, 0), layer.revision);
    const pin = try layer.pin(first);
    try std.testing.expectEqual(@as(u64, 1), layer.revision);
    const modal = try layer.addModal(second);
    try std.testing.expectEqual(@as(u64, 3), layer.revision);
    try std.testing.expect(try layer.addModal(second) == modal);
    layer.remove(std.math.maxInt(usize));
    try std.testing.expectEqual(@as(u64, 3), layer.revision);
    const modal_id = modal.id;
    layer.remove(pin.id);
    layer.remove(modal_id);
    try std.testing.expectEqual(@as(u64, 5), layer.revision);
    const wrap = try layer.pin(first);
    layer.revision = std.math.maxInt(u64);
    layer.remove(wrap.id);
    try std.testing.expectEqual(@as(u64, 0), layer.revision);
    _ = try layer.pin(first);
    _ = try layer.pin(second);
    layer.deinit();
    cleaned = true;
    try std.testing.expectEqual(@as(u64, 4), layer.revision);

    var orphan = dom.top_layer.State.init(std.testing.allocator, document);
    var orphan_cleaned = false;
    defer if (!orphan_cleaned) orphan.deinit();
    _ = try orphan.pin(first);
    _ = try orphan.addModal(second);
    const before = orphan.revision;
    orphan.releaseAfterRealmEnded();
    orphan_cleaned = true;
    try std.testing.expectEqual(before +% 2, orphan.revision);
}

test "top-layer revision covers insert promotion removal no-op wrap and cleanup" {
    if (comptime @hasDecl(dom.top_layer, "revisionOf") and @hasField(dom.top_layer.State, "revision")) {
        try helpers.onFreshThread(revisionChanges);
    } else return error.MissingTopLayerRevision;
}

fn observerAllocation() !void {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var style_engine = dom.style.StyleEngine.init(failing.allocator());
    defer style_engine.deinit();
    const initial_generation = style_engine.generation;
    try style_engine.observeTopLayer(0);
    try std.testing.expect(style_engine.rare == null);
    try std.testing.expectEqual(initial_generation, style_engine.generation);
    try std.testing.expectError(error.OutOfMemory, style_engine.observeTopLayer(1));
    try std.testing.expect(style_engine.rare == null);
    try std.testing.expectEqual(initial_generation, style_engine.generation);
    failing.fail_index = std.math.maxInt(usize);
    try style_engine.observeTopLayer(1);
    try std.testing.expectEqual(initial_generation +% 1, style_engine.generation);
    try style_engine.observeTopLayer(1);
    try std.testing.expectEqual(initial_generation +% 1, style_engine.generation);
    try style_engine.observeTopLayer(2);
    try std.testing.expectEqual(initial_generation +% 2, style_engine.generation);
}

test "top-layer observation is lazy atomic on OOM and stable on repeated revisions" {
    if (comptime @hasDecl(dom.style.StyleEngine, "observeTopLayer")) {
        try observerAllocation();
    } else return error.MissingTopLayerObserver;
}
