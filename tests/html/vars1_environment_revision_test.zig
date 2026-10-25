//! env() invalidation (lane vars1): the document's environment variables
//! are PULLED like media values. StyleEngine.environmentChanged moves the
//! generation every cached style's key carries, so the next read recomputes
//! (no sheet rebuild); observeEnvironment, which every style read runs with
//! hooks.environmentRevision(document), calls it only when the revision
//! moved (0: no provider). Codex row 121's provider reports revisions.
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const testing = std.testing;
const helper = @import("edges_node_holders_helpers.zig");

/// The generation the element's cached style was computed under (a style
/// pointer cannot tell: a recomputed style may reuse the freed address).
fn cachedGeneration(element: *runtime.Instance) u64 {
    return dom.style.element_style.existingOf(element).?.cached.?.key.generation;
}

test "a moved environment revision recomputes a cached style, an unmoved one does not" {
    try helper.onFreshThread(revision);
}

fn revision() !void {
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="env-target" style="width: env(safe-area-inset-top, 3px)"></div>';
        \\if (getComputedStyle(document.getElementById('env-target')).width !== '3px') throw Error('env fallback');
    );
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.hooks.engineOf(document).?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("env-target"))).?;
    _ = (try dom.style.computedStyle(target, null)).?;
    const generation = engine.generation;
    try testing.expectEqual(generation, cachedGeneration(target));
    // No provider: revision 0 never invalidates, and a read keeps the cache.
    try engine.observeEnvironment(0);
    try testing.expectEqual(generation, engine.generation);
    _ = (try dom.style.computedStyle(target, null)).?;
    try testing.expectEqual(generation, cachedGeneration(target));
    // A moved revision invalidates once; the same revision again does not.
    try engine.observeEnvironment(7);
    try testing.expectEqual(generation +% 1, engine.generation);
    try engine.observeEnvironment(7);
    try testing.expectEqual(generation +% 1, engine.generation);
    // The next read recomputes under the current generation. (It pulls the
    // hook's revision, 0 here with no provider installed, which moved again
    // from 7: one more invalidation, as a provider going away would cause.)
    _ = (try dom.style.computedStyle(target, null)).?;
    try testing.expectEqual(engine.generation, cachedGeneration(target));
    try testing.expect(cachedGeneration(target) != generation);
}

test "environmentChanged recomputes every cached style on its next read" {
    try helper.onFreshThread(changed);
}

fn changed() !void {
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="env-changed"></div>';
        \\getComputedStyle(document.getElementById('env-changed')).width;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.hooks.engineOf(document).?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("env-changed"))).?;
    _ = (try dom.style.computedStyle(target, null)).?;
    const generation = cachedGeneration(target);
    engine.environmentChanged();
    _ = (try dom.style.computedStyle(target, null)).?;
    try testing.expectEqual(generation +% 1, cachedGeneration(target));
}
