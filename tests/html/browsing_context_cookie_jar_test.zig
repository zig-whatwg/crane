//! A browsing context reaches the user agent's cookie jar: a top-level one
//! holds it, and a frame reads its top's (src/html/window/browsing_context.zig).
//! html_core's own test blocks run under no test target, so the case lives
//! here.

const std = @import("std");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
/// cookiestore's CookieJar, reached through the field that holds one.
const CookieJar = std.meta.Child(std.meta.Child(@FieldType(BrowsingContext, "cookie_jar")));

test "a frame reaches its top-level context's cookie jar, and a context no Browser made has none" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    try std.testing.expect(top.cookieJar() == null);
    top.cookie_jar = &jar;

    // A context does not free its children (BrowsingContext.deinit).
    const child = try BrowsingContext.initChild(allocator, top);
    defer child.deinit();
    try std.testing.expect(child.cookieJar() == &jar);
    const grandchild = try BrowsingContext.initChild(allocator, child);
    defer grandchild.deinit();
    try std.testing.expect(grandchild.cookieJar() == &jar);
}
