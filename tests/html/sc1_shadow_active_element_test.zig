//! ShadowRoot uses HTML's existing DocumentOrShadowRoot focus getter.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn activeElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  for (const mode of ['open', 'closed']) {
        \\    const host = document.body.appendChild(document.createElement('div'));
        \\    const root = host.attachShadow({mode});
        \\    const nestedHost = root.appendChild(document.createElement('div'));
        \\    const nestedRoot = nestedHost.attachShadow({mode});
        \\    const input = nestedRoot.appendChild(document.createElement('input'));
        \\    if (root.activeElement !== null) return mode + ': initial';
        \\    input.focus();
        \\    if (nestedRoot.activeElement !== input) return mode + ': inner';
        \\    if (root.activeElement !== nestedHost) return mode + ': retarget';
        \\    if (document.activeElement !== host) return mode + ': document';
        \\    host.remove();
        \\    if (root.activeElement !== null || nestedRoot.activeElement !== null)
        \\      return mode + ': removed';
        \\  }
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "ShadowRoot.activeElement retargets the document designation and observes removal" {
    try helpers.onFreshThread(activeElement);
}
