//! User-origin text edits notify a changed selection through the existing queue.
const std = @import("std");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const tag of ['input', 'textarea']) {
        \\  const control = document.createElement(tag);
        \\  control.id = tag;
        \\  control.value = 'hello';
        \\  document.body.append(control);
        \\  control.setSelectionRange(5, 5);
        \\}
    );
    try page.turn();
    try page.run(
        \\globalThis.counts = {input: 0, textarea: 0};
        \\globalThis.selects = 0;
        \\for (const tag of ['input', 'textarea']) {
        \\  const control = document.getElementById(tag);
        \\  control.addEventListener('selectionchange', e => {
        \\    if (e.target !== control || !e.bubbles || e.composed || e.cancelable)
        \\      throw new Error('wrong selectionchange target or flags');
        \\    counts[tag]++;
        \\  });
        \\  control.addEventListener('select', () => selects++);
        \\}
    );
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    inline for (.{ "input", "textarea" }) |tag| {
        const control = (try interfaces.Document.call_getElementById(document, .initInterned(tag))) orelse return error.NoControl;
        try std.testing.expect(try dom.form_controls.userEdit(control, .{ .text = "hell", .selection_start = 4, .selection_end = 4 }));
        try std.testing.expect(try dom.form_controls.userEdit(control, .{ .text = "hel", .selection_start = 3, .selection_end = 3 }));
    }
    try page.run("if (counts.input || counts.textarea) throw new Error('notification was synchronous');");
    try page.turn();
    try page.run("if (counts.input !== 1 || counts.textarea !== 1 || selects !== 0) throw new Error('edit notifications did not coalesce');");
    inline for (.{ "input", "textarea" }) |tag| {
        const control = (try interfaces.Document.call_getElementById(document, .initInterned(tag))) orelse return error.NoControl;
        try std.testing.expect(try dom.form_controls.userEdit(control, .{ .text = "hey", .selection_start = 3, .selection_end = 3 }));
    }
    try page.turn();
    try page.run("if (counts.input !== 1 || counts.textarea !== 1 || selects !== 0) throw new Error('unchanged selection notified');");
}

test "user edit selectionchange is asynchronous, coalesced, and suppressed for equal offsets" {
    try helpers.onFreshThread(exercise);
}
