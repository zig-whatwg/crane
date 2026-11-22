//! A Browser's isolated worlds: the host side of the engine's world realms
//! (engine_protocol.zig section 4.2a; tmp/plans/cdp-part1-design.md 3.5),
//! for whatever runs code beside a page without being the page - CDP's
//! Page.createIsolatedWorld and addScriptToEvaluateOnNewDocument {worldName}
//! (Playwright's and Puppeteer's utility worlds), and any host that wants an
//! extension's content-script world.
//!
//! Blink's InspectorPageAgent::EnsureDOMWrapperWorld (third_party/blink/
//! renderer/core/inspector/inspector_page_agent.cc; BSD-3 - reproduced, not
//! copied): a world per (frame, name), made on the first request for that
//! name in that frame - its id new, its security origin the frame's or, with
//! `grantUniveralAccess`, one that reaches every origin - and kept for the
//! frame's life, across its navigations: each new document gets the world's
//! realm when something asks for it again (a createIsolatedWorld, or a script
//! to evaluate on each new document in that world). Crane keys the frame by
//! its navigable's id, which a navigation keeps.
//!
//! The registry is a supplement of the Browser's scope (runtime.BrowserScope,
//! docs/instances.md rule 2): no Browser field, no global. Its ids are the
//! Browser's, allocated from 1 (0 is the main world). The world REALMS are
//! the engine's - each made for a main realm, ended with it - so this file
//! keeps only what outlives a document: the names, ids and options.

const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");

const Allocator = std.mem.Allocator;
const BrowserScope = runtime.BrowserScope;

/// One world of one navigable.
pub const World = struct {
    /// The navigable whose documents the world's realms are made for (its
    /// id: a navigation keeps it).
    navigable: u64,
    /// OWNED by the registry.
    name: []u8,
    id: engine.WorldId,
    universal_access: bool,
};

/// The Browser's worlds (a BrowserScope supplement: `init`, `deinit`).
/// Reached on the window agent's thread; its mutex guards it all the same,
/// as every supplement guards its own state.
pub const IsolatedWorlds = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    worlds: std.ArrayListUnmanaged(World) = .empty,
    /// The next id to give out. 0 is the main world.
    next_id: engine.WorldId = 1,

    pub fn init(allocator: Allocator) IsolatedWorlds {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *IsolatedWorlds) void {
        for (self.worlds.items) |world| self.allocator.free(world.name);
        self.worlds.deinit(self.allocator);
        self.* = undefined;
    }

    fn lock(self: *IsolatedWorlds) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *IsolatedWorlds) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// The world named `name` of `navigable`, made if it is new (Blink's
    /// EnsureDOMWrapperWorld): its id. A world made before keeps the access
    /// it was made with, as Blink's keeps the security origin it set first.
    pub fn ensure(self: *IsolatedWorlds, navigable: u64, name: []const u8, universal_access: bool) Allocator.Error!engine.WorldId {
        self.lock();
        defer self.unlock();
        for (self.worlds.items) |world| {
            if (world.navigable == navigable and std.mem.eql(u8, world.name, name)) return world.id;
        }
        try self.worlds.ensureUnusedCapacity(self.allocator, 1);
        const owned = try self.allocator.dupe(u8, name);
        const id = self.next_id;
        self.next_id += 1;
        self.worlds.appendAssumeCapacity(.{ .navigable = navigable, .name = owned, .id = id, .universal_access = universal_access });
        return id;
    }

    /// The world named `name` of `navigable`, if one was made.
    pub fn named(self: *IsolatedWorlds, navigable: u64, name: []const u8) ?engine.WorldId {
        self.lock();
        defer self.unlock();
        for (self.worlds.items) |world| {
            if (world.navigable == navigable and std.mem.eql(u8, world.name, name)) return world.id;
        }
        return null;
    }

    /// World `id`'s record, copied out (its name BORROWED until the
    /// navigable is forgotten or the Browser ends); null for an id this
    /// Browser never gave out.
    pub fn lookup(self: *IsolatedWorlds, id: engine.WorldId) ?World {
        self.lock();
        defer self.unlock();
        for (self.worlds.items) |world| {
            if (world.id == id) return world;
        }
        return null;
    }

    /// `navigable` was destroyed: its worlds are forgotten (their realms
    /// ended with its documents' realms). Their ids are never given out
    /// again.
    pub fn forgetNavigable(self: *IsolatedWorlds, navigable: u64) void {
        self.lock();
        defer self.unlock();
        var i: usize = 0;
        while (i < self.worlds.items.len) {
            const world = self.worlds.items[i];
            if (world.navigable != navigable) {
                i += 1;
                continue;
            }
            self.allocator.free(world.name);
            _ = self.worlds.orderedRemove(i);
        }
    }
};

