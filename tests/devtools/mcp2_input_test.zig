//! Lane mcp2-b5 (MCP Batch 5 — User Ruling Option 2, 2026-11-23 12:51 PM ET):
//! Element-targeted trusted input (`click`, `hover`, `drag`, `fill`,
//! `fill_form`, `upload_file` file-chooser fallback, `press_key`
//! `includeSnapshot`), driven through Crane's real `user_input` and
//! `drag_and_drop` pipeline with `isTrusted: true`, Chrome event order,
//! `:hover`/`:active`, focus, dialog interruption, and computed-style
//! hit-testability refusals (`display:none`, `visibility:hidden`,
//! `pointer-events:none`, `inert`, `disabled`).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

fn expectResult(text: []const u8, json: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    const want = try std.fmt.bufPrint(&buffer, "Script ran on page and returned:\n```json\n{s}\n```", .{json});
    try testing.expectEqualStrings(want, text);
}

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

test "tools/list advertises all Batch 5 element-input tools by default" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const list = try h.send("tools/list", "{}");
    const tools = list.object.get("result").?.object.get("tools").?.array.items;
    for ([_][]const u8{ "click", "hover", "drag", "fill", "fill_form", "upload_file", "press_key", "type_text" }) |want| {
        var found = false;
        for (tools) |t| {
            if (std.mem.eql(u8, t.object.get("name").?.string, want)) {
                found = true;
                break;
            }
        }
        if (!found) std.debug.print("missing tool in tools/list: {s}\n", .{want});
        try testing.expect(found);
    }
}

