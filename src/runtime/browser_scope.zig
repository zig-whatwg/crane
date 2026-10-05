//! A Browser's scope: where its per-Browser state lives, reached through the
//! realm (docs/instances.md, rule 2: "a realm will carry its Browser's scope
//! ... Per-Browser state of a subsystem is a supplement of that scope (Blink's
//! `Supplementable`), made on first use and destroyed with the scope").
//!
//! A Browser runs its window agent on one thread and every worker on a thread
//! of its own, so a supplement is reached from several threads: the scope's
//! mutex guards the supplement list, and a supplement guards its own state.
//!
//! This is instances B1's first piece, with what workers need: the
//! WorkerRegistry (html), the Browser's live workers. B1 adds the runtime's
//! allocators and registries; batch 2 of the workers lane the shared worker
//! manager and BroadcastChannel delivery.
//!
//! A supplement type `T` has `pub fn init(allocator: Allocator) T` and
//! `pub fn deinit(self: *T) void`. It is keyed by its type: `of(T)` returns
//! the one `T` of this scope, made on first use. Supplements end in the
//! reverse order they were made, with the scope.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const BrowserScope = struct {
    /// Thread-safe: supplements are made on whichever thread first asks.
    allocator: Allocator,
    /// Protects `supplements`. Never held across a supplement's own steps
    /// beyond its `init`.
    mutex: std.Io.Mutex = .init,
    supplements: std.ArrayListUnmanaged(Supplement) = .empty,

    const Supplement = struct {
        /// `@typeName` of the supplement's type: its key.
        key: []const u8,
        ptr: *anyopaque,
        destroy: *const fn (ptr: *anyopaque, allocator: Allocator) void,
    };

    pub fn init(allocator: Allocator) BrowserScope {
        return .{ .allocator = allocator };
    }

    /// The scope's end, with its Browser's: every supplement ends, the last
    /// made first.
    pub fn deinit(self: *BrowserScope) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        var supplements = self.supplements;
        self.supplements = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        var i = supplements.items.len;
        while (i > 0) {
            i -= 1;
            const supplement = supplements.items[i];
            supplement.destroy(supplement.ptr, self.allocator);
        }
        supplements.deinit(self.allocator);
    }

    /// This scope's `T`, made on first use.
    pub fn of(self: *BrowserScope, comptime T: type) Allocator.Error!*T {
        const key = @typeName(T);
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (find(self, key)) |ptr| return @ptrCast(@alignCast(ptr));
        try self.supplements.ensureUnusedCapacity(self.allocator, 1);
        const made = try self.allocator.create(T);
        made.* = T.init(self.allocator);
        self.supplements.appendAssumeCapacity(.{ .key = key, .ptr = made, .destroy = Destroy(T).destroy });
        return made;
    }

    /// This scope's `T` if one was made; never makes one.
    pub fn existing(self: *BrowserScope, comptime T: type) ?*T {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const ptr = find(self, @typeName(T)) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    fn find(self: *BrowserScope, key: []const u8) ?*anyopaque {
        for (self.supplements.items) |supplement| {
            if (std.mem.eql(u8, supplement.key, key)) return supplement.ptr;
        }
        return null;
    }

    fn Destroy(comptime T: type) type {
        return struct {
            fn destroy(ptr: *anyopaque, allocator: Allocator) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.deinit();
                allocator.destroy(self);
            }
        };
    }
};
