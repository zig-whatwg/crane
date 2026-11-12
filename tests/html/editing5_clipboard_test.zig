//! Lane editing5 batch 3: the Clipboard API's copy, cut and paste actions
//! (specs/w3c/clipboard-apis.md 8, Appendix A "fire a clipboard event";
//! src/html/execcommand/clipboard.zig) reached from Ctrl/Meta+C, X and V
//! (src/html/user_input.zig) and execCommand, and their only way to the
//! clipboard: the platform protocol's readClipboard / writeClipboard
//! (docs/platform-protocol.md 6.10.6; clipboard_platform.zig). These tests
//! run on the testing platform and reach its clipboard only through the
//! protocol, as an embedder's adapter would be reached.
const std = @import("std");
const html = @import("html");
const platform = @import("platform");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const ReadRequest = html.execcommand.clipboard_platform.ReadRequest;

// ---------------------------------------------------------------------------
// The synchronous read never hangs, and its record is freed exactly once
// (std.testing.allocator fails a leak or a double free).
// ---------------------------------------------------------------------------

const one_item = [_]platform.ClipboardRepresentation{
    .{ .mime_type = platform.Str.from("text/plain"), .data = platform.Bytes.from("copied") },
    .{ .mime_type = platform.Str.from("text/html"), .data = platform.Bytes.from("<b>copied</b>") },
};
const one_entry = [_]platform.ClipboardEntry{.{ .ptr = &one_item, .len = one_item.len }};
const items: platform.ClipboardItems = .{ .ptr = &one_entry, .len = 1 };

test "a read the platform answers inside the call returns at once with the items" {
    const request = try ReadRequest.create(std.testing.allocator);
    defer request.release();
    const reply = request.reply();
    reply.deliver(reply.context, &items);
    try std.testing.expect(request.wait());
    try std.testing.expectEqualStrings("copied", request.contents.find("text/plain").?);
    try std.testing.expectEqualStrings("<b>copied</b>", request.contents.find("text/html").?);
}

test "a read the platform drops inside the call returns, with nothing" {
    const request = try ReadRequest.create(std.testing.allocator);
    defer request.release();
    const reply = request.reply();
    reply.drop(reply.context);
    try std.testing.expect(!request.wait());
    try std.testing.expect(request.contents.find("text/plain") == null);
}

const Late = struct {
    reply: platform.Reply(platform.ClipboardItems),
    deliver: bool,

    fn run(self: *const Late) void {
        // Answer well after the caller started waiting.
        var spin: usize = 0;
        while (spin < 20_000_000) : (spin += 1) std.mem.doNotOptimizeAway(spin);
        if (self.deliver) self.reply.deliver(self.reply.context, &items) else self.reply.drop(self.reply.context);
    }
};

test "a read answered later from another thread wakes the waiting caller" {
    const request = try ReadRequest.create(std.testing.allocator);
    defer request.release();
    const late: Late = .{ .reply = request.reply(), .deliver = true };
    const thread = try std.Thread.spawn(.{}, Late.run, .{&late});
    const delivered = request.wait();
    thread.join();
    try std.testing.expect(delivered);
    try std.testing.expectEqualStrings("copied", request.contents.find("text/plain").?);
}

test "a read dropped later from another thread (the platform ends) wakes the caller" {
    const request = try ReadRequest.create(std.testing.allocator);
    defer request.release();
    const late: Late = .{ .reply = request.reply(), .deliver = false };
    const thread = try std.Thread.spawn(.{}, Late.run, .{&late});
    const delivered = request.wait();
    thread.join();
    try std.testing.expect(!delivered);
}

test "the caller letting go first leaves the record to the platform's answer" {
    // The caller gives up its reference before the platform answers (the
    // record outlives the call): the answer frees it, once.
    const request = try ReadRequest.create(std.testing.allocator);
    const reply = request.reply();
    request.release();
    reply.deliver(reply.context, &items);
}

// ---------------------------------------------------------------------------
// The actions on a page, through the testing platform's clipboard.
// ---------------------------------------------------------------------------