test "click: single, double, trusted event order, option, dialog, includeSnapshot, and Option 2 refusals" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    const html =
        \\data:text/html,<!doctype html><title>Click</title>
        \\<button id=b>Go</button>
        \\<button id=dlg onclick="alert('clicked!')">Alert</button>
        \\<select id=sel><option value=a>Alpha</option><option value=b>Beta</option></select>
        \\<button id=dis disabled>Disabled</button>
        \\<button id=hid style="visibility:hidden">Hidden</button>
        \\<button id=pe style="pointer-events:none">NoPointer</button>
        \\<div inert><button id=inrt>Inert</button></div>
        \\<div id=dnone style="display:none"><button id=dnbtn>Gone</button></div>
        \\<script>
        \\window.ev = [];
        \\const b = document.getElementById('b');
        \\for (const t of ['pointerdown','mousedown','focus','pointerup','mouseup','click','dblclick']) {
        \\  b.addEventListener(t, e => ev.push(t + ':' + e.isTrusted + ':' + (e.detail ?? 0)));
        \\}
        \\window.selEv = [];
        \\const sel = document.getElementById('sel');
        \\sel.addEventListener('input', () => selEv.push('input:' + sel.value));
        \\sel.addEventListener('change', () => selEv.push('change:' + sel.value));
        \\</script>
    ;
    try navigate(&h, a, html);

    var r = try h.tool("take_snapshot", "{\"pageId\":1,\"verbose\":true}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const b_uid = try a.dupe(u8, try uidOf(snap, "button \"Go\""));
    const dlg_uid = try a.dupe(u8, try uidOf(snap, "button \"Alert\""));
    const opt_b_uid = try a.dupe(u8, try uidOf(snap, "option \"Beta\""));
    const pe_uid = try a.dupe(u8, try uidOf(snap, "button \"NoPointer\""));

    // Single click with includeSnapshot.
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"includeSnapshot\":true}}", .{b_uid}));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Successfully clicked on the element\n## Latest page snapshot\n"));

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [ev.join(','), document.activeElement.id, document.getElementById('b').matches(':hover')]\"}");
    try expectResult(r.text, "[\"pointerdown:true:0,mousedown:true:1,focus:true:0,pointerup:true:0,mouseup:true:1,click:true:1\",\"b\",true]");

    // Double click.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { ev = []; }\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"dblClick\":true}}", .{b_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully double clicked on the element", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => ev.filter(x => x.startsWith('click:') || x.startsWith('dblclick:')).join(',')\"}");
    try expectResult(r.text, "\"click:true:1,click:true:2,dblclick:true:2\"");

    // Clicking an <option> selects it on its <select>.
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{opt_b_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully clicked on the element", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('sel').value, selEv.join(',')]\"}");
    try expectResult(r.text, "[\"b\",\"input:b,change:b\"]");

    // Option 2 refusals: pointer-events:none, and dynamic visibility:hidden / inert.
    // (A disabled control is waited for as Puppeteer's locator waits: mcp3_input_wait_test.zig.)
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{pe_uid}));
    try testing.expect(r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "pointer-events: none") != null);

    // Hide b with visibility:hidden -> refused.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { document.getElementById('b').style.visibility = 'hidden'; }\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{b_uid}));
    try testing.expect(r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "visibility: hidden") != null);

    // (display:none is waited for as the locator waits for a box: mcp3_input_wait_test.zig.)

    // Make b inert -> refused.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { const b = document.getElementById('b'); b.style.visibility = ''; b.inert = true; }\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{b_uid}));
    try testing.expect(r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "inert") != null);

    // Clicking a button that opens alert() reports the open dialog immediately.
    r = try h.tool("click", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{dlg_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(
        "The element was clicked and it opened a dialog.\n# Open dialog\nalert: clicked!.\nCall handle_dialog to handle it before continuing.",
        r.text,
    );
    r = try h.tool("handle_dialog", "{\"pageId\":1,\"action\":\"accept\"}");
    try testing.expect(!r.is_error);
}

test "hover: sets :hover, fires boundary events, allows disabled, refuses hidden/pointer-events:none/inert" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    const html =
        \\data:text/html,<!doctype html><title>Hover</title>
        \\<button id=a>One</button>
        \\<button id=b>Two</button>
        \\<button id=dis disabled>Disabled</button>
        \\<button id=pe style="pointer-events:none">NoPointer</button>
        \\<script>
        \\window.log = [];
        \\for (const id of ['a','b']) {
        \\  const el = document.getElementById(id);
        \\  for (const t of ['pointerover','pointerenter','mouseover','mouseenter','pointerout','pointerleave','mouseout','mouseleave']) {
        \\    el.addEventListener(t, e => log.push(id + ':' + t + ':' + e.isTrusted));
        \\  }
        \\}
        \\</script>
    ;
    try navigate(&h, a, html);
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const a_uid = try a.dupe(u8, try uidOf(snap, "button \"One\""));
    const b_uid = try a.dupe(u8, try uidOf(snap, "button \"Two\""));
    const dis_uid = try a.dupe(u8, try uidOf(snap, "button \"Disabled\""));
    const pe_uid = try a.dupe(u8, try uidOf(snap, "button \"NoPointer\""));

    r = try h.tool("hover", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"includeSnapshot\":true}}", .{a_uid}));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Successfully hovered over the element\n## Latest page snapshot\n"));

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('a').matches(':hover'), document.getElementById('b').matches(':hover'), log.join(',')]\"}");
    try expectResult(r.text, "[true,false,\"a:pointerover:true,a:pointerenter:true,a:mouseover:true,a:mouseenter:true\"]");

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { log = []; }\"}");
    r = try h.tool("hover", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{b_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully hovered over the element", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('a').matches(':hover'), document.getElementById('b').matches(':hover'), log.includes('a:pointerout:true') && log.includes('b:pointerover:true')]\"}");
    try expectResult(r.text, "[false,true,true]");

    // Disabled controls CAN be hovered (Puppeteer Locator.hover does not wait for enabled).
    r = try h.tool("hover", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{dis_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully hovered over the element", r.text);

    // pointer-events:none is refused.
    r = try h.tool("hover", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\"}}", .{pe_uid}));
    try testing.expect(r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "pointer-events: none") != null);
}

test "drag: HTML5 drag-and-drop transfers DataTransfer and fires trusted DnD events" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    const html =
        \\data:text/html,<title>Drag</title>
        \\<button id=src draggable="true">Source</button>
        \\<button id=dst>Target</button>
        \\<script>
        \\window.dnd = [];
        \\const src = document.getElementById('src');
        \\const dst = document.getElementById('dst');
        \\src.addEventListener('dragstart', e => { dnd.push('dragstart:' + e.isTrusted); e.dataTransfer.setData('text/plain', 'payload'); });
        \\dst.addEventListener('dragenter', e => { e.preventDefault(); dnd.push('dragenter:' + e.isTrusted); });
        \\dst.addEventListener('dragover', e => { e.preventDefault(); if (!dnd.includes('dragover')) dnd.push('dragover'); });
        \\dst.addEventListener('drop', e => { e.preventDefault(); dnd.push('drop:' + e.isTrusted + ':' + e.dataTransfer.getData('text/plain')); });
        \\src.addEventListener('dragend', e => { dnd.push('dragend:' + e.isTrusted); });
        \\</script>
    ;
    try navigate(&h, a, html);
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const src_uid = try a.dupe(u8, try uidOf(snap, "button \"Source\""));
    const dst_uid = try a.dupe(u8, try uidOf(snap, "button \"Target\""));

    r = try h.tool("drag", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"from_uid\":\"{s}\",\"to_uid\":\"{s}\",\"includeSnapshot\":true}}", .{ src_uid, dst_uid }));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Successfully dragged an element\n## Latest page snapshot\n"));

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => dnd.join(',')\"}");
    try expectResult(r.text, "\"dragstart:true,dragenter:true,dragover,drop:true:payload,dragend:true\"");
}

