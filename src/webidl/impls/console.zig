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
const developer_console = @import("dom").developer_console;
const Level = developer_console.Level;
const engine = @import("engine");

/// The console call reaches the agent's inspector too (engine section 4.2b
/// [inspector_protocol]; CDP part 1, design 3.4 "Console"): V8's own console
/// `method` with the call's own arguments (engine.inspectorConsoleMessage), so
/// a debugger session with Runtime enabled gets Runtime.consoleAPICalled - its
/// arguments wrapped, its stack and timestamp - as Chrome's does, and a later
/// Runtime.enable the stored message. A second consumer beside the Printer's
/// developer console (dom.developer_console, which takes text). Compiled out
/// where the engine has no inspector protocol (-Dcdp=false, JavaScriptCore);
/// one lookup for an agent with no inspector.
fn toInspector(ctx: runtime.Context, comptime method: []const u8, args: []const runtime.JSValue) void {
    if (engine.capabilities.inspector_protocol != .unsupported) engine.inspectorConsoleMessage(ctx, method, args);
}

/// A label argument for the inspector: the one passed, or none (V8's console
/// then uses "default", as the Standard does).
fn labelArguments(label: webidl.Opt(runtime.DOMString), buffer: *[1]runtime.JSValue) []const runtime.JSValue {
    if (!label.wasPassed()) return &.{};
    buffer[0] = stringArgument(label.value.asSlice());
    return buffer[0..1];
}

/// The group stack's size: how many levels a message is indented.
fn groupDepth(ctx: runtime.Context) usize {
    return ctx.console_state.getIndentLevel();
}

/// Write `bytes`, what the Printer printed for `level`, to the realm's
/// Browser's developer console when its host shows one
/// (dom.developer_console: the browser console), else to stderr, the console
/// namespace's output.
fn writeOut(ctx: runtime.Context, level: Level, bytes: []const u8, data: []const runtime.JSValue) void {
    if (reportToDeveloperConsole(ctx, level, bytes, data)) return;
    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    stderr.file_writer.interface.writeAll(bytes) catch {};
}

/// `bytes` (lines, each ending in a newline) reported to the realm's
/// Browser's developer console, without the last newline: whether one took
/// it.
fn reportToDeveloperConsole(ctx: runtime.Context, level: Level, bytes: []const u8, data: []const runtime.JSValue) bool {
    const text = if (std.mem.endsWith(u8, bytes, "\n")) bytes[0 .. bytes.len - 1] else bytes;
    return developer_console.report(&.{ .realm = ctx, .kind = .console, .level = level, .text = text, .args = data });
}

/// Print a message of the console's own (a count, a timer's warning), at
/// the group's indentation. Straight to stderr, allocating nothing: it runs
/// no script, so nothing waits on the lock, and count() and time() on an
/// existing label allocate nothing even under memory pressure
/// (tests/v8/console_state_operations_test.zig). With a developer console
/// attached it goes there instead, formatted first - into a buffer on the
/// stack, or, for a longer message, the realm's allocator.
fn printIndented(ctx: runtime.Context, level: Level, comptime fmt: []const u8, args: anytype) void {
    if (developer_console.isAttached(ctx)) {
        var buffer: [512]u8 = undefined;
        var fixed = std.Io.Writer.fixed(&buffer);
        if (writeIndentedMessage(&fixed, groupDepth(ctx), fmt, args)) {
            if (reportToDeveloperConsole(ctx, level, fixed.buffered(), &.{})) return;
        } else |_| {
            var line: std.Io.Writer.Allocating = .init(ctx.allocator);
            defer line.deinit();
            writeIndentedMessage(&line.writer, groupDepth(ctx), fmt, args) catch return;
            if (reportToDeveloperConsole(ctx, level, line.written(), &.{})) return;
        }
    }
    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    writeIndentedMessage(&stderr.file_writer.interface, groupDepth(ctx), fmt, args) catch return;
}

fn writeIndentedMessage(out: *std.Io.Writer, depth: usize, comptime fmt: []const u8, args: anytype) std.Io.Writer.Error!void {
    try out.splatByteAll(' ', depth * 2);
    try out.print(fmt ++ "\n", args);
}

/// Logger(logLevel, data) (Console 2.1): Formatter, then Printer.
fn printConsoleValues(ctx: runtime.Context, level: Level, data: []const runtime.JSValue) void {
    var line: std.Io.Writer.Allocating = .init(ctx.allocator);
    defer line.deinit();
    printer.printLogged(ctx.allocator, ctx, data, groupDepth(ctx), &line.writer) catch return;
    writeOut(ctx, level, line.written(), data);
}