/// The platform's command modifier, as navigator.platform names it (the
/// shortcut's own rule, user_input.isCommandModifier).
fn commandModifiers(page: helpers.Page) !html.user_input.Modifiers {
    const name = try page.evaluate("navigator.platform");
    defer std.testing.allocator.free(name);
    return if (std.mem.indexOf(u8, name, "Mac") != null) .{ .meta = true } else .{ .ctrl = true };
}

fn press(page: helpers.Page, letter: []const u8, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    const upper = std.ascii.toUpper(letter[0]);
    const code = [_]u8{ 'K', 'e', 'y', upper };
    const key: html.user_input.Key = .{ .key = letter, .code = &code, .key_code = upper, .text = letter };
    html.user_input.keyDown(&keyboard, document, key, modifiers);
    html.user_input.keyUp(&keyboard, document, key, modifiers);
}

fn browserPlatform(page: helpers.Page) !*platform.BrowserPlatform {
    const document = page.browser.current_context.?.document_instance.?;
    return html.platform_state.of(document.ctx) orelse error.NoPlatform;
}

const requester: platform.Requester = .{ .request_id = 1, .tab = 0, .frame = 0, .origin = .{}, .top_level_origin = .{}, .secure_context = true, .transient_activation = true };

fn keepUnit(context: *anyopaque, value: *const platform.Unit) callconv(.c) void {
    _ = value;
    const written: *u8 = @ptrCast(context);
    written.* = 1;
}

fn droppedUnit(context: *anyopaque) callconv(.c) void {
    const written: *u8 = @ptrCast(context);
    written.* = 2;
}

/// What the embedder's side of the protocol reads back: one MIME type's
/// data, copied.
const ReadBack = struct {
    want: []const u8,
    found: [256]u8 = undefined,
    len: ?usize = null,
    answered: bool = false,

    fn deliver(context: *anyopaque, value: *const platform.ClipboardItems) callconv(.c) void {
        const self: *ReadBack = @ptrCast(@alignCast(context));
        self.answered = true;
        for (value.ptr[0..value.len]) |entry| for (entry.ptr[0..entry.len]) |representation| {
            if (!std.mem.eql(u8, representation.mime_type.slice(), self.want)) continue;
            const data = representation.data.slice();
            const kept = @min(data.len, self.found.len);
            @memcpy(self.found[0..kept], data[0..kept]);
            self.len = kept;
        };
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *ReadBack = @ptrCast(@alignCast(context));
        self.answered = true;
    }

    fn text(self: *const ReadBack) ?[]const u8 {
        return if (self.len) |n| self.found[0..n] else null;
    }
};

/// Read `mime_type` from the page's Browser's clipboard as the embedder
/// would: through platform.readClipboard.
fn platformRead(page: helpers.Page, mime_type: []const u8) !ReadBack {
    var back: ReadBack = .{ .want = mime_type };
    const browser = try browserPlatform(page);
    if (platform.capabilities.clipboard != .unsupported) {
        platform.readClipboard(browser, &requester, &.{platform.Str.from(mime_type)}, .{ .context = &back, .deliver = ReadBack.deliver, .drop = ReadBack.drop });
    }
    try std.testing.expect(back.answered);
    return back;
}

/// Put text/plain `text` (and text/html `markup`, if any) on the page's
/// Browser's clipboard as another application would: platform.writeClipboard.
fn platformWrite(page: helpers.Page, text: []const u8, markup: ?[]const u8) !void {
    const browser = try browserPlatform(page);
    const representations = [_]platform.ClipboardRepresentation{
        .{ .mime_type = platform.Str.from("text/plain"), .data = platform.Bytes.from(text) },
        .{ .mime_type = platform.Str.from("text/html"), .data = platform.Bytes.from(markup orelse "") },
    };
    const entry = [_]platform.ClipboardEntry{.{ .ptr = &representations, .len = if (markup != null) 2 else 1 }};
    var written: u8 = 0;
    if (platform.capabilities.clipboard != .unsupported) {
        platform.writeClipboard(browser, &requester, &.{ .ptr = &entry, .len = 1 }, .{ .context = &written, .deliver = keepUnit, .drop = droppedUnit });
    }
    try std.testing.expectEqual(@as(u8, 1), written);
}

