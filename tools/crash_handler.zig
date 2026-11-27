//! Custom panic and fatal-signal crash handler for the shipped `crane` CLI.
//!
//! Exports:
//! - `PanicHandler(comptime info)` -> `pub const panic = crash_handler.PanicHandler(build_info);`
//! - `handleSegfault` -> `pub const debug = struct { pub const handleSegfault = crash_handler.handleSegfault; };`
//! - `installSignalHandlers(info)` -> installs POSIX handlers for SIGSEGV, SIGABRT,
//!   SIGBUS, SIGILL, and SIGFPE using the thread's alternate signal stack (`SA.ONSTACK`).
//! - Pure `writeHeader` / `writeFooter` formatting helpers for unit testing.

const std = @import("std");
const builtin = @import("builtin");

pub const issues_url = "https://github.com/zig-whatwg/crane/issues";
pub const issue_url = "https://github.com/zig-whatwg/crane/issues/new";

pub const BuildInfo = struct {
    version: []const u8 = "0.1.0",
    git_sha: []const u8 = "unknown",
    build_mode: []const u8 = @tagName(builtin.mode),
    os: []const u8 = @tagName(builtin.os.tag),
    arch: []const u8 = @tagName(builtin.cpu.arch),
    zig_version: []const u8 = builtin.zig_version_string,
};

pub const CrashKind = union(enum) {
    panic: []const u8,
    signal: struct {
        name: []const u8,
        addr: ?usize = null,
    },
};

var active_info: BuildInfo = .{};
var crash_stage: std.atomic.Value(u8) = .init(0);

/// Write the crash report header before the symbolized stack trace.
pub fn writeHeader(writer: *std.Io.Writer, info: BuildInfo, kind: CrashKind) std.Io.Writer.Error!void {
    try writer.writeAll("\n========================================================================\n");
    try writer.writeAll("Crane crashed unexpectedly!\n");
    try writer.writeAll("========================================================================\n");
    try writer.print("Version:    crane {s} ({s})\n", .{ info.version, info.git_sha });
    try writer.print("Build:      {s} ({s}-{s}, Zig {s})\n", .{
        info.build_mode,
        info.os,
        info.arch,
        info.zig_version,
    });
    switch (kind) {
        .panic => |msg| try writer.print("Cause:      panic: {s}\n", .{msg}),
        .signal => |sig| {
            if (sig.addr) |a| {
                try writer.print("Cause:      signal: {s} at address 0x{x}\n", .{ sig.name, a });
            } else {
                try writer.print("Cause:      signal: {s}\n", .{sig.name});
            }
        },
    }
    try writer.writeAll("------------------------------------------------------------------------\n");
    try writer.writeAll("Stack trace:\n");
}

/// Write copy/paste-ready bug-report and triage instructions (for a human or
/// browser AI agent) after the stack trace.
pub fn writeFooter(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("------------------------------------------------------------------------\n");
    try writer.writeAll("Bug report & triage instructions (copy/paste this entire block to a\n");
    try writer.writeAll("human or AI agent):\n\n");
    try writer.print("  1. Search existing issues (both open and closed) before filing:\n       {s}\n\n", .{issues_url});
    try writer.writeAll("  2. If a matching CLOSED issue is found:\n");
    try writer.writeAll("     - Closed as `wontfix` / not planned: do NOT file a new issue;\n");
    try writer.writeAll("       explain to the user why it was closed.\n");
    try writer.writeAll("     - Fixed and already released: do NOT file a new issue; suggest\n");
    try writer.writeAll("       that the user upgrade Crane to get the bugfix.\n");
    try writer.writeAll("     - Fixed but not yet released: do NOT file a new issue; let the\n");
    try writer.writeAll("       user know they can try the nightly release channel.\n\n");
    try writer.writeAll("  3. If a matching OPEN issue already exists:\n");
    try writer.writeAll("     - Do NOT open a duplicate. If this stack trace, OS/arch, or\n");
    try writer.writeAll("       reproduction adds useful diagnostic data, add it as a comment\n");
    try writer.writeAll("       on that issue.\n\n");
    try writer.print("  4. Otherwise, open a new issue at:\n       {s}\n", .{issue_url});
    try writer.writeAll("     Include:\n");
    try writer.writeAll("     - The Crane version, commit SHA, build mode, and OS/arch above\n");
    try writer.writeAll("     - The exact `crane` command and flags run\n");
    try writer.writeAll("     - The URL or minimal HTML reproduction\n");
    try writer.writeAll("     - The full stack trace above\n");
    try writer.writeAll("========================================================================\n");
}

/// Build a `root.panic` namespace carrying `info` at comptime so even an
/// early panic before `main` reports the exact Crane version and commit SHA.
pub fn PanicHandler(comptime info: BuildInfo) type {
    const Impl = struct {
        fn call(msg: []const u8, first_trace_addr: ?usize) noreturn {
            @branchHint(.cold);
            resetSignalHandlers();

            const prev = crash_stage.swap(1, .seq_cst);
            if (prev == 0) {
                trace: {
                    const stderr = std.debug.lockStderr(&.{}).terminal();
                    defer std.debug.unlockStderr();

                    writeHeader(stderr.writer, info, .{ .panic = msg }) catch break :trace;
                    if (@errorReturnTrace()) |t| if (t.index > 0) {
                        stderr.writer.writeAll("Error return trace:\n") catch break :trace;
                        std.debug.writeErrorReturnTrace(t, stderr) catch break :trace;
                        stderr.writer.writeAll("\nStack trace:\n") catch break :trace;
                    };
                    std.debug.writeCurrentStackTrace(.{
                        .first_address = first_trace_addr orelse @returnAddress(),
                        .allow_unsafe_unwind = true,
                    }, stderr) catch break :trace;
                    writeFooter(stderr.writer) catch break :trace;
                }
            } else if (prev == 1) {
                crash_stage.store(2, .seq_cst);
                const stderr = std.debug.lockStderr(&.{}).terminal();
                stderr.writer.writeAll("aborting due to recursive panic\n") catch {};
            }
            std.process.abort();
        }
    };
    return std.debug.FullPanic(Impl.call);
}

