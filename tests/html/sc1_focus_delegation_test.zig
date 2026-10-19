//! Delegated focus uses the existing document designation without new holders.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn delegatedFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  customElements.define('sc1-native-control', class extends HTMLElement {
        \\    static formAssociated = true;
        \\    constructor() { super(); this.attachInternals(); }
        \\  });
        \\  for (const mode of ['open', 'closed']) {
        \\    const host = document.body.appendChild(document.createElement('sc1-native-control'));
        \\    host.tabIndex = 0;
        \\    host.setAttribute('disabled', '');
        \\    const root = host.attachShadow({mode, delegatesFocus: true});
        \\    const first = root.appendChild(document.createElement('input'));
        \\    const preferred = root.appendChild(document.createElement('input'));
        \\    preferred.autofocus = true;
        \\    let focused = 0, blurred = 0;
        \\    host.addEventListener('focus', () => ++focused);
        \\    host.addEventListener('blur', () => ++blurred);
        \\    host.focus();
        \\    if (root.activeElement !== preferred || focused !== 1) return mode + ': delegate';
        \\    first.focus(); host.focus();
        \\    if (root.activeElement !== first) return mode + ': retain';
        \\    host.blur();
        \\    if (root.activeElement !== null || blurred !== 1) return mode + ': blur';
        \\    host.remove();
        \\  }
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "disabled custom hosts delegate focus, preserve descendant focus, and delegate blur" {
    try helpers.onFreshThread(delegatedFocus);
}
