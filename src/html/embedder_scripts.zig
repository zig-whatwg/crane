//! The embedder's answer for the external classic scripts that frame and
//! popup documents prepare.
//!
//! A top-level page's embedder hands its parser a script loader
//! (`Context.loadPageWithOptions`), but the documents of the page's
//! iframes and window.open popups are parsed by the engine
//! (`HTMLIFrameElement.parseHtmlForIframe`), which has no embedder to ask.
//! An embedder that must answer for those documents too registers a
//! `Loader` here, once, before any page loads; the frame parse path asks
//! `forRealm` for a script loader bound to the frame's realm.
//!
//! Test-only today: the WPT runner registers one, answering
//! /resources/testdriver-vendor.js in every document the tests drive (the
//! role wptrunner's server-side testdriver injection plays for a browser).
//!
//! Unregistered - every build but the runner's: the browser, iOS, the unit
//! tests - `forRealm` is null and a frame document's parser has no loader,
//! exactly as before this module existed.
//!
//! What a loader answers is used as the script's source; null leaves the
//! fetch to "fetch a classic script" (script_execution.fetchClassicScriptSource),
//! so a loader answers only for the URLs it means to.

const std = @import("std");
const runtime = @import("runtime");
const scripted_parser = @import("scripted_parser.zig");

/// An embedder's loader: the source of the external classic script whose
/// src attribute is `src`, prepared by a parser of a document in `realm` -
/// allocated with `realm`'s allocator, which the parser frees it with - or
/// null to fetch it as usual.
pub const Loader = *const fn (realm: runtime.Context, src: []const u8) ?[]const u8;

/// The registered loader, per thread: a thread's pages are parsed on it.
threadlocal var registered: ?Loader = null;

/// The embedder's hook, test-only today: register `loader` for every frame
/// and popup document parsed on this thread from now on. Call it once, at
/// startup, before any page loads - never lazily, or a frame parsed before
/// the registration gets no loader and the result depends on what ran first.
pub fn register(loader: Loader) void {
    registered = loader;
}

/// Forget the registered loader (the embedder's shutdown).
pub fn unregister() void {
    registered = null;
}

/// The script loader for the parser of a frame or popup document in
/// `realm`: null when no embedder registered one, which is today's
/// behaviour for every build but the WPT runner's.
pub fn forRealm(realm: runtime.Context) ?scripted_parser.ScriptLoader {
    if (registered == null) return null;
    return .{ .context = @ptrCast(realm), .loadScript = &load };
}

/// `ScriptLoader.loadScript`: the registered loader, given the realm the
/// loader was made for.
fn load(context: ?*anyopaque, src: []const u8) ?[]const u8 {
    const loader = registered orelse return null;
    const realm: runtime.Context = @ptrCast(@alignCast(context orelse return null));
    return loader(realm, src);
}

test "unregistered, a frame document's parser gets no loader" {
    const saved = registered;
    defer registered = saved;
    registered = null;
    // Never dereferenced: with nothing registered the realm is not read.
    const realm: runtime.Context = @ptrFromInt(0x10000);
    try std.testing.expect(forRealm(realm) == null);
    try std.testing.expect(load(@ptrCast(realm), "/resources/testdriver-vendor.js") == null);
}

test "registered, the loader is asked with the frame's realm and may decline" {
    const saved = registered;
    defer registered = saved;
    const Fake = struct {
        var seen_realm: ?runtime.Context = null;
        fn loader(realm: runtime.Context, src: []const u8) ?[]const u8 {
            seen_realm = realm;
            if (std.mem.eql(u8, src, "/answered.js")) return "answered";
            return null;
        }
    };
    register(&Fake.loader);
    const realm: runtime.Context = @ptrFromInt(0x10000);
    const script_loader = forRealm(realm) orelse return error.TestExpectedLoader;
    try std.testing.expectEqualStrings("answered", script_loader.loadScript(script_loader.context, "/answered.js").?);
    try std.testing.expectEqual(@as(?runtime.Context, realm), Fake.seen_realm);
    try std.testing.expect(script_loader.loadScript(script_loader.context, "/other.js") == null);
    unregister();
    try std.testing.expect(forRealm(realm) == null);
}