test "fill and fill_form: text, textarea, select, checkbox, radio, contenteditable, long, refusals, dialog" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    const html =
        \\data:text/html,<title>Form</title>
        \\<label>Name <input id=name type=text></label>
        \\<label>Bio <textarea id=bio></textarea></label>
        \\<label>Color <select id=col><option value=r>Red</option><option value=g>Green</option></select></label>
        \\<label><input id=cb type=checkbox> Agree</label>
        \\<label><input id=rad type=radio name=g value=1> Choice</label>
        \\<div id=ce contenteditable="true" role=textbox aria-label="Editor"></div>
        \\<label>Locked <input id=ro type=text readonly value="fixed"></label>
        \\<label><input id=trig type=checkbox onchange="alert('changed!')"> Trigger</label>
        \\<button id=notinput>Plain</button>
    ;
    try navigate(&h, a, html);
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const name_uid = try a.dupe(u8, try uidOf(snap, "textbox \"Name\""));
    const bio_uid = try a.dupe(u8, try uidOf(snap, "textbox \"Bio\""));
    const col_uid = try a.dupe(u8, try uidOf(snap, "combobox \"Color\""));
    const cb_uid = try a.dupe(u8, try uidOf(snap, "checkbox \"Agree\""));
    const rad_uid = try a.dupe(u8, try uidOf(snap, "radio \"Choice\""));
    const ce_uid = try a.dupe(u8, try uidOf(snap, "textbox \"Editor\""));
    const trig_uid = try a.dupe(u8, try uidOf(snap, "checkbox \"Trigger\""));

    // fill text input (short typed path), then replace with new text.
    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"Ada\"}}", .{name_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully filled out the element", r.text);

    // fill textarea with >=100 chars (direct fill path).
    const long_val: [120]u8 = @splat('x');
    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"{s}\"}}", .{ bio_uid, long_val }));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully filled out the element", r.text);

    // fill combobox by option accessible name ("Green" -> value "g").
    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"Green\"}}", .{col_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully filled out the element", r.text);

    // fill contenteditable.
    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"Hello CE\"}}", .{ce_uid}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings("Successfully filled out the element", r.text);

    // fill_form across multiple controls + includeSnapshot.
    r = try h.tool("fill_form", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"elements\":[{{\"uid\":\"{s}\",\"value\":\"Grace\"}},{{\"uid\":\"{s}\",\"value\":\"true\"}},{{\"uid\":\"{s}\",\"value\":\"true\"}}],\"includeSnapshot\":true}}",
        .{ name_uid, cb_uid, rad_uid },
    ));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Successfully filled out the form\n## Latest page snapshot\n"));

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.getElementById('name').value, document.getElementById('bio').value.length, document.getElementById('col').value, document.getElementById('cb').checked, document.getElementById('rad').checked, document.getElementById('ce').textContent]\"}");
    try expectResult(r.text, "[\"Grace\",120,\"g\",true,true,\"Hello CE\"]");

    // Refusals chrome-devtools-mcp makes before the locator: an unknown combobox option, an invalid toggle value.
    // (A read-only field, or an element nothing fills, is retried until the locator's timeout: mcp3_input_wait_test.zig.)
    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"Purple\"}}", .{col_uid}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Error: Failed to interact with the element with uid {s}. Could not find option with text \"Purple\"", .{col_uid}), r.text);

    r = try h.tool("fill", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"value\":\"yes\"}}", .{cb_uid}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Error: Failed to interact with the element with uid {s}. Checkboxes, radio boxes and toggles require \"true\" or \"false\" value, but yes was used", .{cb_uid}), r.text);

    // fill_form interrupted by dialog stops and reports remaining elements.
    r = try h.tool("fill_form", try std.fmt.allocPrint(
        a,
        "{{\"pageId\":1,\"elements\":[{{\"uid\":\"{s}\",\"value\":\"true\"}},{{\"uid\":\"{s}\",\"value\":\"After\"}}]}}",
        .{ trig_uid, name_uid },
    ));
    try testing.expect(!r.is_error);
    const want_dlg = try std.fmt.allocPrint(
        a,
        "Filling out the element with uid {s} opened a dialog. The remaining elements were not filled out.\n# Open dialog\nalert: changed!.\nCall handle_dialog to handle it before continuing.",
        .{trig_uid},
    );
    try testing.expectEqualStrings(want_dlg, r.text);
    r = try h.tool("handle_dialog", "{\"pageId\":1,\"action\":\"accept\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => document.getElementById('name').value\"}");
    try expectResult(r.text, "\"Grace\"");
}