const events_script =
    \\globalThis.events = [];
    \\for (const type of ['copy', 'cut', 'paste']) document.addEventListener(type, (e) => {
    \\  events.push(type + ':' + e.isTrusted + ':' + e.bubbles + ':' + e.cancelable + ':' + e.composed + ':' + (e.target.id || e.target.localName) + ':' + (e.clipboardData ? JSON.stringify(e.clipboardData.types) + '=' + e.clipboardData.getData('text/plain') : 'null'));
    \\});
    \\for (const type of ['beforeinput', 'input']) document.addEventListener(type, (e) => {
    \\  events.push(type + ':' + e.inputType + ':' + e.data + ':' + (e.dataTransfer ? e.dataTransfer.getData('text') : 'null'));
    \\});
;

fn copyThenPasteThroughThePlatform() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(events_script);
    const modifiers = try commandModifiers(page);
    // Copy the <b> from an editing host: the copy event, then text/plain
    // and text/html on the platform's clipboard.
    try page.run("setupHost('foo{<b>bar</b>}baz').focus(); setupHost('foo{<b>bar</b>}baz'); events.length = 0;");
    press(page, "c", modifiers);
    try harness.expectEval(page, "events.join('|')", "copy:true:true:true:true:host:[]=");
    const plain = try platformRead(page, "text/plain");
    try std.testing.expectEqualStrings("bar", plain.text().?);
    const markup = try platformRead(page, "text/html");
    try std.testing.expectEqualStrings("<b>bar</b>", markup.text().?);
    // Paste at the end: the paste event (read-only data, both types), then
    // beforeinput and input insertFromPaste with a dataTransfer.
    try page.run("const t = host.lastChild; getSelection().collapse(t, t.length); events.length = 0;");
    press(page, "v", modifiers);
    try harness.expectEval(page, "events.join('|')", "paste:true:true:true:true:host:[\"text/plain\",\"text/html\"]=bar|beforeinput:insertFromPaste:null:bar|input:insertFromPaste:null:bar");
    try harness.expectEval(page, "hostHTML()", "foo<b>bar</b>baz<b>bar</b>");
}

test "Ctrl/Meta+C and V copy and paste through the platform's clipboard" {
    try helpers.onFreshThread(copyThenPasteThroughThePlatform);
}

fn pasteWhatAnotherApplicationCopied() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(events_script);
    const modifiers = try commandModifiers(page);
    // Plain text only: the insertText action.
    try platformWrite(page, "xyz", null);
    try page.run("setupHost('a[]b').focus(); setupHost('a[]b'); events.length = 0;");
    press(page, "v", modifiers);
    try harness.expectEval(page, "hostHTML()", "axyzb");
    // A canceled paste inserts nothing.
    try page.run("setupHost('a[]b'); document.addEventListener('paste', (e) => e.preventDefault(), { once: true });");
    press(page, "v", modifiers);
    try harness.expectEval(page, "hostHTML()", "ab");
    // Into a textarea: data is the text, dataTransfer null.
    try page.run("document.body.insertAdjacentHTML('beforeend', '<textarea id=area>12</textarea>'); area.focus(); area.setSelectionRange(1, 1); events.length = 0;");
    press(page, "v", modifiers);
    try harness.expectEval(page, "area.value + '|' + events.join('|')", "1xyz2|paste:true:true:true:true:area:[\"text/plain\"]=xyz|beforeinput:insertFromPaste:xyz:null|input:insertFromPaste:xyz:null");
}

test "a paste inserts what the platform's clipboard holds, in a host or a textarea" {
    try helpers.onFreshThread(pasteWhatAnotherApplicationCopied);
}

fn canceledCopyWritesTheEventData() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const modifiers = try commandModifiers(page);
    // A canceled copy writes what the listener set, not the selection.
    try page.run(
        \\setupHost('[abc]').focus(); setupHost('[abc]');
        \\document.addEventListener('copy', (e) => { e.clipboardData.setData('text', 'override'); e.preventDefault(); }, { once: true });
    );
    press(page, "c", modifiers);
    const plain = try platformRead(page, "text/plain");
    try std.testing.expectEqualStrings("override", plain.text().?);
    // Cut: the selection goes to the clipboard and leaves the host, with
    // deleteByCut.
    try page.run(events_script);
    try page.run("setupHost('a[bc]d'); events.length = 0;");
    press(page, "x", modifiers);
    try harness.expectEval(page, "hostHTML() + '|' + events.filter((e) => !e.startsWith('cut')).join('|')", "ad|beforeinput:deleteByCut:null:null|input:deleteByCut:null:null");
    const cut = try platformRead(page, "text/plain");
    try std.testing.expectEqualStrings("bc", cut.text().?);
}

