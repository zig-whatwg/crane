//! DOM "clone a single node", Document step 2: the copy's base URL override
//! is the result of the source's "get the base URL" - its document base
//! URL - and HTML's document base URL step 2 returns that override when the
//! copy has no base element of its own (whatwg/dom#454;
//! dom/nodes/Document-cloneNode-*base-url*.window.js: Firefox 160 and
//! Safari 27.2 pass at wpt.fyi 2358bd4835, Chrome 157 does not).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const setup =
    \\globalThis.BASE = 'http://example.com/foo/bar';
    \\globalThis.parsed = (markup) => new DOMParser().parseFromString(markup, 'text/html');
;

fn cloneKeepsBase() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    // A shallow clone has no base element, yet its base URL is the source's.
    try harness.expectEval(page, "parsed(`<!DOCTYPE html><base href=\"${BASE}\">`).cloneNode(false).baseURI", "http://example.com/foo/bar");
    try harness.expectEval(page, "parsed(`<!DOCTYPE html><base href=\"${BASE}\">`).cloneNode(true).baseURI", "http://example.com/foo/bar");
    // createHTMLDocument's about:blank document with a base.
    try harness.expectEval(page,
        \\(() => { const d = document.implementation.createHTMLDocument('');
        \\  const b = d.createElement('base'); b.setAttribute('href', BASE); d.head.appendChild(b);
        \\  return d.cloneNode(false).baseURI; })()
    , "http://example.com/foo/bar");
    // The source's later mutation does not reach the copy; the copy's own
    // mutation keeps it; a base element inserted in the copy wins.
    try harness.expectEval(page,
        \\(() => { const d = parsed(`<!DOCTYPE html><base href="${BASE}">`); const c = d.cloneNode(false);
        \\  d.querySelector('base').remove(); c.appendChild(c.createComment('x'));
        \\  return [d.baseURI == d.URL, c.baseURI].join(' '); })()
    , "true http://example.com/foo/bar");
    try harness.expectEval(page,
        \\(() => { const c = parsed(`<!DOCTYPE html><base href="${BASE}">`).cloneNode(false);
        \\  const b = c.createElement('base'); b.setAttribute('href', 'http://example.org/other/'); c.appendChild(b);
        \\  return c.baseURI; })()
    , "http://example.org/other/");
    // Without a base element the clone's base URL is the source's URL.
    try harness.expectEval(page, "(() => { const d = parsed('<!DOCTYPE html>'); return d.cloneNode(false).baseURI == d.URL; })()", "true");
}

test "a cloned Document keeps its source's document base URL as its base URL override" {
    try helpers.onFreshThread(cloneKeepsBase);
}
