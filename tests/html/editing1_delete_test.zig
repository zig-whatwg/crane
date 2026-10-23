//! Lane editing1, batch 1a: the delete and forwardDelete commands and
//! "delete the selection" (specs/w3c/execCommand.md), script and key paths.
//!
//! Each case is the WPT editing data format: the editing host's innerHTML
//! with the selection marked by [ ] (in text) or { } (around nodes), the
//! command, and the expected innerHTML (markers stripped).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

/// The page's script-side harness: a contenteditable host, the WPT marker
/// syntax turned into a selection, and the host's innerHTML read back.
const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\globalThis.setupHost = (markup) => {
    \\  const host = document.getElementById('host');
    \\  host.innerHTML = markup;
    \\  const idx = (n) => Array.prototype.indexOf.call(n.parentNode.childNodes, n);
    \\  let s = null, so = 0, e = null, eo = 0;
    \\  const walker = document.createTreeWalker(host, NodeFilter.SHOW_TEXT);
    \\  const texts = [];
    \\  while (walker.nextNode()) texts.push(walker.currentNode);
    \\  for (const t of texts) {
    \\    let d = t.data, i;
    \\    if ((i = d.indexOf('[')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); s = t; so = i; }
    \\    if ((i = d.indexOf('{')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); s = t.parentNode; so = idx(t) + (i === 0 ? 0 : 1); }
    \\    if ((i = d.indexOf(']')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); e = t; eo = i; }
    \\    if ((i = d.indexOf('}')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); e = t.parentNode; eo = idx(t) + (i === 0 ? 0 : 1); }
    \\    t.data = d;
    \\  }
    \\  for (const t of texts) {
    \\    if (t.data !== '') continue;
    \\    const parent = t.parentNode, i = idx(t);
    \\    if (s === t) { s = parent; so = i; } else if (s === parent && so > i) so--;
    \\    if (e === t) { e = parent; eo = i; } else if (e === parent && eo > i) eo--;
    \\    parent.removeChild(t);
    \\  }
    \\  const range = document.createRange();
    \\  range.setStart(s, so);
    \\  range.setEnd(e, eo);
    \\  if (range.collapsed) range.setEnd(s, so);
    \\  getSelection().removeAllRanges();
    \\  getSelection().addRange(range);
    \\  return host;
    \\};
    \\globalThis.hostHTML = () => document.getElementById('host').innerHTML;
    \\globalThis.events = [];
    \\document.getElementById('host').addEventListener('beforeinput', (ev) => events.push('beforeinput:' + ev.inputType + ':' + ev.cancelable));
    \\document.getElementById('host').addEventListener('input', (ev) => events.push('input:' + ev.inputType + ':' + ev.cancelable));
;

const Case = struct {
    input: []const u8,
    command: []const u8,
    expected: []const u8,
};