/// Printer(logLevel, data) (Console 2.3) alone, without the Formatter.
fn printValuesOnly(ctx: runtime.Context, level: Level, data: []const runtime.JSValue) void {
    var line: std.Io.Writer.Allocating = .init(ctx.allocator);
    defer line.deinit();
    printer.printValues(ctx.allocator, ctx, data, groupDepth(ctx), &line.writer) catch return;
    writeOut(ctx, level, line.written(), data);
}

/// `text` as a string argument, borrowed.
fn stringArgument(text: []const u8) runtime.JSValue {
    return .{ .string = .{ .data = text, .owned = false } };
}

/// console.log(data...)
///
/// WHATWG Console Standard: Logger("log", data)
pub fn call_log(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "log", data);
    printConsoleValues(ctx, .log, data);
}

/// console.info(data...)
///
/// WHATWG Console Standard: Logger("info", data)
pub fn call_info(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "info", data);
    printConsoleValues(ctx, .info, data);
}

/// console.debug(data...)
///
/// WHATWG Console Standard: Logger("debug", data)
pub fn call_debug(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "debug", data);
    printConsoleValues(ctx, .debug, data);
}

/// console.warn(data...)
///
/// WHATWG Console Standard: Logger("warn", data)
pub fn call_warn(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "warn", data);
    printConsoleValues(ctx, .warn, data);
}

/// console.error(data...)
///
/// WHATWG Console Standard: Logger("error", data)
pub fn call_error(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "error", data);
    printConsoleValues(ctx, .@"error", data);
}

/// console.trace(data...)
///
/// WHATWG Console Standard: Log with stack trace
pub fn call_trace(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "trace", data);
    if (data.len > 0) {
        printConsoleValues(ctx, .trace, data);
    } else {
        printIndented(ctx, .trace, "Trace", .{});
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
    // V8's console.assert(false, ...data): its own "Assertion failed" message.
    {
        const changed = ctx.allocator.alloc(runtime.JSValue, data.len + 1) catch null;
        defer if (changed) |c| ctx.allocator.free(c);
        if (changed) |c| {
            c[0] = .{ .boolean = false };
            @memcpy(c[1..], data);
            toInspector(ctx, "assert", c);
        }
    }
    // 2. Let message be a string without any formatting specifiers
    //    indicating generically an assertion failure.
    const message = "Assertion failed";
    // 3. If data is empty, append message to data.
    if (data.len == 0) return printConsoleValues(ctx, .assert, &.{stringArgument(message)});
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
            printConsoleValues(ctx, .assert, changed);
        },
        // 4.2. If first is not a String, prepend message to data.
        else => {
            const changed = ctx.allocator.alloc(runtime.JSValue, data.len + 1) catch return;
            defer ctx.allocator.free(changed);
            changed[0] = stringArgument(message);
            @memcpy(changed[1..], data);
            printConsoleValues(ctx, .assert, changed);
        },
    }
}

/// console.group(data...)
///
/// WHATWG Console Standard: Push new group onto stack
pub fn call_group(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "group", data);
    // Print group header with data
    if (data.len > 0) {
        printConsoleValues(ctx, .group, data);
    } else {
        printIndented(ctx, .group, "Group", .{});
    }
    // Push new indent level
    ctx.console_state.group_stack.append(ctx.allocator, 0) catch {};
}

/// console.groupCollapsed(data...)
///
/// WHATWG Console Standard: Same as group() but collapsed by default
pub fn call_groupCollapsed(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    // Same implementation as group (collapsed state is UI concern) - but the
    // inspector is told it was collapsed (CDP's startGroupCollapsed).
    toInspector(ctx, "groupCollapsed", data);
    if (data.len > 0) {
        printConsoleValues(ctx, .group, data);
    } else {
        printIndented(ctx, .group, "Group", .{});
    }
    ctx.console_state.group_stack.append(ctx.allocator, 0) catch {};
}

/// console.groupEnd()
///
/// WHATWG Console Standard: Pop group from stack
pub fn call_groupEnd(ctx: runtime.Context) anyerror!void {
    toInspector(ctx, "groupEnd", &.{});
    if (ctx.console_state.group_stack.items.len > 0) {
        _ = ctx.console_state.group_stack.pop();
    }
}

/// console.time(label)
///
/// WHATWG Console Standard: Start timer with label
pub fn call_time(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    var label_argument: [1]runtime.JSValue = undefined;
    toInspector(ctx, "time", labelArguments(label, &label_argument));
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
        printIndented(ctx, .warn, "Timer '{s}' already exists", .{label_str});
    }
}

