//! A Browser's platform objects come from its own scope (instances B1,
//! docs/instances.md): `Instance.init` takes the handle from the realm's
//! `BrowserScope.slab` and the state from its `.arena`, the instance's
//! lifecycle flags live in its slot, and its internal state is recorded in
//! its scope's table. So two Browsers on two threads make and free objects
//! at once without touching each other's, and one Browser's end frees
//! exactly its own: the other's objects, generations, flags and internal
//! states are untouched.

const std = @import("std");
const runtime = @import("runtime");
const testing = std.testing;
const BrowserScope = runtime.BrowserScope;

const Marked = struct {
    owner: u64,
    serial: u64,
    /// Enough bytes that the arena's size classes are exercised, not only
    /// the smallest.
    pad: [6]u64 = @splat(0),
};

const Internal = struct {
    owner: u64,
    serial: u64,
};

const no_methods = .{};
const vtable: runtime.VTable = .{
    .name = "Marked",
    .deinit = null,
    .methods_ptr = &no_methods,
    .state_size = @sizeOf(Marked),
    .state_align = @alignOf(Marked),
};

const objects_per_browser = 1_000_000;
const window = 64;
/// Objects each Browser still holds when the churn ends.
const kept = 512;

const Held = struct {
    instance: *runtime.Instance,
    generation: u64,
    serial: u64,
    internal: *Internal,
};

/// One Browser's thread: makes and frees a million objects through its
/// realm, keeping a window of live ones and checking each before it goes;
/// ends holding `kept` of them.
const Churn = struct {
    id: u64,
    scope: *BrowserScope,
    realm: runtime.Context,
    mismatches: u32 = 0,
    held: [kept]Held = undefined,

    fn make(self: *Churn, serial: u64) ?Held {
        const instance = runtime.Instance.init(std.heap.smp_allocator, Marked, &vtable, self.realm) catch {
            self.mismatches += 1;
            return null;
        };
        const state: *Marked = @ptrCast(@alignCast(instance.state));
        state.* = .{ .owner = self.id, .serial = serial };
        const internal = std.heap.smp_allocator.create(Internal) catch {
            self.mismatches += 1;
            runtime.Instance.deinit(instance);
            return null;
        };
        internal.* = .{ .owner = self.id, .serial = serial };
        runtime.internal_state.setInternal(instance, internal) catch {
            self.mismatches += 1;
            std.heap.smp_allocator.destroy(internal);
            runtime.Instance.deinit(instance);
            return null;
        };
        return .{
            .instance = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
            .serial = serial,
            .internal = internal,
        };
    }

    fn free(held: Held) void {
        runtime.internal_state.removeInternal(held.instance);
        std.heap.smp_allocator.destroy(held.internal);
        runtime.Instance.deinit(held.instance);
    }

    fn run(self: *Churn) void {
        var live: [window]?Held = @splat(null);
        var serial: u64 = 0;
        var i: usize = 0;
        while (i < objects_per_browser) : (i += 1) {
            const slot = i % window;
            if (live[slot]) |held| {
                self.check(held);
                free(held);
                live[slot] = null;
            }
            serial += 1;
            live[slot] = self.make(serial);
        }
        for (live) |maybe| {
            const held = maybe orelse continue;
            self.check(held);
            free(held);
        }
        for (&self.held) |*held| {
            serial += 1;
            held.* = self.make(serial) orelse return;
            // A flag set on this Browser's object stays its own.
            _ = runtime.instance_lifecycle.markCleanupStarted(held.instance);
        }
    }

    /// Everything this Browser recorded about `held` still reads back - and
    /// the object is this Browser's.
    fn check(self: *Churn, held: Held) void {
        if (runtime.SlabAllocator.generationOf(held.instance) != held.generation) {
            self.mismatches += 1;
            return;
        }
        if (BrowserScope.ofInstance(held.instance) != self.scope) self.mismatches += 1;
        if (held.instance.ctx != self.realm) self.mismatches += 1;
        const state: *Marked = @ptrCast(@alignCast(held.instance.state));
        if (state.owner != self.id or state.serial != held.serial) self.mismatches += 1;
        const internal = runtime.internal_state.getInternal(Internal, held.instance) orelse {
            self.mismatches += 1;
            return;
        };
        if (internal != held.internal or internal.owner != self.id or internal.serial != held.serial) self.mismatches += 1;
    }
};

