//! Lane quick2: touch and pen input, and pointer capture (Pointer Events 4,
//! Touch Events). A touch tap is one touch frame pressing a contact and one
//! lifting it (html.user_input.touchFrame): a touch does not hover, so its
//! boundary events come with contact; it is implicitly captured to the
//! element it went down on (Pointer Events 8.4); its touch events follow its
//! pointer events; a tap with no canceled touch event ends in mouse events
//! and a click (Touch Events, "Interaction with Mouse Events and click").
//! Element.setPointerCapture / releasePointerCapture / hasPointerCapture act
//! on the top-level traversable's active pointers (Pointer Events 8.2-8.3).
//! The WPT side: html/semantics/forms/the-select-element/*touch*,
//! shadow-dom/touch-event-retargeting-leak.html, selection/longpress-selection.html.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer testing.allocator.free(actual);
    testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn byId(page: helpers.Page, id: []const u8) !*runtime.Instance {
    const document = try documentOf(page);
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

/// A page with `markup` in its body and a recorder of the input events at
/// window (capture): `log` holds "type@id" in order.
fn openWith(markup: []const u8) !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    var buffer: [4096]u8 = undefined;
    const source = try std.fmt.bufPrint(&buffer,
        \\document.body.innerHTML = `{s}`;
        \\globalThis.log = [];
        \\for (const type of ['pointerover', 'pointerenter', 'pointerdown', 'pointermove', 'pointerup', 'pointercancel', 'pointerout', 'pointerleave',
        \\    'gotpointercapture', 'lostpointercapture', 'touchstart', 'touchmove', 'touchend', 'touchcancel',
        \\    'mouseover', 'mouseenter', 'mousemove', 'mousedown', 'mouseup', 'click'])
        \\  addEventListener(type, (e) => {{ if (e.target.id) log.push(type + '@' + e.target.id); }}, {{ capture: true }});
    , .{markup});
    try page.run(source);
    return page;
}

fn touchPoint(id: i32) user_input.Pointer {
    return .{ .pointer_id = id, .pointer_type = .touch };
}

/// One tap of `point` on `target`: a frame pressing it, a frame lifting it.
fn tap(point: *user_input.Pointer, target: *runtime.Instance) void {
    point.touch_hit = user_input.Weak.of(target);
    point.touch_change = .pressed;
    user_input.touchFrame(&.{point}, .{});
    point.touch_change = .released;
    user_input.touchFrame(&.{point}, .{});
}

fn tapSequence() !void {
    const page = try openWith("<div id=a></div>");
    defer page.close();
    try page.run(
        \\addEventListener('touchend', (e) => log.push('touches=' + e.touches.length + ' changed=' + e.changedTouches.length), { capture: true });
        \\addEventListener('click', (e) => log.push('click:' + e.pointerType + ':' + e.pointerId + ':' + e.isPrimary), { capture: true });
    );
    var point = touchPoint(2);
    tap(&point, try byId(page, "a"));
    try expectScript(page, "log.join(' ')", "pointerover@a pointerenter@a pointerdown@a touchstart@a gotpointercapture@a pointerup@a lostpointercapture@a " ++
        "pointerout@a pointerleave@a touchend@a touches=0 changed=1 mouseover@a mouseenter@a mousemove@a mousedown@a mouseup@a click@a click:touch:2:true");
}

test "a tap: pointer events with implicit capture, then touch events, then mouse events and a click" {
    try helpers.onFreshThread(tapSequence);
}

fn canceledTouchstartPreventsMouseEvents() !void {
    const page = try openWith("<div id=a></div>");
    defer page.close();
    try page.run("a.addEventListener('touchstart', (e) => e.preventDefault(), { once: true });");
    var point = touchPoint(2);
    tap(&point, try byId(page, "a"));
    try expectScript(page, "log.filter(t => t.startsWith('mouse') || t.startsWith('click')).join(' ') || 'none'", "none");
    try page.run("log = []; a.addEventListener('touchend', (e) => e.preventDefault());");
    var second = touchPoint(3);
    tap(&second, try byId(page, "a"));
    try expectScript(page, "log.filter(t => t.startsWith('mouse') || t.startsWith('click')).join(' ') || 'none'", "none");
}

test "a canceled touchstart or touchend: no mouse events and no click" {
    try helpers.onFreshThread(canceledTouchstartPreventsMouseEvents);
}

fn implicitCaptureIsSetBeforePointerdownListeners() !void {
    const page = try openWith("<div id=a></div><div id=b></div>");
    defer page.close();
    try page.run(
        \\a.addEventListener('pointerdown', (e) => {
        \\  log.push('has=' + a.hasPointerCapture(e.pointerId));
        \\  a.releasePointerCapture(e.pointerId);
        \\  log.push('released=' + a.hasPointerCapture(e.pointerId));
        \\});
    );
    var point = touchPoint(2);
    tap(&point, try byId(page, "a"));
    try expectScript(page, "log.filter(t => !t.startsWith('mouse')).join(' ')", "pointerover@a pointerenter@a pointerdown@a has=true released=false touchstart@a pointerup@a " ++
        "pointerout@a pointerleave@a touchend@a click@a");
}

test "a touch's implicit capture is set before pointerdown listeners run, and can be released there" {
    try helpers.onFreshThread(implicitCaptureIsSetBeforePointerdownListeners);
}