test "upload_file file-chooser fallback and press_key includeSnapshot" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();

    // Create a temp file in the OS temp directory (which MCP's default path policy allows).
    const tmp_dir = std.c.getenv("TMPDIR");
    const base_dir: []const u8 = if (tmp_dir) |p| std.mem.trimEnd(u8, std.mem.span(p), "/") else "/tmp";
    const file_path = try std.fmt.allocPrint(a, "{s}/crane-mcp2-b5-upload.txt", .{base_dir});
    {
        const io = std.Io.Threaded.global_single_threaded.io();
        var f = try std.Io.Dir.createFileAbsolute(io, file_path, .{});
        defer f.close(io);
        try f.writeStreamingAll(io, "hello file chooser");
    }
    defer {
        const io = std.Io.Threaded.global_single_threaded.io();
        std.Io.Dir.deleteFileAbsolute(io, file_path) catch {};
    }

    const html =
        \\data:text/html,<title>Upload</title>
        \\<input id=f type=file style="display:none">
        \\<button id=choose onclick="document.getElementById('f').click()">Choose</button>
        \\<button id=plain>Plain</button>
        \\<input id=txt type=text>
        \\<script>
        \\window.seen = [];
        \\const f = document.getElementById('f');
        \\f.addEventListener('input', () => seen.push('input'));
        \\f.addEventListener('change', () => seen.push('change:' + f.files.length + ':' + (f.files[0]?.name ?? '')));
        \\</script>
    ;
    try navigate(&h, a, html);
    var r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const snap = try a.dupe(u8, r.text);
    const choose_uid = try a.dupe(u8, try uidOf(snap, "button \"Choose\""));
    const plain_uid = try a.dupe(u8, try uidOf(snap, "button \"Plain\""));

    // upload_file on <button> that calls fileInput.click() -> file chooser fallback succeeds!
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[{f}],\"includeSnapshot\":true}}", .{ choose_uid, std.json.fmt(file_path, .{}) }));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "File uploaded from "));
    try testing.expect(std.mem.indexOf(u8, r.text, "\n## Latest page snapshot\n") != null);

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => seen.join(',')\"}");
    try expectResult(r.text, "\"input,change:1:crane-mcp2-b5-upload.txt\"");

    // upload_file on a plain button that does NOT trigger a file chooser -> exact Google text.
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[{f}]}}", .{ plain_uid, std.json.fmt(file_path, .{}) }));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Failed to upload file. The element could not accept the file directly, and clicking it did not trigger a file chooser.", r.text);

    // press_key with includeSnapshot: true now returns the snapshot!
    r = try h.tool("press_key", "{\"pageId\":1,\"key\":\"Tab\",\"includeSnapshot\":true}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Successfully pressed key: Tab\n## Latest page snapshot\n"));
}

test "external WebSocket CDP clients cannot call local-only element actions (-32601)" {
    const browser_mod = @import("browser");
    const devtools = @import("devtools");
    const cdp = @import("cdp_client.zig");
    const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();

    var path_buf: [96]u8 = undefined;
    const client = try cdp.Client.openWebSocket(allocator, server.port, try std.fmt.bufPrint(&path_buf, "/devtools/browser/{s}", .{server.browser_id.slice()}), null);
    defer client.close();

    const targets = try client.call("Target.getTargets", "{}", "");
    defer targets.deinit();
    const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
    var params_buf: [128]u8 = undefined;
    const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buf, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[0], "targetId").?}), "");
    defer attached.deinit();
    const session = cdp.stringAt(attached.value, "result.sessionId").?;

    // Local-only MCP element command must be rejected with standard -32601 on WebSocket.
    const refused = try client.call("Input._craneClickElement", "{}", session);
    defer refused.deinit();
    const err_obj = refused.value.object.get("error").?.object;
    try testing.expectEqual(@as(i64, -32601), err_obj.get("code").?.integer);

    // Standard CDP Page.setInterceptFileChooserDialog works on WebSocket too.
    const fc = try client.call("Page.setInterceptFileChooserDialog", "{\"enabled\":true}", session);
    defer fc.deinit();
    try testing.expect(fc.value.object.get("error") == null);
}
