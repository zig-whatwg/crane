//! Lane forms1 batch 2, C6: form control state restoration - HTML 7.4.6.5
//! "save persisted state" / "restore persisted state" step 2, the persisted
//! user state HTML leaves implementation-defined, as Blink's FormController
//! (form_controller.cc) keeps it: the controls' states grouped by form key
//! (the owner form's action without its query, its first two named
//! controls, its index among forms with that signature; "No owner"), each
//! (name, type) a queue in tree order; restored in tree order (a form's
//! controls together), skipping disabled, readonly, user-edited and
//! disconnected controls, firing no input or change event (HTML 7.4.6.5's
//! note), a select's selectedcontent updated at once
//! (selectedcontent-restore.optional.html). Navigation's part (save at
//! "activate history entry", restore after a back/forward traversal) is
//! covered by the WPT files and crane/forms1b2-form-state-restore.html.
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const form_state = html.forms.form_state;
const saved_form_state = dom.saved_form_state;
const Allocator = std.mem.Allocator;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

/// Build `markup` in the body, let `edit` change it, save its states, build
/// `markup` afresh (new controls, as a traversal's new document has), give
/// the document the states and run the restore task.
fn saveAndRestore(page: helpers.Page, markup: []const u8, edit: []const u8) !void {
    const document = try documentOf(page);
    const build = try std.fmt.allocPrint(std.testing.allocator, "document.body.innerHTML = {s};", .{markup});
    defer std.testing.allocator.free(build);
    try page.run(build);
    try page.run(edit);
    const bytes = (try form_state.save(std.testing.allocator, document)) orelse return error.NothingSaved;
    defer std.testing.allocator.free(bytes);
    try page.run(build);
    try page.run(
        \\globalThis.events = [];
        \\for (const control of document.querySelectorAll('input, select, textarea')) {
        \\  control.addEventListener('input', () => events.push('input'));
        \\  control.addEventListener('change', () => events.push('change'));
        \\}
    );
    try std.testing.expect(!form_state.hasStates(document));
    form_state.setStateForNewControls(document, bytes);
    try std.testing.expect(form_state.hasStates(document));
    try page.turn();
    try std.testing.expect(!form_state.hasStates(document));
    try expectScript(page, "events.join()", "");
}

const controls_markup =
    \\`<form action="http://example.test/submit?session=1#f">
    \\  <input name=t value=initial>
    \\  <input type=range name=r min=0 max=10 value=5>
    \\  <input type=checkbox name=c>
    \\  <input type=radio name=g value=a checked><input type=radio name=g value=b>
    \\  <textarea name=a>default</textarea>
    \\  <select name=s><option>one<option value=two>Two</select>
    \\  <select name=m multiple><option>x<option selected>y<option>z</select>
    \\  <input type=password name=p><input type=hidden name=h value=hv>
    \\  <input name=off autocomplete=off>
    \\</form><input name=outside>`
;

const controls_edit =
    \\const f = document.forms[0];
    \\f.t.value = 'typed'; f.r.value = '8'; f.c.checked = true; f.g[1].checked = true;
    \\f.a.value = 'line1\nline2'; f.s.value = 'two';
    \\f.m.options[0].selected = true; f.m.options[1].selected = false; f.m.options[2].selected = true;
    \\f.p.value = 'secret'; f.off.value = 'not kept';
    \\document.querySelector('[name=outside]').value = 'no owner';
;

fn restoresEveryKind() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try saveAndRestore(page, controls_markup, controls_edit);
    try expectScript(page,
        \\(() => { const f = document.forms[0]; return [f.t.value, f.r.value, f.c.checked, f.g[0].checked, f.g[1].checked,
        \\  JSON.stringify(f.a.value), f.s.value, [...f.m.selectedOptions].map(o => o.value).join('+'),
        \\  f.p.value, f.off.value, document.querySelector('[name=outside]').value].join('|'); })()
    , "typed|8|true|false|true|\"line1\\nline2\"|two|x+z|||no owner");
}

test "a saved document's controls of every kind are restored, with no input or change event" {
    try helpers.onFreshThread(restoresEveryKind);
}

test "disabled and readonly controls keep their values, and a queue gives each state to its own control" {
    const Run = struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            const document = try documentOf(page);
            try page.run("document.body.innerHTML = '<input name=x value=d1><input name=x value=d2><input name=y value=d3>';");
            try page.run("const [a, b, c] = document.querySelectorAll('input'); a.value = 'first'; b.value = 'second'; c.value = 'third';");
            const bytes = (try form_state.save(std.testing.allocator, document)).?;
            defer std.testing.allocator.free(bytes);
            try page.run("document.body.innerHTML = '<input name=x value=d1 disabled><input name=x value=d2><input name=y value=d3 readonly>';");
            form_state.setStateForNewControls(document, bytes);
            try page.turn();
            try expectScript(page, "[...document.querySelectorAll('input')].map(i => i.value).join()", "d1,second,d3");
        }
    };
    try helpers.onFreshThread(Run.run);
}

