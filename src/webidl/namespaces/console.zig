//! WebIDL namespace: console
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const console_impl = @import("impls").console;

pub const console = struct {
    pub const Meta = struct {
        pub const name = "console";
        pub const is_namespace = true;
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        pub const BaseType = null;
        pub const MixinTypes = &.{};

        /// Method binding hints (JS name, Zig function name, WebIDL length)
        pub const methods = .{
            .{ "clear", "call_clear", 0 },
            .{ "log", "call_log", 0 },
            .{ "table", "call_table", 0 },
            .{ "trace", "call_trace", 0 },
            .{ "groupEnd", "call_groupEnd", 0 },
            .{ "info", "call_info", 0 },
            .{ "count", "call_count", 0 },
            .{ "debug", "call_debug", 0 },
            .{ "countReset", "call_countReset", 0 },
            .{ "time", "call_time", 0 },
            .{ "assert", "call_assert", 0 },
            .{ "groupCollapsed", "call_groupCollapsed", 0 },
            .{ "error", "call_error", 0 },
            .{ "timeLog", "call_timeLog", 0 },
            .{ "dir", "call_dir", 0 },
            .{ "warn", "call_warn", 0 },
            .{ "dirxml", "call_dirxml", 0 },
            .{ "timeEnd", "call_timeEnd", 0 },
            .{ "group", "call_group", 0 },
        };

        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_clear(ctx: runtime.Context) anyerror!void {
        return try console_impl.call_clear(ctx);
    }

    pub fn call_log(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_log(ctx, data);
    }

    pub fn call_table(ctx: runtime.Context, tabularData: webidl.Opt(runtime.JSValue), properties: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try console_impl.call_table(ctx, tabularData, properties);
    }

    pub fn call_trace(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_trace(ctx, data);
    }

    pub fn call_groupEnd(ctx: runtime.Context) anyerror!void {
        return try console_impl.call_groupEnd(ctx);
    }

    pub fn call_info(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_info(ctx, data);
    }

    pub fn call_count(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
        return try console_impl.call_count(ctx, label);
    }

    pub fn call_debug(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_debug(ctx, data);
    }

    pub fn call_countReset(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
        return try console_impl.call_countReset(ctx, label);
    }

    pub fn call_time(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
        return try console_impl.call_time(ctx, label);
    }

    pub fn call_assert(ctx: runtime.Context, condition: webidl.Opt(bool), data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_assert(ctx, condition, data);
    }

    pub fn call_groupCollapsed(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_groupCollapsed(ctx, data);
    }

    pub fn call_error(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_error(ctx, data);
    }

    pub fn call_timeLog(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_timeLog(ctx, label, data);
    }

    pub fn call_dir(ctx: runtime.Context, item: webidl.Opt(runtime.JSValue), options: webidl.Opt(?runtime.JSValue)) anyerror!void {
        return try console_impl.call_dir(ctx, item, options);
    }

    pub fn call_warn(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_warn(ctx, data);
    }

    pub fn call_dirxml(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_dirxml(ctx, data);
    }

    pub fn call_timeEnd(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
        return try console_impl.call_timeEnd(ctx, label);
    }

    pub fn call_group(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
        return try console_impl.call_group(ctx, data);
    }
};
