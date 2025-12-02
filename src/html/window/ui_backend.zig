//! UI Backend Interface - Pluggable User Prompts
//!
//! Provides an abstraction layer for user prompts (alert, confirm, prompt, print)
//! per HTML Standard §8.8 (Simple dialogs).
//!
//! Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#simple-dialogs
//!
//! ## Architecture
//!
//! The UI backend is pluggable, allowing different implementations:
//! - StubUIBackend: Returns default values (for headless/testing)
//! - ConsoleUIBackend: Prints to stdout/reads from stdin
//! - Custom implementations: GUI dialogs, etc.
//!
//! ## Usage
//!
//! ```zig
//! const ui_backend = @import("window/ui_backend.zig");
//!
//! // Use stub backend for testing
//! var backend = ui_backend.StubUIBackend.init(.{});
//!
//! // Show alert
//! backend.showAlert("Hello!");
//!
//! // Get confirmation
//! const result = backend.showConfirm("Are you sure?");
//!
//! // Get input
//! const input = backend.showPrompt("Enter your name:", "default");
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// UI Backend interface for user prompts
/// Per HTML Standard §8.8 (Simple dialogs)
pub const UIBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Show an alert dialog (§8.8.1)
        /// Displays a message and waits for user acknowledgment.
        showAlert: *const fn (ptr: *anyopaque, message: []const u8) void,

        /// Show a confirm dialog (§8.8.2)
        /// Displays a message and returns true if user confirms, false otherwise.
        showConfirm: *const fn (ptr: *anyopaque, message: []const u8) bool,

        /// Show a prompt dialog (§8.8.3)
        /// Displays a message with an input field and returns user input,
        /// or null if cancelled.
        showPrompt: *const fn (ptr: *anyopaque, message: []const u8, default_value: []const u8) ?[]const u8,

        /// Show print dialog (§8.8.4)
        /// Triggers the print functionality.
        showPrint: *const fn (ptr: *anyopaque) void,

        /// Free a string returned by showPrompt
        freeString: *const fn (ptr: *anyopaque, str: []const u8) void,
    };

    /// Show an alert dialog
    pub fn showAlert(self: UIBackend, message: []const u8) void {
        self.vtable.showAlert(self.ptr, message);
    }

    /// Show a confirm dialog
    pub fn showConfirm(self: UIBackend, message: []const u8) bool {
        return self.vtable.showConfirm(self.ptr, message);
    }

    /// Show a prompt dialog
    pub fn showPrompt(self: UIBackend, message: []const u8, default_value: []const u8) ?[]const u8 {
        return self.vtable.showPrompt(self.ptr, message, default_value);
    }

    /// Show print dialog
    pub fn showPrint(self: UIBackend) void {
        self.vtable.showPrint(self.ptr);
    }

    /// Free a string returned by showPrompt
    pub fn freeString(self: UIBackend, str: []const u8) void {
        self.vtable.freeString(self.ptr, str);
    }
};

/// Configuration for StubUIBackend
pub const StubUIBackendConfig = struct {
    /// Default return value for confirm dialogs
    confirm_result: bool = false,

    /// Default return value for prompt dialogs (null = cancelled)
    prompt_result: ?[]const u8 = null,

    /// Whether to log calls (for debugging)
    log_calls: bool = false,
};

/// Stub UI backend that returns default values
/// Useful for headless environments and testing
pub const StubUIBackend = struct {
    config: StubUIBackendConfig,
    allocator: ?Allocator,

    /// Initialize with configuration
    pub fn init(config: StubUIBackendConfig) StubUIBackend {
        return .{
            .config = config,
            .allocator = null,
        };
    }

    /// Initialize with allocator (needed for prompt to return strings)
    pub fn initWithAllocator(allocator: Allocator, config: StubUIBackendConfig) StubUIBackend {
        return .{
            .config = config,
            .allocator = allocator,
        };
    }

    /// Get the UIBackend interface
    pub fn backend(self: *StubUIBackend) UIBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UIBackend.VTable{
        .showAlert = showAlert,
        .showConfirm = showConfirm,
        .showPrompt = showPrompt,
        .showPrint = showPrint,
        .freeString = freeString,
    };

    fn showAlert(ptr: *anyopaque, message: []const u8) void {
        const self: *StubUIBackend = @ptrCast(@alignCast(ptr));
        if (self.config.log_calls) {
            std.debug.print("[StubUI] alert: {s}\n", .{message});
        }
    }

    fn showConfirm(ptr: *anyopaque, message: []const u8) bool {
        const self: *StubUIBackend = @ptrCast(@alignCast(ptr));
        if (self.config.log_calls) {
            std.debug.print("[StubUI] confirm: {s} -> {}\n", .{ message, self.config.confirm_result });
        }
        return self.config.confirm_result;
    }

    fn showPrompt(ptr: *anyopaque, message: []const u8, default_value: []const u8) ?[]const u8 {
        const self: *StubUIBackend = @ptrCast(@alignCast(ptr));
        if (self.config.log_calls) {
            std.debug.print("[StubUI] prompt: {s} (default: {s})\n", .{ message, default_value });
        }

        // If a custom result is configured and we have an allocator, return a copy
        if (self.config.prompt_result) |result| {
            if (self.allocator) |alloc| {
                return alloc.dupe(u8, result) catch null;
            }
        }

        // Otherwise return the default value if we have an allocator
        if (self.allocator) |alloc| {
            return alloc.dupe(u8, default_value) catch null;
        }

        return null;
    }

    fn showPrint(ptr: *anyopaque) void {
        const self: *StubUIBackend = @ptrCast(@alignCast(ptr));
        if (self.config.log_calls) {
            std.debug.print("[StubUI] print dialog\n", .{});
        }
    }

    fn freeString(ptr: *anyopaque, str: []const u8) void {
        const self: *StubUIBackend = @ptrCast(@alignCast(ptr));
        if (self.allocator) |alloc| {
            alloc.free(str);
        }
    }
};

