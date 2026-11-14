//! Lane sel1 (batch 1): the select element's selectedcontent updates as HTML
//! states them since whatwg/html#13201 (2026-11-09), and two user
//! selection paths.
//!
//! - "clone an option into a selectedcontent" steps 3-4 remove script, SVG
//!   script, frame, iframe, embed and object elements from the clone, in
//!   shadow trees too (selectedcontent-omits-scripts-frames-and-plugins.html).
//! - A select's "pending selectedcontent update": the selectedcontent and
//!   option post-connection steps update EVERY descendant selectedcontent
//!   of the select while it is set (selectedcontent-mutations.html test3 and
//!   test8), the moving steps queue nothing when the select did not change
//!   (selectedcontent-subtree-mutations.html), and the queued microtask does
//!   nothing once an update ran in the meantime.
//! - Typeahead in a native-appearance select picks the match and sets its
//!   dirtiness (select-user-selection-dirtiness.html, typing subtest).
//! - A click on a base-appearance single-select list box picks the option,
//!   never toggles it off (customizable-select-listbox-mouse-behavior.html).
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn element(document: *runtime.Instance, selector: []const u8) !*runtime.Instance {
    return (try dom.selector_matching.querySelector(document, selector)) orelse error.NoElement;
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn cloneOmissions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=s><button><selectedcontent></selectedcontent></button><option>zero</option>' +
        \\  '<option id=o><span>one</span><iframe></iframe><embed><object></object><svg><script></script></svg><script>window.ran = true</script><div id=host></div></option></select>';
        \\const option = document.getElementById('o');
        \\option.append(document.createElement('frame'));
        \\const shadow = document.getElementById('host').attachShadow({mode: 'closed', clonable: true});
        \\shadow.innerHTML = '<span>shadow</span><iframe></iframe><p><object></object></p>';
        \\globalThis.framesBefore = window.frames.length;
        \\option.selected = true;
    );
    // The clone keeps everything else, and its shadow tree.
    try expectScript(page, "document.querySelector('selectedcontent span').textContent", "one");
    try expectScript(page, "String(document.querySelector('selectedcontent').querySelectorAll('script, frame, iframe, embed, object').length)", "0");
    try expectScript(page, "String(document.querySelector('selectedcontent').querySelectorAll('svg, div').length)", "2");
    // A closed root is a shadow-including descendant too: read it natively.
    const document = try documentOf(page);
    const host = try element(document, "selectedcontent div");
    const root = dom.custom_elements.shadowRootOf(host) orelse return error.NoShadowRoot;
    try std.testing.expect((try dom.selector_matching.querySelector(root, "span")) != null);
    try std.testing.expect((try dom.selector_matching.querySelector(root, "iframe, object, p > object")) == null);
    try std.testing.expect((try dom.selector_matching.querySelector(root, "p")) != null);
    try expectScript(page, "String(window.frames.length === framesBefore)", "true");
}

test "cloning an option into selectedcontent omits script, SVG script, frame, iframe, embed and object, in shadow trees too" {
    try helpers.onFreshThread(cloneOmissions);
}

fn postConnectionUpdatesAll() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=s><button><selectedcontent id=a></selectedcontent></button><option>one</option></select>';
        \\globalThis.a = document.getElementById('a');
    );
    try expectScript(page, "a.innerHTML", "one");
    // The new selectedcontent's insertion steps queue an update (the pending
    // flag) and its post-connection steps perform it: every descendant
    // selectedcontent of the select, at once.
    try expectScript(page,
        \\a.textContent = 'stale';
        \\const b = document.createElement('selectedcontent');
        \\document.querySelector('button').append(b);
        \\a.innerHTML + '|' + b.innerHTML
    , "one|one");
}

test "a selectedcontent's post-connection steps update every selectedcontent of its select" {
    try helpers.onFreshThread(postConnectionUpdatesAll);
}

fn reinsertedSelectUpdatesOnce() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=from><select><button><selectedcontent></selectedcontent></button><option>one</option><option>two</option></select></div><div id=to></div>';
        \\globalThis.records = [];
        \\globalThis.observer = new MutationObserver(list => records.push(...list));
        \\observer.observe(document.querySelector('selectedcontent'), {childList: true});
        \\document.getElementById('to').appendChild(document.querySelector('select'));
    );
    // The option post-connection steps and the selectedcontent ones share
    // the select's one pending update: one record, not one per element.
    try expectScript(page,
        \\const taken = records.concat(observer.takeRecords());
        \\taken.length + '|' + taken.map(r => r.addedNodes.length + '/' + r.removedNodes.length).join() + '|' + document.querySelector('selectedcontent').innerHTML
    , "1|1/1|one");
}