test "two Browsers' scopes make and free a million objects each at once, and one's end leaves the other's objects intact" {
    // Not testing.allocator: each scope's arena keeps its blocks to its end,
    // which a leak check of the process cannot see past - the slab and arena
    // statistics below are the check.
    var scopes = [_]BrowserScope{
        BrowserScope.init(std.heap.smp_allocator),
        BrowserScope.init(std.heap.smp_allocator),
    };
    var a_ended = false;
    defer if (!a_ended) scopes[0].deinit();
    defer scopes[1].deinit();

    var realms: [2]runtime.ContextData = undefined;
    for (&realms, &scopes) |*realm, *scope| {
        realm.* = try runtime.ContextData.init(std.heap.smp_allocator, .{});
        realm.browser_scope = scope;
    }
    defer for (&realms) |*realm| realm.deinit();

    var churns = [_]Churn{
        .{ .id = 1, .scope = &scopes[0], .realm = &realms[0] },
        .{ .id = 2, .scope = &scopes[1], .realm = &realms[1] },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &churns) |*thread, *churn| thread.* = try std.Thread.spawn(.{}, Churn.run, .{churn});
    for (threads) |thread| thread.join();
    try testing.expectEqual(@as(u32, 0), churns[0].mismatches);
    try testing.expectEqual(@as(u32, 0), churns[1].mismatches);

    // Each scope's slab issued its own Browser's objects, and holds exactly
    // the ones its Browser kept.
    for (&scopes, &churns) |*scope, *churn| {
        const stats = scope.slab.stats();
        try testing.expectEqual(@as(usize, objects_per_browser + kept), stats.total_allocated);
        try testing.expectEqual(@as(usize, kept), stats.currently_allocated);
        for (churn.held) |held| try testing.expectEqual(scope, BrowserScope.ofInstance(held.instance));
    }

    // Browser 1 ends: its slab, arena and table go, with every object it
    // still held.
    for (churns[0].held) |held| std.heap.smp_allocator.destroy(held.internal);
    scopes[0].deinit();
    a_ended = true;

    // Browser 2's objects are as it left them: the same generations, state,
    // flags and internal states, in its own scope.
    const b = &churns[1];
    for (b.held) |held| {
        b.check(held);
        try testing.expect(runtime.instance_lifecycle.isCleanupStarted(held.instance));
    }
    try testing.expectEqual(@as(u32, 0), b.mismatches);
    for (b.held) |held| Churn.free(held);
    try testing.expectEqual(@as(usize, 0), scopes[1].slab.stats().currently_allocated);
}

test "a realm with no Browser of its own makes its objects in its principal realm's (a ShadowRealm's)" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var principal = try runtime.ContextData.init(testing.allocator, .{});
    defer principal.deinit();
    principal.browser_scope = &scope;
    var shadow = try runtime.ContextData.init(testing.allocator, .{});
    defer shadow.deinit();
    shadow.principal_realm = &principal;

    try testing.expectEqual(@as(?*BrowserScope, &scope), shadow.browserScope());
    const instance = try runtime.Instance.init(testing.allocator, Marked, &vtable, &shadow);
    defer runtime.Instance.deinit(instance);
    try testing.expectEqual(&scope, BrowserScope.ofInstance(instance));
}

test "the standalone scope (runtime.initializeRuntime) serves a realm no Browser made, and is no Browser's" {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();

    const standalone = BrowserScope.standalone() orelse return error.NoStandaloneScope;
    try testing.expectEqual(@as(?*BrowserScope, standalone), realm.browserScope());
    const instance = try runtime.Instance.init(testing.allocator, Marked, &vtable, &realm);
    defer runtime.Instance.deinit(instance);
    try testing.expectEqual(standalone, BrowserScope.ofInstance(instance));

    // A Browser's realm never reaches it.
    var browser = BrowserScope.init(testing.allocator);
    defer browser.deinit();
    realm.browser_scope = &browser;
    try testing.expectEqual(@as(?*BrowserScope, &browser), realm.browserScope());
}
