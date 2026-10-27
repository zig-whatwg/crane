//! Lane editing3, units 3-4: the Document's state and value overrides
//! (specs/w3c/execCommand.md "Recording and restoring overrides"), the
//! insertText action that honours them, and typing from the keyboard in an
//! editing host (src/html/execcommand/insert_text.zig, overrides.zig,
//! root.zig typeByKey; src/html/user_input.zig).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\const reset = document.createElement('style');
    \\reset.textContent = 'body { font-family: serif } b, strong { font-weight: bold }';
    \\document.head.appendChild(reset);
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
    \\globalThis.hostHTML = () => {
    \\  const host = document.getElementById('host');
    \\  for (const node of host.querySelectorAll('[style]')) {
    \\    node.setAttribute('style', node.getAttribute('style').replace(/; ?$/, '').replace(/: /g, ':'));
    \\  }
    \\  return host.innerHTML;
    \\};
    \\globalThis.events = [];
    \\document.getElementById('host').addEventListener('beforeinput', (ev) => events.push('beforeinput:' + ev.inputType + ':' + ev.data + ':' + ev.cancelable));
    \\document.getElementById('host').addEventListener('input', (ev) => events.push('input:' + ev.inputType + ':' + ev.data));
;

const Case = struct {
    input: []const u8,
    commands: []const u8,
    expected: []const u8,
};

// tests/wpt/editing/data/multitest.js and inserttext.js. The typing-style
// cases are editing1's class A rows the browsers agree on (sub/sup:
// Chrome and Firefox; the span: Chrome and Safari; the <div>abc<b>...
// rows: all three).
const cases = [_]Case{
    // A collapsed bold, then typing: the state override styles the text.
    .{ .input = "foo[]bar", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"],[\"inserttext\",\"a\"]]", .expected = "foo<b>a</b>bar" },
    .{ .input = "foo[]bar", .commands = "[[\"stylewithcss\",\"true\"],[\"italic\",\"\"],[\"inserttext\",\"a\"]]", .expected = "foo<span style=\"font-style:italic\">a</span>bar" },
    .{ .input = "<b>foo[]bar</b>", .commands = "[[\"bold\",\"\"],[\"inserttext\",\"a\"]]", .expected = "<b>foo</b>a<b>bar</b>" },
    .{ .input = "foo[]bar", .commands = "[[\"fontname\",\"sans-serif\"],[\"inserttext\",\"a\"]]", .expected = "foo<font face=\"sans-serif\">a</font>bar" },
    .{ .input = "foo[]bar", .commands = "[[\"createlink\",\"http://www.google.com/\"],[\"inserttext\",\"a\"]]", .expected = "foo<a href=\"http://www.google.com/\">a</a>bar" },
    // Deleting a wrapper records its style; the next character gets it.
    .{ .input = "foo<sub>[bar]</sub>baz", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"a\"]]", .expected = "foo<sub>a</sub>baz" },
    .{ .input = "foo<sup>[bar]</sup>baz", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"a\"]]", .expected = "foo<sup>a</sup>baz" },
    .{ .input = "foo<span style=background-color:#00FFFF>[bar]</span>baz", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"a\"]]", .expected = "foo<span style=\"background-color:rgb(0, 255, 255)\">a</span>baz" },
    .{ .input = "<div>abc<b>[def]</b></div>", .commands = "[[\"stylewithcss\",\"false\"],[\"delete\",\"\"],[\"inserttext\",\"d\"]]", .expected = "<div>abc<b>d</b></div>" },
    // insertText itself.
    .{ .input = "foo[]bar", .commands = "[[\"inserttext\",\"a\"]]", .expected = "fooabar" },
    .{ .input = "foo[bar]baz", .commands = "[[\"inserttext\",\"a\"]]", .expected = "fooabaz" },
    .{ .input = "foo[]bar", .commands = "[[\"inserttext\",\"abc\"]]", .expected = "fooabcbar" },
    .{ .input = "foo[]bar", .commands = "[[\"inserttext\",\" \"]]", .expected = "foo bar" },
    .{ .input = "foo[]", .commands = "[[\"inserttext\",\" \"]]", .expected = "foo&nbsp;" },
    .{ .input = "<p>[]<br></p>", .commands = "[[\"inserttext\",\"a\"]]", .expected = "<p>a</p>" },
    .{ .input = "http://a[]", .commands = "[[\"inserttext\",\" \"]]", .expected = "http://a&nbsp;" },
    // insertHTML and insertImage (editing/data/inserthtml.js, insertimage.js).
    .{ .input = "foo[]bar", .commands = "[[\"inserthtml\",\"ab<b>c</b>d\"]]", .expected = "fooab<b>c</b>dbar" },
    .{ .input = "foo<span style=color:#aBcDeF>[bar]</span>baz", .commands = "[[\"inserthtml\",\"ab<b>c</b>d\"]]", .expected = "fooab<b>c</b>dbaz" },
    .{ .input = "foo[]bar", .commands = "[[\"insertimage\",\"/img/lion.svg\"]]", .expected = "foo<img src=\"/img/lion.svg\">bar" },
};