fn touchTargetsAreRetargeted() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=host></div>';
        \\globalThis.root = host.attachShadow({ mode: 'closed' });
        \\root.innerHTML = '<div id=inner></div>';
        \\globalThis.inner = root.getElementById('inner');
        \\globalThis.seen = [];
        \\addEventListener('touchstart', (e) => seen.push('window:' + e.target.id + ':' + e.changedTouches[0].target.id), { capture: true });
        \\inner.addEventListener('touchstart', (e) => seen.push('inner:' + e.target.id + ':' + e.changedTouches[0].target.id));
    );
    const inner = blk: {
        const value = try page.browser.evaluateScript("inner");
        defer value.release();
        break :blk @import("engine").convertToPlatformObject(page.browser.getRealm().?, value.borrow()) orelse return error.NoElement;
    };
    var point = touchPoint(2);
    tap(&point, inner);
    try expectScript(page, "seen.join(' ')", "window:host:host inner:inner:inner");
}

test "a touch's target is retargeted like the event's: a closed shadow tree's element reads as its host outside" {
    try helpers.onFreshThread(touchTargetsAreRetargeted);
}

fn twoContactsAreNoTap() !void {
    const page = try openWith("<div id=a></div>");
    defer page.close();
    try page.run("addEventListener('touchend', (e) => log.push('changed=' + e.changedTouches.length), { capture: true });");
    const a = try byId(page, "a");
    var first = touchPoint(2);
    var second = touchPoint(3);
    first.touch_hit = user_input.Weak.of(a);
    second.touch_hit = user_input.Weak.of(a);
    first.touch_change = .pressed;
    second.touch_change = .pressed;
    user_input.touchFrame(&.{ &first, &second }, .{});
    first.touch_change = .released;
    second.touch_change = .released;
    user_input.touchFrame(&.{ &first, &second }, .{});
    try expectScript(page, "log.filter(t => t.startsWith('touch') || t.startsWith('changed') || t.startsWith('mouse') || t.startsWith('click')).join(' ')", "touchstart@a touchend@a changed=2");
}

test "two contacts in one frame: one touch event for both, and no mouse events" {
    try helpers.onFreshThread(twoContactsAreNoTap);
}

fn setPointerCaptureSteps() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectScript(page,
        \\document.body.innerHTML = '<div id=a></div>';
        \\const out = [];
        \\try { a.setPointerCapture(99); } catch (e) { out.push(e.name); }
        \\try { document.createElement('div').setPointerCapture(1); } catch (e) { out.push(e.name); }
        \\a.setPointerCapture(1); out.push(String(a.hasPointerCapture(1)));
        \\try { a.releasePointerCapture(99); } catch (e) { out.push(e.name); }
        \\a.releasePointerCapture(1); out.push('ok');
        \\out.join(' ')
    , "NotFoundError InvalidStateError false NotFoundError ok");
}

test "setPointerCapture: an unknown pointerId throws NotFoundError, a disconnected element InvalidStateError; the mouse is active but unpressed" {
    try helpers.onFreshThread(setPointerCaptureSteps);
}

fn mouseCaptureRetargetsPointerupAndClick() !void {
    const page = try openWith("<div id=a></div><div id=b></div>");
    defer page.close();
    try page.run("b.addEventListener('pointerdown', (e) => a.setPointerCapture(e.pointerId));");
    var mouse: user_input.Pointer = .{};
    user_input.pointerMove(&mouse, try byId(page, "b"), .{});
    try page.run("log = [];");
    user_input.pointerDown(&mouse, 0, .{});
    user_input.pointerUp(&mouse, 0, .{});
    try expectScript(page, "log.join(' ')", "pointerdown@b mousedown@b gotpointercapture@a pointerup@a lostpointercapture@a mouseup@a click@a");
}

test "a mouse captured in its pointerdown: pointerup, mouseup and click go to the capture target" {
    try helpers.onFreshThread(mouseCaptureRetargetsPointerupAndClick);
}

fn penIsAHoveringPointer() !void {
    const page = try openWith("<div id=a></div>");
    defer page.close();
    try page.run("addEventListener('pointerdown', (e) => log.push(e.pointerType + ':' + e.pointerId + ':' + e.pressure), { capture: true });");
    var pen: user_input.Pointer = .{ .pointer_id = 2, .pointer_type = .pen, .pressure = 0.25 };
    user_input.pointerMove(&pen, try byId(page, "a"), .{});
    user_input.pointerDown(&pen, 0, .{});
    user_input.pointerUp(&pen, 0, .{});
    try expectScript(page, "log.filter(t => t.startsWith('pen') || t.startsWith('click')).join(' ')", "pen:2:0.25 click@a");
    try expectScript(page, "String(navigator.userActivation.hasBeenActive)", "true");
}

test "a pen hovers like a mouse, reports its pointerType and pressure, and activates the page at pointerup" {
    try helpers.onFreshThread(penIsAHoveringPointer);
}

fn touchEventConstructor() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectScript(page,
        \\const t = new Touch({ identifier: 7, target: document.body, clientX: 3, force: 0.5, touchType: 'stylus' });
        \\const e = new TouchEvent('touchstart', { touches: [t], changedTouches: [t, t], ctrlKey: true, modifierCapsLock: true });
        \\[t.identifier, t.target === document.body, t.clientX, t.force, t.touchType, t.altitudeAngle,
        \\ e.touches.length, e.targetTouches.length, e.changedTouches.length, e.changedTouches.item(1) === t, e.touches === e.touches,
        \\ e.ctrlKey, e.getModifierState('Control'), e.getModifierState('CapsLock'), e.getModifierState('Shift')].join()
    , "7,true,3,0.5,stylus,0,1,0,2,true,true,true,true,true,false");
}

test "Touch and TouchEvent constructors: the dictionaries' members, the three lists, the modifiers" {
    try helpers.onFreshThread(touchEventConstructor);
}
