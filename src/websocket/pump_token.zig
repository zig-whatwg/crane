//! The token a WebSocket's scheduled pump turn points at, and who frees it.
//!
//! The WebSocket interface drives its connection one event-loop turn at a
//! time: a one-shot timer on the realm's timer manager runs a turn, and the
//! turn arms the next one while the socket is live
//! (src/webidl/impls/WebSocket.zig, `pumpCallback`). A timer outlives the page
//! that armed it - the timer manager is the browser's - so what it carries
//! must not be the socket itself: the socket can be freed at any time between
//! turns (its realm ends, its wrapper is collected) and its address reissued.
//!
//! So a turn points at a token: a small allocation of its own, pointing at
//! the socket (the `target`), which the socket's teardown `detach`es and
//! which is freed exactly once, by whoever owns it at that moment:
//!
//!   armed      a turn is scheduled against it: THAT TURN owns it, and frees
//!              it when it fires (`beginTurn`) if the socket went meanwhile -
//!              or, if its timer ends with it unfired, when the timer drops
//!              it (`dropTurn`).
//!   in a turn  the turn owns it: a socket freed by the script the turn runs
//!              (`detach` inside the turn) leaves the free to the turn's end.
//!   neither    the socket owns it: `detach` frees it.
//!
//! A turn can be both at once: the script it runs calls close(), which arms
//! the next turn, and then ends the socket's realm, which detaches the token.
//! Its end must then leave the token to the turn it armed - freeing it there
//! left that turn firing into freed memory.
//!
//! A scheduled turn may also never fire: a worker's end makes its sockets
//! disappear (`detach`, with a turn scheduled) and then ends its loop's
//! timers without running them. So a turn is armed as an OWNED timer
//! (`setTimeoutOwned`), whose drop is the turn's end without its steps: a
//! token whose socket went is freed there, and one whose socket lives goes
//! back to the socket - with nothing armed on the ended timer again. Armed
//! as a plain timer, the token leaked with every worker that ended with a
//! socket's turn pending (2 x 64 B per socket in leaks --atExit).

const std = @import("std");

