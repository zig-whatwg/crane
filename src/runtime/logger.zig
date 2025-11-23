//! Runtime Logger for WebIDL Console API
//!
//! Provides colored logging output for console.log, console.error, console.warn, etc.
//! This logger is designed to match browser console behavior with color-coded output.
//!
//! ## Design
//!
//! The logger supports multiple log levels with color coding:
//! - LOG: Default output (no color prefix)
//! - INFO: Blue prefix "ℹ️ "
//! - WARN: Yellow prefix "⚠️ "
//! - ERROR: Red prefix "❌ "
//! - DEBUG: Gray prefix "🐛 "
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! var logger = runtime.Logger.init(allocator, .{ .colored = true });
//! defer logger.deinit();
//!
//! try logger.log("Hello, world!");
//! try logger.error("Something went wrong!");
//! try logger.warn("Deprecated API");
//! try logger.info("Server started on port 3000");
//! ```

const std = @import("std");

/// Log level enumeration
pub const LogLevel = enum {
    debug,
    log,
    info,
    warn,
    @"error",

    /// Get ANSI color code for this log level
    pub fn colorCode(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "\x1b[90m", // Gray
            .log => "\x1b[0m", // Default
            .info => "\x1b[34m", // Blue
            .warn => "\x1b[33m", // Yellow
            .@"error" => "\x1b[31m", // Red
        };
    }

    /// Get prefix emoji/symbol for this log level
    pub fn prefix(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "🐛 ",
            .log => "",
            .info => "ℹ️  ",
            .warn => "⚠️  ",
            .@"error" => "❌ ",
        };
    }

    /// Get label text for this log level
    pub fn label(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .log => "LOG",
            .info => "INFO",
            .warn => "WARN",
            .@"error" => "ERROR",
        };
    }
};

/// Logger configuration
pub const LoggerConfig = struct {
    /// Enable colored output (ANSI escape codes)
    colored: bool = true,

    /// Show timestamps in output
    show_timestamp: bool = false,

    /// Show log level labels
    show_labels: bool = false,
};

/// Runtime logger for console output
pub const Logger = struct {
    allocator: std.mem.Allocator,
    config: LoggerConfig,

    const Self = @This();

    /// ANSI color codes
    const Colors = struct {
        const reset = "\x1b[0m";
        const bold = "\x1b[1m";
        const dim = "\x1b[2m";
    };

    /// Initialize logger with configuration
    pub fn init(allocator: std.mem.Allocator, config: LoggerConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Deinitialize logger (currently no-op, but here for future extensions)
    pub fn deinit(_: *Self) void {
        // Future: Close files, flush buffers, etc.
    }

    /// Log a message at the specified level
    pub fn logAt(self: *Self, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
        // Use std.debug.print for output with colors
        // Print prefix (color + emoji)
        if (self.config.colored) {
            std.debug.print("{s}", .{level.colorCode()});
        }

        if (self.config.show_labels) {
            std.debug.print("[{s}] ", .{level.label()});
        }

        std.debug.print("{s}", .{level.prefix()});

        // Write timestamp if enabled
        if (self.config.show_timestamp) {
            const timestamp = std.time.timestamp();
            std.debug.print("[{d}] ", .{timestamp});
        }

        // Print the actual message
        std.debug.print(fmt, args);

        // Reset color
        if (self.config.colored) {
            std.debug.print("{s}", .{Colors.reset});
        }

        std.debug.print("\n", .{});
    }

    /// Log at DEBUG level
    pub fn debug(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.logAt(.debug, fmt, args);
    }

    /// Log at LOG level (default console.log)
    pub fn log(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.logAt(.log, fmt, args);
    }

    /// Log at INFO level
    pub fn info(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.logAt(.info, fmt, args);
    }

    /// Log at WARN level
    pub fn warn(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.logAt(.warn, fmt, args);
    }

    /// Log at ERROR level
    pub fn @"error"(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.logAt(.@"error", fmt, args);
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Logger - basic initialization" {
    var logger = Logger.init(testing.allocator, .{ .colored = false });
    defer logger.deinit();

    try testing.expect(logger.config.colored == false);
}

test "Logger - log at different levels" {
    var logger = Logger.init(testing.allocator, .{
        .colored = false,
    });
    defer logger.deinit();

    // Just test that logging doesn't crash
    try logger.log("Test message", .{});
    try logger.info("Info message", .{});
    try logger.warn("Warning message", .{});
    try logger.@"error"("Error message", .{});
}

test "Logger - colored output" {
    var logger = Logger.init(testing.allocator, .{
        .colored = true,
    });
    defer logger.deinit();

    // Just test that colored logging doesn't crash
    try logger.@"error"("Error!", .{});
}

test "Logger - format arguments work" {
    var logger = Logger.init(testing.allocator, .{
        .colored = false,
    });
    defer logger.deinit();

    // Just test that formatted logging doesn't crash
    try logger.log("Number: {d}, String: {s}", .{ 42, "hello" });
}

test "Logger - show labels option" {
    var logger = Logger.init(testing.allocator, .{
        .colored = false,
        .show_labels = true,
    });
    defer logger.deinit();

    // Just test that labeled logging doesn't crash
    try logger.warn("Warning!", .{});
}