/// console.timeLog(label, data...)
///
/// WHATWG Console Standard: Log elapsed time for label
pub fn call_timeLog(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), data: []const runtime.JSValue) anyerror!void {
    {
        const changed = ctx.allocator.alloc(runtime.JSValue, data.len + 1) catch null;
        defer if (changed) |c| ctx.allocator.free(c);
        if (changed) |c| {
            c[0] = if (label.wasPassed()) stringArgument(label.value.asSlice()) else stringArgument("default");
            @memcpy(c[1..], data);
            toInspector(ctx, "timeLog", c);
        }
    }
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
        printValuesOnly(ctx, .timeLog, changed);
    } else {
        printIndented(ctx, .warn, "Timer '{s}' does not exist", .{label_str});
    }
}

/// console.timeEnd(label)
///
/// WHATWG Console Standard: Log elapsed time and remove timer
pub fn call_timeEnd(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    var label_argument: [1]runtime.JSValue = undefined;
    toInspector(ctx, "timeEnd", labelArguments(label, &label_argument));
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    if (ctx.console_state.timer_table.fetchRemove(label_str)) |entry| {
        const start_time = entry.value;
        const now = clock.monotonicMillis();
        const elapsed = now - start_time;
        printIndented(ctx, .timeEnd, "{s}: {d}ms - timer ended", .{ label_str, elapsed });
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        printIndented(ctx, .warn, "Timer '{s}' does not exist", .{label_str});
    }
}

/// console.count(label)
///
/// WHATWG Console Standard: Increment and log count for label
pub fn call_count(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    var label_argument: [1]runtime.JSValue = undefined;
    toInspector(ctx, "count", labelArguments(label, &label_argument));
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

    printIndented(ctx, .count, "{s}: {d}", .{ label_str, gop.value_ptr.* });
}

/// console.countReset(label)
///
/// WHATWG Console Standard: Reset count for label
pub fn call_countReset(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) anyerror!void {
    var label_argument: [1]runtime.JSValue = undefined;
    toInspector(ctx, "countReset", labelArguments(label, &label_argument));
    const label_str = if (label.wasPassed()) label.value.asSlice() else "default";

    // Console 1.2.2 step 2 retains zero, but Chrome and Firefox remove the
    // entry: V8 v8-console-message.cc:664-670 and Gecko Console.cpp:2440.
    // WebKit InspectorConsoleAgent.cpp:233 retains zero (2026-10-18).
    // Golden rule 2 follows the majority; the spec step dates to 2018.
    if (ctx.console_state.count_map.fetchRemove(label_str)) |entry| {
        ctx.allocator.free(entry.key); // Free the owned label string
    } else {
        printIndented(ctx, .warn, "Count for '{s}' does not exist", .{label_str});
    }
}

/// console.clear()
///
/// WHATWG Console Standard: Clear console (implementation-specific)
pub fn call_clear(ctx: runtime.Context) anyerror!void {
    toInspector(ctx, "clear", &.{});
    // Clear is UI concern - no-op in this implementation
}

/// console.table(tabularData, properties)
///
/// WHATWG Console Standard 1.1.7: "Fall back to just logging the argument if
/// it can't be parsed as tabular" - no table is constructed yet, so the
/// argument is logged (Logger("log", « tabularData »)).
pub fn call_table(ctx: runtime.Context, tabularData: webidl.Opt(runtime.JSValue), properties: webidl.Opt(runtime.JSValue)) anyerror!void {
    if (tabularData.wasPassed() and properties.wasPassed()) {
        toInspector(ctx, "table", &.{ tabularData.value, properties.value });
    } else if (tabularData.wasPassed()) {
        toInspector(ctx, "table", &.{tabularData.value});
    } else toInspector(ctx, "table", &.{});
    printConsoleValues(ctx, .table, &.{if (tabularData.wasPassed()) tabularData.value else runtime.JSValue.jsUndefined});
}

/// console.dir(item, options)
///
/// WHATWG Console Standard 1.1.10: 1. Let object be item with generic
/// JavaScript object formatting applied. 2. Perform Printer("dir",
/// « object », options).
pub fn call_dir(ctx: runtime.Context, item: webidl.Opt(runtime.JSValue), options: webidl.Opt(?runtime.JSValue)) anyerror!void {
    _ = options;
    if (item.wasPassed()) toInspector(ctx, "dir", &.{item.value}) else toInspector(ctx, "dir", &.{});
    printValuesOnly(ctx, .dir, &.{if (item.wasPassed()) item.value else runtime.JSValue.jsUndefined});
}

/// console.dirxml(data...)
///
/// WHATWG Console Standard 1.1.11: each item as a DOM tree representation
/// where it is a node (the Printer prints a node as its markup), else with
/// optimally useful formatting; then Logger("dirxml", finalList).
pub fn call_dirxml(ctx: runtime.Context, data: []const runtime.JSValue) anyerror!void {
    toInspector(ctx, "dirxml", data);
    printConsoleValues(ctx, .dirxml, data);
}
