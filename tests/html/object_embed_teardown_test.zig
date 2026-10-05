//! An object or embed element torn down with its tree runs its own deinit.
//!
//! A tree's teardown (Node.deinit, its children through deinitNodeByType)
//! ran the element's own deinit only for script and iframe; every other
//! element got Element's. An object or embed element keeps a record of its
//! processing - and, once it shows a document, a content navigable whose
//! deinit frees what its navigations committed - which only its own deinit
//! hands back. Torn down as a plain Element, an object that had shown a
//! document leaked three allocations (crane/obj-navigables.html,
//! CRANE_LEAK_TRACES=1). An element's own deinit hands its state back and
//! clears the pointer to it, which says whose deinit ran.

const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");

const interfaces = html.interfaces;
const testing = std.testing;

/// Whether `element`'s own state is still held: its interface's deinit hands
/// it back and clears the pointer to it.
fn holdsState(comptime Interface: type, element: *runtime.Instance) bool {
    const state = element.stateAs(Interface.State) orelse return false;
    return state.own._internal != null;
}

test "an object or embed torn down with its tree runs its own deinit" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const div = try interfaces.HTMLDivElement.init(allocator, ctx);
    const object = try interfaces.HTMLObjectElement.init(allocator, ctx);
    const embed = try interfaces.HTMLEmbedElement.init(allocator, ctx);
    _ = try interfaces.Node.call_appendChild(div, object);
    _ = try interfaces.Node.call_appendChild(div, embed);
    try testing.expect(holdsState(interfaces.HTMLObjectElement, object));
    try testing.expect(holdsState(interfaces.HTMLEmbedElement, embed));

    // The div's teardown: Node.deinit tears its children down by type. (The
    // Instances themselves stay until the collector or the page frees them:
    // their state can still be read.)
    interfaces.HTMLDivElement.deinit(div);

    try testing.expect(!holdsState(interfaces.HTMLObjectElement, object));
    try testing.expect(!holdsState(interfaces.HTMLEmbedElement, embed));
}