/// Override for `root.debug.handleSegfault` so std's segfault hook routes
/// through Crane's crash banner as well.
pub fn handleSegfault(addr: ?usize, name: []const u8, opt_ctx: ?std.debug.CpuContextPtr) noreturn {
    @branchHint(.cold);
    resetSignalHandlers();
    handleCrashSignal(addr, name, opt_ctx);
}

/// Install fatal signal handlers for SIGSEGV, SIGABRT, SIGBUS, SIGILL, and
/// SIGFPE using the thread's alternate signal stack (`SA.ONSTACK`).
pub fn installSignalHandlers(info: BuildInfo) void {
    active_info = info;
    if (comptime builtin.os.tag == .windows or !std.debug.have_segfault_handling_support) return;

    const act: std.posix.Sigaction = .{
        .handler = .{ .sigaction = handleFatalSignalPosix },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.SIGINFO | std.posix.SA.RESETHAND | std.posix.SA.ONSTACK,
    };
    setFatalSignals(&act);
}

/// Restore all fatal signals to their default dispositions before aborting or
/// unwinding so a secondary fault or `std.process.abort()` never recurses.
pub fn resetSignalHandlers() void {
    if (comptime builtin.os.tag == .windows or !std.debug.have_segfault_handling_support) return;

    const dfl: std.posix.Sigaction = .{
        .handler = .{ .handler = std.posix.SIG.DFL },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    setFatalSignals(&dfl);
}

fn setFatalSignals(act: *const std.posix.Sigaction) void {
    std.posix.sigaction(.SEGV, act, null);
    std.posix.sigaction(.ABRT, act, null);
    std.posix.sigaction(.BUS, act, null);
    std.posix.sigaction(.ILL, act, null);
    std.posix.sigaction(.FPE, act, null);
}

fn handleFatalSignalPosix(sig: std.posix.SIG, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) noreturn {
    @branchHint(.cold);
    resetSignalHandlers();

    const addr: ?usize, const name: []const u8 = extractSignalInfo(sig, info);
    const opt_ctx: ?std.debug.cpu_context.Native = std.debug.cpu_context.fromPosixSignalContext(ctx_ptr);
    handleCrashSignal(addr, name, if (opt_ctx) |*ctx| ctx else null);
}

fn extractSignalInfo(sig: std.posix.SIG, info: *const std.posix.siginfo_t) struct { ?usize, []const u8 } {
    const name: []const u8 = switch (sig) {
        .SEGV => "SIGSEGV (Segmentation fault)",
        .ABRT => "SIGABRT (Aborted)",
        .BUS => "SIGBUS (Bus error)",
        .ILL => "SIGILL (Illegal instruction)",
        .FPE => "SIGFPE (Arithmetic exception)",
        else => "Fatal signal",
    };
    if (sig == .ABRT) return .{ null, name };
    if (comptime builtin.os.tag == .linux and builtin.cpu.arch == .x86_64) {
        const SI_KERNEL = 0x80;
        if (sig == .SEGV and info.code == SI_KERNEL) {
            return .{ null, "SIGSEGV (General protection exception)" };
        }
    }
    const addr: ?usize = switch (builtin.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst, .driverkit, .freebsd, .dragonfly, .haiku, .serenity => @intFromPtr(info.addr),
        .linux => @intFromPtr(info.fields.sigfault.addr),
        .netbsd => @intFromPtr(info.info.reason.fault.addr),
        .openbsd => @intFromPtr(info.data.fault.addr),
        .illumos => @intFromPtr(info.reason.fault.addr),
        else => null,
    };
    return .{ addr, name };
}

fn handleCrashSignal(addr: ?usize, name: []const u8, opt_ctx: ?std.debug.CpuContextPtr) noreturn {
    @branchHint(.cold);
    const prev = crash_stage.swap(1, .seq_cst);
    if (prev == 0) {
        trace: {
            const stderr = std.debug.lockStderr(&.{}).terminal();
            defer std.debug.unlockStderr();

            writeHeader(stderr.writer, active_info, .{ .signal = .{ .name = name, .addr = addr } }) catch break :trace;
            std.debug.writeCurrentStackTrace(.{
                .context = opt_ctx,
                .allow_unsafe_unwind = true,
            }, stderr) catch break :trace;
            writeFooter(stderr.writer) catch break :trace;
        }
    } else if (prev == 1) {
        crash_stage.store(2, .seq_cst);
        const stderr = std.debug.lockStderr(&.{}).terminal();
        stderr.writer.writeAll("aborting due to recursive crash\n") catch {};
    }
    std.process.abort();
}
