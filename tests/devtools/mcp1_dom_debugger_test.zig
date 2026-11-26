//! Lane mcp1, batch 4b item 5: CDP `DOMDebugger.getEventListeners`.
//!
//! Covers Blink `InspectorDOMDebuggerAgent::getEventListeners` semantics:
//! - Node targets: `depth` (default 1 = self only, >1 = descendants, -1 = full
//!   subtree) and `pierce` (open & closed ShadowRoot, local iframe
//!   contentDocument, cross-context / isolated-world reporting).
//! - Non-Node EventTargets (`window`, `XMLHttpRequest`, `new EventTarget()`):
//!   own listeners, no `backendNodeId`.
//! - Non-EventTarget JS objects: empty `listeners` array; invalid `objectId`:
//!   protocol error.
//! - Listener forms: regular function, bound function (`handler` unwrapped vs
//!   `originalHandler` bound), `{ handleEvent }` object (`handler` =
//!   `handleEvent` vs `originalHandler` = object), content attribute (`onclick`),
//!   IDL event handler (`.onkeydown`), removed listeners excluded.
//! - Ordering: all `useCapture: true` before `useCapture: false`.
//! - `objectGroup` gating: `handler` / `originalHandler` populated iff the
//!   unwrapped `objectId` belonged to a non-empty `objectGroup`.
//! - `scriptId`, 0-based `lineNumber`, 0-based `columnNumber`.

const std = @import("std");
const testing = std.testing;
const cdpd1 = @import("cdpd1_harness.zig");
const replay = @import("cdpr_replay.zig");

fn dataUrl(arena: std.mem.Allocator, html: []const u8) ![]const u8 {
    const enc = std.base64.standard.Encoder;
    const b64 = try arena.alloc(u8, enc.calcSize(html.len));
    _ = enc.encode(b64, html);
    return std.fmt.allocPrint(arena, "data:text/html;base64,{s}", .{b64});
}

fn evalObjectId(h: *cdpd1.Harness, expr: []const u8, object_group: ?[]const u8) ![]const u8 {
    const params = if (object_group) |grp|
        try std.fmt.allocPrint(h.arena(), "{{\"expression\":{f},\"objectGroup\":{f}}}", .{ std.json.fmt(expr, .{}), std.json.fmt(grp, .{}) })
    else
        try std.fmt.allocPrint(h.arena(), "{{\"expression\":{f}}}", .{std.json.fmt(expr, .{})});
    const res = try h.call("Runtime.evaluate", params);
    const result_obj = res.object.get("result").?.object;
    return result_obj.get("objectId").?.string;
}

fn findByType(listeners: []const std.json.Value, event_type: []const u8) ?std.json.ObjectMap {
    for (listeners) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, obj.get("type").?.string, event_type)) return obj;
    }
    return null;
}

const listeners_html =
    \\<!doctype html>
    \\<html>
    \\<head><meta charset="utf-8"></head>
    \\<body>
    \\<button id="btn" onclick="window.__clicked = 1">Click</button>
    \\<script>
    \\function onClickBubble() { return 1; }
    \\function onClickCapture() { return 2; }
    \\function onTargetBase() { return 3; }
    \\function onHandleEventImpl() { return 4; }
    \\function onKeyDownIdl() { return 5; }
    \\function onRemoved() { return 6; }
    \\
    \\const btn = document.getElementById('btn');
    \\const boundFn = onTargetBase.bind(null, 42);
    \\const handleObj = { handleEvent: onHandleEventImpl };
    \\
    \\btn.addEventListener('click', onClickBubble, { passive: true, once: true });
    \\btn.addEventListener('click', onClickCapture, { capture: true });
    \\btn.addEventListener('custom-bound', boundFn);
    \\btn.addEventListener('custom-obj', handleObj);
    \\btn.onkeydown = onKeyDownIdl;
    \\btn.addEventListener('removed-evt', onRemoved);
    \\btn.removeEventListener('removed-evt', onRemoved);
    \\</script>
    \\</body>
    \\</html>
;

