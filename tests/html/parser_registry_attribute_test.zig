//! "Create an element for a token" step 6 and the customelementregistry
//! attribute (browsers-first audit R3).
//!
//! - An element token with a customelementregistry attribute gets a null
//!   custom element registry: Chrome and Safari, the browsers that ship scoped
//!   registries (custom-elements/registries/scoped-custom-element-registry-
//!   customelementregistry-attribute.html); the spec text has no such
//!   attribute.
//! - Every other element's registry is looked up from its intended parent
//!   (step 6, "look up a custom element registry given intendedParent"), so a
//!   descendant of a null-registry element is null too during the initial
//!   parse. Chrome does this and Safari does not - a tie between the browsers
//!   that ship it, which goes to the current spec text (integrator ruling).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn registries() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body>
        \\<div id=a customelementregistry><span id=b><x-y id=c></x-y></span></div>
        \\<div id=d></div><x-y id=e></x-y>
        \\<template id=t><p id=f></p></template>
    , .{ .base_url = "http://example.test/registry-attribute" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const $ = (id) => document.getElementById(id);
        \\  const fail = [];
        \\  if ($('a').customElementRegistry !== null) fail.push('attribute');
        \\  if ($('b').customElementRegistry !== null) fail.push('child inherits');
        \\  if ($('c').customElementRegistry !== null) fail.push('candidate inherits');
        \\  if ($('d').customElementRegistry !== customElements) fail.push('ordinary');
        \\  if ($('e').customElementRegistry !== customElements) fail.push('ordinary candidate');
        \\  if ($('t').content.getElementById('f').customElementRegistry !== null) fail.push('template contents');
        \\  const host = document.createElement('div');
        \\  host.setHTMLUnsafe('<i customelementregistry><b></b></i><u></u>');
        \\  if (host.firstChild.customElementRegistry !== null) fail.push('setHTMLUnsafe attribute');
        \\  if (host.firstChild.firstChild.customElementRegistry !== null) fail.push('setHTMLUnsafe child');
        \\  if (host.lastChild.customElementRegistry !== customElements) fail.push('setHTMLUnsafe ordinary');
        \\  if ($('a').cloneNode(true).customElementRegistry !== null) fail.push('clone');
        \\  const later = document.createElement('div');
        \\  later.setAttribute('customelementregistry', '');
        \\  if (later.customElementRegistry !== customElements) fail.push('set later');
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

test "the customelementregistry attribute gives a parsed element a null registry, and descendants look theirs up from the parent" {
    try onFreshThread(registries);
}
