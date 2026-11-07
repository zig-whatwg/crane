//! Lane anim1 (C2): CSS Scoping 3.1.1 - a shadow tree's `:host::before` rule
//! styles the host's ::before. The host is featureless inside its shadow
//! tree, but the style engine resolving that pseudo-element matches the
//! compound's ::before against it (selector_matching
//! matchesFeaturelessCompound). Chrome, Firefox and Safari apply it
//! (css/css-shadow/keyframes-006.html relies on it).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn hostBeforeMatches() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.attachShadow({ mode: 'open' }).innerHTML = '<style>:host::before { content: ""; margin-left: 7px } :host::after { margin-left: 3px }</style>';
        \\const before = getComputedStyle(host, '::before').marginLeft;
        \\if (before !== '7px') throw new Error(':host::before: ' + before);
        \\const after = getComputedStyle(host, '::after').marginLeft;
        \\if (after !== '3px') throw new Error(':host::after: ' + after);
        \\const own = getComputedStyle(host).marginLeft;
        \\if (own !== '0px') throw new Error('the host itself: ' + own);
    );
}

test "a shadow tree's :host::before rule styles the host's ::before" {
    try helpers.onFreshThread(hostBeforeMatches);
}
