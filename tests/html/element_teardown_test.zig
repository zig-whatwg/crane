//! A tree's teardown runs each element's OWN deinit: the one its interface's
//! vtable names - what the garbage collector's finalizer runs for a collected
//! root - never Element's in its place.
//!
//! Node.deinitNodeByType chose an element's teardown by name and ran
//! Element.deinit for every element it did not name, so HTMLElement's state
//! (the inline style `style` writes) and the element type's own (an input's
//! dirty value, a textarea's raw value) stayed in their registries, keyed by
//! the element's address, when its subtree was torn down: swept at the
//! browser's end, or - once the slab reissued the address and a new
//! element's init overwrote the entry - leaked
//! (docs/lessons/architecture-a-teardown-dispatched-by-name-runs-the-wrong-types-deinit.md).
//! No sweep runs here: std.testing.allocator fails a test whose teardown
//! left anything behind.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const element_interface = @import("html_core").element_interface;

/// Give `element` an inline style, as `element.style.display = "none"` does:
/// the element's HTMLElement state copies the name and the value.
fn styleDisplayNone(element: *runtime.Instance) !void {
    const style = try interfaces.HTMLElement.get_style(element);
    // In a page the declaration is its wrapper's to free; here it is the
    // test's. It owns none of the style - the element does.
    defer interfaces.CSSStyleDeclaration.deinit(style);
    try interfaces.CSSStyleDeclaration.call_setNamedItem(style, runtime.DOMString.initInterned("display"), runtime.DOMString.initInterned("none"));
}

test "every element the HTML factory makes runs its own deinit when its tree is torn down" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    // The parent's teardown walks its children: no child is freed on its own.
    defer interfaces.HTMLDivElement.deinit(parent);
    // Each interface HTML's "element interface" algorithm can answer - the
    // ones document.createElement and the parser make - with an inline style,
    // which only HTMLElement's deinit frees: reached through the element's
    // own deinit, or not at all.
    inline for (@typeInfo(element_interface.ElementInterface).@"enum".fields) |field| {
        const child = try @field(interfaces, field.name).init(testing.allocator, &ctx);
        try styleDisplayNone(child);
        _ = try interfaces.Node.call_appendChild(parent, child);
    }
}

test "an input's dirty value is freed by its tree's teardown" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLDivElement.deinit(parent);
    const input = try interfaces.HTMLInputElement.init(testing.allocator, &ctx);
    _ = try interfaces.Node.call_appendChild(parent, input);
    // A text input is in the value mode: the value setter stores a copy.
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("dirty"));
}

test "a textarea's raw value is freed by its tree's teardown" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLDivElement.deinit(parent);
    const textarea = try interfaces.HTMLTextAreaElement.init(testing.allocator, &ctx);
    _ = try interfaces.Node.call_appendChild(parent, textarea);
    try interfaces.HTMLTextAreaElement.set_value(textarea, runtime.DOMString.initInterned("raw"));
}

test "an autonomous custom element's inline style is freed by its tree's teardown" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLDivElement.deinit(parent);
    // An autonomous custom element implements HTMLElement (HTML 4.13.3): its
    // own deinit is HTMLElement's.
    const custom = try interfaces.HTMLElement.init(testing.allocator, &ctx);
    try styleDisplayNone(custom);
    _ = try interfaces.Node.call_appendChild(parent, custom);
}

test "a grandchild is freed even when its parent's deinit does not chain" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    errdefer interfaces.HTMLDivElement.deinit(parent);
    // A deinit that never reaches Node's - the shape of a codegen stub - must
    // not cost the subtree: the teardown completes the node itself.
    const stub = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &stub_vtable, &ctx);
    _ = try interfaces.Node.call_appendChild(parent, stub);
    const grandchild = try interfaces.HTMLDivElement.init(testing.allocator, &ctx);
    try styleDisplayNone(grandchild);
    _ = try interfaces.Node.call_appendChild(stub, grandchild);
    interfaces.HTMLDivElement.deinit(parent);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(stub));
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(grandchild));
}

fn deinitNothing(_: *runtime.Instance) void {}

/// HTMLElement's vtable with a deinit that does nothing.
const stub_vtable = blk: {
    var vtable = interfaces.HTMLElement.vtable;
    vtable.deinit = &deinitNothing;
    break :blk vtable;
};