/// Console UI backend that uses stdio
/// Useful for CLI applications
pub const ConsoleUIBackend = struct {
    allocator: Allocator,
    stdout: std.fs.File.Writer,
    stdin: std.fs.File.Reader,

    /// Initialize with stdio
    pub fn init(allocator: Allocator) ConsoleUIBackend {
        return .{
            .allocator = allocator,
            .stdout = std.io.getStdOut().writer(),
            .stdin = std.io.getStdIn().reader(),
        };
    }

    /// Get the UIBackend interface
    pub fn backend(self: *ConsoleUIBackend) UIBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UIBackend.VTable{
        .showAlert = showAlert,
        .showConfirm = showConfirm,
        .showPrompt = showPrompt,
        .showPrint = showPrint,
        .freeString = freeString,
    };

    fn showAlert(ptr: *anyopaque, message: []const u8) void {
        const self: *ConsoleUIBackend = @ptrCast(@alignCast(ptr));
        self.stdout.print("Alert: {s}\n", .{message}) catch {};
        self.stdout.print("Press Enter to continue...\n", .{}) catch {};
        _ = self.stdin.readUntilDelimiterAlloc(self.allocator, '\n', 1024) catch {};
    }

    fn showConfirm(ptr: *anyopaque, message: []const u8) bool {
        const self: *ConsoleUIBackend = @ptrCast(@alignCast(ptr));
        self.stdout.print("Confirm: {s} [y/N]: ", .{message}) catch {};

        const line = self.stdin.readUntilDelimiterAlloc(self.allocator, '\n', 1024) catch return false;
        defer self.allocator.free(line);

        if (line.len == 0) return false;
        return line[0] == 'y' or line[0] == 'Y';
    }

    fn showPrompt(ptr: *anyopaque, message: []const u8, default_value: []const u8) ?[]const u8 {
        const self: *ConsoleUIBackend = @ptrCast(@alignCast(ptr));

        if (default_value.len > 0) {
            self.stdout.print("Prompt: {s} [{s}]: ", .{ message, default_value }) catch {};
        } else {
            self.stdout.print("Prompt: {s}: ", .{message}) catch {};
        }

        const line = self.stdin.readUntilDelimiterAlloc(self.allocator, '\n', 4096) catch return null;

        // If empty input and we have a default, return the default
        if (line.len == 0 and default_value.len > 0) {
            self.allocator.free(line);
            return self.allocator.dupe(u8, default_value) catch null;
        }

        return line;
    }

    fn showPrint(ptr: *anyopaque) void {
        const self: *ConsoleUIBackend = @ptrCast(@alignCast(ptr));
        self.stdout.print("Print dialog (not supported in console mode)\n", .{}) catch {};
    }

    fn freeString(ptr: *anyopaque, str: []const u8) void {
        const self: *ConsoleUIBackend = @ptrCast(@alignCast(ptr));
        self.allocator.free(str);
    }
};

