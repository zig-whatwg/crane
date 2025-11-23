//! WebIDL namespace: console
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! TEMPORARY: Manually updated to use ConsoleValue instead of anyopaque (TODO: fix codegen)

const runtime = @import("runtime");
const console_impl = @import("impls").console;

pub const console = struct {
    pub const Meta = struct {
        pub const name = "console";
        pub const is_namespace = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};

        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "info", "call_info" },
            .{ "group", "call_group" },
            .{ "groupCollapsed", "call_groupCollapsed" },
            .{ "groupEnd", "call_groupEnd" },
            .{ "timeLog", "call_timeLog" },
            .{ "trace", "call_trace" },
            .{ "timeEnd", "call_timeEnd" },
            .{ "count", "call_count" },
            .{ "time", "call_time" },
            .{ "warn", "call_warn" },
            .{ "clear", "call_clear" },
            .{ "log", "call_log" },
            .{ "error", "call_error" },
            .{ "assert", "call_assert" },
            .{ "table", "call_table" },
            .{ "debug", "call_debug" },
            .{ "dir", "call_dir" },
            .{ "dirxml", "call_dirxml" },
            .{ "countReset", "call_countReset" },
        };

        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_info(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_info(ctx, data);
    }

    pub fn call_group(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_group(ctx, data);
    }

    pub fn call_groupCollapsed(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_groupCollapsed(ctx, data);
    }

    pub fn call_groupEnd(ctx: runtime.Context) void {
        return console_impl.call_groupEnd(ctx);
    }

    pub fn call_timeLog(ctx: runtime.Context, label: runtime.DOMString, data: []const runtime.ConsoleValue) void {
        return console_impl.call_timeLog(ctx, label, data);
    }

    pub fn call_trace(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_trace(ctx, data);
    }

    pub fn call_timeEnd(ctx: runtime.Context, label: runtime.DOMString) void {
        return console_impl.call_timeEnd(ctx, label);
    }

    pub fn call_count(ctx: runtime.Context, label: runtime.DOMString) void {
        return console_impl.call_count(ctx, label);
    }

    pub fn call_time(ctx: runtime.Context, label: runtime.DOMString) void {
        return console_impl.call_time(ctx, label);
    }

    pub fn call_warn(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_warn(ctx, data);
    }

    pub fn call_clear(ctx: runtime.Context) void {
        return console_impl.call_clear(ctx);
    }

    pub fn call_log(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_log(ctx, data);
    }

    pub fn call_error(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_error(ctx, data);
    }

    pub fn call_assert(ctx: runtime.Context, condition: bool, data: []const runtime.ConsoleValue) void {
        return console_impl.call_assert(ctx, condition, data);
    }

    pub fn call_table(ctx: runtime.Context, tabularData: *const anyopaque, properties: *const anyopaque) void {
        return console_impl.call_table(ctx, tabularData, properties);
    }

    pub fn call_debug(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
        return console_impl.call_debug(ctx, data);
    }

    pub fn call_dir(ctx: runtime.Context, item: *const anyopaque, options: *const anyopaque) void {
        return console_impl.call_dir(ctx, item, options);
    }

    pub fn call_dirxml(ctx: runtime.Context, data: []const *const anyopaque) void {
        return console_impl.call_dirxml(ctx, data);
    }

    pub fn call_countReset(ctx: runtime.Context, label: runtime.DOMString) void {
        return console_impl.call_countReset(ctx, label);
    }
};
