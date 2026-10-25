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
    // A page's realm, as far as the teardown can tell: it has an agent, and
    // the elements are marked wrapped - a wrapper may reach them - so a
    // torn-down node's storage stays for its wrapper (or the page's end) to
    // free, and its state can still be read below. Without either, its
    // storage would go back to the slab and arena at once
    // (Node.deinitNodeByType: an engine-less realm, or one whose nodes the
    // wrap mark proves unreachable), and reading it here would read freed
    // memory.
    var page_agent: u8 = 0;
    ctx_data.agent = @ptrCast(&page_agent);
    const ctx: runtime.Context = &ctx_data;

    const div = try interfaces.HTMLDivElement.init(allocator, ctx);
    const object = try interfaces.HTMLObjectElement.init(allocator, ctx);
    const embed = try interfaces.HTMLEmbedElement.init(allocator, ctx);
    for ([_]*runtime.Instance{ div, object, embed }) |node| runtime.instance_lifecycle.markWrapped(node);
    _ = try interfaces.Node.call_appendChild(div, object);
    _ = try interfaces.Node.call_appendChild(div, embed);
    try testing.expect(holdsState(interfaces.HTMLObjectElement, object));
    try testing.expect(holdsState(interfaces.HTMLEmbedElement, embed));

    // The div's teardown: Node.deinit tears its children down by type. (The
    // Instances themselves stay until the collector or the page frees them -
    // here the standalone scope's end: their state can still be read.)
    interfaces.HTMLDivElement.deinit(div);

    try testing.expect(!holdsState(interfaces.HTMLObjectElement, object));
    try testing.expect(!holdsState(interfaces.HTMLEmbedElement, embed));
}

test "an unwrapped object or embed in a retired realm gives its slot back with its tree, and an impostor takes it whole" {
    // The same tree, never wrapped, in a context modelling a retired realm
    // (an agent, no engine): the wrap mark proves nothing reaches the
    // children ([wrap_tracking]), so their teardown returns their slots at
    // once (Node.deinitNodeByType; lane pageretention1). Nothing here reads
    // them afterwards - only their slots' generations - and impostors of the
    // same types, made next (the slab hands out the last freed slot first),
    // are whole and are torn down exactly once.
    @import("interfaces").process_hooks.startHooksForTest();
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    var page_agent: u8 = 0;
    ctx_data.agent = @ptrCast(&page_agent);
    const ctx: runtime.Context = &ctx_data;

    const div = try interfaces.HTMLDivElement.init(allocator, ctx);
    const object = try interfaces.HTMLObjectElement.init(allocator, ctx);
    const embed = try interfaces.HTMLEmbedElement.init(allocator, ctx);
    _ = try interfaces.Node.call_appendChild(div, object);
    _ = try interfaces.Node.call_appendChild(div, embed);
    const object_generation = runtime.SlabAllocator.generationOf(object);
    const embed_generation = runtime.SlabAllocator.generationOf(embed);

    interfaces.HTMLDivElement.deinit(div);
    try testing.expect(runtime.SlabAllocator.generationOf(object) != object_generation);
    try testing.expect(runtime.SlabAllocator.generationOf(embed) != embed_generation);

    const embed_impostor = try interfaces.HTMLEmbedElement.init(allocator, ctx);
    const object_impostor = try interfaces.HTMLObjectElement.init(allocator, ctx);
    // At least one landed in a slot the teardown gave back.
    try testing.expect(embed_impostor == embed or embed_impostor == object or object_impostor == embed or object_impostor == object);
    try testing.expect(holdsState(interfaces.HTMLEmbedElement, embed_impostor));
    try testing.expect(holdsState(interfaces.HTMLObjectElement, object_impostor));
    @import("dom").node_creation.destroyUninserted(embed_impostor);
    @import("dom").node_creation.destroyUninserted(object_impostor);
}
