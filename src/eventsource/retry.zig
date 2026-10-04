//! A delayed reconnect's owned callback, independent of any engine.
const std = @import("std");

/// Timer supplies setTimeout/clearTimeout with runtime.TimerInterface's contract.
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
            const id = timer.setTimeout(delay, Ticket.fire, ticket);
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
        };
    };
}
