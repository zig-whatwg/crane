//! The Web Locks lock managers (html.web_locks.Registry), engine-free: the
//! lock request queue per resource name, exclusive and shared grants,
//! ifAvailable, steal, abort, the snapshot query() reads, an environment's
//! termination, and two threads contending for one lock.
//!
//! tests/html is one executable shared by every file in it; nothing here
//! starts an engine or assumes it runs first.

const std = @import("std");
const testing = std.testing;
const web_locks = @import("html").web_locks;
const Registry = web_locks.Registry;
const Client = web_locks.Client;
const Event = web_locks.Event;

/// A test environment's event loop: what the lock task queue posted to it.
const Mailbox = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    events: std.ArrayListUnmanaged(Event) = .empty,
    deinits: usize = 0,

    fn init(allocator: std.mem.Allocator) Mailbox {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *Mailbox) void {
        self.events.deinit(self.allocator);
    }

    fn delivery(self: *Mailbox) web_locks.Delivery {
        return .{ .ctx = self, .post = post, .deinit = deinitCtx };
    }

    fn post(ctx: *anyopaque, event: Event) void {
        const self: *Mailbox = @ptrCast(@alignCast(ctx));
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.events.append(self.allocator, event) catch @panic("out of memory in a test mailbox");
    }

    fn deinitCtx(ctx: *anyopaque) void {
        const self: *Mailbox = @ptrCast(@alignCast(ctx));
        self.deinits += 1;
    }

    /// Everything posted so far, in order; the mailbox is emptied.
    fn take(self: *Mailbox) ![]Event {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.events.toOwnedSlice(self.allocator);
    }

    fn expect(self: *Mailbox, expected: []const Event) !void {
        const got = try self.take();
        defer self.allocator.free(got);
        try testing.expectEqualSlices(Event, expected, got);
    }
};

/// Stand-ins for two realms and their LockManager objects: compared only.
var realm_a: u8 = 0;
var realm_b: u8 = 0;
var realm_c: u8 = 0;

fn granted(id: u64) Event {
    return .{ .kind = .granted, .id = id };
}

const origin = "https://web-platform.test:8443";

test "an exclusive lock is held by one request at a time; the next in its queue is granted on release" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    var b = Mailbox.init(testing.allocator);
    defer b.deinit();
    const client_a = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    const client_b = try registry.register(&realm_b, &realm_b, origin, b.delivery());

    const first = try registry.request(client_a, "res", .{});
    const second = try registry.request(client_b, "res", .{});
    try a.expect(&.{granted(first)});
    try b.expect(&.{});

    var snapshot = try registry.snapshot(client_a, testing.allocator);
    defer snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), snapshot.held.len);
    try testing.expectEqual(@as(usize, 1), snapshot.pending.len);
    try testing.expectEqualStrings("res", snapshot.held[0].name);
    try testing.expectEqual(web_locks.Mode.exclusive, snapshot.held[0].mode);
    try testing.expectEqualSlices(u8, &client_a.id, &snapshot.held[0].client_id);
    try testing.expectEqualSlices(u8, &client_b.id, &snapshot.pending[0].client_id);

    registry.release(first);
    try b.expect(&.{granted(second)});
    // Releasing it again does nothing.
    registry.release(first);
    try b.expect(&.{});
    registry.release(second);

    var after = try registry.snapshot(client_b, testing.allocator);
    defer after.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), after.held.len);
    try testing.expectEqual(@as(usize, 0), after.pending.len);
}

test "shared locks are held together; an exclusive request waits for every one, and shared requests queue behind it" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, origin, a.delivery());

    const s1 = try registry.request(client, "res", .{ .mode = .shared });
    const s2 = try registry.request(client, "res", .{ .mode = .shared });
    try a.expect(&.{ granted(s1), granted(s2) });

    const x = try registry.request(client, "res", .{ .mode = .exclusive });
    // Grantable only as the first of its queue: a shared request behind the
    // exclusive one waits too, though only shared locks are held.
    const s3 = try registry.request(client, "res", .{ .mode = .shared });
    try a.expect(&.{});

    registry.release(s1);
    try a.expect(&.{});
    registry.release(s2);
    try a.expect(&.{granted(x)});
    registry.release(x);
    try a.expect(&.{granted(s3)});
    registry.release(s3);
}

test "locks of different names, and of different storage keys, never block each other" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    var b = Mailbox.init(testing.allocator);
    defer b.deinit();
    const client_a = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    const client_b = try registry.register(&realm_b, &realm_b, "https://other.test", b.delivery());

    const one = try registry.request(client_a, "one", .{});
    const two = try registry.request(client_a, "two", .{});
    const other = try registry.request(client_b, "one", .{});
    try a.expect(&.{ granted(one), granted(two) });
    try b.expect(&.{granted(other)});

    // Each storage key has its own lock manager: B's snapshot sees only B's.
    var snapshot = try registry.snapshot(client_b, testing.allocator);
    defer snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), snapshot.held.len);
    try testing.expectEqualSlices(u8, &client_b.id, &snapshot.held[0].client_id);
    registry.release(one);
    registry.release(two);
    registry.release(other);
}