test "re-inserting a select updates its selectedcontent once" {
    try helpers.onFreshThread(reinsertedSelectUpdatesOnce);
}

fn movedAncestorQueuesNothing() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=old><div id=wrapper><select><button><selectedcontent></selectedcontent></button><option>one</option><option id=b>two</option></select></div></div><div id=new></div>';
        \\globalThis.content = document.querySelector('selectedcontent');
        \\globalThis.original = content.firstChild;
        \\globalThis.observer = new MutationObserver(() => {});
        \\observer.observe(content, {childList: true, subtree: true});
        \\document.getElementById('new').moveBefore(document.getElementById('wrapper'), null);
    );
    // The microtask checkpoint after the script ran: no update was queued.
    try expectScript(page, "String(content.firstChild === original) + '|' + observer.takeRecords().length", "true|0");
    try expectScript(page, "document.getElementById('b').selected = true; content.innerHTML", "two");
}

test "moving an ancestor of the select queues no selectedcontent update" {
    try helpers.onFreshThread(movedAncestorQueuesNothing);
}

fn movedIntoMultipleSelect() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=a><button><selectedcontent></selectedcontent></button><option>one</option></select>' +
        \\  '<select id=b><button></button><option>two</option></select>';
        \\globalThis.content = document.querySelector('selectedcontent');
        \\const b = document.getElementById('b');
        \\b.querySelector('button').moveBefore(content, null);
        \\b.multiple = true;
    );
    // The microtask the moving steps queued finds the update already done:
    // the multiple attribute's steps ran it (and it changes nothing then).
    try expectScript(page, "content.innerHTML", "one");
}

test "a selectedcontent moved into a select that becomes multiple before the microtask runs is not updated" {
    try helpers.onFreshThread(movedIntoMultipleSelect);
}

fn removalRecalculatesDisabledness() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select><option id=o>one</option></select>';
        \\globalThis.content = document.createElement('selectedcontent');
        \\document.getElementById('o').append(content);
    );
    const document = try documentOf(page);
    const content = try element(document, "selectedcontent");
    try std.testing.expect(dom.selected_content.isDisabled(content));
    // HTML selectedcontent removing steps: recalculate its disabledness.
    try page.run("content.remove()");
    try std.testing.expect(!dom.selected_content.isDisabled(content));
}

test "removing a selectedcontent recalculates its disabledness" {
    try helpers.onFreshThread(removalRecalculatesDisabledness);
}

fn nativeTypeahead() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=s><option>apple</option><option>banana</option><option>cherry</option></select>';
        \\globalThis.select = document.getElementById('s');
        \\globalThis.log = [];
        \\select.addEventListener('input', () => log.push('input'));
        \\select.addEventListener('change', () => log.push('change'));
        \\select.focus();
    );
    const document = try documentOf(page);
    var keyboard: user_input.Keyboard = .{};
    user_input.keyDown(&keyboard, document, .{ .key = "b", .text = "b" }, .{});
    user_input.keyUp(&keyboard, document, .{ .key = "b", .text = "b" }, .{});
    try expectScript(page, "select.value", "banana");
    try page.turn();
    try expectScript(page, "log.join()", "input,change");
    // Picked: dirty, so the selected attribute no longer controls it.
    try expectScript(page,
        \\select.options[1].setAttribute('selected', '');
        \\select.options[1].removeAttribute('selected');
        \\select.value
    , "banana");
}

test "typeahead in a native-appearance select picks the match and sets its dirtiness" {
    try helpers.onFreshThread(nativeTypeahead);
}

fn listBoxClickPicks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = 'select { appearance: base-select }';
        \\document.head.append(style);
        \\document.body.innerHTML = '<select id=s size=4><option id=one>one</option><option id=two>two</option></select>';
    );
    const document = try documentOf(page);
    const two = try element(document, "#two");
    var pointer = user_input.Pointer{};
    for (0..2) |_| {
        user_input.pointerMove(&pointer, two, .{});
        user_input.pointerDown(&pointer, 0, .{});
        user_input.pointerUp(&pointer, 0, .{});
    }
    try expectScript(page, "String(document.getElementById('s').selectedOptions.length) + '|' + document.getElementById('s').value", "1|two");
}

test "clicking the selected option of a base-appearance single-select list box keeps it selected" {
    try helpers.onFreshThread(listBoxClickPicks);
}
