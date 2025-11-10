//! Console Supporting Types
//!
//! This file defines supporting types for the Console WHATWG implementation.
//! These types are NOT WebIDL interfaces - they're plain Zig types for
//! internal console state management and runtime integration.
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! # Types Overview
//!
//! ## State Management
//! - **Group**: Represents a collapsible/expandable console group
//! - **Message**: Buffered console message with lazy formatting
//! - **CircularMessageBuffer**: FIFO buffer for message history
//! - **LogLevel**: Severity levels for console operations
//!
//! ## Runtime Integration
//! - **RuntimeInterface**: Integration point for JavaScript engines
//! - **VTable**: Function pointers for ECMAScript operations
//! - **StackFrame**: Call stack frame for trace() output
//!
//! # Memory Management
//!
//! All types follow Zig allocation patterns:
//! - Explicit allocator parameters
//! - `init()` allocates, `deinit()` frees
//! - Owned strings tracked for cleanup
//! - `errdefer` for error path cleanup
//!
//! # Thread Safety
//!
//! These types are NOT thread-safe. Each thread should have its own
//! Console instance, or synchronize access externally.

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");

const Allocator = std.mem.Allocator;

/// A group represents a collapsible/expandable section in the console output.
///
/// WHATWG Console Standard lines 178-179:
/// "A group is an implementation-defined, potentially-interactive view for output
/// produced by calls to Printer, with one further level of indentation than its parent."
///
/// Groups are maintained on a stack (group_stack) where only the last group
/// receives output from Printer calls. Groups can be expanded or collapsed
/// (for interactive environments like browser DevTools).
///
/// # Fields
/// - `label`: Optional UTF-8 label for the group (owned, must be freed)
/// - `collapsed`: Whether group should be collapsed by default
///
/// # Lifecycle
/// 1. Created by group() or groupCollapsed()
/// 2. Pushed onto group_stack
/// 3. All subsequent output is indented by one level
/// 4. Popped by groupEnd()
/// 5. Label freed in deinit()
///
/// # Example
/// ```zig
/// // Create expanded group with label
/// var group = Group.init(try allocator.dupe(u8, "My Group"));
/// defer group.deinit(allocator);
///
/// // Create collapsed group
/// var collapsed_group = Group.initCollapsed(null);
/// defer collapsed_group.deinit(allocator);
/// ```
pub const Group = struct {
    /// Optional label for the group.
    /// If null, an implementation-chosen default label is used.
    /// Owned string - must be freed in deinit().
    label: ?webidl.DOMString,

    /// Whether the group is collapsed by default (groupCollapsed) or expanded (group).
    /// This is a hint for interactive environments (browser DevTools).
    collapsed: bool,

    /// Create a new expanded group with optional label.
    pub fn init(label: ?webidl.DOMString) Group {
        return .{
            .label = label,
            .collapsed = false,
        };
    }

    /// Create a new collapsed group with optional label.
    pub fn initCollapsed(label: ?webidl.DOMString) Group {
        return .{
            .label = label,
            .collapsed = true,
        };
    }

    /// Free the group's label if it was allocated.
    pub fn deinit(self: *Group, allocator: Allocator) void {
        if (self.label) |lbl| {
            allocator.free(lbl);
        }
    }
};

/// A console message stored in the message buffer.
///
/// Messages are buffered to provide message history and enable lazy formatting.
pub const Message = struct {
    logLevel: LogLevel,
    timestamp: infra.Moment,
    args: []const webidl.JSValue,
    indent: usize,
    ownedStrings: infra.List([]const u8),

    pub fn init(logLevel: LogLevel, timestamp: infra.Moment, args: []const webidl.JSValue, indent: usize, allocator: Allocator) !Message {
        const owned_args = try allocator.dupe(webidl.JSValue, args);
        return .{
            .logLevel = logLevel,
            .timestamp = timestamp,
            .args = owned_args,
            .indent = indent,
            .ownedStrings = infra.List([]const u8).init(allocator),
        };
    }

    pub fn format(self: *const Message, allocator: Allocator) ![]const u8 {
        var result = infra.List(u8).init(allocator);
        errdefer result.deinit();

        // Add indentation (2 spaces per level)
        var indent_count: usize = 0;
        while (indent_count < self.indent) : (indent_count += 1) {
            try result.appendSlice("  ");
        }

        // Format level tag
        const level_tag = try std.fmt.allocPrint(allocator, "[{s}] ", .{@tagName(self.logLevel)});
        defer allocator.free(level_tag);
        try result.appendSlice(level_tag);

        // Convert each JSValue arg to string
        for (self.args, 0..) |arg, i| {
            if (i > 0) try result.append(' ');

            const arg_str = switch (arg) {
                .string => |s| s,
                .number => |n| {
                    const temp = try std.fmt.allocPrint(allocator, "{d}", .{n});
                    defer allocator.free(temp);
                    try result.appendSlice(temp);
                    continue;
                },
                .boolean => |b| if (b) "true" else "false",
                .null => "null",
                .undefined => "undefined",
            };
            try result.appendSlice(arg_str);
        }

        const items_slice = result.items();
        const owned = try allocator.dupe(u8, items_slice);
        result.deinit();
        return owned;
    }

    pub fn deinit(self: *Message, allocator: Allocator) void {
        var i: usize = 0;
        while (i < self.ownedStrings.size()) : (i += 1) {
            const owned_str = self.ownedStrings.get(i).?;
            allocator.free(owned_str);
        }
        self.ownedStrings.deinit();
        allocator.free(self.args);
    }

    pub fn takeOwnership(self: *Message, owned_str: []const u8) !void {
        try self.ownedStrings.append(owned_str);
    }
};

