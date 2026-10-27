//! HTML focus navigation scopes through hosts, assigned nodes and fallback.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn tab(page: helpers.Page, backward: bool) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    const modifiers = html.user_input.Modifiers{ .shift = backward };
    html.user_input.keyDown(&keyboard, document, .{ .key = "Tab" }, modifiers);
    html.user_input.keyUp(&keyboard, document, .{ .key = "Tab" }, modifiers);
}

fn expectActive(page: helpers.Page, id: []const u8) !void {
    const actual = try page.evaluate("roots.map(root => root.activeElement).filter(Boolean).at(-1).id");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(id, actual);
}

fn scopes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="before"><div id="host" tabindex="0"><input id="assigned2" slot="named" tabindex="2"><input id="assigned1" slot="named" tabindex="1"><input id="unassigned"></div><input id="after">';
        \\globalThis.root = host.attachShadow({mode:'closed'});
        \\root.innerHTML = '<input id="inner2" tabindex="2"><input id="inner1" tabindex="1"><slot name="named"></slot><slot name="empty"><input id="fallback"></slot>';
        \\globalThis.roots = [document, root];
        \\before.focus();
    );
    const expected = [_][]const u8{ "before", "host", "inner1", "inner2", "assigned1", "assigned2", "fallback", "after" };
    for (expected[1..]) |id| {
        tab(page, false);
        try expectActive(page, id);
    }
    var i = expected.len - 1;
    while (i > 0) {
        i -= 1;
        tab(page, true);
        try expectActive(page, expected[i]);
    }
}

fn negativeScope() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="before"><div id="host" tabindex="-1"></div><input id="after">';
        \\globalThis.root = host.attachShadow({mode:'open'});
        \\root.innerHTML = '<input id="first"><input id="second">';
        \\globalThis.roots = [document, root];
        \\before.focus();
    );
    tab(page, false);
    try expectActive(page, "after");
    try page.run("root.getElementById('first').focus()");
    tab(page, false);
    try expectActive(page, "second");
    tab(page, false);
    try expectActive(page, "after");
    try page.run("root.getElementById('second').focus()");
    tab(page, true);
    try expectActive(page, "first");
    tab(page, true);
    try expectActive(page, "before");
}

fn noFixedLimit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.replaceChildren();
        \\for (let i=0; i<1100; ++i) { const b=document.createElement('button'); b.id='b'+i; b.tabIndex=1; document.body.append(b); }
        \\globalThis.roots = [document];
        \\document.getElementById('b1098').focus();
    );
    tab(page, false);
    try expectActive(page, "b1099");
    tab(page, true);
    try expectActive(page, "b1098");
}

test "sd1 focus scopes sort host and assigned and fallback scopes independently in both directions" {
    try helpers.onFreshThread(scopes);
}

test "sd1 a negative host excludes entry but permits navigation within and out of its focused tree" {
    try helpers.onFreshThread(negativeScope);
}

test "sd1 sequential navigation has no fixed positive tabindex or focusable count limit" {
    try helpers.onFreshThread(noFixedLimit);
}