test "DOMDebugger.getEventListeners: flags, capture-first ordering, bound & handleEvent, inline onclick, objectGroup" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var h: cdpd1.Harness = undefined;
    try h.init(allocator);
    defer h.deinit();

    const url = try dataUrl(h.arena(), listeners_html);
    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Runtime.enable", "{}");
    _ = try h.call("DOM.enable", "{}");
    const from_nav = h.seen.items.len;
    const nav_params = try std.fmt.allocPrint(h.arena(), "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
    _ = try h.call("Page.navigate", nav_params);
    _ = try h.waitEvent("Page.loadEventFired", from_nav);

    // 1. With a non-empty objectGroup: handler & originalHandler must be present.
    const obj_id_grouped = try evalObjectId(&h, "document.getElementById('btn')", "grp1");
    const get_params = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(obj_id_grouped, .{})});
    const res = try h.call("DOMDebugger.getEventListeners", get_params);
    const listeners = res.object.get("listeners").?.array.items;

    // Expected active listeners on #btn:
    //  - click (capture: true, onClickCapture)  <-- capture-first!
    //  - click (content attribute onclick)
    //  - click (bubble: onClickBubble, passive: true, once: true)
    //  - custom-bound (boundFn -> handler=onTargetBase, originalHandler=boundFn)
    //  - custom-obj (handleObj -> handler=onHandleEventImpl, originalHandler=handleObj)
    //  - keydown (IDL onKeyDownIdl)
    // Excluded: removed-evt
    try testing.expectEqual(@as(usize, 6), listeners.len);
    try testing.expect(findByType(listeners, "removed-evt") == null);

    // Capture-first ordering: first listener must be useCapture=true, all others false.
    try testing.expectEqual(true, listeners[0].object.get("useCapture").?.bool);
    try testing.expectEqualStrings("click", listeners[0].object.get("type").?.string);
    for (listeners[1..]) |item| {
        try testing.expectEqual(false, item.object.get("useCapture").?.bool);
    }

    // Every Node listener carries a positive backendNodeId and valid scriptId/line/col.
    const first_backend_id = listeners[0].object.get("backendNodeId").?.integer;
    try testing.expect(first_backend_id > 0);
    for (listeners) |item| {
        const obj = item.object;
        try testing.expectEqual(first_backend_id, obj.get("backendNodeId").?.integer);
        const sid = obj.get("scriptId").?.string;
        try testing.expect(sid.len > 0);
        try testing.expect(obj.get("lineNumber").?.integer >= 0);
        try testing.expect(obj.get("columnNumber").?.integer >= 0);
        try testing.expect(obj.get("handler") != null);
        try testing.expect(obj.get("originalHandler") != null);
    }

    // Verify passive & once flags on onClickBubble.
    var saw_passive_once = false;
    for (listeners) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, obj.get("type").?.string, "click") and !obj.get("useCapture").?.bool and obj.get("passive").?.bool) {
            try testing.expectEqual(true, obj.get("once").?.bool);
            const handler_desc = obj.get("handler").?.object.get("description").?.string;
            try testing.expect(std.mem.indexOf(u8, handler_desc, "onClickBubble") != null);
            saw_passive_once = true;
        }
    }
    try testing.expect(saw_passive_once);

    // Verify bound function unwrapping: handler is target (onTargetBase), originalHandler is bound.
    const bound_entry = findByType(listeners, "custom-bound").?;
    const bound_handler = bound_entry.get("handler").?.object;
    const bound_orig = bound_entry.get("originalHandler").?.object;
    try testing.expectEqualStrings("function", bound_handler.get("type").?.string);
    try testing.expect(std.mem.indexOf(u8, bound_handler.get("description").?.string, "onTargetBase") != null);
    try testing.expectEqualStrings("function", bound_orig.get("type").?.string);
    // Handler and originalHandler must be distinct RemoteObjects for a bound function.
    try testing.expect(!std.mem.eql(u8, bound_handler.get("objectId").?.string, bound_orig.get("objectId").?.string));

    // Verify { handleEvent } object: handler is function onHandleEventImpl, originalHandler is object.
    const obj_entry = findByType(listeners, "custom-obj").?;
    const obj_handler = obj_entry.get("handler").?.object;
    const obj_orig = obj_entry.get("originalHandler").?.object;
    try testing.expectEqualStrings("function", obj_handler.get("type").?.string);
    try testing.expect(std.mem.indexOf(u8, obj_handler.get("description").?.string, "onHandleEventImpl") != null);
    try testing.expectEqualStrings("object", obj_orig.get("type").?.string);

    // Verify IDL event handler (.onkeydown) is reported.
    const keydown_entry = findByType(listeners, "keydown").?;
    try testing.expect(std.mem.indexOf(u8, keydown_entry.get("handler").?.object.get("description").?.string, "onKeyDownIdl") != null);

    // Verify lineNumber ordering: onClickBubble is declared 1 line before onClickCapture.
    const capture_line = listeners[0].object.get("lineNumber").?.integer;
    const bound_line = bound_entry.get("lineNumber").?.integer;
    try testing.expect(bound_line == capture_line + 1);

    // 2. Without objectGroup: handler & originalHandler must be omitted (matching Blink).
    const obj_id_ungrouped = try evalObjectId(&h, "document.getElementById('btn')", null);
    const ungrouped_params = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(obj_id_ungrouped, .{})});
    const ungrouped_res = try h.call("DOMDebugger.getEventListeners", ungrouped_params);
    const ungrouped_listeners = ungrouped_res.object.get("listeners").?.array.items;
    try testing.expectEqual(@as(usize, 6), ungrouped_listeners.len);
    for (ungrouped_listeners) |item| {
        try testing.expect(item.object.get("handler") == null);
        try testing.expect(item.object.get("originalHandler") == null);
    }
}