/// A circular buffer for storing console messages.
///
/// Follows browser pattern of buffering up to N messages (default 1000).
/// When full, the oldest message is discarded (FIFO).
pub const CircularMessageBuffer = struct {
    const Self = @This();

    allocator: Allocator,
    buffer: []?Message,
    maxSize: usize,
    head: usize,
    tail: usize,
    count: usize,

    pub fn init(allocator: Allocator, maxSize: usize) !Self {
        const buffer = try allocator.alloc(?Message, maxSize);
        @memset(buffer, null);

        return .{
            .allocator = allocator,
            .buffer = buffer,
            .maxSize = maxSize,
            .head = 0,
            .tail = 0,
            .count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.allocator.free(self.buffer);
    }

    pub fn push(self: *Self, message: Message) void {
        if (self.count == self.maxSize) {
            if (self.buffer[self.tail]) |*old_msg| {
                old_msg.deinit(self.allocator);
            }
            self.tail = (self.tail + 1) % self.maxSize;
            self.count -= 1;
        }

        self.buffer[self.head] = message;
        self.head = (self.head + 1) % self.maxSize;
        self.count += 1;
    }

    pub fn get(self: *const Self, index: usize) ?*const Message {
        if (index >= self.count) return null;
        const actual_index = (self.tail + index) % self.maxSize;
        if (self.buffer[actual_index]) |*msg| {
            return msg;
        }
        return null;
    }

    pub fn pop(self: *Self) ?Message {
        if (self.count == 0) return null;

        const message = self.buffer[self.tail];
        self.buffer[self.tail] = null;
        self.tail = (self.tail + 1) % self.maxSize;
        self.count -= 1;

        return message;
    }

    pub fn clear(self: *Self) void {
        while (self.pop()) |msg| {
            var msg_mut = msg;
            msg_mut.deinit(self.allocator);
        }
    }

    pub fn size(self: *const Self) usize {
        return self.count;
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.count == 0;
    }

    pub fn isFull(self: *const Self) bool {
        return self.count == self.maxSize;
    }
};

/// Log level severity for Printer operations.
///
/// WHATWG Console Standard lines 373-383
pub const LogLevel = enum {
    assert_level,
    clear,
    debug,
    error_level,
    info,
    log,
    warn,
    dir,
    dirxml,
    trace,
    count,
    count_reset,
    group,
    group_collapsed,
    time,
    time_log,
    time_end,
    table,

    pub fn getSeverity(self: LogLevel) Severity {
        return switch (self) {
            .log, .trace, .dir, .dirxml, .group, .group_collapsed, .debug, .time_log => .log,
            .count, .info, .time_end => .info,
            .warn, .count_reset => .warn,
            .error_level, .assert_level => .@"error",
            .clear, .time, .table => .log,
        };
    }

    pub const Severity = enum {
        log,
        info,
        warn,
        @"error",
    };
};

/// Represents a single frame in a JavaScript call stack.
pub const StackFrame = struct {
    function_name: ?[]const u8,
    file_name: ?[]const u8,
    line_number: u32,
    column_number: u32,

    pub fn format(self: *const StackFrame, allocator: Allocator) ![]const u8 {
        const func_name = self.function_name orelse "<anonymous>";

        if (self.file_name) |file| {
            return try std.fmt.allocPrint(
                allocator,
                "    at {s} ({s}:{d}:{d})",
                .{ func_name, file, self.line_number, self.column_number },
            );
        } else {
            return try std.fmt.allocPrint(
                allocator,
                "    at {s}",
                .{func_name},
            );
        }
    }
};

/// Virtual function table for runtime operations.
///
/// Each function receives the opaque context as first parameter.
/// The context should be cast to the runtime's specific context type:
///
/// ```zig
/// const my_ctx: *MyRuntimeContext = @ptrCast(@alignCast(ctx));
/// ```
///
/// # Error Handling
/// - Functions should return Zig errors for failures
/// - Do NOT panic or abort on errors
/// - Return null for optional operations that fail
///
/// # Memory Management
/// - Allocated memory is owned by the caller (console library)
/// - Runtime must NOT retain pointers after function returns
/// - Allocator is provided for all allocations
///
/// # Function Categories
///
/// ## Type Checking (Required)
/// - `isArray`: Check if value is JavaScript Array
/// - `isObject`: Check if value is JavaScript Object
/// - `isSymbol`: Check if value is JavaScript Symbol
///
/// ## Type Conversion (Required for Format Specifiers)
/// - `toString`: ECMAScript ToString() for %s
/// - `toInteger`: ECMAScript parseInt(value, 10) for %d, %i
/// - `toFloat`: ECMAScript parseFloat() for %f
///
/// ## Object Introspection (Required for table())
/// - `getProperty`: Get property value by name
/// - `getKeys`: Get all enumerable property names
/// - `getLength`: Get array length property
///
/// ## Stack Traces (Required for trace())
/// - `captureStackTrace`: Capture current call stack
///
/// ## DOM Operations (Optional for dirxml())
/// - `isDOMNode`: Check if value is a DOM node
/// - `toDOMString`: Convert DOM node to HTML string
///
/// # Example Implementation
///
/// ```zig
/// const MyRuntimeContext = struct {
///     engine: *JSEngine,
/// };
///
/// fn myToString(ctx: *anyopaque, value: webidl.JSValue, allocator: Allocator) anyerror![]const u8 {
///     const runtime_ctx: *MyRuntimeContext = @ptrCast(@alignCast(ctx));
///     return runtime_ctx.engine.callToString(value, allocator);
/// }
///
/// const my_vtable = VTable{
///     .toString = myToString,
///     // ... implement other functions
/// };
/// ```
pub const VTable = struct {
    // Type Checking
    isArray: *const fn (ctx: *anyopaque, value: webidl.JSValue) bool,
    isObject: *const fn (ctx: *anyopaque, value: webidl.JSValue) bool,
    isSymbol: *const fn (ctx: *anyopaque, value: webidl.JSValue) bool,

    // Type Conversion (for format specifiers)
    toString: *const fn (ctx: *anyopaque, value: webidl.JSValue, allocator: Allocator) anyerror![]const u8,
    toInteger: *const fn (ctx: *anyopaque, value: webidl.JSValue) anyerror!i32,
    toFloat: *const fn (ctx: *anyopaque, value: webidl.JSValue) anyerror!f64,

    // Object Introspection (for table())
    getProperty: *const fn (ctx: *anyopaque, value: webidl.JSValue, property: []const u8, allocator: Allocator) anyerror!?webidl.JSValue,
    getKeys: *const fn (ctx: *anyopaque, value: webidl.JSValue, allocator: Allocator) anyerror![][]const u8,
    getLength: *const fn (ctx: *anyopaque, value: webidl.JSValue) anyerror!?u32,

    // Stack Traces (for trace())
    captureStackTrace: *const fn (ctx: *anyopaque, allocator: Allocator) anyerror![]StackFrame,

    // DOM Operations (for dirxml())
    isDOMNode: *const fn (ctx: *anyopaque, value: webidl.JSValue) bool,
    toDOMString: *const fn (ctx: *anyopaque, value: webidl.JSValue, allocator: Allocator) anyerror![]const u8,
};

/// Runtime integration interface for JavaScript engines.
///
/// This interface allows the console library to interact with any JavaScript
/// runtime (V8, JavaScriptCore, SpiderMonkey, etc.) through a vtable pattern.
///
/// # Lifetime
/// - The RuntimeInterface is borrowed by Console (not owned)
/// - Runtime must outlive all Console instances using it
/// - Console.deinit() does NOT free the runtime (caller's responsibility)
///
/// # Thread Safety
/// - RuntimeInterface must be used from the same thread that created it
/// - No synchronization is provided by the console library
/// - Runtime is responsible for thread safety of its operations
///
/// # Usage
///
/// ```zig
/// // 1. Create your runtime
/// var my_runtime = try MyJSRuntime.init(allocator);
/// defer my_runtime.deinit();
///
/// // 2. Create RuntimeInterface
/// const runtime_interface = RuntimeInterface{
///     .vtable = &my_vtable,
///     .context = @ptrCast(&my_runtime),
/// };
///
/// // 3. Pass to Console
/// var console = try Console.init(allocator);
/// defer console.deinit();
/// console.runtime = &runtime_interface;
///
/// // 4. Console now uses runtime for type conversions
/// console.call_log(&.{my_js_object});
/// ```
///
/// # Fallback Behavior
///
/// If console.runtime is null, the console uses simple fallback conversions:
/// - toString: Uses Zig's std.fmt
/// - toInteger: Uses std.fmt.parseInt
/// - toFloat: Uses std.fmt.parseFloat
/// - table(): Falls back to regular logging
/// - trace(): Omits stack trace, just logs data
///
/// # See Also
/// - tests/console/mock_runtime.zig - Example implementation
pub const RuntimeInterface = struct {
    /// Function pointers for runtime operations
    vtable: *const VTable,

    /// Opaque pointer to runtime-specific context
    /// Cast to your runtime's context type in vtable implementations
    context: *anyopaque,
};