/// Callback-based UI backend for integration with external systems
pub const CallbackUIBackend = struct {
    allocator: Allocator,
    context: ?*anyopaque,

    /// Callbacks for UI operations
    alert_callback: ?*const fn (ctx: ?*anyopaque, message: []const u8) void,
    confirm_callback: ?*const fn (ctx: ?*anyopaque, message: []const u8) bool,
    prompt_callback: ?*const fn (ctx: ?*anyopaque, message: []const u8, default_value: []const u8) ?[]const u8,
    print_callback: ?*const fn (ctx: ?*anyopaque) void,

    /// Initialize with allocator and callbacks
    pub fn init(
        allocator: Allocator,
        context: ?*anyopaque,
    ) CallbackUIBackend {
        return .{
            .allocator = allocator,
            .context = context,
            .alert_callback = null,
            .confirm_callback = null,
            .prompt_callback = null,
            .print_callback = null,
        };
    }

    /// Set the alert callback
    pub fn setAlertCallback(self: *CallbackUIBackend, callback: *const fn (ctx: ?*anyopaque, message: []const u8) void) void {
        self.alert_callback = callback;
    }

    /// Set the confirm callback
    pub fn setConfirmCallback(self: *CallbackUIBackend, callback: *const fn (ctx: ?*anyopaque, message: []const u8) bool) void {
        self.confirm_callback = callback;
    }

    /// Set the prompt callback
    pub fn setPromptCallback(self: *CallbackUIBackend, callback: *const fn (ctx: ?*anyopaque, message: []const u8, default_value: []const u8) ?[]const u8) void {
        self.prompt_callback = callback;
    }

    /// Set the print callback
    pub fn setPrintCallback(self: *CallbackUIBackend, callback: *const fn (ctx: ?*anyopaque) void) void {
        self.print_callback = callback;
    }

    /// Get the UIBackend interface
    pub fn backend(self: *CallbackUIBackend) UIBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UIBackend.VTable{
        .showAlert = showAlert,
        .showConfirm = showConfirm,
        .showPrompt = showPrompt,
        .showPrint = showPrint,
        .freeString = freeString,
    };

    fn showAlert(ptr: *anyopaque, message: []const u8) void {
        const self: *CallbackUIBackend = @ptrCast(@alignCast(ptr));
        if (self.alert_callback) |cb| {
            cb(self.context, message);
        }
    }

    fn showConfirm(ptr: *anyopaque, message: []const u8) bool {
        const self: *CallbackUIBackend = @ptrCast(@alignCast(ptr));
        if (self.confirm_callback) |cb| {
            return cb(self.context, message);
        }
        return false;
    }

    fn showPrompt(ptr: *anyopaque, message: []const u8, default_value: []const u8) ?[]const u8 {
        const self: *CallbackUIBackend = @ptrCast(@alignCast(ptr));
        if (self.prompt_callback) |cb| {
            return cb(self.context, message, default_value);
        }
        return null;
    }

    fn showPrint(ptr: *anyopaque) void {
        const self: *CallbackUIBackend = @ptrCast(@alignCast(ptr));
        if (self.print_callback) |cb| {
            cb(self.context);
        }
    }

    fn freeString(ptr: *anyopaque, str: []const u8) void {
        const self: *CallbackUIBackend = @ptrCast(@alignCast(ptr));
        self.allocator.free(str);
    }
};

test "StubUIBackend - basic operations" {
    var backend_impl = StubUIBackend.init(.{
        .confirm_result = true,
        .log_calls = false,
    });
    const ui = backend_impl.backend();

    // Alert doesn't return anything
    ui.showAlert("Test message");

    // Confirm returns configured result
    try std.testing.expect(ui.showConfirm("Test?"));

    // Print doesn't return anything
    ui.showPrint();
}

test "StubUIBackend - with allocator" {
    const allocator = std.testing.allocator;

    var backend_impl = StubUIBackend.initWithAllocator(allocator, .{
        .prompt_result = "custom result",
    });
    const ui = backend_impl.backend();

    // Prompt returns allocated string
    if (ui.showPrompt("Enter name:", "default")) |result| {
        defer ui.freeString(result);
        try std.testing.expectEqualStrings("custom result", result);
    }
}

test "CallbackUIBackend - basic operations" {
    const allocator = std.testing.allocator;

    var alert_called = false;
    var confirm_called = false;
    var print_called = false;

    const TestContext = struct {
        alert_called: *bool,
        confirm_called: *bool,
        print_called: *bool,
    };

    var ctx = TestContext{
        .alert_called = &alert_called,
        .confirm_called = &confirm_called,
        .print_called = &print_called,
    };

    var backend_impl = CallbackUIBackend.init(allocator, &ctx);

    backend_impl.setAlertCallback(struct {
        fn callback(context: ?*anyopaque, _: []const u8) void {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.alert_called.* = true;
        }
    }.callback);

    backend_impl.setConfirmCallback(struct {
        fn callback(context: ?*anyopaque, _: []const u8) bool {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.confirm_called.* = true;
            return true;
        }
    }.callback);

    backend_impl.setPrintCallback(struct {
        fn callback(context: ?*anyopaque) void {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.print_called.* = true;
        }
    }.callback);

    const ui = backend_impl.backend();

    ui.showAlert("Test");
    try std.testing.expect(alert_called);

    try std.testing.expect(ui.showConfirm("Test?"));
    try std.testing.expect(confirm_called);

    ui.showPrint();
    try std.testing.expect(print_called);
}
