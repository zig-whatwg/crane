//! WHATWG Console Standard Implementation
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! This implements the console namespace object per WHATWG Console Standard.
//! All console operations are stateless from the perspective of the namespace -
//! state is managed by runtime.Context.console_state.
//!
//! ## Implementation Notes
//!
//! ### State Management
//! Console state (counts, timers, groups) is stored in `runtime.Context.console_state`.
//! This allows namespaces (which are stateless static objects) to maintain per-context state.
//!
//! ### Data Formatting
//! The `data` parameter is `[]const *const anyopaque` - an array of opaque pointers to values.
//! Full format specifier support (%s, %d, etc.) requires runtime type introspection.
//! Current implementation provides basic string output with proper indentation.
//!
//! ### Indentation
//! Group operations (group, groupCollapsed, groupEnd) manage indent level via group_stack.
//! Each log operation respects the current indent level.

const std = @import("std");
const runtime = @import("runtime");

/// Get indentation string for current group level
fn getIndent(ctx: runtime.Context) []const u8 {
    const indent_level = ctx.console_state.getIndentLevel();
    if (indent_level == 0) return "";

    // Each level = 2 spaces
    const indent_spaces = indent_level * 2;
    const max_indent = 32; // Max 16 levels
    const spaces = "                                "; // 32 spaces
    return spaces[0..@min(indent_spaces, max_indent)];
}

/// Print message with indentation
fn printIndented(ctx: runtime.Context, comptime fmt: []const u8, args: anytype) void {
    const indent = getIndent(ctx);
    if (indent.len > 0) {
        std.debug.print("{s}", .{indent});
    }
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

/// Format and print console values
fn printConsoleValues(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    const indent = getIndent(ctx);
    if (indent.len > 0) {
        std.debug.print("{s}", .{indent});
    }

    for (data, 0..) |value, i| {
        if (i > 0) std.debug.print(" ", .{});

        switch (value) {
            .undefined => std.debug.print("undefined", .{}),
            .null => std.debug.print("null", .{}),
            .boolean => |b| std.debug.print("{}", .{b}),
            .number => |n| std.debug.print("{d}", .{n}),
            .string => |s| std.debug.print("{s}", .{s}),
            .bigint => |bi| std.debug.print("{s}n", .{bi}),
            .symbol => std.debug.print("Symbol()", .{}),
            .object => std.debug.print("[object Object]", .{}),
        }
    }

    std.debug.print("\n", .{});
}

/// console.info(data...)
///
/// WHATWG Console Standard: Logger("info", data)
pub fn call_info(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    printConsoleValues(ctx, data);
}

/// console.group(data...)
///
/// WHATWG Console Standard: Push new group onto stack
pub fn call_group(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    // Print group header with data
    if (data.len > 0) {
        printConsoleValues(ctx, data);
    } else {
        printIndented(ctx, "▼ Group", .{});
    }
    // Push new indent level
    ctx.console_state.group_stack.append(ctx.allocator, 0) catch {};
}

/// console.groupCollapsed(data...)
///
/// WHATWG Console Standard: Same as group() but collapsed by default
pub fn call_groupCollapsed(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    // Same implementation as group (collapsed state is UI concern)
    call_group(ctx, data);
}

/// console.groupEnd()
///
/// WHATWG Console Standard: Pop group from stack
pub fn call_groupEnd(ctx: runtime.Context) void {
    if (ctx.console_state.group_stack.items.len > 0) {
        _ = ctx.console_state.group_stack.pop();
    }
}

/// console.timeLog(label, data...)
///
/// WHATWG Console Standard: Log elapsed time for label
pub fn call_timeLog(ctx: runtime.Context, label: runtime.DOMString, data: []const runtime.ConsoleValue) void {
    const label_str = label.asSlice();

    if (ctx.console_state.timer_table.get(label_str)) |start_time| {
        const now = std.time.milliTimestamp();
        const elapsed = now - start_time;
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        std.debug.print("{s}: {d}ms", .{ label_str, elapsed });
        if (data.len > 0) {
            std.debug.print(" ", .{});
            for (data, 0..) |value, i| {
                if (i > 0) std.debug.print(" ", .{});
                switch (value) {
                    .string => |s| std.debug.print("{s}", .{s}),
                    .number => |n| std.debug.print("{d}", .{n}),
                    .boolean => |b| std.debug.print("{}", .{b}),
                    else => std.debug.print("[value]", .{}),
                }
            }
        }
        std.debug.print("\n", .{});
    } else {
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        ctx.logger.warn("Timer '{s}' does not exist", .{label_str}) catch {};
    }
}

/// console.trace(data...)
///
/// WHATWG Console Standard: Log with stack trace
pub fn call_trace(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    if (data.len > 0) {
        printConsoleValues(ctx, data);
    } else {
        printIndented(ctx, "Trace", .{});
    }
    // TODO: Stack trace generation requires debug info integration
}

/// console.timeEnd(label)
///
/// WHATWG Console Standard: Log elapsed time and remove timer
pub fn call_timeEnd(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();

    if (ctx.console_state.timer_table.fetchRemove(label_str)) |entry| {
        const start_time = entry.value;
        const now = std.time.milliTimestamp();
        const elapsed = now - start_time;
        printIndented(ctx, "{s}: {d}ms - timer ended", .{ label_str, elapsed });
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        ctx.logger.warn("Timer '{s}' does not exist", .{label_str}) catch {};
    }
}

/// console.count(label)
///
/// WHATWG Console Standard: Increment and log count for label
pub fn call_count(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();

    const gop = ctx.console_state.count_map.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        // Allocate owned copy of label
        const owned_label = ctx.allocator.dupe(u8, label_str) catch return;
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = 1;
    } else {
        gop.value_ptr.* += 1;
    }

    printIndented(ctx, "{s}: {d}", .{ label_str, gop.value_ptr.* });
}