/// A pump token for a `Target` (the socket), armed on a `Timer` - anything
/// with `setTimeoutOwned(ms: u64, callback: *const fn (?*anyopaque) void,
/// user_data: ?*anyopaque, drop: *const fn (?*anyopaque) void)` returning a
/// nonzero id when it armed one, as the runtime's TimerInterface has.
pub fn PumpToken(comptime Target: type, comptime Timer: type) type {
    return struct {
        const Self = @This();

        /// A turn's entry point, as the timer calls it with the token.
        pub const Callback = *const fn (?*anyopaque) void;

        allocator: std.mem.Allocator,
        /// The socket this pumps. Read ONLY while `cancelled` is false.
        target: *Target,
        timer: Timer,
        /// Set by `detach`: the socket is gone, and nothing but the token
        /// may be touched from here on.
        cancelled: bool = false,
        /// True exactly while a turn is scheduled against this token.
        armed: bool = false,
        /// True while a turn runs (`beginTurn` to `endTurn`).
        in_turn: bool = false,
        /// Set by `dropTurn`: the timer ended (its manager is freed), so
        /// nothing may be armed on it again.
        timer_ended: bool = false,

        pub fn create(allocator: std.mem.Allocator, target: *Target, timer: Timer) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .allocator = allocator, .target = target, .timer = timer };
            return self;
        }

        /// Schedule the next turn in `ms`. A no-op if one is scheduled already,
        /// if the socket is gone, or if the timer has ended. A timer that arms
        /// nothing (it failed, or cannot promise the drop) leaves the token
        /// the socket's, unarmed: no turn owns it then.
        pub fn arm(self: *Self, ms: u64, callback: Callback) void {
            if (self.armed or self.cancelled or self.timer_ended) return;
            self.armed = true;
            if (self.timer.setTimeoutOwned(ms, callback, @ptrCast(self), dropTurn) == 0) {
                self.armed = false;
            }
        }

        /// The timer ended with the scheduled turn unfired (a worker's loop
        /// ends its timers without running them): the turn's end, without its
        /// steps. The token is freed if the socket went and no turn is running
        /// (one that is frees it at its end); a live socket gets it back, and
        /// its `detach` frees it. Called by the timer, with the token.
        pub fn dropTurn(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data orelse return));
            self.armed = false;
            self.timer_ended = true;
            if (self.cancelled and !self.in_turn) self.allocator.destroy(self);
        }

        /// The socket is going: give it up. Frees the token unless a turn owns
        /// it (scheduled or running), which frees it instead.
        pub fn detach(self: *Self) void {
            self.cancelled = true;
            if (!self.armed and !self.in_turn) self.allocator.destroy(self);
        }

        /// A scheduled turn fired. The socket to run it for - or null when the
        /// socket went before it fired, in which case the token is freed and
        /// the turn must touch nothing.
        pub fn beginTurn(self: *Self) ?*Target {
            self.armed = false;
            if (self.cancelled) {
                self.allocator.destroy(self);
                return null;
            }
            self.in_turn = true;
            return self.target;
        }

        /// The turn is over; `live` says whether the socket wants another,
        /// armed in `ms`. A socket that went during the turn leaves the token
        /// to the turn's end - or, if the turn armed another before it went,
        /// to that turn, which owns it now.
        pub fn endTurn(self: *Self, live: bool, ms: u64, callback: Callback) void {
            self.in_turn = false;
            if (self.cancelled) {
                // Armed during the turn: the turn it armed owns the token and
                // frees it when it fires (`beginTurn`).
                if (!self.armed) self.allocator.destroy(self);
                return;
            }
            if (live) self.arm(ms, callback);
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

/// A timer that runs nothing by itself: the test fires what is scheduled,
/// or ends the timer with it unfired, as a worker's loop ends its timers.
const FakeTimer = struct {
    scheduled: std.ArrayListUnmanaged(Entry) = .empty,
    /// Set by `end`: the timer is gone, as a NativeTimerManager after its
    /// deinit. Anything scheduled on it from then on is counted here.
    ended: bool = false,
    used_after_end: usize = 0,

    const Callback = *const fn (?*anyopaque) void;
    const Entry = struct { callback: Callback, data: ?*anyopaque, drop: ?Callback = null };

    fn setTimeout(self: *FakeTimer, ms: u64, callback: Callback, data: ?*anyopaque) u32 {
        return self.schedule(ms, .{ .callback = callback, .data = data });
    }

    fn setTimeoutOwned(self: *FakeTimer, ms: u64, callback: Callback, data: ?*anyopaque, drop: Callback) u32 {
        return self.schedule(ms, .{ .callback = callback, .data = data, .drop = drop });
    }

    fn schedule(self: *FakeTimer, ms: u64, entry: Entry) u32 {
        _ = ms;
        if (self.ended) {
            self.used_after_end += 1;
            return 0;
        }
        self.scheduled.append(testing.allocator, entry) catch return 0;
        return @intCast(self.scheduled.items.len);
    }

    /// Fire everything scheduled so far, as the timer manager would.
    fn fireAll(self: *FakeTimer) void {
        const due = self.scheduled.toOwnedSlice(testing.allocator) catch return;
        defer testing.allocator.free(due);
        for (due) |entry| entry.callback(entry.data);
    }

    /// The timer's end with everything still scheduled unfired, as
    /// NativeTimerManager.deinit: an owned timer's data is dropped, a plain
    /// one's is left to whoever armed it.
    fn end(self: *FakeTimer) void {
        self.ended = true;
        const unfired = self.scheduled.toOwnedSlice(testing.allocator) catch return;
        defer testing.allocator.free(unfired);
        for (unfired) |entry| if (entry.drop) |drop| drop(entry.data);
    }

    fn deinit(self: *FakeTimer) void {
        self.scheduled.deinit(testing.allocator);
    }
};

const TimerRef = struct {
    fake: *FakeTimer,
    fn setTimeout(self: TimerRef, ms: u64, callback: FakeTimer.Callback, data: ?*anyopaque) u32 {
        return self.fake.setTimeout(ms, callback, data);
    }
    fn setTimeoutOwned(self: TimerRef, ms: u64, callback: FakeTimer.Callback, data: ?*anyopaque, drop: FakeTimer.Callback) u32 {
        return self.fake.setTimeoutOwned(ms, callback, data, drop);
    }
};

/// A socket, as far as the token sees one: what the script a turn runs does.
const FakeSocket = struct {
    turns: usize = 0,
    /// What the next turn's script does: call close() (arming the next
    /// turn), end the socket (detach), or both, in that order.
    close_in_turn: bool = false,
    end_in_turn: bool = false,
    /// A timer the next turn's script ends, after the rest.
    end_timer_in_turn: ?*FakeTimer = null,
    token: ?*Token = null,
};

const Token = PumpToken(FakeSocket, TimerRef);

fn turn(data: ?*anyopaque) void {
    const token: *Token = @ptrCast(@alignCast(data.?));
    const socket = token.beginTurn() orelse return;
    socket.turns += 1;
    if (socket.close_in_turn) token.arm(1, turn);
    if (socket.end_in_turn) {
        token.detach();
        socket.token = null;
    }
    if (socket.end_timer_in_turn) |timer| timer.end();
    token.endTurn(true, 1, turn);
}

test "a token detached between turns is freed by detach" {
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    token.detach();
    try testing.expectEqual(@as(usize, 0), timer.scheduled.items.len);
}

test "a token detached while a turn is scheduled is freed by that turn, which touches nothing else" {
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    token.arm(1, turn);
    token.detach();
    timer.fireAll();
    try testing.expectEqual(@as(usize, 0), socket.turns);
    try testing.expectEqual(@as(usize, 0), timer.scheduled.items.len);
}

test "a live turn arms the next; a token detached during a turn is freed at its end" {
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    socket.token = token;
    token.arm(1, turn);
    timer.fireAll();
    try testing.expectEqual(@as(usize, 1), socket.turns);
    try testing.expectEqual(@as(usize, 1), timer.scheduled.items.len);
    socket.end_in_turn = true;
    timer.fireAll();
    try testing.expectEqual(@as(usize, 2), socket.turns);
    try testing.expectEqual(@as(usize, 0), timer.scheduled.items.len);
}

test "a turn that arms the next and then ends the socket leaves the token to the turn it armed" {
    // close() then the realm's end, from one event listener: the turn arms
    // the next turn, then the socket's teardown detaches the token. Freeing
    // the token at this turn's end left the armed turn firing into freed
    // memory - the testing allocator reports that second free.
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    socket.token = token;
    token.arm(1, turn);
    socket.close_in_turn = true;
    socket.end_in_turn = true;
    timer.fireAll();
    try testing.expectEqual(@as(usize, 1), socket.turns);
    // The armed turn is still scheduled, and it owns the token.
    try testing.expectEqual(@as(usize, 1), timer.scheduled.items.len);
    timer.fireAll();
    try testing.expectEqual(@as(usize, 1), socket.turns);
    try testing.expectEqual(@as(usize, 0), timer.scheduled.items.len);
}

test "a token detached while its turn is scheduled is freed when the timer ends with the turn unfired" {
    // A worker's end: unloading cleanup makes the socket disappear (detach)
    // while a turn is scheduled, which then owns the token - and the worker's
    // loop ends its timers without firing it. The turn that would have freed
    // the token never runs, so the timer's end must free it (2 x 64 B per
    // worker socket in leaks --atExit before).
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    token.arm(1, turn);
    token.detach();
    timer.end();
    try testing.expectEqual(@as(usize, 0), socket.turns);
}

test "a turn the timer ends unfired gives the token back to a live socket, whose detach frees it" {
    // The timer ends first, the socket after (a Browser whose loop ends
    // before its realms do): the token goes back to the socket, which frees
    // it at its teardown.
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    token.arm(1, turn);
    timer.end();
    try testing.expectEqual(@as(usize, 0), socket.turns);
    token.detach();
}

test "a token whose timer ended its turn unfired arms nothing on that timer again" {
    // The timer is gone (its manager freed): arming on it again would write
    // into freed memory. Once it has dropped a turn, the token arms no more;
    // the socket's teardown still frees it.
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    token.arm(1, turn);
    timer.end();
    token.arm(1, turn);
    try testing.expectEqual(@as(usize, 0), timer.used_after_end);
    token.detach();
}

test "a turn armed during a running turn and ended unfired leaves the token to the running turn's end" {
    // Defensive: NativeTimerManager cannot end inside its own poll, but should
    // a timer end while a turn runs - the turn arms the next (close()), its
    // script ends the socket (detach) and then the timer (the armed turn is
    // dropped unfired) - the token is still the running turn's, and only its
    // end may free it.
    var timer: FakeTimer = .{};
    defer timer.deinit();
    var socket: FakeSocket = .{};
    const token = try Token.create(testing.allocator, &socket, .{ .fake = &timer });
    socket.token = token;
    token.arm(1, turn);
    socket.close_in_turn = true;
    socket.end_in_turn = true;
    socket.end_timer_in_turn = &timer;
    timer.fireAll();
    try testing.expectEqual(@as(usize, 1), socket.turns);
    try testing.expectEqual(@as(usize, 0), timer.used_after_end);
}