test "a canceled copy writes its DataTransfer, and cut removes the selection" {
    try helpers.onFreshThread(canceledCopyWritesTheEventData);
}

fn copyAcrossInlineFlex() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const modifiers = try commandModifiers(page);
    // The copy's text/plain is the selection's rendered text (its
    // stringifier), whatever the content around it: here
    // editing/other/plain-text-copy-paste-of-paragraph-ending-with-non-
    // layed-out-content.html's inline-flex rows. (Chrome and Safari give
    // "test;" there, where the stringifier's line break around the
    // blockified flex item differs - the rendered-text collector's, queued.)
    try page.run(
        \\document.body.innerHTML = '<div id="button-in-inline">\n  <span id="contains-button">test<div id="contains-button" style="display: inline-flex"><button> </button></div>;\n  </span>\n</div>';
        \\const range = document.createRange();
        \\range.selectNodeContents(document.getElementById('button-in-inline'));
        \\getSelection().removeAllRanges(); getSelection().addRange(range);
        \\globalThis.selected = getSelection().toString();
    );
    press(page, "c", modifiers);
    const plain = try platformRead(page, "text/plain");
    const selected = try page.evaluate("selected");
    defer std.testing.allocator.free(selected);
    try std.testing.expectEqualStrings(selected, plain.text() orelse "(nothing)");
    try std.testing.expect(std.mem.startsWith(u8, selected, "test"));
}

test "copy writes the selection's rendered text around an inline-flex block" {
    try helpers.onFreshThread(copyAcrossInlineFlex);
}

fn scriptTriggered() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(events_script);
    // No transient activation: copy and cut return false and fire nothing;
    // paste is never allowed to script (no permission is configured).
    try page.run("setupHost('[abc]'); events.length = 0;");
    try harness.expectEval(page, "[document.execCommand('copy'), document.execCommand('cut'), document.execCommand('paste')].join() + '|' + events.join('|')", "false,false,false|");
    try harness.expectEval(page, "hostHTML()", "abc");
}

test "execCommand copy, cut and paste without the user's activation" {
    try helpers.onFreshThread(scriptTriggered);
}

fn clipboardEventConstructor() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try harness.expectEval(page,
        \\(() => {
        \\  const dt = new DataTransfer();
        \\  const e = new ClipboardEvent('copy', { bubbles: true, clipboardData: dt });
        \\  const plain = new ClipboardEvent('paste');
        \\  let fired = 0; document.body.addEventListener('copy', () => fired++);
        \\  document.body.dispatchEvent(e);
        \\  return [e.type, e.bubbles, e.clipboardData === dt, plain.clipboardData, plain.bubbles, fired, e.isTrusted].join();
        \\})()
    , "copy,true,true,,false,1,false");
    // The old interface of a constructed DataTransfer.
    try harness.expectEval(page,
        \\(() => {
        \\  const dt = new DataTransfer();
        \\  dt.setData('Text', 'a'); dt.setData('text/html', '<i>b</i>'); dt.setData('URL', '#c\r\nhttp://x/\r\n');
        \\  const before = dt.types.join();
        \\  const got = [dt.getData('text/plain'), dt.getData('TEXT/HTML'), dt.getData('url'), dt.getData('none')].join('/');
        \\  dt.clearData('text/html'); const one = dt.types.join();
        \\  dt.clearData(); return [before, got, one, dt.types.length, dt.items.length].join('|');
        \\})()
    , "text/plain,text/html,text/uri-list|a/<i>b</i>/http://x//|text/plain,text/uri-list|0|0");
}

test "ClipboardEvent keeps its clipboardData; DataTransfer's types, getData, setData and clearData" {
    try helpers.onFreshThread(clipboardEventConstructor);
}