fn runCaseList(list: []const Case) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (list) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "document.execCommand('styleWithCSS', false, 'false'); setupHost({f}); for (const [c, v] of {s}) document.execCommand(c, false, v);", .{ std.json.fmt(case.input, .{}), case.commands });
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        const actual = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("{s} on {s}: expected {s}, got {s}\n", .{ case.commands, case.input, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

fn runCases() !void {
    try runCaseList(&cases);
}

test "insertText honours the state and value overrides" {
    try helpers.onFreshThread(runCases);
}

// The typing style a deletion leaves comes from where the deletion starts
// (Blink DeleteSelectionCommand::SaveTypingStyleState), not from the first
// formattable node inside it as the spec records it: here the spec would
// make "de" bold and italic (the <img> is the first formattable node).
// multitest.html ?9001-last class-B rows: Chrome 156 and Safari 27 pass,
// Firefox 158 fails (wpt.fyi c645564b0e).
const start_of_deletion_cases = [_]Case{
    .{ .input = "<div>abc[<b><i><img src=\"about:blank\">de]f</i></b>ghi</div>", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"d\"],[\"inserttext\",\"e\"]]", .expected = "<div>abcde<b><i>f</i></b>ghi</div>" },
    .{ .input = "<div>abc{<b><i>de]f</i></b>ghi</div>", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"d\"],[\"inserttext\",\"e\"]]", .expected = "<div>abcde<b><i>f</i></b>ghi</div>" },
    // Started inside the wrappers: their style carries on.
    .{ .input = "<div>abc<b>[def]</b></div>", .commands = "[[\"stylewithcss\",\"false\"],[\"delete\",\"\"],[\"inserttext\",\"d\"]]", .expected = "<div>abc<b>d</b></div>" },
};

fn startOfDeletion() !void {
    try runCaseList(&start_of_deletion_cases);
}

test "the typing style a deletion leaves comes from where it starts" {
    try helpers.onFreshThread(startOfDeletion);
}

// Restoring the recorded wrappers outermost first, in the order the
// overrides were set, rebuilds their nesting: all three browsers pass
// multitest.html ?9001-last "delete, inserttext d,e,f on <div>abc<b><i>
// [def]</i></b>ghi</div>" and its forwarddelete form (wpt.fyi
// c645564b0e); the spec's fixed order gives <i><b>def</b></i>.
const nesting_cases = [_]Case{
    .{ .input = "<div>abc<b><i>[def]</i></b>ghi</div>", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"d\"],[\"inserttext\",\"e\"],[\"inserttext\",\"f\"]]", .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc<b><i>[def]</i></b>ghi</div>", .commands = "[[\"forwarddelete\",\"\"],[\"inserttext\",\"d\"],[\"inserttext\",\"e\"],[\"inserttext\",\"f\"]]", .expected = "<div>abc<b><i>def</i></b>ghi</div>" },
    .{ .input = "<div>abc<i><b>[def]</b></i>ghi</div>", .commands = "[[\"delete\",\"\"],[\"inserttext\",\"d\"]]", .expected = "<div>abc<i><b>d</b></i>ghi</div>" },
};

fn nestingOrder() !void {
    try runCaseList(&nesting_cases);
}

test "retyped text gets the deleted wrappers back in their nesting order" {
    try helpers.onFreshThread(nestingOrder);
}

fn overridesOutliveTheCommand() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // One command sets the override (its scratch arena is freed when it
    // returns); later commands and queries read it from the Document.
    try page.run("setupHost('foo[]bar'); document.execCommand('fontName', false, 'monospace'); document.execCommand('bold');");
    const state = try page.evaluate("[document.queryCommandState('bold'), document.queryCommandValue('fontName')].join(',')");
    defer std.testing.allocator.free(state);
    try std.testing.expectEqualStrings("true,monospace", state);
    // Moving the selection unsets every override.
    try page.run("getSelection().collapse(host.firstChild, 1);");
    const moved = try page.evaluate("[document.queryCommandState('bold'), document.queryCommandValue('fontName')].join(',')");
    defer std.testing.allocator.free(moved);
    try std.testing.expectEqualStrings("false,serif", moved);
}

test "the overrides outlive the command that set them, until the selection moves" {
    try helpers.onFreshThread(overridesOutliveTheCommand);
}

fn reusedSlotIsADifferentSelection() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // The overrides remember the selection by address and slab generation,
    // never by dereferencing it: a node freed and its slot reissued to a
    // new node at the same offset is a different selection.
    try page.run("setupHost('xy[]'); getSelection().collapse(host.firstChild, 1); document.execCommand('bold');");
    const before = try page.evaluate("document.queryCommandState('bold')");
    defer std.testing.allocator.free(before);
    try std.testing.expectEqualStrings("true", before);
    // Free the Text node the selection was in (and its range), let the slab
    // reissue slots, and put the caret at the same offset of a new Text
    // node - likely the freed slot.
    try page.run("host.firstChild.remove(); getSelection().removeAllRanges(); collectNow(); const fresh = document.createTextNode('xy'); host.appendChild(fresh); getSelection().collapse(fresh, 1);");
    const after = try page.evaluate("document.queryCommandState('bold')");
    defer std.testing.allocator.free(after);
    try std.testing.expectEqualStrings("false", after);
}

test "an override does not follow a reused node slot" {
    try helpers.onFreshThread(reusedSlotIsADifferentSelection);
}

fn typeKey(page: helpers.Page, text: []const u8, name: []const u8) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = name, .text = text }, .{});
    html.user_input.keyUp(&keyboard, document, .{ .key = name, .text = text }, .{});
}

