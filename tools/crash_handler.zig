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

pub fn modeName(mode: std.builtin.OptimizeMode) []const u8 {
    return switch (mode) {
        .Debug => "Debug",
        .ReleaseSafe => "ReleaseSafe",
        .ReleaseFast => "ReleaseFast",
        .ReleaseSmall => "ReleaseSmall",
    };
}

pub const BuildInfo = struct {
    version: []const u8 = "0.1.0",
    git_sha: []const u8 = "unknown",
    build_mode: []const u8 = modeName(builtin.mode),
    os: []const u8 = @tagName(builtin.os.tag),
    arch: []const u8 = @tagName(builtin.cpu.arch),
    zig_version: []const u8 = builtin.zig_version_string,
    command: ?[]const u8 = null,
};

pub const CrashKind = union(enum) {
    panic: []const u8,
    signal: struct {
        name: []const u8,
        addr: ?usize = null,
    },
};

const max_command_len = 1024;
var active_info: BuildInfo = .{};
var command_buf: [max_command_len]u8 = undefined;
var command_len: std.atomic.Value(usize) = .init(0);
var crash_stage: std.atomic.Value(u8) = .init(0);

/// Record the sanitized process command line once at startup into static
/// storage so both panic and fatal-signal handlers can print it without
/// allocating memory.
pub fn recordCommandLine(args: []const []const u8) void {
    const formatted = formatCommandLine(&command_buf, args);
    command_len.store(formatted.len, .release);
}

/// Return the recorded command line slice, or `null` if none was recorded.
pub fn recordedCommandLine() ?[]const u8 {
    const len = command_len.load(.acquire);
    if (len == 0 or len > command_buf.len) return null;
    return command_buf[0..len];
}

/// Format `args` into `buf` for the crash banner:
/// - uses only the basename of `argv[0]` (avoids leaking local paths)
/// - redacts secret-bearing flag values and URL `user:pass@` credentials
/// - single-quotes arguments containing whitespace or shell metacharacters
/// - truncates cleanly with ` ...` if the full command exceeds `buf.len`
pub fn formatCommandLine(buf: []u8, args: []const []const u8) []const u8 {
    if (args.len == 0 or buf.len == 0) return buf[0..0];

    var pos: usize = 0;
    var truncated = false;
    var redact_next = false;

    for (args, 0..) |raw_arg, idx| {
        if (idx > 0) {
            if (!appendRaw(buf, &pos, " ")) {
                truncated = true;
                break;
            }
        }

        if (idx == 0) {
            const base = std.fs.path.basename(raw_arg);
            if (!appendShellArg(buf, &pos, if (base.len > 0) base else raw_arg)) {
                truncated = true;
                break;
            }
            continue;
        }

        if (redact_next) {
            redact_next = false;
            if (!appendRaw(buf, &pos, "<redacted>")) {
                truncated = true;
                break;
            }
            continue;
        }

        if (std.mem.startsWith(u8, raw_arg, "-")) {
            if (std.mem.indexOfScalar(u8, raw_arg, '=')) |eq| {
                const flag = raw_arg[0..eq];
                const val = raw_arg[eq + 1 ..];
                if (isSensitiveFlagName(flag)) {
                    if (!appendRaw(buf, &pos, flag) or !appendRaw(buf, &pos, "=<redacted>")) {
                        truncated = true;
                        break;
                    }
                    continue;
                }
                if (hasUrlCredentials(val)) {
                    if (!appendRaw(buf, &pos, flag) or !appendRaw(buf, &pos, "=") or !appendSanitizedUrlArg(buf, &pos, val)) {
                        truncated = true;
                        break;
                    }
                    continue;
                }
            } else if (isSensitiveFlagName(raw_arg)) {
                redact_next = true;
                if (!appendRaw(buf, &pos, raw_arg)) {
                    truncated = true;
                    break;
                }
                continue;
            }
        }

        if (hasUrlCredentials(raw_arg)) {
            if (!appendSanitizedUrlArg(buf, &pos, raw_arg)) {
                truncated = true;
                break;
            }
        } else if (!appendShellArg(buf, &pos, raw_arg)) {
            truncated = true;
            break;
        }
    }

    if (truncated) {
        const suffix = " ...";
        if (buf.len >= suffix.len) {
            const cut = @min(pos, buf.len - suffix.len);
            @memcpy(buf[cut .. cut + suffix.len], suffix);
            pos = cut + suffix.len;
        }
    }
    return buf[0..pos];
}

