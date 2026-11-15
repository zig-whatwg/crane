//! A delayed reconnect's owned callback, independent of any engine.
const std = @import("std");

/// Timer supplies setTimeoutOwned/clearTimeout with runtime.TimerInterface's contract.
///
/// Who frees the ticket, on every path:
/// - the timer fires: `Ticket.fire`;
/// - the owner cancels and the clear succeeds: `cancel`;
/// - the owner cancels and the clear misses (the timer has fired and its callback is on its way): the
///   detached ticket frees itself in `Ticket.fire`;
/// - the timer manager ends with the wait pending - its loop is gone, the timer never fires:
///   `Ticket.drop`, which the manager runs for a timer armed with the owned form. With the plain form
///   nobody freed it: `cancel` frees only after a successful clear, and an ended manager clears nothing
///   (lane tl1; docs/lessons/architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md).
pub fn Retry(comptime Timer: type) type {
    return struct {
        const Self = @This();
        /// Queues the reconnect task; it does not run script itself.
        pub const Callback = *const fn (*anyopaque) void;
        timer: ?Timer = null,
        id: u64 = 0,
        ticket: ?*Ticket = null,

        /// HTML 9.2.3 reestablish step 2: a one-shot delayed wait.
        pub fn start(self: *Self, allocator: std.mem.Allocator, timer: Timer, delay: u64, callback: Callback, context: *anyopaque) !void {
            self.cancel();
            const ticket = try allocator.create(Ticket);
            errdefer allocator.destroy(ticket);
            ticket.* = .{ .owner = self, .allocator = allocator, .callback = callback, .context = context };
            // Owned by the timer: 0 also when the timer cannot promise the drop, and then nothing waits.
            const id = timer.setTimeoutOwned(delay, Ticket.fire, ticket, Ticket.drop);
            if (id == 0) return error.TimerUnavailable;
            self.timer = timer;
            self.id = id;
            self.ticket = ticket;
        }

        /// Detach first. Only a successful clear permits freeing user_data;
        /// otherwise the late callback frees its now-inert ticket itself.
        pub fn cancel(self: *Self) void {
            const ticket = self.ticket orelse return;
            const timer = self.timer.?;
            const id = self.id;
            self.ticket = null;
            self.timer = null;
            self.id = 0;
            ticket.owner = null;
            if (timer.clearTimeout(id)) ticket.allocator.destroy(ticket);
        }

        const Ticket = struct {
            owner: ?*Self,
            allocator: std.mem.Allocator,
            callback: Callback,
            context: *anyopaque,

            fn fire(raw: ?*anyopaque) void {
                const ticket: *Ticket = @ptrCast(@alignCast(raw.?));
                const owner = ticket.owner;
                const callback = ticket.callback;
                const context = ticket.context;
                if (owner) |self| {
                    self.ticket = null;
                    self.timer = null;
                    self.id = 0;
                }
                ticket.allocator.destroy(ticket);
                if (owner != null) callback(context);
            }

            /// The timer manager ended with the wait pending: the callback never runs. An owner that
            /// still waits is detached first - it lives on (a node can outlive its event loop), and its
            /// later `cancel` must find nothing: the timer it would clear is gone with its manager.
            /// Frees memory and nothing else, as every drop does.
            fn drop(raw: ?*anyopaque) void {
                const ticket: *Ticket = @ptrCast(@alignCast(raw.?));
                if (ticket.owner) |self| {
                    self.ticket = null;
                    self.timer = null;
                    self.id = 0;
                }
                ticket.allocator.destroy(ticket);
            }
        };
    };
}
