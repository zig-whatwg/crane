//! One navigation call's radio summary: parity, laziness and allocation failure.
const std = @import("std");
const runtime = @import("runtime");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn documentOf(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn expectParity(page: helpers.Page, allocator: std.mem.Allocator) !void {
    const document = documentOf(page);
    var summary = html.forms.radio_focus.Navigation.init(allocator, document);
    defer summary.deinit();
    var fallback: std.ArrayList(*runtime.Instance) = .empty;
    defer fallback.deinit(std.testing.allocator);
    var summarized: std.ArrayList(*runtime.Instance) = .empty;
    defer summarized.deinit(std.testing.allocator);
    var node: ?*runtime.Instance = document;
    while (node) |element| : (node = html.form_associated.nextInTree(element, document, false)) {
        if (html.focus.isSequentiallyFocusable(element)) try fallback.append(std.testing.allocator, element);
        if (summary.eligibility(element) orelse html.focus.isSequentiallyFocusable(element))
            try summarized.append(std.testing.allocator, element);
    }
    // All fixture tab indices are zero or negative, so this is the actual
    // sequential order as well as the eligibility parity check.
    try std.testing.expectEqualSlices(*runtime.Instance, fallback.items, summarized.items);
}

fn summaryParity() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button>Start</button><form id="one"><input type="radio" name="disabled" disabled checked><input type="radio" name="disabled"><input type="radio" name="focused"><input type="radio" name="focused" id="focused"><input type="radio" name="cross" checked><input type="radio" name="negative" tabindex="-1" checked><input type="radio" name="negative"></form><form id="two"><input type="radio" name="cross"><input type="radio" name="cross"></form><input type="radio" form="one" name="cross"><div inert><input type="radio" name="inert" checked></div><input type="radio" name="inert"><input type="radio"><input type="radio"><button>End</button>';
        \\document.getElementById('focused').focus();
        \\globalThis.summaryScriptCalls = 0;
        \\for (const type of ['focus', 'blur', 'input', 'change']) document.addEventListener(type, () => ++summaryScriptCalls, true);
        \\for (const radio of document.querySelectorAll('input')) {
        \\  for (const property of ['checked', 'name', 'form']) Object.defineProperty(radio, property, {get() { ++summaryScriptCalls; throw Error('summary invoked a script accessor'); }});
        \\}
        \\window.getComputedStyle = () => { ++summaryScriptCalls; throw Error('summary invoked script style lookup'); };
    );
    try expectParity(page, std.testing.allocator);
    // The summary has been destroyed before this assertion enters script.
    try page.run("if (summaryScriptCalls !== 0) throw Error('script ran during radio summary')");
}

fn summaryNoRadios() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<button>Button</button><input><textarea></textarea><select><option>Option</option></select><a href=\"#\">Link</a>'");
    var counted = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectParity(page, counted.allocator());
    try std.testing.expectEqual(@as(usize, 0), counted.alloc_index);
    try std.testing.expect(!counted.has_induced_failure);
}

fn summaryAllocationFailure() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<form id="groups"></form>';
        \\for (let group = 0; group < 64; ++group) {
        \\  for (let member = 0; member < 2; ++member) {
        \\    const radio = document.createElement('input');
        \\    radio.type = 'radio'; radio.name = 'group-' + group;
        \\    radio.checked = member === 1;
        \\    groups.append(radio);
        \\  }
        \\}
    );
    var counted = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    try expectParity(page, counted.allocator());
    try std.testing.expect(counted.alloc_index > 0);
    // Fail the initial allocation and every later growth allocation. A
    // partial summary must be discarded, with all answers from the scan.
    for (0..counted.alloc_index) |failure| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        try expectParity(page, failing.allocator());
        try std.testing.expect(failing.has_induced_failure);
    }
}

test "radio navigation summary matches fallback order without running script" {
    try helpers.onFreshThread(summaryParity);
}

test "radio navigation summary allocates nothing on a non-radio page" {
    try helpers.onFreshThread(summaryNoRadios);
}

test "radio navigation summary falls back after every allocation failure" {
    try helpers.onFreshThread(summaryAllocationFailure);
}
