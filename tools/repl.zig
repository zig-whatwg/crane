//! JavaScript REPL with V8 Engine and WebIDL Bindings
//!
//! Interactive Read-Eval-Print Loop with:
//! - V8 JavaScript execution
//! - Console API (console.log, etc.)
//! - Tab completion for JavaScript globals
//! - Multi-line input support
//! - History support

const std = @import("std");
const v8 = @import("v8");
const context_manager = @import("v8").context_manager;
const runtime = @import("runtime");

/// REPL state
const Repl = struct {
    allocator: std.mem.Allocator,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
    input_buffer: std.ArrayListUnmanaged(u8),
    history: std.ArrayListUnmanaged([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);

        // Initialize V8 platform
        v8.ffi.v8_Platform_Initialize();

        // Initialize V8 isolate
        const isolate = v8.ffi.v8_Isolate_New() orelse return error.V8InitFailed;
        errdefer v8.ffi.v8_Isolate_Dispose(isolate);

        v8.ffi.v8_Isolate_Enter(isolate);
        errdefer v8.ffi.v8_Isolate_Exit(isolate);

        const context = v8.ffi.v8_Context_New(isolate) orelse return error.ContextCreateFailed;
        errdefer v8.ffi.v8_Context_Dispose(context);

        v8.ffi.v8_Context_Enter(context);

        // Initialize context manager for V8 callbacks
        context_manager.init(allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
            // Continue anyway - some interfaces may not work properly
        };

        // Register the V8 context with context manager to enable wrapper caching
        // This creates a runtime context with wrapper cache for object identity
        _ = context_manager.getOrCreate(context, allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            // Continue anyway - wrapper caching won't work but basic functionality will
        };

        // Register all interface bindings using comptime reflection
        // The @setEvalBranchQuota is needed because we iterate over 1231 declarations
        @setEvalBranchQuota(200_000);
        const interfaces = @import("interfaces");
        const iface_decls = @typeInfo(interfaces).@"struct".decls;

        // Interfaces to skip due to codegen issues (missing types, etc.)
        const skip_list = .{
            "CSSMarginRule", // References undefined CSSMarginDescriptors
            "ViewCSS", // References undefined AbstractView
            "AuthenticatorAssertionResponse", // ArrayBuffer type issues
            "AuthenticatorAttestationResponse", // ArrayBuffer type issues
            "AuthenticatorResponse", // ArrayBuffer type issues
            "CSSMediaRule", // Missing cached field
            "CSSViewTransitionRule", // DOMString array issues
            "ChapterInformation", // MediaImage array issues
            "CookieChangeEvent", // CookieListItem array issues
            "DeviceChangeEvent", // MediaDeviceInfo array issues
            "ExtendableCookieChangeEvent", // CookieListItem array issues
            "ExtendableMessageEvent", // Union type issues
            "FontFaceSetLoadEvent", // FontFace array issues
            "GamepadHapticActuator", // GamepadHapticEffectType array issues
            "MediaMetadata", // ChapterInformation array issues
            "Notification", // Missing unsignedlong type
            "PerformanceLongAnimationFrameTiming", // PerformanceScriptTiming array issues
            "PerformanceObserver", // Missing cached field
            "PressureObserver", // Missing cached field
            "PublicKeyCredential", // ArrayBuffer type issues
            "PushManager", // Missing cached field
            "PushSubscriptionOptions", // ArrayBuffer type issues
            "RTCTrackEvent", // MediaStream array issues
            "SVGPathElement", // Missing cached field
            "WindowClient", // Missing VisibilityState type
            "XRCPUDepthInformation", // ArrayBuffer type issues
            "XRInputSource", // DOMString array issues
            "XRInputSourcesChangeEvent", // XRInputSource array issues
            "XRRay", // TypedArray issues
            "XRViewerPose", // XRView array issues
            "XRVisibilityMaskChangeEvent", // TypedArray issues
        };

        inline for (iface_decls) |decl| {
            // Skip problematic interfaces
            const should_skip = comptime blk: {
                for (skip_list) |skip| {
                    if (std.mem.eql(u8, decl.name, skip)) break :blk true;
                }
                break :blk false;
            };
            if (should_skip) continue;

            const InterfaceType = @field(interfaces, decl.name);
            // Only bind types that have Meta (actual interfaces)
            if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
                // Skip mixin interfaces - they should not be exposed as globals
                const is_mixin = comptime blk: {
                    const Meta = InterfaceType.Meta;
                    if (@hasDecl(Meta, "is_mixin")) {
                        break :blk Meta.is_mixin;
                    }
                    break :blk false;
                };
                if (is_mixin) continue;

                // Check if this interface has LegacyNamespace - if so, skip global registration
                const has_legacy_namespace = comptime blk: {
                    const Meta = InterfaceType.Meta;
                    if (@hasDecl(Meta, "extended_attributes")) {
                        const ext_attrs = Meta.extended_attributes;
                        for (ext_attrs) |attr| {
                            if (std.mem.eql(u8, attr.name, "LegacyNamespace")) {
                                break :blk true;
                            }
                        }
                    }
                    break :blk false;
                };

                // Skip interfaces with LegacyNamespace - they get attached to namespaces below
                if (has_legacy_namespace) continue;

                const Binding = v8.V8Interface(InterfaceType);
                Binding.registerGlobal(isolate, context, decl.name);
            }
        }

        // Register all namespace bindings
        const namespaces = @import("namespaces");
        const ns_decls = @typeInfo(namespaces).@"struct".decls;

        inline for (ns_decls) |decl| {
            const NamespaceType = @field(namespaces, decl.name);
            // Only bind types that have Meta (actual namespaces)
            if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
                // Use V8Namespace to create object with all methods bound
                const NamespaceBinding = v8.V8Namespace(NamespaceType);
                NamespaceBinding.registerGlobal(isolate, context, decl.name);

                // Get the namespace object we just created
                const global_obj = v8.ffi.v8_Context_Global(context);
                const ns_key_str = v8.ffi.v8_String_NewFromUtf8(isolate, decl.name.ptr, @intCast(decl.name.len));
                const ns_obj_value = v8.ffi.v8_Object_Get(global_obj.?, context, @ptrCast(ns_key_str));
                const ns_obj = @as(?*v8.ffi.Object, @ptrCast(ns_obj_value));

                // Now attach interfaces with [LegacyNamespace=<this namespace>] as properties
                const namespace_name = decl.name;
                inline for (iface_decls) |iface_decl| {
                    const InterfaceType = @field(interfaces, iface_decl.name);
                    if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
                        // Check if this interface belongs to this namespace
                        const belongs_here = comptime blk: {
                            const Meta = InterfaceType.Meta;
                            if (@hasDecl(Meta, "extended_attributes")) {
                                const ext_attrs = Meta.extended_attributes;
                                for (ext_attrs) |attr| {
                                    if (std.mem.eql(u8, attr.name, "LegacyNamespace")) {
                                        const val = attr.value;
                                        if (@hasField(@TypeOf(val), "identifier")) {
                                            if (std.mem.eql(u8, val.identifier, namespace_name)) {
                                                break :blk true;
                                            }
                                        }
                                    }
                                }
                            }
                            break :blk false;
                        };

                        if (belongs_here) {
                            // Create the interface constructor
                            const InterfaceBinding = v8.V8Interface(InterfaceType);
                            const template = InterfaceBinding.createTemplate(isolate);
                            const constructor = v8.ffi.v8_FunctionTemplate_GetFunction(template, context);

                            // Attach as property: WebAssembly.Instance = constructor
                            const iface_key = v8.ffi.v8_String_NewFromUtf8(isolate, iface_decl.name.ptr, @intCast(iface_decl.name.len));
                            _ = v8.ffi.v8_Object_Set(@ptrCast(ns_obj), context, @ptrCast(iface_key), @ptrCast(constructor));
                        }
                    }
                }

                // Make namespace object non-extensible (per WebIDL spec)
                _ = v8.ffi.v8_Object_PreventExtensions(@ptrCast(ns_obj), context);
            }
        }

        // Set up constructor inheritance chain after all interfaces are registered
        // This makes Element.__proto__ === Node, Node.__proto__ === EventTarget, etc.
        v8.interface_bindings.setupConstructorInheritance(isolate, context);

        return Self{
            .allocator = allocator,
            .isolate = isolate,
            .context = context,
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

        // Cleanup context manager
        context_manager.deinit();

        // Cleanup V8
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Context_Dispose(self.context);
        v8.ffi.v8_Isolate_Exit(self.isolate);
        v8.ffi.v8_Isolate_Dispose(self.isolate);

        // Cleanup WebIDL runtime
        runtime.deinitializeRuntime();
    }

    /// Execute JavaScript code and return result
    pub fn eval(self: *Self, code: []const u8) ![]const u8 {
        // Create V8 string from code
        const source_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, code.ptr, @intCast(code.len)) orelse return error.StringCreateFailed;

        // Compile script
        const script = v8.ffi.v8_Script_Compile(self.context, source_str) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(self.context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, self.context);
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
        const result = v8.ffi.v8_Script_Run(self.context, script) orelse {
            // Get exception message
            const exception = v8.ffi.v8_TryCatch_Exception(self.context);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, self.context);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    return buffer;
                }
            }
            return error.RuntimeError;
        };

        // Convert result to string
        const result_str = v8.ffi.v8_Value_ToString(result, self.context) orelse {
            return try self.allocator.dupe(u8, "undefined");
        };

        const len = v8.ffi.v8_String_Utf8Length(result_str);
        const buffer = try self.allocator.alloc(u8, @intCast(len));
        _ = v8.ffi.v8_String_WriteUtf8(result_str, buffer.ptr, @intCast(len));

        return buffer;
    }

    /// Get completions for tab completion
    /// Handles both global completions and object property completions (e.g., "Event.")
    pub fn getCompletions(self: *Self, input: []const u8) !struct { completions: [][]const u8, prefix_len: usize } {
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
        const global = v8.ffi.v8_Context_Global(self.context) orelse return error.NoGlobal;
        try self.getPropertyNames(global, input, &completions);

        return .{ .completions = try completions.toOwnedSlice(self.allocator), .prefix_len = input.len };
    }

    /// Evaluate an expression and return the resulting object (or null if not an object)
    fn evalExpression(self: *Self, expr: []const u8) ?*v8.ffi.Object {
        if (expr.len == 0) return null;

        const source = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            expr.ptr,
            @intCast(expr.len),
        ) orelse return null;

        const script = v8.ffi.v8_Script_Compile(self.context, source) orelse return null;
        const result = v8.ffi.v8_Script_Run(self.context, script) orelse return null;

        // Check if result is an object
        if (!v8.ffi.v8_Value_IsObject(result)) return null;

        return @ptrCast(result);
    }

    /// Get property names from an object that match prefix
    fn getPropertyNames(self: *Self, obj: *v8.ffi.Object, prefix: []const u8, completions: *std.ArrayList([]const u8)) !void {
        // Get all property names including prototype chain
        const names = v8.ffi.v8_Object_GetPropertyNames(self.context, obj) orelse return;
        const len = v8.ffi.v8_Array_Length(names);
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const name_val = v8.ffi.v8_Array_Get(self.context, names, i) orelse continue;
            const name_str = v8.ffi.v8_Value_ToString(name_val, self.context) orelse continue;

            const name_len = v8.ffi.v8_String_Utf8Length(name_str);
            const name_buf = try self.allocator.alloc(u8, @intCast(name_len));
            _ = v8.ffi.v8_String_WriteUtf8(name_str, name_buf.ptr, @intCast(name_len));

            // Check if matches prefix
            if (prefix.len == 0 or std.mem.startsWith(u8, name_buf, prefix)) {
                try completions.append(self.allocator, name_buf);
            } else {
                self.allocator.free(name_buf);
            }
        }
    }

    /// Legacy wrapper for backward compatibility
    pub fn getGlobalCompletions(self: *Self, prefix: []const u8) ![][]const u8 {
        const result = try self.getCompletions(prefix);
        return result.completions;
    }

    /// Sync file if supported (currently disabled due to Zig stdlib issues with pipes)
    /// File syncing works for interactive terminals but causes stack traces on pipes.
    /// Output flushing is automatic for line-buffered stdout, so explicit sync isn't needed.
    fn syncIfSupported(file: std.fs.File) void {
        _ = file;
        // Disabled: file.sync() causes unexpectedErrno stack traces on pipes (errno 45 ENOTSUP)
        // Interactive terminals handle flushing automatically, pipes work fine without it
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
        // Clear current line: move to start, clear to end
        const current_len = self.input_buffer.items.len;
        // Move cursor back to start of input
        if (current_len > 0) {
            try print(self.allocator, stdout, "\x1b[{d}D", .{current_len});
        }
        // Clear from cursor to end of line
        try stdout.writeAll("\x1b[K");
        // Update buffer and display new content
        self.input_buffer.clearRetainingCapacity();
        try self.input_buffer.appendSlice(self.allocator, new_content);
        try stdout.writeAll(new_content);
    }

    /// Read line with tab completion and history navigation
    pub fn readLine(self: *Self) !?[]const u8 {
        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();

        // Enable raw mode to capture tab key and arrow keys directly
        var original_termios: std.posix.termios = undefined;
        const is_tty = std.posix.isatty(stdin.handle);
        if (is_tty) {
            original_termios = try std.posix.tcgetattr(stdin.handle);
            var raw = original_termios;
            // Disable canonical mode and echo
            raw.lflag.ICANON = false;
            raw.lflag.ECHO = false;
            // Set minimum bytes and timeout
            raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
            raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
            try std.posix.tcsetattr(stdin.handle, .FLUSH, raw);
        }
        defer if (is_tty) {
            std.posix.tcsetattr(stdin.handle, .FLUSH, original_termios) catch {};
        };

        self.input_buffer.clearRetainingCapacity();

        // History navigation index (history.len means "current input", not in history)
        var history_index: usize = self.history.items.len;
        // Save current input when navigating history
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
                    syncIfSupported(stdout);
                    break;
                },
                '\x1b' => {
                    // Escape sequence (arrow keys, etc.)
                    const seq1 = readByte(stdin) catch continue;
                    if (seq1 != '[') continue;
                    const seq2 = readByte(stdin) catch continue;

                    switch (seq2) {
                        'A' => {
                            // Up arrow - previous history
                            if (self.history.items.len > 0 and history_index > 0) {
                                // Save current input if we're leaving it
                                if (history_index == self.history.items.len) {
                                    if (saved_input) |s| self.allocator.free(s);
                                    saved_input = try self.allocator.dupe(u8, self.input_buffer.items);
                                }
                                history_index -= 1;
                                try self.clearAndRedraw(stdout, self.history.items[history_index]);
                            }
                        },
                        'B' => {
                            // Down arrow - next history
                            if (history_index < self.history.items.len) {
                                history_index += 1;
                                if (history_index == self.history.items.len) {
                                    // Restore saved input
                                    const content = saved_input orelse "";
                                    try self.clearAndRedraw(stdout, content);
                                } else {
                                    try self.clearAndRedraw(stdout, self.history.items[history_index]);
                                }
                            }
                        },
                        else => {},
                    }
                },
                '\t' => {
                    // Tab completion - handles both globals and object properties
                    const input = self.input_buffer.items;
                    const result = try self.getCompletions(input);
                    const completions = result.completions;
                    const prefix_len = result.prefix_len;
                    defer {
                        for (completions) |comp| {
                            self.allocator.free(comp);
                        }
                        self.allocator.free(completions);
                    }

                    if (completions.len == 1) {
                        // Single match - autocomplete
                        const completion = completions[0];
                        const remaining = completion[prefix_len..];
                        try self.input_buffer.appendSlice(self.allocator, remaining);
                        try stdout.writeAll(remaining);
                        syncIfSupported(stdout);
                    } else if (completions.len > 1) {
                        // Multiple matches - show options
                        try writeByte(stdout, '\n');
                        for (completions) |comp| {
                            try print(self.allocator, stdout, "  {s}\n", .{comp});
                        }
                        try stdout.writeAll(">>> ");
                        try stdout.writeAll(self.input_buffer.items);
                        syncIfSupported(stdout);
                    }
                },
                127, 8 => {
                    // Backspace
                    if (self.input_buffer.items.len > 0) {
                        _ = self.input_buffer.pop();
                        try stdout.writeAll("\x08 \x08");
                        syncIfSupported(stdout);
                    }
                },
                4 => {
                    // Ctrl+D - EOF
                    if (self.input_buffer.items.len == 0) {
                        return null;
                    }
                },
                32...126 => {
                    // Printable ASCII
                    try self.input_buffer.append(self.allocator, byte);
                    try writeByte(stdout, byte);
                    syncIfSupported(stdout);
                },
                else => {},
            }
        }

        const line = try self.allocator.dupe(u8, self.input_buffer.items);
        return line;
    }

    /// Add line to history
    pub fn addHistory(self: *Self, line: []const u8) !void {
        const dup = try self.allocator.dupe(u8, line);
        try self.history.append(self.allocator, dup);
    }

    /// Check if JavaScript code is syntactically complete using bracket counting
    /// Returns true if the code can be evaluated, false if more input is needed
    ///
    /// This uses a simple heuristic: count brackets, braces, and parens.
    /// If they're balanced and we're not inside a string/template literal, the code is likely complete.
    fn isCompleteCode(_: *Self, code: []const u8) bool {
        if (code.len == 0) return true;

        var brace_count: i32 = 0; // { }
        var bracket_count: i32 = 0; // [ ]
        var paren_count: i32 = 0; // ( )

        var in_string: u8 = 0; // 0 = not in string, '"' or '\'' = in that string type
        var in_template: bool = false; // Inside template literal ``
        var escape_next: bool = false;

        for (code) |c| {
            // Handle escape sequences
            if (escape_next) {
                escape_next = false;
                continue;
            }

            if (c == '\\' and (in_string != 0 or in_template)) {
                escape_next = true;
                continue;
            }

            // Handle string literals
            if (in_string != 0) {
                if (c == in_string) {
                    in_string = 0;
                }
                continue;
            }

            // Handle template literals
            if (in_template) {
                if (c == '`') {
                    in_template = false;
                }
                // Note: We're ignoring ${} inside templates for simplicity
                continue;
            }

            // Check for string/template start
            if (c == '"' or c == '\'') {
                in_string = c;
                continue;
            }
            if (c == '`') {
                in_template = true;
                continue;
            }

            // Handle single-line comment
            // Note: This is simplified - doesn't handle all comment cases perfectly

            // Count brackets
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

        // If we're inside a string or template, need more input
        if (in_string != 0 or in_template) {
            return false;
        }

        // If brackets are unbalanced (more opens than closes), need more input
        if (brace_count > 0 or bracket_count > 0 or paren_count > 0) {
            return false;
        }

        // Code appears complete
        return true;
    }

    /// Run the REPL loop
    pub fn run(self: *Self) !void {
        const stdout = std.fs.File.stdout();

        try stdout.writeAll("JavaScript REPL with V8 and WebIDL\n");
        try stdout.writeAll("Type JavaScript code and press Enter\n");
        try stdout.writeAll("Press Tab for completions, Ctrl+D to exit\n\n");
        syncIfSupported(stdout); // Flush output (ignore errors on pipes)

        // Buffer for accumulating multi-line input
        var multiline_buffer = std.ArrayListUnmanaged(u8){};
        defer multiline_buffer.deinit(self.allocator);

        while (true) {
            // Show appropriate prompt
            if (multiline_buffer.items.len == 0) {
                try stdout.writeAll(">>> ");
            } else {
                try stdout.writeAll("... ");
            }
            syncIfSupported(stdout); // Flush prompt immediately

            const line = try self.readLine() orelse break;
            defer self.allocator.free(line);

            // Handle empty lines
            if (line.len == 0) {
                if (multiline_buffer.items.len == 0) {
                    continue;
                }
                // Empty line in multi-line mode - try to execute what we have
            } else {
                // Append line to buffer
                if (multiline_buffer.items.len > 0) {
                    try multiline_buffer.append(self.allocator, '\n');
                }
                try multiline_buffer.appendSlice(self.allocator, line);
            }

            // Check if code is complete
            if (!self.isCompleteCode(multiline_buffer.items)) {
                // Need more input
                continue;
            }

            // Code is complete - evaluate it
            const code = try self.allocator.dupe(u8, multiline_buffer.items);
            defer self.allocator.free(code);

            // Clear buffer for next input
            multiline_buffer.clearRetainingCapacity();

            // Skip if empty after trimming
            const trimmed = std.mem.trim(u8, code, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            // Add to history
            try self.addHistory(code);

            // Evaluate
            const result = self.eval(code) catch |err| {
                try print(self.allocator, stdout, "Error: {}\n", .{err});
                syncIfSupported(stdout); // Flush error output
                continue;
            };
            defer self.allocator.free(result);

            try print(self.allocator, stdout, "{s}\n", .{result});
            syncIfSupported(stdout); // Flush result output
        }

        try stdout.writeAll("\nGoodbye!\n");
        syncIfSupported(stdout);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try Repl.init(allocator);
    defer repl.deinit();

    try repl.run();
}