fn isSensitiveFlagName(flag: []const u8) bool {
    const trimmed = std.mem.trimStart(u8, flag, "-");
    return containsAsciiCaseInsensitive(trimmed, "token") or
        containsAsciiCaseInsensitive(trimmed, "password") or
        containsAsciiCaseInsensitive(trimmed, "passwd") or
        containsAsciiCaseInsensitive(trimmed, "secret") or
        containsAsciiCaseInsensitive(trimmed, "api-key") or
        containsAsciiCaseInsensitive(trimmed, "apikey") or
        containsAsciiCaseInsensitive(trimmed, "auth");
}

fn containsAsciiCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

fn hasUrlCredentials(s: []const u8) bool {
    const scheme_end = std.mem.indexOf(u8, s, "://") orelse return false;
    const after_scheme = s[scheme_end + 3 ..];
    const auth_end = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
    const authority = after_scheme[0..auth_end];
    return std.mem.indexOfScalar(u8, authority, '@') != null;
}

fn appendSanitizedUrlArg(buf: []u8, pos: *usize, s: []const u8) bool {
    const scheme_end = std.mem.indexOf(u8, s, "://") orelse return appendShellArg(buf, pos, s);
    const after_scheme = s[scheme_end + 3 ..];
    const auth_end = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
    const authority = after_scheme[0..auth_end];
    const at = std.mem.lastIndexOfScalar(u8, authority, '@') orelse return appendShellArg(buf, pos, s);

    const prefix = s[0 .. scheme_end + 3];
    const rest = after_scheme[at + 1 ..];
    const quote = needsShellQuoting(prefix) or needsShellQuoting(rest);
    if (quote and !appendRaw(buf, pos, "'")) return false;
    if (!appendQuotedBody(buf, pos, prefix, quote)) return false;
    if (!appendRaw(buf, pos, "<redacted>@")) return false;
    if (!appendQuotedBody(buf, pos, rest, quote)) return false;
    if (quote and !appendRaw(buf, pos, "'")) return false;
    return true;
}

fn needsShellQuoting(s: []const u8) bool {
    if (s.len == 0) return true;
    for (s) |c| {
        switch (c) {
            ' ', '\t', '\n', '\r', '\'', '"', '\\', '$', '`', '<', '>', '|', '&', ';', '(', ')', '*', '?', '[', ']', '{', '}', '!', '#', '~' => return true,
            else => if (c < 0x20 or c == 0x7f) return true,
        }
    }
    return false;
}

fn appendShellArg(buf: []u8, pos: *usize, arg: []const u8) bool {
    const quote = needsShellQuoting(arg);
    if (!quote) return appendRaw(buf, pos, arg);
    if (!appendRaw(buf, pos, "'")) return false;
    if (!appendQuotedBody(buf, pos, arg, true)) return false;
    return appendRaw(buf, pos, "'");
}

fn appendQuotedBody(buf: []u8, pos: *usize, s: []const u8, quote: bool) bool {
    if (!quote) return appendRaw(buf, pos, s);
    for (s) |c| {
        if (c == '\'') {
            if (!appendRaw(buf, pos, "'\\''")) return false;
        } else {
            if (!appendRaw(buf, pos, &.{c})) return false;
        }
    }
    return true;
}

fn appendRaw(buf: []u8, pos: *usize, s: []const u8) bool {
    if (pos.* + s.len > buf.len) return false;
    @memcpy(buf[pos.* .. pos.* + s.len], s);
    pos.* += s.len;
    return true;
}

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
    if (info.command) |cmd| {
        if (cmd.len > 0) {
            try writer.print("Command:    {s}\n", .{cmd});
        }
    }
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
    try writer.writeAll("     Include the version, build, command, cause, and full stack trace\n");
    try writer.writeAll("     above, plus a minimal URL/HTML reproduction if not already in the\n");
    try writer.writeAll("     command.\n");
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

                    var effective_info = info;
                    if (effective_info.command == null) {
                        effective_info.command = recordedCommandLine();
                    }
                    writeHeader(stderr.writer, effective_info, .{ .panic = msg }) catch break :trace;
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

            var effective_info = active_info;
            if (effective_info.command == null) {
                effective_info.command = recordedCommandLine();
            }
            writeHeader(stderr.writer, effective_info, .{ .signal = .{ .name = name, .addr = addr } }) catch break :trace;
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