// Expected results from tests/wpt/editing/data/delete.js and
// forwarddelete.js where at least two of Chrome, Firefox and Safari agree,
// or, for the sibling-block merge, the integrator's first-line ruling
// (Chrome and Safari): only the end block's first line joins the start
// block.
const cases = [_]Case{
    // delete: a character before the caret
    .{ .input = "foo[]bar", .command = "delete", .expected = "fobar" },
    .{ .input = "<span>foo</span>{}<span>bar</span>", .command = "delete", .expected = "<span>fo</span><span>bar</span>" },
    .{ .input = "<span>foo[</span><span>]bar</span>", .command = "delete", .expected = "<span>foo</span><span>bar</span>" },
    // invisible nodes are removed first
    .{ .input = "foo<span style=display:none>bar</span>[]baz", .command = "delete", .expected = "fobaz" },
    .{ .input = "foo<script>bar</script>[]baz", .command = "delete", .expected = "fobaz" },
    // a br, hr or img before the caret
    .{ .input = "foo<br>[]bar", .command = "delete", .expected = "foobar" },
    .{ .input = "foo<img src=about:blank>[]bar", .command = "delete", .expected = "foobar" },
    .{ .input = "<p>foo</p><hr>[]bar", .command = "delete", .expected = "<p>foo</p>bar" },
    // block merging
    .{ .input = "<p>foo</p><p>[]bar</p>", .command = "delete", .expected = "<p>foobar</p>" },
    .{ .input = "<p>foo</p><div>[]bar</div>", .command = "delete", .expected = "<p>foobar</p>" },
    .{ .input = "foo<p>[]bar</p>", .command = "delete", .expected = "foobar" },
    .{ .input = "<p>foo</p>[]bar", .command = "delete", .expected = "<p>foobar</p>" },
    .{ .input = "<p>foo</p><p>[]bar<br>baz</p>", .command = "delete", .expected = "<p>foobar</p><p>baz</p>" },
    .{ .input = "<p>fo[o</p><p>b]ar</p>", .command = "delete", .expected = "<p>foar</p>" },
    .{ .input = "<p>fo[o</p><p>bar</p><p>b]az</p>", .command = "delete", .expected = "<p>foaz</p>" },
    // a non-collapsed selection, with and without wrappers to strip
    .{ .input = "foo[bar]baz", .command = "delete", .expected = "foobaz" },
    .{ .input = "<b>foo[bar</b>baz]", .command = "delete", .expected = "<b>foo</b>" },
    .{ .input = "<p>[foo]</p>", .command = "delete", .expected = "<p><br></p>" },
    .{ .input = "<p><b>[foo]</b></p>", .command = "delete", .expected = "<p><br></p>" },
    .{ .input = "<span>[abc]</span>", .command = "forwardDelete", .expected = "<br>" },
    // canonical white-space
    .{ .input = "foo  []bar", .command = "delete", .expected = "foobar" },
    .{ .input = "foo&nbsp; []bar", .command = "delete", .expected = "foo bar" },
    .{ .input = "<pre>foo&nbsp; []bar</pre>", .command = "delete", .expected = "<pre>foo&nbsp;bar</pre>" },
    // nothing before the caret: no change, still returns true
    .{ .input = "[]foo", .command = "delete", .expected = "foo" },
    // collapsed white-space at a line boundary is left alone (the browsers;
    // the spec would strip it)
    .{ .input = "<div> []abc</div>", .command = "delete", .expected = "<div> abc</div>" },
    .{ .input = "<div> [] abc</div>", .command = "delete", .expected = "<div>  abc</div>" },
    .{ .input = "<div>abc[] </div>", .command = "forwardDelete", .expected = "<div>abc </div>" },
    .{ .input = "<div>abc [] </div>", .command = "forwardDelete", .expected = "<div>abc  </div>" },
    // ...but a deletion next to it strips it, as the spec's canonicalize
    // whitespace does and the browsers accept
    .{ .input = "<div> a[]bc</div>", .command = "delete", .expected = "<div>bc</div>" },
    .{ .input = "<div>abc </div><div>[]def</div>", .command = "delete", .expected = "<div>abcdef</div>" },
    .{ .input = "<div>abc</div><div> []def</div>", .command = "delete", .expected = "<div>abcdef</div>" },
    // forwardDelete: a character after the caret, with its combining marks
    .{ .input = "foo[]bar", .command = "forwardDelete", .expected = "fooar" },
    .{ .input = "foo[]b\u{308}ar", .command = "forwardDelete", .expected = "fooar" },
    .{ .input = "foo[]<span style=display:none>bar</span>baz", .command = "forwardDelete", .expected = "fooaz" },
    .{ .input = "foo[]<br>bar", .command = "forwardDelete", .expected = "foobar" },
    .{ .input = "<p>foo[]</p><p>bar</p>", .command = "forwardDelete", .expected = "<p>foobar</p>" },
    .{ .input = "<p>foo[]</p><p>bar<br>baz</p>", .command = "forwardDelete", .expected = "<p>foobar</p><p>baz</p>" },
    .{ .input = "foo[]<p>bar</p>", .command = "forwardDelete", .expected = "foobar" },
    .{ .input = "foo[bar]baz", .command = "forwardDelete", .expected = "foobaz" },
    .{ .input = "foo[]", .command = "forwardDelete", .expected = "foo" },
};

fn expectHost(page: helpers.Page, expected: []const u8, input: []const u8, command: []const u8) !void {
    const actual = try page.evaluate("hostHTML()");
    defer std.testing.allocator.free(actual);
    if (!std.mem.eql(u8, actual, expected)) {
        std.debug.print("{s} on {s}: expected {s}, got {s}\n", .{ command, input, expected, actual });
        return error.TestUnexpectedResult;
    }
}

fn commandCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "setupHost({f}); events.length = 0; document.execCommand({f}, false, '')", .{ std.json.fmt(case.input, .{}), std.json.fmt(case.command, .{}) });
        defer std.testing.allocator.free(source);
        const returned = try page.evaluate(source);
        defer std.testing.allocator.free(returned);
        if (!std.mem.eql(u8, returned, "true")) {
            std.debug.print("{s} on {s}: execCommand returned {s}\n", .{ case.command, case.input, returned });
            failures += 1;
        }
        expectHost(page, case.expected, case.input, case.command) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "delete and forwardDelete: the editing spec's actions" {
    try helpers.onFreshThread(commandCases);
}

