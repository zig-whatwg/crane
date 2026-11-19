//! Lane css1: a document's view transition state is made by the first
//! startViewTransition(), never by a read. "Update the rendering" step 18
//! (perform pending transition operations) runs for every document on every
//! rendering opportunity, and document.activeViewTransition is a plain read:
//! neither may make the style engine's rare record (cv1_random_provider_test
//! pins it lazy; a rendering opportunity between two of its scripts made it).
const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const helper = @import("edges_node_holders_helpers.zig");

test "a rendering opportunity and activeViewTransition make no view transition state" {
    try helper.onFreshThread(readsAreLazy);
}

fn readsAreLazy() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.hooks.engineOf(document).?;
    try page.run(
        \\document.body.innerHTML = '<div id="vt-target"></div>';
        \\getComputedStyle(document.getElementById('vt-target')).color;
        \\if (document.activeViewTransition !== null) throw Error('no transition was started');
    );
    try testing.expect(engine.rare == null);
    dom.view_transitions.performPendingTransitionOperations(document, .{ .timestamp_ns = 0 });
    try testing.expect(engine.rare == null);
    try testing.expect(dom.view_transitions.activeOf(document) == null);
    try testing.expect(engine.rare == null);
}
