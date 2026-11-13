//! Crane WebDriver Browser
//!
//! Command-line browser that implements WebDriver protocol for WPT testing.
//!
//! ## Usage
//!
//! ```bash
//! # Start WebDriver server on default port (9515)
//! crane
//!
//! # Start on custom port
//! crane --port 4444
//!
//! # Verbose logging
//! crane --verbose
//! ```
//!
//! ## WPT Integration
//!
//! This binary is controlled by wptrunner via WebDriver:
//!
//! ```bash
//! cd tests/wpt
//! ./wpt run crane /url/url-constructor.html
//! ```

const std = @import("std");

// No thread-local signal stack: Zig std's default (`signal_stack_size`,
// 1 << 18) is a 256 KB thread-local array, which every thread that touches
// any thread-local pays for - V8's worker threads included, which never use
// it. The platform maps each thread's alternate stack instead
// (platform.attachSignalStack, src/platform/kit/posix/signal_stack.zig);
// build.zig's thread-local block check (tools/thread_local_size.zig) holds it.
pub const std_options: std.Options = .{ .signal_stack_size = null };
const engine = @import("engine");
const host = @import("host");
// The server through the `webdriver` module, not by relative path: server.zig
// is that module's file, and one file cannot belong to two modules of a compile.
const webdriver = @import("webdriver");
const Server = webdriver.Server;
const Config = webdriver.Config;

/// Zig 0.16 removed std.heap.GeneralPurposeAllocator and std.process.argsAlloc:
/// std.process.Init carries the gpa (std.start's DebugAllocator in Debug builds,
/// which reports leaks when main returns, as the GPA's deinit did), the argument
/// vector and the process Io.
pub fn main(init: std.process.Init) !void {
    // The main thread's alternate signal stack, for the life of the process
    // (platform 6.4): std_options sets std's own off.
    _ = @import("platform").attachSignalStack();
    // First, before any thread exists: the engine's per-process state that
    // only threads created after it inherit (V8's thread isolation key on
    // x86-64 Linux; docs/engine-protocol.md 4.1).
    engine.initializeBeforeThreadCreation();
    // Adopt the Io std.start built rather than letting host.io() build a second
    // one (src/platform/host.zig: one Io.Threaded per process).
    host.adopt(init.io);
    const allocator = init.gpa;

    // Parse command line arguments. `toSlice` may point into the argument
    // vector, so it is given the process-lifetime arena rather than the gpa.
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var config = Config{};

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") or std.mem.eql(u8, args[i], "-p")) {
            i += 1;
            if (i >= args.len) {
                try printUsage();
                return;
            }
            config.port = std.fmt.parseInt(u16, args[i], 10) catch {
                std.debug.print("Invalid port number: {s}\n", .{args[i]});
                return;
            };
        } else if (std.mem.eql(u8, args[i], "--host") or std.mem.eql(u8, args[i], "-h")) {
            i += 1;
            if (i >= args.len) {
                try printUsage();
                return;
            }
            config.host = args[i];
        } else if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
            // Verbose mode: would need build-time configuration in Zig 0.15+
        } else if (std.mem.eql(u8, args[i], "--help")) {
            try printUsage();
            return;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{args[i]});
            try printUsage();
            return;
        }
    }

    // Print banner
    std.debug.print(
        \\
        \\  ██████╗██████╗  █████╗ ███╗   ██╗███████╗
        \\ ██╔════╝██╔══██╗██╔══██╗████╗  ██║██╔════╝
        \\ ██║     ██████╔╝███████║██╔██╗ ██║█████╗
        \\ ██║     ██╔══██╗██╔══██║██║╚██╗██║██╔══╝
        \\ ╚██████╗██║  ██║██║  ██║██║ ╚████║███████╗
        \\  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝
        \\
        \\ Crane WebDriver Browser v0.1.0
        \\ WebDriver endpoint: http://{s}:{d}
        \\
        \\
    , .{ config.host, config.port });

    // Start server
    var server = Server.init(allocator, config);
    defer server.deinit();

    // Set up signal handler for graceful shutdown
    const handler = struct {
        // process-wide: a signal handler takes no context argument, so the one server this WebDriver executable runs is reached through it; set once by main before the handler can run, on main's thread, and only read after
        var server_ptr: *Server = undefined;

        fn handle(_: c_int) callconv(.C) void {
            std.debug.print("\nShutting down...\n", .{});
            server_ptr.stop();
        }
    };
    handler.server_ptr = &server;

    // Note: Signal handling may need platform-specific implementation
    // For now, Ctrl+C will still work via default behavior

    try server.run();
}

fn printUsage() !void {
    const usage =
        \\Usage: crane [OPTIONS]
        \\
        \\Crane WebDriver Browser - W3C WebDriver compatible browser for testing
        \\
        \\Options:
        \\  -p, --port PORT    Port to listen on (default: 9515)
        \\  -h, --host HOST    Host to bind to (default: 127.0.0.1)
        \\  -v, --verbose      Enable verbose logging
        \\      --help         Show this help message
        \\
        \\Examples:
        \\  crane                    Start with defaults
        \\  crane --port 4444        Start on port 4444
        \\  crane --verbose          Start with debug logging
        \\
        \\WPT Usage:
        \\  cd tests/wpt
        \\  ./wpt run crane /url/url-constructor.html
        \\
    ;
    std.debug.print("{s}", .{usage});
}
