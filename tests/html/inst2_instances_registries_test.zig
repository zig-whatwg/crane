//! Two Browsers on two threads at once, one origin, share none of the
//! registries a Browser's tabs share (instances-design 6.1; roadmap
//! "instances": "Cross-tab registries (BroadcastChannel, SharedWorker, Web
//! Locks, service worker registrations and clients, permissions) belong to
//! the instance"). inst2_tabs_sharing_test.zig shows each one shared by the
//! tabs of one Browser; here the same steps in another Browser reach none of
//! it - each registry is a supplement of its Browser's scope
//! (runtime.BrowserScope), never a process global.
//!
//! Each Browser serves http://localhost from a loopback server of its own
//! (inst2_tabs_fixture.zig) and allocates from a leak-checking allocator of
//! its own (AGENTS.md: a race test between Browsers gives each its own).
const std = @import("std");
const testing = std.testing;
const permissions = @import("permissions");
const fixture_mod = @import("inst2_tabs_fixture.zig");

const Fixture = fixture_mod.Fixture;

/// The two threads' meeting points.
const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),
    /// A side that failed: the other stops waiting for it.
    failed: std.atomic.Value(bool) = .init(false),

    /// Wait until both threads have arrived at meeting point `point` (1, 2..).
    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (self.failed.load(.acquire)) return error.TheOtherBrowserFailed;
            if (spins > 20_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    /// A writes first; B, after the meeting point, finds none of it.
    is_a: bool,
    shared: *Shared,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug.deinit() != .ok) {
            if (self.failure == null) self.failure = error.Leaked;
        };
        self.steps(debug.allocator()) catch |err| {
            self.failure = err;
            self.shared.failed.store(true, .release);
        };
    }

    fn steps(self: *Side, allocator: std.mem.Allocator) !void {
        const shared = self.shared;
        const fixture = try Fixture.start(allocator);
        defer fixture.stop();
        const host = try fixture.hostTab();

        if (self.is_a) {
            // A: a lock held, a shared worker running, a service worker
            // registered, a permission granted - and a channel heard by
            // A's own page (`channel`, made as it loaded).
            try fixture.run(host,
                \\globalThis.held = false;
                \\navigator.locks.request('x', () => { held = true; return new Promise(() => {}); });
                \\globalThis.count = 0;
                \\globalThis.worker = new SharedWorker('/counter.js', 'n');
                \\worker.port.onmessage = e => { count = e.data; };
                \\globalThis.registered = 'pending';
                \\navigator.serviceWorker.register('/sw.js').then(r => { registered = r.scope; }, e => { registered = String(e); });
                \\true
            );
            try fixture.waitFor(host, "held && count === 1 && registered !== 'pending'");
            try fixture.expect(host, "registered", fixture_mod.origin ++ "/");
            const store = try fixture.browser.scope.of(permissions.BrowserStore);
            const set = try store.set(fixture_mod.origin, permissions.PermissionDescriptor.simple(.geolocation), .granted);
            set.release();
            try fixture.run(host,
                \\globalThis.state = 'pending';
                \\navigator.permissions.query({ name: 'geolocation' }).then(s => { state = s.state; });
                \\true
            );
            try fixture.waitFor(host, "state !== 'pending'");
            try fixture.expect(host, "state", "granted");
        }

        // Both Browsers alive; A has written.
        try shared.meet(1);

        if (!self.is_a) {
            // B, the same origin: none of A's registries is B's.
            try fixture.run(host,
                \\globalThis.available = 'pending';
                \\navigator.locks.request('x', { ifAvailable: true }, lock => { available = lock ? lock.name : 'null'; });
                \\globalThis.count = 0;
                \\globalThis.worker = new SharedWorker('/counter.js', 'n');
                \\worker.port.onmessage = e => { count = e.data; };
                \\globalThis.found = 'pending';
                \\navigator.serviceWorker.getRegistrations().then(rs => { found = String(rs.length); });
                \\globalThis.state = 'pending';
                \\navigator.permissions.query({ name: 'geolocation' }).then(s => { state = s.state; });
                \\true
            );
            try fixture.waitFor(host, "available !== 'pending' && count !== 0 && found !== 'pending' && state !== 'pending'");
            // A's lock is not B's lock manager's.
            try fixture.expect(host, "available", "x");
            // B's own shared worker: its first connection.
            try fixture.expect(host, "count", "1");
            try fixture.expect(host, "found", "0");
            try fixture.expect(host, "state", "prompt");
        }

        try shared.meet(2);

        // BroadcastChannel: B posts on "c"; A's page hears nothing, while
        // B's own page - another channel object on "c" - does.
        if (!self.is_a) try fixture.run(host, "new BroadcastChannel('c').postMessage('from B'); true");
        try shared.meet(3);
        if (!self.is_a) try fixture.waitFor(host, "messages.length === 1");
        try shared.meet(4);
        if (self.is_a) {
            try fixture.turn(100);
            try fixture.expect(host, "messages.length", "0");
        }
        try shared.meet(5);
    }
};

test "two Browsers on two threads share no lock manager, shared worker, service worker registration, permission or BroadcastChannel" {
    var shared: Shared = .{};
    var a: Side = .{ .is_a = true, .shared = &shared };
    var b: Side = .{ .is_a = false, .shared = &shared };
    const thread_a = try std.Thread.spawn(.{}, Side.run, .{&a});
    const thread_b = try std.Thread.spawn(.{}, Side.run, .{&b});
    thread_a.join();
    thread_b.join();
    if (a.failure) |err| {
        std.debug.print("Browser A failed with {s}\n", .{@errorName(err)});
        return err;
    }
    if (b.failure) |err| {
        std.debug.print("Browser B failed with {s}\n", .{@errorName(err)});
        return err;
    }
}