/// The Browser's registry, made on first use.
pub fn of(scope: *BrowserScope) Allocator.Error!*IsolatedWorlds {
    return scope.of(IsolatedWorlds);
}

/// The Browser's registry if it was ever made.
pub fn existing(scope: *BrowserScope) ?*IsolatedWorlds {
    return scope.existing(IsolatedWorlds);
}

pub const Error = engine.Error || Allocator.Error || error{NoBrowser};

/// CDP's Page.createIsolatedWorld {frameId, worldName, grantUniveralAccess}
/// - and addScriptToEvaluateOnNewDocument {worldName} at a new document - in
/// one call: the world named `name` of `navigable` (made if new, Blink's
/// EnsureDOMWrapperWorld), and its realm for `main`, the navigable's active
/// Window's main-world realm (made if new: engine.createWorldRealm). The
/// realm is the engine's, ended with `main`; script runs in it through the
/// engine's operations given that realm. `main` must be a live Window realm
/// of a Browser.
pub fn createIsolatedWorld(main: runtime.Context, navigable: u64, name: []const u8, universal_access: bool) Error!runtime.Context {
    const scope = main.browser_scope orelse return error.NoBrowser;
    const registry = try of(scope);
    const id = try registry.ensure(navigable, name, universal_access);
    return worldRealm(main, id);
}

/// The realm of world `id` for `main` (made if new). `id` is one this
/// Browser gave out; the main world's is `main` itself.
pub fn worldRealm(main: runtime.Context, id: engine.WorldId) Error!runtime.Context {
    if (id == engine.main_world) return main;
    const scope = main.browser_scope orelse return error.NoBrowser;
    const registry = existing(scope) orelse return error.OperationFailed;
    const world = registry.lookup(id) orelse return error.OperationFailed;
    return engine.createWorldRealm(main, &.{ .world = id, .name = world.name, .universal_access = world.universal_access });
}

/// The world realms of `main` that exist now - its main realm's isolated
/// worlds, for a host that lists a frame's execution contexts (CDP's
/// Runtime.enable replays them) - copied into `out` (as many as fit);
/// answers how many there are.
pub fn realmsOf(main: runtime.Context, out: []runtime.Context) usize {
    return engine.worldRealmsOf(main, out);
}

test "a world per (navigable, name), ids from 1, kept across lookups and forgotten with the navigable" {
    var registry: IsolatedWorlds = .init(std.testing.allocator);
    defer registry.deinit();
    const a = try registry.ensure(7, "__playwright_utility_world__", true);
    const b = try registry.ensure(7, "__puppeteer_utility_world__", false);
    const c = try registry.ensure(8, "__playwright_utility_world__", true);
    try std.testing.expectEqual(@as(engine.WorldId, 1), a);
    try std.testing.expectEqual(@as(engine.WorldId, 2), b);
    // Blink's worlds are per frame: the same name in another frame is
    // another world.
    try std.testing.expectEqual(@as(engine.WorldId, 3), c);
    // The same request answers the same world, with the access it was made
    // with.
    try std.testing.expectEqual(a, try registry.ensure(7, "__playwright_utility_world__", false));
    try std.testing.expect(registry.lookup(a).?.universal_access);
    try std.testing.expectEqual(@as(?engine.WorldId, b), registry.named(7, "__puppeteer_utility_world__"));
    try std.testing.expectEqualStrings("__puppeteer_utility_world__", registry.lookup(b).?.name);
    registry.forgetNavigable(7);
    try std.testing.expectEqual(@as(?engine.WorldId, null), registry.named(7, "__playwright_utility_world__"));
    try std.testing.expectEqual(@as(?World, null), registry.lookup(b));
    try std.testing.expectEqual(c, registry.named(8, "__playwright_utility_world__").?);
    // A forgotten world's id is never given out again.
    try std.testing.expectEqual(@as(engine.WorldId, 4), try registry.ensure(7, "__playwright_utility_world__", true));
}