test "ifAvailable: granted when grantable, otherwise not_granted at once and never queued" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, origin, a.delivery());

    const held = try registry.request(client, "res", .{ .if_available = true });
    try a.expect(&.{granted(held)});
    const refused = try registry.request(client, "res", .{ .if_available = true });
    try a.expect(&.{.{ .kind = .not_granted, .id = refused }});

    // A shared ifAvailable request is not grantable behind a queued request
    // either, even when only shared locks are held.
    registry.release(held);
    const shared = try registry.request(client, "s", .{ .mode = .shared });
    const exclusive = try registry.request(client, "s", .{});
    const behind = try registry.request(client, "s", .{ .mode = .shared, .if_available = true });
    try a.expect(&.{ granted(shared), .{ .kind = .not_granted, .id = behind } });

    var snapshot = try registry.snapshot(client, testing.allocator);
    defer snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), snapshot.held.len);
    try testing.expectEqual(@as(usize, 1), snapshot.pending.len);
    try testing.expectEqual(web_locks.Mode.exclusive, snapshot.pending[0].mode);

    registry.release(shared);
    try a.expect(&.{granted(exclusive)});
    registry.release(exclusive);
}

test "steal releases every held lock of the name, telling each holder, and goes before the queue" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    var b = Mailbox.init(testing.allocator);
    defer b.deinit();
    var c = Mailbox.init(testing.allocator);
    defer c.deinit();
    const client_a = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    const client_b = try registry.register(&realm_b, &realm_b, origin, b.delivery());
    const client_c = try registry.register(&realm_c, &realm_c, origin, c.delivery());

    const shared_a = try registry.request(client_a, "res", .{ .mode = .shared });
    const shared_b = try registry.request(client_b, "res", .{ .mode = .shared });
    const waiting = try registry.request(client_b, "res", .{});
    try a.expect(&.{granted(shared_a)});
    try b.expect(&.{granted(shared_b)});

    const thief = try registry.request(client_c, "res", .{ .steal = true });
    try a.expect(&.{.{ .kind = .stolen, .id = shared_a }});
    try b.expect(&.{.{ .kind = .stolen, .id = shared_b }});
    try c.expect(&.{granted(thief)});

    // The stolen locks' own releases come later, and change nothing.
    registry.release(shared_a);
    registry.release(shared_b);
    try b.expect(&.{});
    registry.release(thief);
    try b.expect(&.{granted(waiting)});
    registry.release(waiting);
}

test "abort removes a pending request and processes its queue; a granted one is not aborted" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, origin, a.delivery());

    const held = try registry.request(client, "res", .{ .mode = .shared });
    const exclusive = try registry.request(client, "res", .{});
    const shared = try registry.request(client, "res", .{ .mode = .shared });
    try a.expect(&.{granted(held)});

    try testing.expect(!registry.abort(held));
    // The exclusive request leaves its queue: the shared one behind it is
    // now first, and grantable beside the held shared lock.
    try testing.expect(registry.abort(exclusive));
    try a.expect(&.{granted(shared)});
    try testing.expect(!registry.abort(exclusive));
    registry.release(held);
    registry.release(shared);
}

test "terminating an environment drops its requests and releases its locks, and the queues behind them proceed" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    var b = Mailbox.init(testing.allocator);
    defer b.deinit();
    const client_a = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    const client_b = try registry.register(&realm_b, &realm_b, origin, b.delivery());

    const a_held = try registry.request(client_a, "x", .{});
    const b_waits_x = try registry.request(client_b, "x", .{});
    const b_held = try registry.request(client_b, "y", .{});
    _ = try registry.request(client_a, "y", .{});
    // A's second request for "x" sits behind B's: A's end must not grant it.
    _ = try registry.request(client_a, "x", .{});
    try a.expect(&.{granted(a_held)});
    try b.expect(&.{granted(b_held)});

    registry.terminate(client_a);
    try a.expect(&.{});
    try b.expect(&.{granted(b_waits_x)});
    try testing.expect(registry.ended(client_a));
    try testing.expectError(error.Ended, registry.request(client_a, "z", .{}));

    var snapshot = try registry.snapshot(client_b, testing.allocator);
    defer snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), snapshot.held.len);
    try testing.expectEqual(@as(usize, 0), snapshot.pending.len);

    // Again: nothing more.
    registry.terminate(client_a);
    try b.expect(&.{});
    registry.release(b_waits_x);
    registry.release(b_held);
}

