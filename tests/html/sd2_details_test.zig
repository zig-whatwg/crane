//! Summary keyboard activation and fragment-driven details revealing.
const helpers = @import("edges_node_holders_helpers.zig");
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");

fn press(page: helpers.Page, key: []const u8) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = key }, .{});
    html.user_input.keyUp(&keyboard, document, .{ .key = key }, .{});
}

fn activation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<details id=d><summary id=first>First <button id=inside>Button</button></summary><summary id=second tabindex=0>Second</summary><p>Contents</p></details>';
        \\const details = document.getElementById('d');
        \\const first = document.getElementById('first');
        \\const second = document.getElementById('second');
    );
    for ([_][]const u8{ " ", "Enter" }) |key| {
        try page.run("first.focus()");
        press(page, key);
        try page.run("if (!details.open) throw new Error('first summary did not activate'); details.open = false; second.focus()");
        press(page, key);
        try page.run("if (details.open) throw new Error('second summary activated'); first.focus(); first.addEventListener('keydown', event => event.preventDefault(), {once: true})");
        press(page, key);
        try page.run("if (details.open) throw new Error('canceled key activated'); document.getElementById('inside').focus()");
        press(page, key);
        try page.run("if (details.open) throw new Error('interactive descendant activated summary')");
    }
}

fn spaceRelease() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<details id=d><summary id=s>Summary</summary><p>Contents</p></details>';
        \\const details = document.getElementById('d');
        \\const summary = document.getElementById('s');
        \\summary.focus();
    );
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = " " }, .{});
    try page.run("if (details.open) throw new Error('Space activated before release'); if (!summary.matches(':active')) throw new Error('Space did not arm summary')");
    html.user_input.keyUp(&keyboard, document, .{ .key = " " }, .{});
    try page.run("if (!details.open || summary.matches(':active')) throw new Error('Space release')");
}

test "summary Space and Enter activate only the first summary with uncanceled keys" {
    try helpers.onFreshThread(activation);
}

test "summary Space arms on keydown and activates on keyup" {
    try helpers.onFreshThread(spaceRelease);
}

fn allocationTrial(allocator: std.mem.Allocator, target: *runtime.Instance, outer: *runtime.Instance, inner: *runtime.Instance) anyerror!void {
    if (comptime !@hasDecl(html, "details")) return error.DetailsRevealingNotImplemented;
    try interfaces.HTMLDetailsElement.set_open(outer, false);
    try interfaces.HTMLDetailsElement.set_open(inner, false);
    try html.details.revealWithAllocator(allocator, target);
    try std.testing.expect(try interfaces.HTMLDetailsElement.get_open(outer));
    try std.testing.expect(try interfaces.HTMLDetailsElement.get_open(inner));
}

fn allocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<details id=outer><summary>Outer</summary><details id=inner><summary>Inner</summary><span id=target></span></details></details>'");
    const document = page.browser.current_context.?.document_instance.?;
    const outer = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("outer"))).?;
    const inner = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("inner"))).?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{ target, outer, inner });
}

fn slottedTarget() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<span id=target slot=contents>Target</span><span id=unassigned>Not in flat tree</span>';
        \\const shadow = host.attachShadow({mode:'open'});
        \\shadow.innerHTML = '<details><summary>Summary</summary><slot name=contents></slot></details>';
        \\location.hash = '#target';
    );
    try page.turn();
    try page.run(
        \\if (!shadow.querySelector('details').open) throw new Error('slotted fragment target did not reveal details');
        \\shadow.querySelector('details').open = false;
        \\location.hash = '#unassigned';
    );
    try page.turn();
    try page.run("if (shadow.querySelector('details').open) throw new Error('unassigned fragment target revealed details')");
}

fn fragmentContent() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<details id=outer><summary>Outer</summary><details id=inner><summary>Inner</summary><span id=target>Target</span></details></details>';
        \\location.hash = '#target';
    );
    try page.turn();
    try page.run(
        \\if (!document.getElementById('inner').open || !document.getElementById('outer').open) throw new Error('fragment did not reveal both details');
        \\if (document.querySelector(':target').id !== 'target') throw new Error('fragment target');
    );
}

fn fragmentSummary() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<details id=d><i></i><summary><span id=target>Summary</span></summary><p>Contents</p></details>';
        \\location.hash = '#target';
    );
    try page.turn();
    try page.run(
        \\if (document.getElementById('d').open) throw new Error('summary target revealed details');
        \\if (document.querySelector(':target').id !== 'target') throw new Error('summary fragment target');
    );
}

test "fragment navigation reveals nested details content ancestors" {
    try helpers.onFreshThread(fragmentContent);
}

test "fragment navigation to the first summary leaves its details closed" {
    try helpers.onFreshThread(fragmentSummary);
}

test "details revealing follows assigned slots and excludes unassigned light children" {
    try helpers.onFreshThread(slottedTarget);
}

test "details revealing frees its ancestor list at every allocation failure" {
    try helpers.onFreshThread(allocationFailures);
}