fn typingInAnEditingHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // A character: beforeinput (insertText, its data, cancelable), the
    // insertText action, input.
    try page.run("setupHost('foo[]bar').focus(); events.length = 0;");
    typeKey(page, "a", "a");
    const html_after = try page.evaluate("hostHTML()");
    defer std.testing.allocator.free(html_after);
    try std.testing.expectEqualStrings("fooabar", html_after);
    const seen = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings("beforeinput:insertText:a:true,input:insertText:a", seen);
    // A cancelled beforeinput: nothing typed, no input.
    try page.run("setupHost('foo[]bar').focus(); events.length = 0; host.addEventListener('beforeinput', (e) => e.preventDefault(), { once: true });");
    typeKey(page, "a", "a");
    const cancelled = try page.evaluate("hostHTML() + '|' + events.join(',')");
    defer std.testing.allocator.free(cancelled);
    try std.testing.expectEqualStrings("foobar|beforeinput:insertText:a:true", cancelled);
    // A collapsed bold, then a typed character: bold.
    try page.run("setupHost('foo[]bar').focus(); document.execCommand('bold'); events.length = 0;");
    typeKey(page, "a", "a");
    const bolded = try page.evaluate("hostHTML()");
    defer std.testing.allocator.free(bolded);
    try std.testing.expectEqualStrings("foo<b>a</b>bar", bolded);
    // execCommand('insertText') fires input only, with the text as data.
    try page.run("setupHost('foo[]bar'); events.length = 0; document.execCommand('insertText', false, 'xy');");
    const script = try page.evaluate("events.join(',')");
    defer std.testing.allocator.free(script);
    try std.testing.expectEqualStrings("input:insertText:xy", script);
}

test "typing in an editing host runs insertText with beforeinput and input" {
    try helpers.onFreshThread(typingInAnEditingHost);
}

fn plaintextOnlyInsertHtml() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // A plaintext-only host takes the HTML's text (editing/plaintext-only/
    // insertHTML.html); scripts never run and their text is not inserted.
    try page.run("host.setAttribute('contenteditable', 'plaintext-only'); globalThis.ran = false;");
    const Row = struct { html: []const u8, expected: []const u8 };
    const rows = [_]Row{
        .{ .html = "plaintext", .expected = "plaintext" },
        .{ .html = "1st line\n2nd line", .expected = "1st line 2nd line" },
        .{ .html = "<div>abc</div><div>def</div>", .expected = "abc<br>def" },
        .{ .html = "<script>globalThis.ran = true</script>", .expected = "" },
        .{ .html = "<style>style</style>", .expected = "" },
        .{ .html = "<span>plain  text</span>", .expected = "plain text" },
    };
    var failures: usize = 0;
    for (rows) |row| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "setupHost('{{}}'); document.execCommand('insertHTML', false, {f}); hostHTML()", .{std.json.fmt(row.html, .{})});
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, row.expected)) {
            std.debug.print("plaintext-only insertHTML {s}: expected {s}, got {s}\n", .{ row.html, row.expected, actual });
            failures += 1;
        }
    }
    const ran = try page.evaluate("String(globalThis.ran)");
    defer std.testing.allocator.free(ran);
    try std.testing.expectEqualStrings("false", ran);
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "insertHTML in a plaintext-only host inserts the text, never runs scripts" {
    try helpers.onFreshThread(plaintextOnlyInsertHtml);
}

fn designModeInsertHtml() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // In design mode a plaintext-only element still takes HTML
    // (plaintext-only-in-designMode.html; all three browsers).
    try page.run("document.body.innerHTML = '<div id=p contenteditable=plaintext-only>x</div>'; document.designMode = 'on'; getSelection().selectAllChildren(p); document.execCommand('insertHTML', false, '<b>ABC</b>');");
    const actual = try page.evaluate("p.innerHTML");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("<b>ABC</b>", actual);
}

test "insertHTML in design mode keeps the HTML even in a plaintext-only element" {
    try helpers.onFreshThread(designModeInsertHtml);
}
