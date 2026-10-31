//! Per-Browser environment values for native tests. The sparse map can
//! represent distant segment indices without allocating the intervening
//! coordinates. No state is shared between Browsers or owned by a document.
const std = @import("std");
const platform = @import("platform");
const headless = @import("kit_headless");

const Key = struct {
    variable: platform.CssEnvironmentVariable,
    x: u32,
    y: u32,

    fn init(variable: platform.CssEnvironmentVariable, x: u32, y: u32) Key {
        const indexed = switch (variable) {
            .viewport_segment_width, .viewport_segment_height, .viewport_segment_top, .viewport_segment_right, .viewport_segment_bottom, .viewport_segment_left => true,
            else => false,
        };
        return .{ .variable = variable, .x = if (indexed) x else 0, .y = if (indexed) y else 0 };
    }
};

pub const Values = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    overrides: std.AutoHashMapUnmanaged(Key, ?f64) = .empty,
    revision: std.atomic.Value(u64) = .init(0),

    pub fn init(allocator: std.mem.Allocator) Values {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Values) void {
        self.overrides.deinit(self.allocator);
    }

    pub fn get(self: *Values, browser: *platform.BrowserPlatform, tab: platform.TabId, variable: platform.CssEnvironmentVariable, x: u32, y: u32) ?f64 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.getLocked(browser, tab, Key.init(variable, x, y));
    }

    fn getLocked(self: *Values, browser: *platform.BrowserPlatform, tab: platform.TabId, key: Key) ?f64 {
        if (self.overrides.get(key)) |value| return value;
        return headless.cssEnvironmentVariable(browser, tab, key.variable, key.x, key.y);
    }

    pub fn set(self: *Values, browser: *platform.BrowserPlatform, tab: platform.TabId, variable: platform.CssEnvironmentVariable, x: u32, y: u32, value: ?f64) error{OutOfMemory}!void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const key = Key.init(variable, x, y);
        if (self.getLocked(browser, tab, key) == value) return;
        // A failed allocation changes neither the answer nor its revision.
        try self.overrides.put(self.allocator, key, value);
        _ = self.revision.fetchAdd(1, .release);
    }
};
