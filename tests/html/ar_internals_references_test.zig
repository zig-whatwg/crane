//! Native and script holders use the existing node hold and traced-value APIs.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn nativeSingleton() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const internals = try interfaces.ElementInternals.init(std.testing.allocator, &context);
    defer runtime.Instance.deinit(internals);
    const target = try interfaces.HTMLElement.init(std.testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(target);
    try interfaces.ElementInternals.set_ariaActiveDescendantElement(internals, target);
    try std.testing.expectEqual(target, (try interfaces.ElementInternals.get_ariaActiveDescendantElement(internals)).?);
    try interfaces.ElementInternals.set_ariaActiveDescendantElement(internals, target);
    try interfaces.ElementInternals.set_ariaActiveDescendantElement(internals, null);
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.ElementInternals.get_ariaActiveDescendantElement(internals));
    // Node teardown may precede the internals; the hold must be notified safely.
    try interfaces.ElementInternals.set_ariaActiveDescendantElement(internals, target);
}

test "ARIA internals singleton keeps its native node and releases safely in either teardown order" {
    try helpers.onFreshThread(nativeSingleton);
}

fn scriptHolders() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\customElements.define('ar-native-holder', class extends HTMLElement {});
        \\globalThis.ariaHolder = document.createElement('ar-native-holder').attachInternals();
        \\(() => {
        \\  const single = document.createElement('span'); single.id = 'single';
        \\  const many = document.createElement('div'); many.id = 'many';
        \\  ariaHolder.ariaActiveDescendantElement = single;
        \\  const input = [many, many];
        \\  ariaHolder.ariaControlsElements = input;
        \\  input.length = 0; // Exclude the existing binding-argument leak as a keeper.
        \\  many.holder = ariaHolder;
        \\})();
    );
    try page.turn();
    try page.run(
        \\collectNow();
        \\if (ariaHolder.ariaActiveDescendantElement.id !== 'single') throw new Error('singleton lost');
        \\if (ariaHolder.ariaControlsElements[0].id !== 'many') throw new Error('array node lost');
        \\if (ariaHolder.ariaControlsElements[0].holder !== ariaHolder) throw new Error('cycle lost');
        \\ariaHolder.ariaControlsElements = null;
        \\ariaHolder.ariaActiveDescendantElement = null;
        \\collectNow();
    );
}

test "ARIA internals traced references survive GC with no other script references" {
    try helpers.onFreshThread(scriptHolders);
}