fn scriptFiresInputOnly() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // The browsers fire no beforeinput for a script's execCommand (WPT
    // input-events/input-events-exec-command.html, "execCommand() should only
    // trigger 'input'": Chrome 156 and Firefox 158 pass its "shouldn't fire
    // beforeinput" subtests), and input only when the DOM changed.
    try page.run("setupHost('foo[]bar'); events.length = 0; document.execCommand('delete', false, '')");
    const changed = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(changed);
    try std.testing.expectEqualStrings("input:deleteContentBackward:false", changed);
    try page.run("setupHost('[]foo'); events.length = 0; document.execCommand('forwardDelete', false, '')");
    const forward = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(forward);
    try std.testing.expectEqualStrings("input:deleteContentForward:false", forward);
    try page.run("setupHost('[]foo'); events.length = 0; document.execCommand('delete', false, '')");
    const unchanged = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(unchanged);
    try std.testing.expectEqualStrings("", unchanged);
}

test "execCommand delete fires input, never beforeinput" {
    try helpers.onFreshThread(scriptFiresInputOnly);
}

fn notEnabledOutsideAnEditingHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // The active range outside every editing host: not enabled, false, no change.
    try page.run("document.body.insertAdjacentHTML('beforeend', '<p id=plain>foobar</p>'); const r = document.createRange(); r.setStart(plain.firstChild, 3); r.setEnd(plain.firstChild, 3); getSelection().removeAllRanges(); getSelection().addRange(r);");
    const returned = try page.evaluate("document.execCommand('delete', false, '')");
    defer std.testing.allocator.free(returned);
    try std.testing.expectEqualStrings("false", returned);
    const enabled = try page.evaluate("document.queryCommandEnabled('delete')");
    defer std.testing.allocator.free(enabled);
    try std.testing.expectEqualStrings("false", enabled);
    const text = try page.evaluate("plain.textContent");
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("foobar", text);
}

test "delete is not enabled outside an editing host" {
    try helpers.onFreshThread(notEnabledOutsideAnEditingHost);
}

fn pressKey(page: helpers.Page, name: []const u8, key_code: u32) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = name, .code = name, .key_code = key_code }, .{});
    html.user_input.keyUp(&keyboard, document, .{ .key = name, .code = name, .key_code = key_code }, .{});
}

fn keysRouteToTheActions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // Backspace: beforeinput (cancelable, deleteContentBackward) at the
    // editing host, the delete action, input.
    try page.run("setupHost('foo[]bar').focus(); events.length = 0;");
    pressKey(page, "Backspace", 8);
    try expectHost(page, "fobar", "foo[]bar", "Backspace");
    const backspace = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(backspace);
    try std.testing.expectEqualStrings("beforeinput:deleteContentBackward:true,input:deleteContentBackward:false", backspace);
    // Delete: the forward action.
    try page.run("setupHost('foo[]bar').focus(); events.length = 0;");
    pressKey(page, "Delete", 46);
    try expectHost(page, "fooar", "foo[]bar", "Delete");
    const forward = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(forward);
    try std.testing.expectEqualStrings("beforeinput:deleteContentForward:true,input:deleteContentForward:false", forward);
    // A cancelled beforeinput: no action, no input.
    try page.run("setupHost('foo[]bar').focus(); events.length = 0; host.addEventListener('beforeinput', (ev) => ev.preventDefault(), { once: true });");
    pressKey(page, "Backspace", 8);
    try expectHost(page, "foobar", "foo[]bar", "cancelled Backspace");
    const cancelled = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(cancelled);
    try std.testing.expectEqualStrings("beforeinput:deleteContentBackward:true", cancelled);
    // Backspace in a block merges with the previous block, as the command does.
    try page.run("setupHost('<p>foo</p><p>[]bar</p>').focus(); events.length = 0;");
    pressKey(page, "Backspace", 8);
    try expectHost(page, "<p>foobar</p>", "<p>foo</p><p>[]bar</p>", "Backspace");
}

test "Backspace and Delete in an editing host run the delete actions" {
    try helpers.onFreshThread(keysRouteToTheActions);
}

fn selectionFollowsTheDeletion() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // After a merge the caret sits at the join (delete the selection step
    // 34.1 collapses at the start block's end; the moved nodes are inserted
    // after it, preserving ranges): typing continues there.
    try page.run("setupHost('<p>foo</p><p>[]bar</p>'); document.execCommand('delete', false, '')");
    const caret = try page.evaluate("(() => { const s = getSelection(); return s.isCollapsed + ':' + s.anchorNode.nodeName + ':' + s.anchorNode.textContent + ':' + s.anchorOffset; })()");
    defer std.testing.allocator.free(caret);
    try std.testing.expectEqualStrings("true:P:foobar:1", caret);
    // A collapsed text deletion leaves the caret where the character was.
    try page.run("setupHost('foo[]bar'); document.execCommand('delete', false, '')");
    const after_text = try page.evaluate("(() => { const s = getSelection(); return s.isCollapsed + ':' + s.anchorNode.textContent + ':' + s.anchorOffset; })()");
    defer std.testing.allocator.free(after_text);
    try std.testing.expectEqualStrings("true:fobar:2", after_text);
}

test "the selection collapses where the deletion happened" {
    try helpers.onFreshThread(selectionFollowsTheDeletion);
}
