//! The embedder's answer for the external classic scripts that frame and
//! popup documents prepare.
//!
//! A top-level page's embedder hands the navigation that loads it a script
//! loader (`Context.loadPageWithOptions`, dom.top_level_traversables
//! NavigateOptions) for that page's document only, but the documents of the
//! page's iframes and window.open popups are parsed with no embedder to ask
//! (`HTMLIFrameElement.parseHtmlForIframe`).
//! An embedder that must answer for those documents too registers a
//! `Loader` on its Browser, once, before any page loads; the frame parse
//! path asks `forRealm` for a script loader bound to the frame's realm,
//! which finds the loader of the realm's Browser.
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

/// A Browser's registered loader: a supplement of its scope
/// (runtime.BrowserScope), made by `register`. The loader is an embedder's
/// answer for its own Browser - another Browser in the process, with its
/// own embedder, registers its own or none. It was one per thread, so two
/// Browsers on one thread shared it and two Browsers on two threads each
/// needed the registration made on their own thread (lane gstate4).
///
/// Written by `register`/`unregister` and read by the frame parse path, both
/// on the Browser's window thread (frames and popups are parsed there; a
/// worker parses no document).
pub const Registration = struct {
    loader: ?Loader = null,

    pub fn init(_: std.mem.Allocator) Registration {
        return .{};
    }

    pub fn deinit(_: *Registration) void {}
};

/// The embedder's hook, test-only today: register `loader` for every frame
/// and popup document of the Browser whose scope is `scope`, from now on.
/// Call it once, at startup, before any page loads - never lazily, or a
/// frame parsed before the registration gets no loader and the result
/// depends on what ran first.
pub fn register(scope: *runtime.BrowserScope, loader: Loader) std.mem.Allocator.Error!void {
    (try scope.of(Registration)).loader = loader;
}

/// Forget the Browser's registered loader (the embedder's shutdown).
pub fn unregister(scope: *runtime.BrowserScope) void {
    if (scope.existing(Registration)) |registration| registration.loader = null;
}

/// The loader registered on `realm`'s Browser, if any.
fn loaderOf(realm: runtime.Context) ?Loader {
    const scope = realm.browserScope() orelse return null;
    const registration = scope.existing(Registration) orelse return null;
    return registration.loader;
}

/// The script loader for the parser of a frame or popup document in
/// `realm`: null when no embedder registered one, which is today's
/// behaviour for every build but the WPT runner's.
pub fn forRealm(realm: runtime.Context) ?scripted_parser.ScriptLoader {
    if (loaderOf(realm) == null) return null;
    return .{ .context = @ptrCast(realm), .loadScript = &load, .retain = &retainRealm, .release = &releaseRealm };
}

// ContextData remains allocated and inert until its agent ends: the engine
// adapter's retirement clears engine/realm/loop before saving retired storage.
// Documents and parsers tear down before that storage drains. Parser resume
// validates realm liveness before invoking this borrowed realm loader; these
// lifetime callbacks never dereference the realm or the registered embedder.
fn retainRealm(_: ?*anyopaque) void {}
fn releaseRealm(_: ?*anyopaque) void {}

/// `ScriptLoader.loadScript`: the loader registered on the Browser of the
/// realm the loader was made for, given that realm.
fn load(context: ?*anyopaque, src: []const u8) ?[]const u8 {
    const realm: runtime.Context = @ptrCast(@alignCast(context orelse return null));
    const loader = loaderOf(realm) orelse return null;
    return loader(realm, src);
}

/// A realm of a Browser whose scope is `scope` (no engine: never run).
fn testRealm(scope: *runtime.BrowserScope) !runtime.ContextData {
    var realm = try runtime.ContextData.init(std.testing.allocator, .{});
    realm.browser_scope = scope;
    return realm;
}

test "unregistered, a frame document's parser gets no loader" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var realm = try testRealm(&scope);
    defer realm.deinit();
    try std.testing.expect(forRealm(&realm) == null);
    try std.testing.expect(load(@ptrCast(&realm), "/resources/testdriver-vendor.js") == null);
}

test "registered, the loader is asked with the frame's realm and may decline" {
    const Fake = struct {
        var seen_realm: ?runtime.Context = null;
        fn loader(realm: runtime.Context, src: []const u8) ?[]const u8 {
            seen_realm = realm;
            if (std.mem.eql(u8, src, "/answered.js")) return "answered";
            return null;
        }
    };
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var realm = try testRealm(&scope);
    defer realm.deinit();
    try register(&scope, &Fake.loader);
    const script_loader = forRealm(&realm) orelse return error.TestExpectedLoader;
    try std.testing.expectEqualStrings("answered", script_loader.loadScript(script_loader.context, "/answered.js").?);
    try std.testing.expectEqual(@as(?runtime.Context, &realm), Fake.seen_realm);
    try std.testing.expect(script_loader.loadScript(script_loader.context, "/other.js") == null);
    unregister(&scope);
    try std.testing.expect(forRealm(&realm) == null);
}

test "a loader registered on one Browser answers for its realms only" {
    const Fake = struct {
        fn loader(_: runtime.Context, _: []const u8) ?[]const u8 {
            return "answered";
        }
    };
    var a = runtime.BrowserScope.init(std.testing.allocator);
    defer a.deinit();
    var b = runtime.BrowserScope.init(std.testing.allocator);
    defer b.deinit();
    var realm_a = try testRealm(&a);
    defer realm_a.deinit();
    var realm_b = try testRealm(&b);
    defer realm_b.deinit();
    try register(&a, &Fake.loader);
    try std.testing.expect(forRealm(&realm_a) != null);
    // B's embedder registered none: its frames get no loader.
    try std.testing.expect(forRealm(&realm_b) == null);
    try std.testing.expect(load(@ptrCast(&realm_b), "/x.js") == null);
}
