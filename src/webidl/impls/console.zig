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
//! ### Formatting and printing
//! The Standard's Formatter and Printer are the console module's
//! (src/console/printer.zig), shared with the browser console
//! (tools/repl.zig), so a value prints the same from console.log and as a
//! console result. What a call prints is formatted first and written to
//! stderr after, so no script (a getter the Printer reads) runs while stderr
//! is locked.
//!
//! ### Indentation
//! Group operations (group, groupCollapsed, groupEnd) manage indent level via group_stack.
//! Each log operation respects the current indent level.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const clock = @import("clock");
const printer = @import("console").printer;

/// The group stack's size: how many levels a message is indented.
fn groupDepth(ctx: runtime.Context) usize {
    return ctx.console_state.getIndentLevel();
}

/// Write `bytes` to stderr, the console namespace's output.
fn writeOut(bytes: []const u8) void {
    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    stderr.file_writer.interface.writeAll(bytes) catch {};
}

/// Print a message of the console's own (a count, a timer's warning), at
/// the group's indentation. Straight to stderr, allocating nothing: it runs
/// no script, so nothing waits on the lock, and count() and time() on an
/// existing label allocate nothing even under memory pressure
/// (tests/v8/console_state_operations_test.zig).
fn printIndented(ctx: runtime.Context, comptime fmt: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    const out = &stderr.file_writer.interface;
    out.splatByteAll(' ', groupDepth(ctx) * 2) catch return;
    out.print(fmt ++ "\n", args) catch return;
}

/// Logger(logLevel, data) (Console 2.1): Formatter, then Printer.
fn printConsoleValues(ctx: runtime.Context, data: []const runtime.JSValue) void {
    var line: std.Io.Writer.Allocating = .init(ctx.allocator);
    defer line.deinit();
    printer.printLogged(ctx.allocator, ctx, data, groupDepth(ctx), &line.writer) catch return;
    writeOut(line.written());
}

/// Printer(logLevel, data) (Console 2.3) alone, without the Formatter.
fn printValuesOnly(ctx: runtime.Context, data: []const runtime.JSValue) void {
    var line: std.Io.Writer.Allocating = .init(ctx.allocator);
    defer line.deinit();
    printer.printValues(ctx.allocator, ctx, data, groupDepth(ctx), &line.writer) catch return;
    writeOut(line.written());
}

/// `text` as a string argument, borrowed.
fn stringArgument(text: []const u8) runtime.JSValue {
    return .{ .string = .{ .data = text, .owned = false } };
}

/// console.log(data...)
///
/// WHATWG Console Standard: Logger("log", data)
pub fn call_log(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}

/// console.info(data...)
///
/// WHATWG Console Standard: Logger("info", data)
pub fn call_info(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}

/// console.debug(data...)
///
/// WHATWG Console Standard: Logger("debug", data)
pub fn call_debug(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}

/// console.warn(data...)
///
/// WHATWG Console Standard: Logger("warn", data)
pub fn call_warn(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}

/// console.error(data...)
///
/// WHATWG Console Standard: Logger("error", data)
pub fn call_error(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}

/// console.trace(data...)
///
/// WHATWG Console Standard: Log with stack trace
pub fn call_trace(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    if (data.len > 0) {
        printConsoleValues(ctx, data);
    } else {
        printIndented(ctx, "Trace", .{});
    }
    // TODO: Stack trace generation requires debug info integration
}

/// console.assert(condition, data...)
///
/// WHATWG Console Standard: If !condition, Logger("assert", data)
pub fn call_assert(ctx: runtime.Context, condition: webidl.Opt(bool), data: []const runtime.JSValue) anyerror!void {
    // 1. If condition is true, return.
    const cond = if (condition.wasPassed()) condition.value else false;
    if (cond) return;
    // 2. Let message be a string without any formatting specifiers
    //    indicating generically an assertion failure.
    const message = "Assertion failed";
    // 3. If data is empty, append message to data.
    if (data.len == 0) return printConsoleValues(ctx, &.{stringArgument(message)});
    switch (data[0]) {
        // 4.3. Otherwise (first is a String): let concat be message, ": " and
        //      first; set data[0] to concat.
        .string => |first| {
            const concat = std.mem.concat(ctx.allocator, u8, &.{ message, ": ", first.data }) catch return;
            defer ctx.allocator.free(concat);
            const changed = ctx.allocator.dupe(runtime.JSValue, data) catch return;
            defer ctx.allocator.free(changed);
            changed[0] = stringArgument(concat);
            // 5. Perform Logger("assert", data).
            printConsoleValues(ctx, changed);
        },
        // 4.2. If first is not a String, prepend message to data.
        else => {
            const changed = ctx.allocator.alloc(runtime.JSValue, data.len + 1) catch return;
            defer ctx.allocator.free(changed);
            changed[0] = stringArgument(message);
            @memcpy(changed[1..], data);
            printConsoleValues(ctx, changed);
        },
    }
}

/// console.group(data...)
///
/// WHATWG Console Standard: Push new group onto stack
pub fn call_group(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    // Print group header with data
    if (data.len > 0) {
        printConsoleValues(ctx, data);
    } else {
        printIndented(ctx, "Group", .{});
    }
    // Push new indent level
    ctx.console_state.group_stack.append(ctx.allocator, 0) catch {};
}

