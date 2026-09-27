//! JavaScript REPL - Headless Browser
//!
//! Interactive Read-Eval-Print Loop using the Browser API.
//! This ensures the REPL has identical behavior to a browser environment:
//! - Full browser globals (window, document, navigator, etc.)
//! - Correct prototype chains (Window.prototype → WindowProperties → EventTarget.prototype)
//! - Timer support (setTimeout, setInterval)
//! - Console API
//! - Tab completion
//! - Multi-line input support
//! - History support

const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");

// Import Browser from the browser module
const Browser = @import("browser").Browser;
const Context = @import("browser").Context;

/// REPL state - wraps Browser with REPL-specific UI features
const Repl = struct {
    allocator: std.mem.Allocator,
    /// The process `std.Io`. Zig 0.16 moved stdio, tty queries and sleeping onto
    /// `Io`, so the REPL carries one rather than reaching for a global.
    io: std.Io,
    browser: *Browser,
    input_buffer: std.ArrayListUnmanaged(u8),
    history: std.ArrayListUnmanaged([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Self {
        // Create browser with default config
        const browser = try Browser.init(allocator, .{});
        errdefer browser.deinit();

        // Navigate to a blank page to create a window context
        try browser.navigate("about:blank", .window);

        return Self{
            .allocator = allocator,
            .io = io,
            .browser = browser,
            // 0.16: ArrayList has no default field values; `.empty` replaces `.{}`.
            .input_buffer = .empty,
            .history = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        // Cleanup history
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit(self.allocator);
        self.input_buffer.deinit(self.allocator);

        // Browser handles all V8 and runtime cleanup - including destroying itself
        // (Browser.zig:352). Destroying it here as well was a double free; it never
        // fired only because the REPL exits the process before this path runs.
        self.browser.deinit();
    }

    /// The page's realm: the browser's current context's.
    fn getRealm(self: *Self) runtime.Context {
        return self.browser.current_context.?.realm.?;
    }

    /// The page's global object, as a value.
    fn getGlobal(self: *Self) runtime.JSValue {
        return .{ .instance = self.browser.current_context.?.window_instance.? };
    }

    /// Execute JavaScript code and return result
    /// Supports top-level await by wrapping code in an async IIFE
    pub fn eval(self: *Self, code: []const u8) ![]const u8 {
        const realm = self.getRealm();

        // Check if code contains 'await' - if so, wrap in async IIFE
        const needs_async_wrap = std.mem.indexOf(u8, code, "await") != null;

        var wrapped_code: []u8 = undefined;
        var source_to_use: []const u8 = undefined;

        if (needs_async_wrap) {
            // Wrap in async IIFE: (async () => { ... })()
            // Handle variable declarations specially to persist to global scope
            const trimmed = std.mem.trim(u8, code, &std.ascii.whitespace);

            // Check for variable declarations with await - these need special handling
            // to persist the variable to the global scope
            const is_const_decl = std.mem.startsWith(u8, trimmed, "const ");
            const is_let_decl = std.mem.startsWith(u8, trimmed, "let ");
            const is_var_decl = std.mem.startsWith(u8, trimmed, "var ");

            if (is_const_decl or is_let_decl or is_var_decl) {
                // Transform: "const x = await ..." -> "globalThis.x = await ...; x"
                // Find the variable name (after const/let/var and before =)
                const decl_len: usize = if (is_const_decl) 6 else if (is_let_decl) 4 else 4;
                const after_keyword = std.mem.trim(u8, trimmed[decl_len..], &std.ascii.whitespace);

                // Find the = sign
                if (std.mem.indexOf(u8, after_keyword, "=")) |eq_pos| {
                    const var_name = std.mem.trim(u8, after_keyword[0..eq_pos], &std.ascii.whitespace);
                    const value_expr = std.mem.trim(u8, after_keyword[eq_pos + 1 ..], &std.ascii.whitespace);

                    // Remove trailing semicolon from value if present
                    const clean_value = if (std.mem.endsWith(u8, value_expr, ";"))
                        value_expr[0 .. value_expr.len - 1]
                    else
                        value_expr;

                    wrapped_code = try std.fmt.allocPrint(
                        self.allocator,
                        "(async () => {{ globalThis.{s} = {s}; return {s}; }})()",
                        .{ var_name, clean_value, var_name },
                    );
                } else {
                    // No = sign, just wrap as statement
                    wrapped_code = try std.fmt.allocPrint(self.allocator, "(async () => {{ {s} }})()", .{code});
                }
            } else if (!std.mem.startsWith(u8, trimmed, "function ") and
                !std.mem.startsWith(u8, trimmed, "class ") and
                !std.mem.startsWith(u8, trimmed, "if ") and
                !std.mem.startsWith(u8, trimmed, "for ") and
                !std.mem.startsWith(u8, trimmed, "while ") and
                !std.mem.startsWith(u8, trimmed, "switch ") and
                !std.mem.startsWith(u8, trimmed, "try ") and
                !std.mem.startsWith(u8, trimmed, "{"))
            {
                // Expression - wrap with return
                wrapped_code = try std.fmt.allocPrint(self.allocator, "(async () => {{ return {s}; }})()", .{code});
            } else {
                // Statement(s) - wrap without return
                wrapped_code = try std.fmt.allocPrint(self.allocator, "(async () => {{ {s} }})()", .{code});
            }
            source_to_use = wrapped_code;
        } else {
            source_to_use = code;
        }
        defer if (needs_async_wrap) self.allocator.free(wrapped_code);

        // Evaluate it. What it throws is the answer: its message, as the
        // console would print it.
        var thrown = Thrown{ .allocator = self.allocator };
        defer thrown.deinit();
        const completion = engine.evaluateClassicScript(realm, .{ .utf8 = source_to_use }, "", null, thrown.reporter()) catch |err| switch (err) {
            error.ExceptionReported => return thrown.take() orelse try self.allocator.dupe(u8, "Uncaught exception"),
            else => return err,
        };
        defer completion.release();

        // The value, where the formatter reads it.
        try engine.setProperty(realm, self.getGlobal(), "__repl_value__", completion.value);
        defer self.runQuietly("delete globalThis.__repl_value__; delete globalThis.__repl_state__;");

        // A promise - an async IIFE's - is waited for: its settled value, or
        // the reason it was rejected, is what is shown.
        if (self.evaluatesTo("globalThis.__repl_value__ instanceof Promise", "true")) {
            self.runQuietly(
                \\globalThis.__repl_state__ = 'pending';
                \\globalThis.__repl_value__.then(
                \\  (v) => { globalThis.__repl_value__ = v; globalThis.__repl_state__ = 'fulfilled'; },
                \\  (e) => { globalThis.__repl_value__ = e; globalThis.__repl_state__ = 'rejected'; });
            );
            var iterations: u32 = 0;
            const max_iterations: u32 = 10000; // Prevent infinite loops
            while (self.evaluatesTo("globalThis.__repl_state__", "pending") and iterations < max_iterations) : (iterations += 1) {
                engine.performMicrotaskCheckpoint(realm) catch {};
                // Small delay to prevent busy-waiting
                if (iterations > 100) {
                    // Swallow cancellation so the poll loop stays infallible.
                    self.io.sleep(.fromNanoseconds(1_000_000), .awake) catch {}; // 1ms
                }
            }
            if (self.evaluatesTo("globalThis.__repl_state__", "pending")) {
                return try self.allocator.dupe(u8, "Promise { <pending> } (timeout)");
            }
            if (self.evaluatesTo("globalThis.__repl_state__", "rejected")) {
                return self.evaluateToString("String(globalThis.__repl_value__)") catch try self.allocator.dupe(u8, "Promise rejected");
            }
        }

        // Format the result for display
        return self.evaluateToString(format_code) catch try self.allocator.dupe(u8, "[object]");
    }

    /// The REPL's view of a value (like Chrome DevTools): a string quoted, a
    /// function its source, an array its first elements, an Error its name
    /// and message, an object its constructor and first properties.
    const format_code =
        \\(function() {
        \\  const obj = globalThis.__repl_value__;
        \\  if (obj === null) return 'null';
        \\  if (obj === undefined) return 'undefined';
        \\  if (typeof obj === 'string') return "'" + obj + "'";
        \\  if (typeof obj !== 'object') return String(obj);
        \\
        \\  let name = '';
        \\  if (obj.constructor && obj.constructor.name) {
        \\    name = obj.constructor.name;
        \\  } else if (Object.prototype.toString.call(obj) === '[object Object]') {
        \\    name = 'Object';
        \\  }
        \\
        \\  if (Array.isArray(obj)) {
        \\    if (obj.length === 0) return '[]';
        \\    if (obj.length > 5) {
        \\      return '[' + obj.slice(0,5).map(v => typeof v === 'string' ? JSON.stringify(v) : String(v)).join(', ') + ', ...]';
        \\    }
        \\    return '[' + obj.map(v => typeof v === 'string' ? JSON.stringify(v) : String(v)).join(', ') + ']';
        \\  }
        \\
        \\  if (obj instanceof Error) {
        \\    return obj.name + ': ' + obj.message;
        \\  }
        \\
        \\  if (obj instanceof Promise) {
        \\    return 'Promise { <pending> }';
        \\  }
        \\
        \\  const props = [];
        \\  const keys = Object.keys(obj);
        \\  const maxProps = 5;
        \\
        \\  for (let i = 0; i < Math.min(keys.length, maxProps); i++) {
        \\    const key = keys[i];
        \\    try {
        \\      const val = obj[key];
        \\      let valStr;
        \\      if (val === null) valStr = 'null';
        \\      else if (val === undefined) valStr = 'undefined';
        \\      else if (typeof val === 'string') valStr = JSON.stringify(val);
        \\      else if (typeof val === 'function') valStr = '[Function]';
        \\      else if (typeof val === 'object') valStr = val.constructor ? val.constructor.name : '[object]';
        \\      else valStr = String(val);
        \\      props.push(key + ': ' + valStr);
        \\    } catch(e) {
        \\      props.push(key + ': [error]');
        \\    }
        \\  }
        \\
        \\  if (keys.length > maxProps) {
        \\    props.push('...');
        \\  }
        \\
        \\  if (props.length === 0) {
        \\    return name + ' {}';
        \\  }
        \\
        \\  return name + ' {' + props.join(', ') + '}';
        \\})()
    ;

    /// What a script threw, as the engine reported it: its message, copied.
    const Thrown = struct {
        allocator: std.mem.Allocator,
        message: ?[]u8 = null,

        fn reporter(self: *Thrown) engine.Reporter {
            return .{ .report = report, .host = self };
        }

        fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
            const self: *Thrown = @ptrCast(@alignCast(host.?));
            if (self.message != null) return;
            self.message = self.allocator.dupe(u8, info.message) catch null;
        }

        fn take(self: *Thrown) ?[]u8 {
            const message = self.message;
            self.message = null;
            return message;
        }

        fn deinit(self: *Thrown) void {
            if (self.message) |m| self.allocator.free(m);
        }
    };

    /// Run the REPL's own script for its effects; what it throws is dropped.
    fn runQuietly(self: *Self, source: []const u8) void {
        var thrown = Thrown{ .allocator = self.allocator };
        defer thrown.deinit();
        engine.runClassicScript(self.getRealm(), .{ .utf8 = source }, "", null, thrown.reporter()) catch {};
    }

    /// The REPL's own script's completion value, ToString'd.
    fn evaluateToString(self: *Self, source: []const u8) ![]u8 {
        var thrown = Thrown{ .allocator = self.allocator };
        defer thrown.deinit();
        return engine.evaluateClassicScriptToString(self.getRealm(), .{ .utf8 = source }, "", null, self.allocator, thrown.reporter());
    }

    /// Whether the REPL's own `source` evaluates to the string `expected`.
    fn evaluatesTo(self: *Self, source: []const u8, expected: []const u8) bool {
        const got = self.evaluateToString(source) catch return false;
        defer self.allocator.free(got);
        return std.mem.eql(u8, got, expected);
    }

    /// Get completions for tab completion
    pub fn getCompletions(self: *Self, input: []const u8) !struct { completions: [][]const u8, prefix_len: usize } {
        var completions = std.ArrayList([]const u8).empty;
        errdefer {
            for (completions.items) |item| {
                self.allocator.free(item);
            }
            completions.deinit(self.allocator);
        }

        // Complete on an object's properties after a dot, else on the globals.
        const dot = std.mem.lastIndexOfScalar(u8, input, '.');
        const object_expression = if (dot) |d| input[0..d] else "globalThis";
        const prefix = if (dot) |d| input[d + 1 ..] else input;
        if (object_expression.len > 0) try self.getPropertyNames(object_expression, prefix, &completions);

        return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = prefix.len };
    }

    /// The enumerable property names of `object_expression`'s value, along its
    /// prototype chain, that start with `prefix`.
    fn getPropertyNames(self: *Self, object_expression: []const u8, prefix: []const u8, completions: *std.ArrayList([]const u8)) !void {
        const source = try std.fmt.allocPrint(self.allocator,
            \\(() => {{
            \\  const o = ({s});
            \\  if (o === null || (typeof o !== 'object' && typeof o !== 'function')) return '';
            \\  const names = [];
            \\  for (const k in o) names.push(k);
            \\  return names.join('\n');
            \\}})()
        , .{object_expression});
        defer self.allocator.free(source);
        const names = self.evaluateToString(source) catch return;
        defer self.allocator.free(names);

        var it = std.mem.splitScalar(u8, names, '\n');
        while (it.next()) |name| {
            if (name.len == 0) continue;
            if (prefix.len == 0 or std.mem.startsWith(u8, name, prefix)) {
                try completions.append(self.allocator, try self.allocator.dupe(u8, name));
            }
        }
    }

    /// Add line to history
    fn addHistory(self: *Self, line: []const u8) !void {
        // Don't add empty lines or duplicates of the last entry
        if (line.len == 0) return;
        if (self.history.items.len > 0 and std.mem.eql(u8, self.history.items[self.history.items.len - 1], line)) return;

        const dup = try self.allocator.dupe(u8, line);
        try self.history.append(self.allocator, dup);
    }

    /// Check if JavaScript code is syntactically complete
    fn isCompleteCode(_: *Self, code: []const u8) bool {
        if (code.len == 0) return true;

        var brace_count: i32 = 0;
        var bracket_count: i32 = 0;
        var paren_count: i32 = 0;

        var in_string: u8 = 0;
        var in_template: bool = false;
        var in_line_comment: bool = false;
        var in_block_comment: bool = false;
        var escape_next: bool = false;
        var prev_char: u8 = 0;

        for (code) |c| {
            if (c == '\n') {
                in_line_comment = false;
                prev_char = c;
                continue;
            }

            if (in_line_comment) {
                prev_char = c;
                continue;
            }

            if (in_block_comment) {
                if (prev_char == '*' and c == '/') {
                    in_block_comment = false;
                }
                prev_char = c;
                continue;
            }

            if (escape_next) {
                escape_next = false;
                prev_char = c;
                continue;
            }

            if (c == '\\' and (in_string != 0 or in_template)) {
                escape_next = true;
                prev_char = c;
                continue;
            }

            if (in_string != 0) {
                if (c == in_string) {
                    in_string = 0;
                }
                prev_char = c;
                continue;
            }

            if (in_template) {
                if (c == '`') {
                    in_template = false;
                }
                prev_char = c;
                continue;
            }

            if (prev_char == '/') {
                if (c == '/') {
                    in_line_comment = true;
                    prev_char = c;
                    continue;
                } else if (c == '*') {
                    in_block_comment = true;
                    prev_char = c;
                    continue;
                }
            }

            if (c == '"' or c == '\'') {
                in_string = c;
                prev_char = c;
                continue;
            }
            if (c == '`') {
                in_template = true;
                prev_char = c;
                continue;
            }

            if (c != '/') {
                switch (c) {
                    '{' => brace_count += 1,
                    '}' => brace_count -= 1,
                    '[' => bracket_count += 1,
                    ']' => bracket_count -= 1,
                    '(' => paren_count += 1,
                    ')' => paren_count -= 1,
                    else => {},
                }
            }

            prev_char = c;
        }

        if (in_string != 0 or in_template) return false;
        if (in_block_comment) return false;
        if (brace_count > 0 or bracket_count > 0 or paren_count > 0) return false;

        return true;
    }

    /// Read a single byte from stdin
    fn readByte(io: std.Io, stdin: std.Io.File) !u8 {
        var buf: [1]u8 = undefined;
        // 0.16: File.read became File.readStreaming, which takes an Io and a
        // vector of buffers. End-of-stream is now error.EndOfStream, which `try`
        // propagates - the same error the 0 case returned before.
        const n = try stdin.readStreaming(io, &.{&buf});
        if (n == 0) return error.EndOfStream;
        return buf[0];
    }

    /// Write a single byte to file
    fn writeByte(io: std.Io, file: std.Io.File, byte: u8) !void {
        const buf = [_]u8{byte};
        try file.writeStreamingAll(io, &buf);
    }

    /// Print formatted output to file
    fn print(allocator: std.mem.Allocator, io: std.Io, file: std.Io.File, comptime format: []const u8, args: anytype) !void {
        const str = try std.fmt.allocPrint(allocator, format, args);
        defer allocator.free(str);
        try file.writeStreamingAll(io, str);
    }

    /// Clear current line and redraw with new content, cursor at end
    fn clearAndRedraw(self: *Self, stdout: std.Io.File, new_content: []const u8, cursor_pos: *usize) !void {
        const current_len = self.input_buffer.items.len;
        // Move cursor to start of input
        if (cursor_pos.* > 0) {
            try print(self.allocator, self.io, stdout, "\x1b[{d}D", .{cursor_pos.*});
        }
        // Clear from cursor to end of line
        try stdout.writeStreamingAll(self.io, "\x1b[K");
        // Update buffer
        self.input_buffer.clearRetainingCapacity();
        try self.input_buffer.appendSlice(self.allocator, new_content);
        // Write new content
        try stdout.writeStreamingAll(self.io, new_content);
        // Set cursor to end
        cursor_pos.* = new_content.len;
        _ = current_len;
    }

    /// Redraw the line from cursor position to end, then restore cursor
    fn redrawFromCursor(self: *Self, stdout: std.Io.File, cursor_pos: usize) !void {
        // Save cursor, clear to end, write rest of buffer, restore cursor
        const rest = self.input_buffer.items[cursor_pos..];
        try stdout.writeStreamingAll(self.io, rest);
        try stdout.writeStreamingAll(self.io, " "); // Clear any leftover character
        // Move back to cursor position
        const move_back = rest.len + 1;
        if (move_back > 0) {
            try print(self.allocator, self.io, stdout, "\x1b[{d}D", .{move_back});
        }
    }

    /// Read line with tab completion, history navigation, and cursor movement
    pub fn readLine(self: *Self) !?[]const u8 {
        const stdout = std.Io.File.stdout();
        const stdin = std.Io.File.stdin();

        var original_termios: std.posix.termios = undefined;
        // std.posix.isatty was removed in 0.16; File.isTty(io) replaces it.
        const is_tty = try stdin.isTty(self.io);
        if (is_tty) {
            original_termios = try std.posix.tcgetattr(stdin.handle);
            var raw = original_termios;
            raw.lflag.ICANON = false;
            raw.lflag.ECHO = false;
            raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
            raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
            try std.posix.tcsetattr(stdin.handle, .FLUSH, raw);
        }
        defer if (is_tty) {
            std.posix.tcsetattr(stdin.handle, .FLUSH, original_termios) catch {};
        };

        self.input_buffer.clearRetainingCapacity();

        var cursor_pos: usize = 0;
        var history_index: usize = self.history.items.len;
        var saved_input: ?[]u8 = null;
        defer if (saved_input) |s| self.allocator.free(s);

        while (true) {
            const byte = readByte(self.io, stdin) catch |err| {
                if (err == error.EndOfStream) return null;
                return err;
            };

            switch (byte) {
                '\n' => {
                    try writeByte(self.io, stdout, '\n');
                    const result = try self.allocator.dupe(u8, self.input_buffer.items);
                    return result;
                },
                4 => return null, // Ctrl+D
                127, 8 => { // Backspace
                    if (cursor_pos > 0) {
                        // Remove character before cursor
                        _ = self.input_buffer.orderedRemove(cursor_pos - 1);
                        cursor_pos -= 1;
                        // Move cursor back
                        try stdout.writeStreamingAll(self.io, "\x08");
                        // Redraw from cursor position
                        try self.redrawFromCursor(stdout, cursor_pos);
                    }
                },
                1 => { // Ctrl+A - move to beginning
                    if (cursor_pos > 0) {
                        try print(self.allocator, self.io, stdout, "\x1b[{d}D", .{cursor_pos});
                        cursor_pos = 0;
                    }
                },
                5 => { // Ctrl+E - move to end
                    if (cursor_pos < self.input_buffer.items.len) {
                        const move = self.input_buffer.items.len - cursor_pos;
                        try print(self.allocator, self.io, stdout, "\x1b[{d}C", .{move});
                        cursor_pos = self.input_buffer.items.len;
                    }
                },
                21 => { // Ctrl+U - clear line
                    if (self.input_buffer.items.len > 0) {
                        // Move to start
                        if (cursor_pos > 0) {
                            try print(self.allocator, self.io, stdout, "\x1b[{d}D", .{cursor_pos});
                        }
                        // Clear line
                        try stdout.writeStreamingAll(self.io, "\x1b[K");
                        self.input_buffer.clearRetainingCapacity();
                        cursor_pos = 0;
                    }
                },
                11 => { // Ctrl+K - clear from cursor to end
                    if (cursor_pos < self.input_buffer.items.len) {
                        self.input_buffer.shrinkRetainingCapacity(cursor_pos);
                        try stdout.writeStreamingAll(self.io, "\x1b[K");
                    }
                },
                '\t' => { // Tab - trigger completion
                    if (self.input_buffer.items.len > 0) {
                        const result = try self.getCompletions(self.input_buffer.items);
                        defer {
                            for (result.completions) |c| self.allocator.free(c);
                            self.allocator.free(result.completions);
                        }

                        if (result.completions.len == 1) {
                            // Single match - complete it
                            const completion = result.completions[0];
                            const suffix = completion[result.prefix_len..];
                            try self.input_buffer.appendSlice(self.allocator, suffix);
                            try stdout.writeStreamingAll(self.io, suffix);
                            cursor_pos = self.input_buffer.items.len;
                        } else if (result.completions.len > 1) {
                            // Multiple matches - show them
                            try stdout.writeStreamingAll(self.io, "\n");
                            for (result.completions) |c| {
                                try print(self.allocator, self.io, stdout, "{s}  ", .{c});
                            }
                            try stdout.writeStreamingAll(self.io, "\n>>> ");
                            try stdout.writeStreamingAll(self.io, self.input_buffer.items);
                            cursor_pos = self.input_buffer.items.len;
                        }
                    }
                },
                27 => { // Escape sequence
                    const next1 = readByte(self.io, stdin) catch continue;
                    if (next1 != '[') continue;
                    const next2 = readByte(self.io, stdin) catch continue;

                    switch (next2) {
                        'A' => { // Up arrow - history previous
                            if (history_index > 0) {
                                if (history_index == self.history.items.len) {
                                    if (saved_input) |s| self.allocator.free(s);
                                    saved_input = try self.allocator.dupe(u8, self.input_buffer.items);
                                }
                                history_index -= 1;
                                try self.clearAndRedraw(stdout, self.history.items[history_index], &cursor_pos);
                            }
                        },
                        'B' => { // Down arrow - history next
                            if (history_index < self.history.items.len) {
                                history_index += 1;
                                if (history_index == self.history.items.len) {
                                    try self.clearAndRedraw(stdout, saved_input orelse "", &cursor_pos);
                                } else {
                                    try self.clearAndRedraw(stdout, self.history.items[history_index], &cursor_pos);
                                }
                            }
                        },
                        'C' => { // Right arrow - move cursor right
                            if (cursor_pos < self.input_buffer.items.len) {
                                cursor_pos += 1;
                                try stdout.writeStreamingAll(self.io, "\x1b[C");
                            }
                        },
                        'D' => { // Left arrow - move cursor left
                            if (cursor_pos > 0) {
                                cursor_pos -= 1;
                                try stdout.writeStreamingAll(self.io, "\x1b[D");
                            }
                        },
                        'H' => { // Home key
                            if (cursor_pos > 0) {
                                try print(self.allocator, self.io, stdout, "\x1b[{d}D", .{cursor_pos});
                                cursor_pos = 0;
                            }
                        },
                        'F' => { // End key
                            if (cursor_pos < self.input_buffer.items.len) {
                                const move = self.input_buffer.items.len - cursor_pos;
                                try print(self.allocator, self.io, stdout, "\x1b[{d}C", .{move});
                                cursor_pos = self.input_buffer.items.len;
                            }
                        },
                        '3' => { // Delete key (ESC [ 3 ~)
                            const next3 = readByte(self.io, stdin) catch continue;
                            if (next3 == '~') {
                                if (cursor_pos < self.input_buffer.items.len) {
                                    _ = self.input_buffer.orderedRemove(cursor_pos);
                                    try self.redrawFromCursor(stdout, cursor_pos);
                                }
                            }
                        },
                        else => {},
                    }
                },
                else => {
                    if (byte >= 32 and byte < 127) {
                        // Insert character at cursor position
                        if (cursor_pos == self.input_buffer.items.len) {
                            // Append at end (common case)
                            try self.input_buffer.append(self.allocator, byte);
                            try writeByte(self.io, stdout, byte);
                        } else {
                            // Insert in middle
                            try self.input_buffer.insert(self.allocator, cursor_pos, byte);
                            try writeByte(self.io, stdout, byte);
                            try self.redrawFromCursor(stdout, cursor_pos + 1);
                        }
                        cursor_pos += 1;
                    }
                },
            }
        }
    }

    /// Run the REPL loop
    pub fn run(self: *Self) !void {
        const stdout = std.Io.File.stdout();

        try stdout.writeStreamingAll(self.io, "JavaScript REPL - Headless Browser\n");
        try stdout.writeStreamingAll(self.io, "Same environment as WPT tests (window, document, etc.)\n");
        try stdout.writeStreamingAll(self.io, "Type JavaScript code and press Enter\n");
        try stdout.writeStreamingAll(self.io, "Press Tab for completions, Ctrl+D to exit\n\n");

        var multiline_buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer multiline_buffer.deinit(self.allocator);

        while (true) {
            if (multiline_buffer.items.len == 0) {
                try stdout.writeStreamingAll(self.io, ">>> ");
            } else {
                try stdout.writeStreamingAll(self.io, "... ");
            }

            const line = try self.readLine() orelse break;
            defer self.allocator.free(line);

            if (line.len == 0) {
                if (multiline_buffer.items.len == 0) continue;
            } else {
                if (multiline_buffer.items.len > 0) {
                    try multiline_buffer.append(self.allocator, '\n');
                }
                try multiline_buffer.appendSlice(self.allocator, line);
            }

            if (!self.isCompleteCode(multiline_buffer.items)) continue;

            const code = try self.allocator.dupe(u8, multiline_buffer.items);
            defer self.allocator.free(code);

            multiline_buffer.clearRetainingCapacity();

            const trimmed = std.mem.trim(u8, code, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            try self.addHistory(code);

            const result = self.eval(code) catch |err| {
                try print(self.allocator, self.io, stdout, "Error: {}\n", .{err});
                continue;
            };
            defer self.allocator.free(result);

            try print(self.allocator, self.io, stdout, "{s}\n", .{result});
        }

        try stdout.writeStreamingAll(self.io, "\nGoodbye!\n");
    }
};

// Zig 0.16 moved stdio and sleeping onto std.Io; std.process.Init supplies the
// process Io along with a gpa.
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var repl = try Repl.init(allocator, init.io);
    errdefer repl.deinit();

    try repl.run();

    repl.deinit();
}