test "unregister terminates the environment, forgets it and frees its delivery; clientOf finds what is registered" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    var b = Mailbox.init(testing.allocator);
    defer b.deinit();
    const client_a = try registry.register(&realm_a, &realm_b, origin, a.delivery());
    const client_b = try registry.register(&realm_b, &realm_b, origin, b.delivery());
    try testing.expectEqual(@as(?*Client, client_a), registry.clientOf(&realm_a));
    try testing.expect(registry.clientOf(&realm_c) == null);
    try testing.expect(!std.mem.eql(u8, &client_a.id, &client_b.id));

    const held = try registry.request(client_a, "x", .{});
    const waits = try registry.request(client_b, "x", .{});
    try a.expect(&.{granted(held)});

    registry.unregister(client_a);
    try testing.expectEqual(@as(usize, 1), a.deinits);
    try testing.expect(registry.clientOf(&realm_a) == null);
    try b.expect(&.{granted(waits)});
    registry.release(waits);
}

test "an environment whose lock manager could not be obtained has none to request from or query" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, null, a.delivery());
    try testing.expectError(error.NoLockManager, registry.request(client, "x", .{}));
    try testing.expectError(error.NoLockManager, registry.snapshot(client, testing.allocator));
}

test "the Browser's end frees what is left: held locks, queued requests and registered environments" {
    var registry = Registry.init(testing.allocator);
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    _ = try registry.request(client, "x", .{});
    _ = try registry.request(client, "x", .{});
    registry.deinit();
    try testing.expectEqual(@as(usize, 1), a.deinits);
}

test "names are compared as the bytes script gave them: a lone surrogate is not U+FFFD" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var a = Mailbox.init(testing.allocator);
    defer a.deinit();
    const client = try registry.register(&realm_a, &realm_a, origin, a.delivery());
    // WTF-8 for U+D800, and UTF-8 for U+FFFD.
    const lone = try registry.request(client, "\xED\xA0\x80", .{});
    const replacement = try registry.request(client, "\xEF\xBF\xBD", .{});
    const empty = try registry.request(client, "", .{});
    try a.expect(&.{ granted(lone), granted(replacement), granted(empty) });
    registry.release(lone);
    registry.release(replacement);
    registry.release(empty);
}

/// One thread's side of the contention test: its environment, and how many
/// times it held the lock.
const Contender = struct {
    registry: *Registry,
    mailbox: Mailbox,
    client: *Client = undefined,
    holders: *std.atomic.Value(u32),
    overlaps: *std.atomic.Value(u32),
    rounds: u32,

    fn run(self: *Contender) void {
        var round: u32 = 0;
        while (round < self.rounds) : (round += 1) {
            const id = self.registry.request(self.client, "contended", .{}) catch @panic("request failed");
            // Wait for this request's grant, as an event loop would.
            while (true) {
                const events = self.mailbox.take() catch @panic("out of memory");
                defer self.mailbox.allocator.free(events);
                var mine = false;
                for (events) |event| {
                    if (event.kind == .granted and event.id == id) mine = true;
                }
                if (mine) break;
                std.Thread.yield() catch {};
            }
            if (self.holders.fetchAdd(1, .acq_rel) != 0) _ = self.overlaps.fetchAdd(1, .monotonic);
            std.Thread.yield() catch {};
            _ = self.holders.fetchSub(1, .acq_rel);
            self.registry.release(id);
        }
    }
};

test "two threads contending for one exclusive lock never hold it together, and both finish" {
    // std.heap's thread-safe allocator: entries made on one thread are
    // freed on the other (testing.allocator is not thread-safe).
    const allocator = std.heap.smp_allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();
    var holders: std.atomic.Value(u32) = .init(0);
    var overlaps: std.atomic.Value(u32) = .init(0);
    var one: Contender = .{ .registry = &registry, .mailbox = Mailbox.init(allocator), .holders = &holders, .overlaps = &overlaps, .rounds = 500 };
    defer one.mailbox.deinit();
    var two: Contender = .{ .registry = &registry, .mailbox = Mailbox.init(allocator), .holders = &holders, .overlaps = &overlaps, .rounds = 500 };
    defer two.mailbox.deinit();
    one.client = try registry.register(&realm_a, &realm_a, origin, one.mailbox.delivery());
    two.client = try registry.register(&realm_b, &realm_b, origin, two.mailbox.delivery());

    const t1 = try std.Thread.spawn(.{}, Contender.run, .{&one});
    const t2 = try std.Thread.spawn(.{}, Contender.run, .{&two});
    t1.join();
    t2.join();
    try testing.expectEqual(@as(u32, 0), overlaps.load(.monotonic));

    var snapshot = try registry.snapshot(one.client, allocator);
    defer snapshot.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), snapshot.held.len);
    try testing.expectEqual(@as(usize, 0), snapshot.pending.len);
}
