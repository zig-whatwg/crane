//! JavaScript REPL - Headless Browser
//!
//! Interactive Read-Eval-Print Loop using the same browser context as WPT tests.
//! This ensures the REPL has identical behavior to the WPT test environment:
//! - Full browser globals (window, document, navigator, etc.)
//! - Correct prototype chains (Window.prototype → WindowProperties → EventTarget.prototype)
//! - Timer support (setTimeout, setInterval)
//! - Console API
//! - Tab completion
//! - Multi-line input support
//! - History support

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

// Import BrowserContext from WPT runner - this is the single source of truth
// for browser initialization, ensuring REPL matches WPT test environment exactly
const BrowserContext = @import("browser_context").BrowserContext;

/// REPL state - wraps BrowserContext with REPL-specific UI features
const Repl = struct {
    allocator: std.mem.Allocator,
    browser: BrowserContext,
    input_buffer: std.ArrayListUnmanaged(u8),
    history: std.ArrayListUnmanaged([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Create browser context with window type (same as WPT .html tests)
        var browser = BrowserContext.init(allocator, .window, ".") catch |err| {
            std.debug.print("Failed to create BrowserContext: {}\n", .{err});
            return err;
        };
        errdefer browser.deinit();

        // Initialize the browser (creates V8 isolate, context, registers all globals)
        browser.initialize() catch |err| {
            std.debug.print("Failed to initialize BrowserContext: {}\n", .{err});
            return err;
        };

        return Self{
            .allocator = allocator,
            .browser = browser,
            .input_buffer = .{},
            .history = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        // Cleanup history
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit(self.allocator);
        self.input_buffer.deinit(self.allocator);

        // BrowserContext handles all V8 and runtime cleanup
        self.browser.deinit();
    }

    /// Get V8 isolate from browser context
    fn getIsolate(self: *Self) *v8.ffi.Isolate {
        return self.browser.isolate.?;
    }

    /// Get V8 context from browser context
    fn getContext(self: *Self) *v8.ffi.Context {
        return self.browser.context.?;
    }

    /// Execute JavaScript code and return result
    pub fn eval(self: *Self, code: []const u8) ![]const u8 {
        const isolate = self.getIsolate();
        const context = self.getContext();

        // Create V8 string from code
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringCreateFailed;

        // Compile script
        const script = v8.ffi.v8_Script_Compile(context, source_str) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    return buffer;
                }
            }
            return error.CompileError;
        };

        // Run script
        const result = v8.ffi.v8_Script_Run(context, script) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    return buffer;
                }
            }
            return error.RuntimeError;
        };

        // Run microtasks to process any pending promises
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        // Format the result for display
        return self.formatValueForDisplay(result);
    }

    /// Format a V8 value for REPL display (like Chrome DevTools)
    fn formatValueForDisplay(self: *Self, value: *v8.ffi.Value) ![]const u8 {
        const context = self.getContext();

        // Handle primitives directly
        if (v8.ffi.v8_Value_IsUndefined(value)) {
            return try self.allocator.dupe(u8, "undefined");
        }
        if (v8.ffi.v8_Value_IsNull(value)) {
            return try self.allocator.dupe(u8, "null");
        }
        if (v8.ffi.v8_Value_IsBoolean(value) or v8.ffi.v8_Value_IsNumber(value)) {
            const str = v8.ffi.v8_Value_ToString(value, context) orelse {
                return try self.allocator.dupe(u8, "undefined");
            };
            const len = v8.ffi.v8_String_Utf8Length(str);
            const buffer = try self.allocator.alloc(u8, @intCast(len));
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
            return buffer;
        }
        if (v8.ffi.v8_Value_IsString(value)) {
            // Wrap strings in quotes for display
            const str: *v8.ffi.String = @ptrCast(value);
            const len = v8.ffi.v8_String_Utf8Length(str);
            // +2 for quotes
            const buffer = try self.allocator.alloc(u8, @intCast(len + 2));
            buffer[0] = '\'';
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr + 1, @intCast(len));
            buffer[@intCast(len + 1)] = '\'';
            return buffer;
        }
        if (v8.ffi.v8_Value_IsFunction(value)) {
            const str = v8.ffi.v8_Value_ToString(value, context) orelse {
                return try self.allocator.dupe(u8, "[Function]");
            };
            const len = v8.ffi.v8_String_Utf8Length(str);
            const buffer = try self.allocator.alloc(u8, @intCast(len));
            _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
            return buffer;
        }

        // For objects (including arrays), use our inspector
        if (v8.ffi.v8_Value_IsObject(value)) {
            return self.formatObjectForDisplay(value);
        }

        // Fallback to toString
        const result_str = v8.ffi.v8_Value_ToString(value, context) orelse {
            return try self.allocator.dupe(u8, "undefined");
        };
        const len = v8.ffi.v8_String_Utf8Length(result_str);
        const buffer = try self.allocator.alloc(u8, @intCast(len));
        _ = v8.ffi.v8_String_WriteUtf8(result_str, buffer.ptr, @intCast(len));
        return buffer;
    }

    /// Format an object for REPL display using JavaScript's own introspection
    fn formatObjectForDisplay(self: *Self, value: *v8.ffi.Value) ![]const u8 {
        const context = self.getContext();
        const isolate = self.getIsolate();

        // Store the value temporarily so our formatter can access it
        const global = v8.ffi.v8_Context_Global(context) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };
        const temp_key = v8.ffi.v8_String_NewFromUtf8(isolate, "__repl_temp__", 13) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };
        _ = v8.ffi.v8_Object_Set(global, context, @ptrCast(temp_key), value);
        defer {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                _ = v8.ffi.v8_Object_Set(global, context, @ptrCast(temp_key), undef);
            }
        }

        // JavaScript code to format the object like Chrome DevTools
        const format_code =
            \\(function() {
            \\  const obj = __repl_temp__;
            \\  if (obj === null) return 'null';
            \\  if (obj === undefined) return 'undefined';
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

        const format_str = v8.ffi.v8_String_NewFromUtf8(isolate, format_code.ptr, @intCast(format_code.len)) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const format_script = v8.ffi.v8_Script_Compile(context, format_str) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const format_result = v8.ffi.v8_Script_Run(context, format_script) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const result_str = v8.ffi.v8_Value_ToString(format_result, context) orelse {
            return try self.allocator.dupe(u8, "[object]");
        };

        const len = v8.ffi.v8_String_Utf8Length(result_str);
        const buffer = try self.allocator.alloc(u8, @intCast(len));
        _ = v8.ffi.v8_String_WriteUtf8(result_str, buffer.ptr, @intCast(len));
        return buffer;
    }

    /// Get completions for tab completion
    pub fn getCompletions(self: *Self, input: []const u8) !struct { completions: [][]const u8, prefix_len: usize } {
        const context = self.getContext();

        var completions = std.ArrayList([]const u8).empty;
        errdefer {
            for (completions.items) |item| {
                self.allocator.free(item);
            }
            completions.deinit(self.allocator);
        }

        // Check if input contains a dot - if so, complete on object properties
        if (std.mem.lastIndexOfScalar(u8, input, '.')) |dot_pos| {
            const obj_expr = input[0..dot_pos];
            const prop_prefix = input[dot_pos + 1 ..];

            // Evaluate the object expression to get the object
            const obj = self.evalExpression(obj_expr) orelse {
                return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = prop_prefix.len };
            };

            // Get property names from the object (including prototype chain)
            try self.getPropertyNames(obj, prop_prefix, &completions);

            return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = prop_prefix.len };
        }

        // No dot - complete on globals
        const global = v8.ffi.v8_Context_Global(context) orelse return error.NoGlobal;
        try self.getPropertyNames(global, input, &completions);

        return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = input.len };
    }

    /// Evaluate an expression and return the resulting object (or null if not an object)
    fn evalExpression(self: *Self, expr: []const u8) ?*v8.ffi.Object {
        if (expr.len == 0) return null;

        const isolate = self.getIsolate();
        const context = self.getContext();

        const source = v8.ffi.v8_String_NewFromUtf8(
            isolate,
            expr.ptr,
            @intCast(expr.len),
        ) orelse return null;

        const script = v8.ffi.v8_Script_Compile(context, source) orelse return null;
        const result = v8.ffi.v8_Script_Run(context, script) orelse return null;

        if (!v8.ffi.v8_Value_IsObject(result)) return null;

        return @ptrCast(result);
    }

    /// Get property names from an object that match prefix
    fn getPropertyNames(self: *Self, obj: *v8.ffi.Object, prefix: []const u8, completions: *std.ArrayList([]const u8)) !void {
        const context = self.getContext();

        const names = v8.ffi.v8_Object_GetPropertyNames(context, obj) orelse return;
        const len = v8.ffi.v8_Array_Length(names);
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const name_val = v8.ffi.v8_Array_Get(context, names, i) orelse continue;
            const name_str = v8.ffi.v8_Value_ToString(name_val, context) orelse continue;

            const name_len = v8.ffi.v8_String_Utf8Length(name_str);
            const name_buf = try self.allocator.alloc(u8, @intCast(name_len));
            _ = v8.ffi.v8_String_WriteUtf8(name_str, name_buf.ptr, @intCast(name_len));

            if (prefix.len == 0 or std.mem.startsWith(u8, name_buf, prefix)) {
                try completions.append(self.allocator, name_buf);
            } else {
                self.allocator.free(name_buf);
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
    fn readByte(stdin: std.fs.File) !u8 {
        var buf: [1]u8 = undefined;
        const n = try stdin.read(&buf);
        if (n == 0) return error.EndOfStream;
        return buf[0];
    }

    /// Write a single byte to file
    fn writeByte(file: std.fs.File, byte: u8) !void {
        const buf = [_]u8{byte};
        try file.writeAll(&buf);
    }

    /// Print formatted output to file
    fn print(allocator: std.mem.Allocator, file: std.fs.File, comptime format: []const u8, args: anytype) !void {
        const str = try std.fmt.allocPrint(allocator, format, args);
        defer allocator.free(str);
        try file.writeAll(str);
    }

    /// Clear current line and redraw with new content
    fn clearAndRedraw(self: *Self, stdout: std.fs.File, new_content: []const u8) !void {
        const current_len = self.input_buffer.items.len;
        if (current_len > 0) {
            try print(self.allocator, stdout, "\x1b[{d}D", .{current_len});
        }
        try stdout.writeAll("\x1b[K");
        self.input_buffer.clearRetainingCapacity();
        try self.input_buffer.appendSlice(self.allocator, new_content);
        try stdout.writeAll(new_content);
    }

    /// Read line with tab completion and history navigation
    pub fn readLine(self: *Self) !?[]const u8 {
        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();

        var original_termios: std.posix.termios = undefined;
        const is_tty = std.posix.isatty(stdin.handle);
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

        var history_index: usize = self.history.items.len;
        var saved_input: ?[]u8 = null;
        defer if (saved_input) |s| self.allocator.free(s);

        while (true) {
            const byte = readByte(stdin) catch |err| {
                if (err == error.EndOfStream) return null;
                return err;
            };

            switch (byte) {
                '\n' => {
                    try writeByte(stdout, '\n');
                    const result = try self.allocator.dupe(u8, self.input_buffer.items);
                    return result;
                },
                4 => return null, // Ctrl+D
                127, 8 => { // Backspace
                    if (self.input_buffer.items.len > 0) {
                        _ = self.input_buffer.pop();
                        try stdout.writeAll("\x08 \x08");
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
                            try stdout.writeAll(suffix);
                        } else if (result.completions.len > 1) {
                            // Multiple matches - show them
                            try stdout.writeAll("\n");
                            for (result.completions) |c| {
                                try print(self.allocator, stdout, "{s}  ", .{c});
                            }
                            try stdout.writeAll("\n>>> ");
                            try stdout.writeAll(self.input_buffer.items);
                        }
                    }
                },
                27 => { // Escape sequence
                    const next1 = readByte(stdin) catch continue;
                    if (next1 != '[') continue;
                    const next2 = readByte(stdin) catch continue;

                    switch (next2) {
                        'A' => { // Up arrow
                            if (history_index > 0) {
                                if (history_index == self.history.items.len) {
                                    if (saved_input) |s| self.allocator.free(s);
                                    saved_input = try self.allocator.dupe(u8, self.input_buffer.items);
                                }
                                history_index -= 1;
                                try self.clearAndRedraw(stdout, self.history.items[history_index]);
                            }
                        },
                        'B' => { // Down arrow
                            if (history_index < self.history.items.len) {
                                history_index += 1;
                                if (history_index == self.history.items.len) {
                                    try self.clearAndRedraw(stdout, saved_input orelse "");
                                } else {
                                    try self.clearAndRedraw(stdout, self.history.items[history_index]);
                                }
                            }
                        },
                        else => {},
                    }
                },
                else => {
                    if (byte >= 32 and byte < 127) {
                        try self.input_buffer.append(self.allocator, byte);
                        try writeByte(stdout, byte);
                    }
                },
            }
        }
    }

    /// Run the REPL loop
    pub fn run(self: *Self) !void {
        const stdout = std.fs.File.stdout();

        try stdout.writeAll("JavaScript REPL - Headless Browser\n");
        try stdout.writeAll("Same environment as WPT tests (window, document, etc.)\n");
        try stdout.writeAll("Type JavaScript code and press Enter\n");
        try stdout.writeAll("Press Tab for completions, Ctrl+D to exit\n\n");

        var multiline_buffer = std.ArrayListUnmanaged(u8){};
        defer multiline_buffer.deinit(self.allocator);

        while (true) {
            if (multiline_buffer.items.len == 0) {
                try stdout.writeAll(">>> ");
            } else {
                try stdout.writeAll("... ");
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
                try print(self.allocator, stdout, "Error: {}\n", .{err});
                continue;
            };
            defer self.allocator.free(result);

            try print(self.allocator, stdout, "{s}\n", .{result});
        }

        try stdout.writeAll("\nGoodbye!\n");
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try Repl.init(allocator);
    errdefer repl.deinit();

    try repl.run();

    repl.deinit();
}
