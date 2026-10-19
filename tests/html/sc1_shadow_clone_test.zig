//! Public cloneNode rejects shadow roots before entering the cloning algorithm.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn shadowClone() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  for (const mode of ['open', 'closed']) {
        \\    const host = document.createElement('div');
        \\    const root = host.attachShadow({mode, clonable: true});
        \\    for (const deep of [false, true]) {
        \\      try { root.cloneNode(deep); return mode + ': did not throw'; }
        \\      catch (error) {
        \\        if (error.name !== 'NotSupportedError' || error.code !== 9)
        \\          return mode + ': ' + error.name;
        \\      }
        \\    }
        \\  }
        \\  const fragment = document.createDocumentFragment();
        \\  fragment.appendChild(document.createElement('span'));
        \\  if (fragment.cloneNode(false).childNodes.length !== 0) return 'shallow';
        \\  if (fragment.cloneNode(true).firstChild.localName !== 'span') return 'deep';
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "cloneNode rejects open and closed shadow roots but accepts ordinary fragments" {
    try helpers.onFreshThread(shadowClone);
}