const subtree_html =
    \\<!doctype html>
    \\<html>
    \\<body>
    \\<div id="root">
    \\  <div id="child">
    \\    <span id="grand">leaf</span>
    \\  </div>
    \\  <div id="openHost"></div>
    \\  <div id="closedHost"></div>
    \\  <iframe id="subframe" srcdoc="<button id='inframe'>hi</button><script>document.getElementById('inframe').addEventListener('frame-evt', () => {});</script>"></iframe>
    \\</div>
    \\<script>
    \\document.getElementById('root').addEventListener('root-evt', () => {});
    \\document.getElementById('child').addEventListener('child-evt', () => {});
    \\document.getElementById('grand').addEventListener('grand-evt', () => {});
    \\
    \\const openShadow = document.getElementById('openHost').attachShadow({ mode: 'open' });
    \\const openBtn = document.createElement('button');
    \\openBtn.addEventListener('open-shadow-evt', () => {});
    \\openShadow.appendChild(openBtn);
    \\
    \\const closedShadow = document.getElementById('closedHost').attachShadow({ mode: 'closed' });
    \\const closedBtn = document.createElement('button');
    \\closedBtn.addEventListener('closed-shadow-evt', () => {});
    \\closedShadow.appendChild(closedBtn);
    \\</script>
    \\</body>
    \\</html>
;