/// console.groupCollapsed(data...)
///
/// WHATWG Console Standard: Same as group() but collapsed by default
pub fn call_groupCollapsed(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    // Same implementation as group (collapsed state is UI concern)
    return call_group(ctx, data);
}

/// console.groupEnd()
///
/// WHATWG Console Standard: Pop group from stack
pub fn call_groupEnd(ctx: runtime.Context) anyerror!void {
    if (ctx.console_state.group_stack.items.len > 0) {
        _ = ctx.console_state.group_stack.pop();
    }
}

/// console.time(label)
///
/// WHATWG Console Standard: Start timer with label
pub fn call_time(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    const gop = ctx.console_state.timer_table.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        // Console 1.4.1 step 2: publish a complete, owned timer entry.
        // getOrPut already inserted the borrowed label; undo it on OOM.
        const owned_label = ctx.allocator.dupe(u8, label_str) catch {
            _ = ctx.console_state.timer_table.remove(label_str);
            return;
        };
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = clock.monotonicMillis();
    } else {
        printIndented(ctx, "Timer '{s}' already exists", .{label_str});
    }
}

/// console.timeLog(label, data...)
///
/// WHATWG Console Standard: Log elapsed time for label
pub fn call_timeLog(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), data: []const runtime.JSValue) anyerror!void {
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    if (ctx.console_state.timer_table.get(label_str)) |start_time| {
        // 3. Let duration be the time since startTime.
        const elapsed = clock.monotonicMillis() - start_time;
        // 4. Let concat be label, ": " and duration.
        const concat = std.fmt.allocPrint(ctx.allocator, "{s}: {d}ms", .{ label_str, elapsed }) catch return;
        defer ctx.allocator.free(concat);
        // 5. Prepend concat to data.
        const changed = ctx.allocator.alloc(runtime.JSValue, data.len + 1) catch return;
        defer ctx.allocator.free(changed);
        changed[0] = stringArgument(concat);
        @memcpy(changed[1..], data);
        // 6. Perform Printer("timeLog", data).
        printValuesOnly(ctx, changed);
    } else {
        printIndented(ctx, "Timer '{s}' does not exist", .{label_str});
    }
}

/// console.timeEnd(label)
///
/// WHATWG Console Standard: Log elapsed time and remove timer
pub fn call_timeEnd(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    if (ctx.console_state.timer_table.fetchRemove(label_str)) |entry| {
        const start_time = entry.value;
        const now = clock.monotonicMillis();
        const elapsed = now - start_time;
        printIndented(ctx, "{s}: {d}ms - timer ended", .{ label_str, elapsed });
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        printIndented(ctx, "Timer '{s}' does not exist", .{label_str});
    }
}

/// console.count(label)
///
/// WHATWG Console Standard: Increment and log count for label
pub fn call_count(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    const gop = ctx.console_state.count_map.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        // Console 1.2.1 step 3: publish a complete, owned counter entry.
        // getOrPut already inserted the borrowed label; undo it on OOM.
        const owned_label = ctx.allocator.dupe(u8, label_str) catch {
            _ = ctx.console_state.count_map.remove(label_str);
            return;
        };
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = 1;
    } else {
        gop.value_ptr.* += 1;
    }

    printIndented(ctx, "{s}: {d}", .{ label_str, gop.value_ptr.* });
}

/// console.countReset(label)
///
/// WHATWG Console Standard: Reset count for label
pub fn call_countReset(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    // Console 1.2.2 step 2 retains zero, but Chrome and Firefox remove the
    // entry: V8 v8-console-message.cc:664-670 and Gecko Console.cpp:2440.
    // WebKit InspectorConsoleAgent.cpp:233 retains zero (2026-10-18).
    // Golden rule 2 follows the majority; the spec step dates to 2018.
    if (ctx.console_state.count_map.fetchRemove(label_str)) |entry| {
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        printIndented(ctx, "Count for '{s}' does not exist", .{label_str});
    }
}

/// console.clear()
///
/// WHATWG Console Standard: Clear console (implementation-specific)
pub fn call_clear(ctx: runtime.Context) anyerror!void {
    _ = ctx;
    // Clear is UI concern - no-op in this implementation
}

/// console.table(tabularData, properties)
///
/// WHATWG Console Standard 1.1.7: "Fall back to just logging the argument if
/// it can't be parsed as tabular" - no table is constructed yet, so the
/// argument is logged (Logger("log", « tabularData »)).
pub fn call_table(ctx: runtime.Context, tabularData: webidl.Opt(runtime.JSValue), properties: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = properties;
    printConsoleValues(ctx, &.{if (tabularData.wasPassed()) tabularData.value else runtime.JSValue.jsUndefined});
}

/// console.dir(item, options)
///
/// WHATWG Console Standard 1.1.10: 1. Let object be item with generic
/// JavaScript object formatting applied. 2. Perform Printer("dir",
/// « object », options).
pub fn call_dir(ctx: runtime.Context, item: webidl.Opt(runtime.JSValue), options: webidl.Opt(?runtime.JSValue)) anyerror!void {
    _ = options;
    printValuesOnly(ctx, &.{if (item.wasPassed()) item.value else runtime.JSValue.jsUndefined});
}

/// console.dirxml(data...)
///
/// WHATWG Console Standard 1.1.11: each item as a DOM tree representation
/// where it is a node (the Printer prints a node as its markup), else with
/// optimally useful formatting; then Logger("dirxml", finalList).
pub fn call_dirxml(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    printConsoleValues(ctx, data);
}