/// console.time(label)
///
/// WHATWG Console Standard: Start timer with label
pub fn call_time(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();

    const gop = ctx.console_state.timer_table.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        // Allocate owned copy of label
        const owned_label = ctx.allocator.dupe(u8, label_str) catch return;
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = std.time.milliTimestamp();
    } else {
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        ctx.logger.warn("Timer '{s}' already exists", .{label_str}) catch {};
    }
}

/// console.warn(data...)
///
/// WHATWG Console Standard: Logger("warn", data)
pub fn call_warn(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    printConsoleValues(ctx, data);
}

/// console.clear()
///
/// WHATWG Console Standard: Clear console (implementation-specific)
pub fn call_clear(ctx: runtime.Context) void {
    _ = ctx;
    // Clear is UI concern - no-op in this implementation
}

/// console.log(data...)
///
/// WHATWG Console Standard: Logger("log", data)
pub fn call_log(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    printConsoleValues(ctx, data);
}

/// console.error(data...)
///
/// WHATWG Console Standard: Logger("error", data)
pub fn call_error(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    printConsoleValues(ctx, data);
}

/// console.assert(condition, data...)
///
/// WHATWG Console Standard: If !condition, Logger("assert", data)
pub fn call_assert(ctx: runtime.Context, condition: bool, data: []const runtime.ConsoleValue) void {
    if (!condition) {
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        std.debug.print("Assertion failed", .{});
        if (data.len > 0) {
            std.debug.print(": ", .{});
            for (data, 0..) |value, i| {
                if (i > 0) std.debug.print(" ", .{});
                switch (value) {
                    .string => |s| std.debug.print("{s}", .{s}),
                    .number => |n| std.debug.print("{d}", .{n}),
                    .boolean => |b| std.debug.print("{}", .{b}),
                    else => std.debug.print("[value]", .{}),
                }
            }
        }
        std.debug.print("\n", .{});
    }
}

/// console.table(tabularData, properties)
///
/// WHATWG Console Standard: Display tabular data
pub fn call_table(ctx: runtime.Context, tabularData: *const anyopaque, properties: *const anyopaque) void {
    _ = tabularData; // TODO: Format as ASCII table
    _ = properties;
    printIndented(ctx, "(table)", .{});
}

/// console.debug(data...)
///
/// WHATWG Console Standard: Logger("debug", data)
pub fn call_debug(ctx: runtime.Context, data: []const runtime.ConsoleValue) void {
    printConsoleValues(ctx, data);
}

/// console.dir(item, options)
///
/// WHATWG Console Standard: Display object properties
pub fn call_dir(ctx: runtime.Context, item: *const anyopaque, options: *const anyopaque) void {
    _ = item; // TODO: Inspect object properties
    _ = options;
    printIndented(ctx, "(dir)", .{});
}

/// console.dirxml(data...)
///
/// WHATWG Console Standard: Display XML/HTML representation
pub fn call_dirxml(ctx: runtime.Context, data: []const *const anyopaque) void {
    _ = data; // TODO: Format as XML/HTML
    printIndented(ctx, "(dirxml)", .{});
}

/// console.countReset(label)
///
/// WHATWG Console Standard: Reset count for label
pub fn call_countReset(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();

    if (ctx.console_state.count_map.fetchRemove(label_str)) |entry| {
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        const indent = getIndent(ctx);
        if (indent.len > 0) std.debug.print("{s}", .{indent});
        ctx.logger.warn("Count for '{s}' does not exist", .{label_str}) catch {};
    }
}