test "DOMDebugger.getEventListeners: depth (1, 2, -1), pierce (open/closed shadow + iframe), isolated world filtering" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var h: cdpd1.Harness = undefined;
    try h.init(allocator);
    defer h.deinit();

    const url = try dataUrl(h.arena(), subtree_html);
    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Runtime.enable", "{}");
    _ = try h.call("DOM.enable", "{}");
    const from_nav = h.seen.items.len;
    const nav_params = try std.fmt.allocPrint(h.arena(), "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
    _ = try h.call("Page.navigate", nav_params);
    _ = try h.waitEvent("Page.loadEventFired", from_nav);

    // Add a listener from an isolated world on #root to verify pierce context filtering.
    const ft_res = try h.call("Page.getFrameTree", "{}");
    const main_frame_id = ft_res.object.get("frameTree").?.object.get("frame").?.object.get("id").?.string;
    const iw_params = try std.fmt.allocPrint(h.arena(), "{{\"frameId\":{f},\"worldName\":\"mcp1-test-world\"}}", .{std.json.fmt(main_frame_id, .{})});
    const iw_res = try h.call("Page.createIsolatedWorld", iw_params);
    const iw_ctx_id = iw_res.object.get("executionContextId").?.integer;
    const iw_eval = try std.fmt.allocPrint(h.arena(), "{{\"contextId\":{d},\"expression\":\"document.getElementById('root').addEventListener('world-evt', () => {{}});\"}}", .{iw_ctx_id});
    _ = try h.call("Runtime.evaluate", iw_eval);

    const root_obj_id = try evalObjectId(&h, "document.getElementById('root')", "tree-grp");

    // depth=1 (default): self only, main-world only -> only 'root-evt' (not 'world-evt' or descendants).
    {
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(root_obj_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expectEqual(@as(usize, 1), list.len);
        try testing.expect(findByType(list, "root-evt") != null);
    }

    // depth=2, pierce=false: self + direct children -> 'root-evt' and 'child-evt' (not 'grand-evt').
    {
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f},\"depth\":2,\"pierce\":false}}", .{std.json.fmt(root_obj_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expectEqual(@as(usize, 2), list.len);
        try testing.expect(findByType(list, "root-evt") != null);
        try testing.expect(findByType(list, "child-evt") != null);
    }

    // depth=-1, pierce=false: light-DOM subtree only (root, child, grand; no shadow, no iframe, no isolated world).
    {
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f},\"depth\":-1,\"pierce\":false}}", .{std.json.fmt(root_obj_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expectEqual(@as(usize, 3), list.len);
        try testing.expect(findByType(list, "root-evt") != null);
        try testing.expect(findByType(list, "child-evt") != null);
        try testing.expect(findByType(list, "grand-evt") != null);
        try testing.expect(findByType(list, "open-shadow-evt") == null);
        try testing.expect(findByType(list, "closed-shadow-evt") == null);
        try testing.expect(findByType(list, "frame-evt") == null);
        try testing.expect(findByType(list, "world-evt") == null);
    }

    // depth=-1, pierce=true: light DOM + open shadow + closed shadow + same-origin iframe + isolated world!
    {
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f},\"depth\":-1,\"pierce\":true}}", .{std.json.fmt(root_obj_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expect(findByType(list, "root-evt") != null);
        try testing.expect(findByType(list, "child-evt") != null);
        try testing.expect(findByType(list, "grand-evt") != null);
        try testing.expect(findByType(list, "open-shadow-evt") != null);
        try testing.expect(findByType(list, "closed-shadow-evt") != null);
        try testing.expect(findByType(list, "frame-evt") != null);
        try testing.expect(findByType(list, "world-evt") != null);
    }
}

test "DOMDebugger.getEventListeners: Window, XMLHttpRequest, EventTarget, plain object, and invalid objectId" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var h: cdpd1.Harness = undefined;
    try h.init(allocator);
    defer h.deinit();

    const html =
        \\<!doctype html><html><body><script>
        \\window.addEventListener('devtoolstooldiscovery', () => {});
        \\window.__xhr = new XMLHttpRequest();
        \\window.__xhr.addEventListener('load', () => {}, { once: true });
        \\window.__et = new EventTarget();
        \\window.__et.addEventListener('ping', () => {}, { capture: true });
        \\window.__plain = { a: 1 };
        \\</script></body></html>
    ;
    const url = try dataUrl(h.arena(), html);
    _ = try h.call("Page.enable", "{}");
    _ = try h.call("Runtime.enable", "{}");
    const from_nav = h.seen.items.len;
    const nav_params = try std.fmt.allocPrint(h.arena(), "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
    _ = try h.call("Page.navigate", nav_params);
    _ = try h.waitEvent("Page.loadEventFired", from_nav);

    // 1. Window: finds 'devtoolstooldiscovery', no backendNodeId.
    {
        const win_id = try evalObjectId(&h, "window", "win-grp");
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(win_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        const entry = findByType(list, "devtoolstooldiscovery").?;
        try testing.expect(entry.get("backendNodeId") == null);
        try testing.expect(entry.get("handler") != null);
    }

    // 2. XMLHttpRequest: finds 'load' with once=true, no backendNodeId.
    {
        const xhr_id = try evalObjectId(&h, "window.__xhr", "xhr-grp");
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(xhr_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expectEqual(@as(usize, 1), list.len);
        const entry = list[0].object;
        try testing.expectEqualStrings("load", entry.get("type").?.string);
        try testing.expectEqual(true, entry.get("once").?.bool);
        try testing.expect(entry.get("backendNodeId") == null);
    }

    // 3. Standalone EventTarget: finds 'ping' with useCapture=true, no backendNodeId.
    {
        const et_id = try evalObjectId(&h, "window.__et", "et-grp");
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(et_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        const list = r.object.get("listeners").?.array.items;
        try testing.expectEqual(@as(usize, 1), list.len);
        try testing.expectEqualStrings("ping", list[0].object.get("type").?.string);
        try testing.expectEqual(true, list[0].object.get("useCapture").?.bool);
        try testing.expect(list[0].object.get("backendNodeId") == null);
    }

    // 4. Plain non-EventTarget object: empty listeners array, no error.
    {
        const plain_id = try evalObjectId(&h, "window.__plain", "plain-grp");
        const p = try std.fmt.allocPrint(h.arena(), "{{\"objectId\":{f}}}", .{std.json.fmt(plain_id, .{})});
        const r = try h.call("DOMDebugger.getEventListeners", p);
        try testing.expectEqual(@as(usize, 0), r.object.get("listeners").?.array.items.len);
    }

    // 5. Invalid objectId: protocol error.
    {
        const req_id = try h.sendOn(0, "DOMDebugger.getEventListeners", "{\"objectId\":\"999999.999999\"}");
        const msg = try h.errorMessage(req_id);
        try testing.expect(msg.len > 0);
    }
}
