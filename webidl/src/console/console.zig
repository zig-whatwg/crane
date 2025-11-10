//! WHATWG Console Standard Implementation
//! Spec: https://console.spec.whatwg.org/

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const types = @import("types");

const Allocator = std.mem.Allocator;

/// Console namespace object per WHATWG Console Standard
pub const Console = webidl.namespace(struct {
    allocator: Allocator,
    count_map: std.StringHashMap(u32),
    timer_table: std.StringHashMap(i64),
    group_stack: std.ArrayList(types.Group),

    pub fn init(allocator: Allocator) !Console {
        return .{
            .allocator = allocator,
            .count_map = std.StringHashMap(u32).init(allocator),
            .timer_table = std.StringHashMap(i64).init(allocator),
            .group_stack = std.ArrayList(types.Group).init(allocator),
        };
    }

    pub fn deinit(self: *Console) void {
        self.count_map.deinit();
        self.timer_table.deinit();
        self.group_stack.deinit();
    }

    /// assert(condition, ...data)
    /// Spec: https://console.spec.whatwg.org/#assert
    pub fn call_assert(self: *Console, condition: bool, data: []const webidl.JSValue) !void {
        // 1. If condition is true, return.
        if (condition) return;

        // 2. Let message be a string indicating assertion failure
        const message = "Assertion failed";

        var args = std.ArrayList(webidl.JSValue).init(self.allocator);
        defer args.deinit();

        // 3. If data is empty, append message to data
        if (data.len == 0) {
            try args.append(webidl.JSValue{ .string = message });
        } else {
            // 4. Otherwise
            const first = data[0];

            // Check if first is not a string
            const is_string = switch (first) {
                .string => true,
                else => false,
            };

            if (!is_string) {
                // 4.2 Prepend message to data
                try args.append(webidl.JSValue{ .string = message });
                try args.appendSlice(data);
            } else {
                // 4.3 Concatenate message with first
                const first_str = first.string;
                const concat = try std.fmt.allocPrint(self.allocator, "{s}: {s}", .{ message, first_str });
                defer self.allocator.free(concat);

                try args.append(webidl.JSValue{ .string = concat });
                if (data.len > 1) {
                    try args.appendSlice(data[1..]);
                }
            }
        }

        // 5. Perform Logger("assert", data)
        try self.logger(.assert_level, args.items);
    }

    /// clear()
    /// Spec: https://console.spec.whatwg.org/#clear
    pub fn call_clear(self: *Console) void {
        // 1. Empty the appropriate group stack
        self.group_stack.clearRetainingCapacity();

        // 2. If possible for the environment, clear the console
        // (Implementation specific - we just clear the group stack)
    }

    /// debug(...data)
    /// Spec: https://console.spec.whatwg.org/#debug
    pub fn call_debug(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Perform Logger("debug", data)
        try self.logger(.debug, data);
    }

    /// error(...data)
    /// Spec: https://console.spec.whatwg.org/#error
    pub fn call_error(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Perform Logger("error", data)
        try self.logger(.error_level, data);
    }

    /// info(...data)
    /// Spec: https://console.spec.whatwg.org/#info
    pub fn call_info(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Perform Logger("info", data)
        try self.logger(.info, data);
    }

    /// log(...data)
    /// Spec: https://console.spec.whatwg.org/#log
    pub fn call_log(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Perform Logger("log", data)
        try self.logger(.log, data);
    }

    /// table(tabularData, properties)
    /// Spec: https://console.spec.whatwg.org/#table
    pub fn call_table(self: *Console, tabular_data: ?webidl.JSValue, properties: ?[]const webidl.DOMString) !void {
        _ = properties;
        // Try to construct a table, fall back to logging the argument
        if (tabular_data) |data| {
            const args: [1]webidl.JSValue = .{data};
            try self.logger(.log, &args);
        } else {
            try self.logger(.log, &.{});
        }
    }

    /// trace(...data)
    /// Spec: https://console.spec.whatwg.org/#trace
    pub fn call_trace(self: *Console, data: []const webidl.JSValue) !void {
        // Implementation-defined trace representation
        try self.logger(.trace, data);
    }

    /// warn(...data)
    /// Spec: https://console.spec.whatwg.org/#warn
    pub fn call_warn(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Perform Logger("warn", data)
        try self.logger(.warn, data);
    }

    /// dir(item, options)
    /// Spec: https://console.spec.whatwg.org/#dir
    pub fn call_dir(self: *Console, item: ?webidl.JSValue, options: ?webidl.JSValue) !void {
        _ = options;
        // 1. Let object be item with generic JavaScript object formatting applied
        // 2. Perform Printer("dir", « object », options)
        if (item) |obj| {
            const args: [1]webidl.JSValue = .{obj};
            try self.logger(.dir, &args);
        } else {
            try self.logger(.dir, &.{});
        }
    }

    /// dirxml(...data)
    /// Spec: https://console.spec.whatwg.org/#dirxml
    pub fn call_dirxml(self: *Console, data: []const webidl.JSValue) !void {
        // 1-3. Convert items to DOM tree representations and perform Logger
        try self.logger(.dirxml, data);
    }

    /// count(label)
    /// Spec: https://console.spec.whatwg.org/#count
    pub fn call_count(self: *Console, label: []const u8) !void {
        // 1. Let map be the associated count map
        // 2. If map[label] exists, set map[label] to map[label] + 1
        // 3. Otherwise, set map[label] to 1
        const result = try self.count_map.getOrPut(label);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;

        // 4. Let concat be the concatenation of label, ":", " ", and ToString(map[label])
        // 5. Perform Logger("count", « concat »)
        std.debug.print("{s}: {d}\n", .{ label, result.value_ptr.* });
    }

    /// countReset(label)
    /// Spec: https://console.spec.whatwg.org/#countreset
    pub fn call_countReset(self: *Console, label: []const u8) void {
        // 1. Let map be the associated count map
        // 2. If map[label] exists, set map[label] to 0
        if (self.count_map.getPtr(label)) |value| {
            value.* = 0;
        }
        // 3. Otherwise: perform Logger with message about label not existing
        // (Implementation skipped for simplicity)
    }

    /// group(...data)
    /// Spec: https://console.spec.whatwg.org/#group
    pub fn call_group(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Let group be a new group
        // 2-5. Create and configure group
        const group = types.Group{ .collapsed = false };

        // 6. Push group onto the appropriate group stack
        try self.group_stack.append(group);

        try self.logger(.group, data);
    }

    /// groupCollapsed(...data)
    /// Spec: https://console.spec.whatwg.org/#groupcollapsed
    pub fn call_groupCollapsed(self: *Console, data: []const webidl.JSValue) !void {
        // 1. Let group be a new group
        // 2-5. Create and configure group (collapsed by default)
        const group = types.Group{ .collapsed = true };

        // 6. Push group onto the appropriate group stack
        try self.group_stack.append(group);

        try self.logger(.group_collapsed, data);
    }

    /// groupEnd()
    /// Spec: https://console.spec.whatwg.org/#groupend
    pub fn call_groupEnd(self: *Console) void {
        // 1. Pop the last group from the group stack
        if (self.group_stack.items.len > 0) {
            _ = self.group_stack.pop();
        }
    }

    /// time(label)
    /// Spec: https://console.spec.whatwg.org/#time
    pub fn call_time(self: *Console, label: []const u8) !void {
        // 1. Let timer table be the associated timer table
        // 2-4. Start timing with label
        const now = std.time.milliTimestamp();
        try self.timer_table.put(label, now);
    }

    /// timeLog(label, ...data)
    /// Spec: https://console.spec.whatwg.org/#timelog
    pub fn call_timeLog(self: *Console, label: []const u8, data: []const webidl.JSValue) !void {
        _ = data;
        // 1-4. Log elapsed time for label
        if (self.timer_table.get(label)) |start_time| {
            const now = std.time.milliTimestamp();
            const elapsed = now - start_time;
            std.debug.print("{s}: {d}ms\n", .{ label, elapsed });
        }
    }

    /// timeEnd(label)
    /// Spec: https://console.spec.whatwg.org/#timeend
    pub fn call_timeEnd(self: *Console, label: []const u8) void {
        // 1-5. Log elapsed time and remove timer
        if (self.timer_table.get(label)) |start_time| {
            const now = std.time.milliTimestamp();
            const elapsed = now - start_time;
            std.debug.print("{s}: {d}ms\n", .{ label, elapsed });
            _ = self.timer_table.remove(label);
        }
    }

    /// Logger abstract operation
    /// Spec: https://console.spec.whatwg.org/#logger
    fn logger(self: *Console, log_level: types.LogLevel, args: []const webidl.JSValue) !void {
        _ = self;
        _ = log_level;
        _ = args;
        // Implementation-defined logging behavior
        // In a real implementation, this would format and output the data
    }
});