fn formsWithOneSignature() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = try documentOf(page);
    const markup = "'<form action=\"http://e.test/a\"><input name=q></form><form action=\"http://e.test/a?x\"><input name=q></form><form><input name=q></form><input name=q form=nowhere>'";
    const build = "document.body.innerHTML = " ++ markup ++ ";";
    try page.run(build);
    try page.run("const qs = document.querySelectorAll('input'); qs.forEach((q, i) => q.value = 'v' + i);");
    const bytes = (try form_state.save(std.testing.allocator, document)).?;
    defer std.testing.allocator.free(bytes);
    // The same forms, with a new first form in front that has another
    // signature: each value still finds its form (its signature and index).
    try page.run("document.body.innerHTML = '<form action=\"http://e.test/b\"><input name=q></form>' + " ++ markup ++ ";");
    form_state.setStateForNewControls(document, bytes);
    try page.turn();
    try expectScript(page, "[...document.querySelectorAll('input')].map(i => i.value).join()", ",v0,v1,v2,v3");
}

test "forms with one signature are told apart by their index, and a query is no part of it" {
    try helpers.onFreshThread(formsWithOneSignature);
}

fn selectedcontentUpdatedFirst() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const document = try documentOf(page);
    const build = "document.body.innerHTML = '<form><select><button><selectedcontent></selectedcontent></button><option value=one>one</option><option value=two>two<b>!</b></option></select></form>';";
    // selectedcontent-input.html's createInput: an input in the
    // selectedcontent, after the select's own update of it.
    const create_input = "globalThis.inside = document.createElement('input'); inside.name = 'inside'; document.querySelector('selectedcontent').replaceChildren(inside);";
    try page.run(build);
    try page.run("document.querySelector('select').value = 'two';");
    try page.run(create_input);
    try page.run("inside.value = 'typed';");
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML", "<input name=\"inside\">");
    const bytes = (try form_state.save(std.testing.allocator, document)).?;
    defer std.testing.allocator.free(bytes);
    // The new document's script puts an input in the selectedcontent again
    // (selectedcontent-input.html's createInput). The select's restore
    // replaces the selectedcontent's contents before the input's turn, so
    // the removed input takes nothing.
    try page.run(build);
    try page.run(create_input);
    form_state.setStateForNewControls(document, bytes);
    try page.turn();
    try expectScript(page, "document.querySelector('select').value + '|' + document.querySelector('selectedcontent').innerHTML + '|' + inside.isConnected + '|' + JSON.stringify(inside.value)", "two|two<b>!</b>|false|\"\"");
}

test "a restored select updates its selectedcontent before the next control's turn" {
    try helpers.onFreshThread(selectedcontentUpdatedFirst);
}

test "encode then decode gives each state once, in its queue's order" {
    const allocator = std.testing.allocator;
    const bytes = (try saved_form_state.encode(allocator, &.{
        .{ .key = "No owner", .controls = &.{
            .{ .name = "a", .type = "text", .values = &.{} },
            .{ .name = "a", .type = "text", .values = &.{"second"} },
            .{ .name = "s", .type = "select-one", .values = &.{ "two", "1" } },
        } },
        .{ .key = "http://x/ [a ] #0", .controls = &.{.{ .name = "a", .type = "text", .values = &.{"form"} }} },
    })).?;
    defer allocator.free(bytes);
    const saved = (try saved_form_state.Saved.decode(allocator, bytes)).?;
    defer saved.destroy();
    try std.testing.expectEqual(@as(usize, 0), saved.take("No owner", "a", "text").?.len);
    try std.testing.expectEqualStrings("second", saved.take("No owner", "a", "text").?[0]);
    try std.testing.expect(saved.take("No owner", "a", "text") == null);
    try std.testing.expect(saved.take("No owner", "s", "select-multiple") == null);
    try std.testing.expectEqualStrings("1", saved.take("No owner", "s", "select-one").?[1]);
    try std.testing.expect(!saved.isEmpty());
    try std.testing.expectEqualStrings("form", saved.take("http://x/ [a ] #0", "a", "text").?[0]);
    try std.testing.expect(saved.isEmpty());
}

test "bytes of another version, cut short or with a bad type decode to nothing" {
    const allocator = std.testing.allocator;
    const bytes = (try saved_form_state.encode(allocator, &.{.{ .key = "k", .controls = &.{.{ .name = "a", .type = "text", .values = &.{"v"} }} }})).?;
    defer allocator.free(bytes);
    try std.testing.expect(try saved_form_state.Saved.decode(allocator, bytes[0 .. bytes.len - 1]) == null);
    try std.testing.expect(try saved_form_state.Saved.decode(allocator, "") == null);
    const other = try allocator.dupe(u8, bytes);
    defer allocator.free(other);
    other[10] ^= 1;
    try std.testing.expect(try saved_form_state.Saved.decode(allocator, other) == null);
    const bad_type = (try saved_form_state.encode(allocator, &.{.{ .key = "k", .controls = &.{.{ .name = "a", .type = "Text", .values = &.{} }} }})).?;
    defer allocator.free(bad_type);
    try std.testing.expect(try saved_form_state.Saved.decode(allocator, bad_type) == null);
    try std.testing.expect(try saved_form_state.encode(allocator, &.{}) == null);
}

test "decoding survives every allocation failure" {
    const bytes = (try saved_form_state.encode(std.testing.allocator, &.{.{ .key = "k", .controls = &.{ .{ .name = "a", .type = "text", .values = &.{"v"} }, .{ .name = "b", .type = "checkbox", .values = &.{"on"} } } }})).?;
    defer std.testing.allocator.free(bytes);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: Allocator, input: []const u8) !void {
            const saved = (try saved_form_state.Saved.decode(allocator, input)) orelse return error.TestUnexpectedResult;
            saved.destroy();
        }
    }.run, .{bytes});
}
