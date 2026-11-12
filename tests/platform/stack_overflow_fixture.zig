//! The stack-overflow fixture (lane tls1): a program that runs its stack out
//! on purpose, set up as Crane's roots are - no thread-local signal stack
//! from std (`std_options.signal_stack_size = null`), the thread's alternate
//! stack mapped by the platform's own code (src/platform/kit/posix/
//! signal_stack.zig, the `signal_stack` import), and Zig std's fault handler,
//! which std's start code installs SA_ONSTACK in every build with runtime
//! safety. build.zig builds it in ReleaseSafe (the release console and the
//! production WPT runner) and in Debug (the bug-finding runner's Crane
//! modules); tls1_stack_overflow_test.zig runs it and reads its stderr.
//!
//!   stack_overflow_fixture main                the main thread overflows
//!   stack_overflow_fixture thread              a spawned, attached thread overflows
//!   stack_overflow_fixture unattached-main     the control: nothing attached
//!   stack_overflow_fixture unattached-thread   the control, on a spawned thread
//!
//! An attached thread's overflow is REPORTED: the handler runs on the
//! alternate stack, prints "<fault> at address 0x..." and the trace, and
//! aborts - which this fixture turns into exit status `reported_exit`, so
//! that the operating system writes no crash report for a test. The two
//! controls are what a thread nobody attached gets (the JavaScript engine's
//! own worker threads, before this lane and after): the handler has no stack
//! to run on, the kernel kills the process with the fault's signal, and
//! nothing is printed. They are for a person to run - the tests do not, a
//! real crash being a crash report on macOS every time.

const std = @import("std");
const signal_stack = @import("signal_stack");

/// As Crane's roots: std attaches no signal stack of its own.
pub const std_options: std.Options = .{ .signal_stack_size = null };

/// The exit status of a run whose overflow was reported.
pub const reported_exit = 77;

/// The stack the overflowing thread gets: small, so the trace is a few
/// hundred frames and not the tens of thousands of a default stack.
const small_stack = 512 * 1024;

/// A frame of about 1 KiB that the optimizer must keep: under every page
/// size, so the recursion cannot step over the stack's guard page.
noinline fn overflow(depth: usize) usize {
    var frame: [1024]u8 = undefined;
    frame[depth % frame.len] = @truncate(depth);
    std.mem.doNotOptimizeAway(&frame);
    // Never a tail call: every level keeps its frame.
    return @call(.never_tail, overflow, .{depth + 1}) + frame[depth % frame.len];
}

fn attachedThread() void {
    // As the platform's thread start does (kit/posix threadMain).
    const stack = signal_stack.attach();
    defer signal_stack.detach(stack);
    _ = overflow(0);
}

fn unattachedThread() void {
    _ = overflow(0);
}

fn onAbort(_: std.posix.SIG) callconv(.c) void {
    std.c._exit(reported_exit);
}

/// Start this program again with a main-thread stack of `small_stack`: the
/// main thread's stack is sized from the limit when a program starts.
fn restartWithSmallStack(path: [*:0]const u8, mode: [*:0]const u8) noreturn {
    // The hard limit too: on Linux, Zig's start code raises the soft limit
    // to the stack size the program was linked for, as far as the hard one.
    var limits: std.c.rlimit = undefined;
    if (std.c.getrlimit(.STACK, &limits) == 0) {
        limits.cur = small_stack;
        limits.max = small_stack;
        _ = std.c.setrlimit(.STACK, &limits);
    }
    const argv = [_:null]?[*:0]const u8{ path, mode };
    _ = std.c.execve(path, &argv, @ptrCast(std.c.environ));
    std.c._exit(2);
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    const path = args.next() orelse return error.Usage;
    const mode = args.next() orelse return error.Usage;

    // std's handler ends by aborting. Exit instead, with a status the test
    // knows: the report is on stderr by then.
    const act: std.posix.Sigaction = .{ .handler = .{ .handler = onAbort }, .mask = std.posix.sigemptyset(), .flags = 0 };
    std.posix.sigaction(.ABRT, &act, null);

    if (std.mem.eql(u8, mode, "main")) restartWithSmallStack(path.ptr, "main-now");
    if (std.mem.eql(u8, mode, "unattached-main")) restartWithSmallStack(path.ptr, "unattached-main-now");
    if (std.mem.eql(u8, mode, "main-now")) {
        // As a root's `main` does first (platform.attachSignalStack).
        _ = signal_stack.attach();
        _ = overflow(0);
    } else if (std.mem.eql(u8, mode, "unattached-main-now")) {
        _ = overflow(0);
    } else if (std.mem.eql(u8, mode, "thread")) {
        _ = signal_stack.attach();
        const thread = try std.Thread.spawn(.{ .stack_size = small_stack }, attachedThread, .{});
        thread.join();
    } else if (std.mem.eql(u8, mode, "unattached-thread")) {
        _ = signal_stack.attach();
        const thread = try std.Thread.spawn(.{ .stack_size = small_stack }, unattachedThread, .{});
        thread.join();
    } else return error.Usage;
    // The overflow never returns.
    std.c._exit(3);
}
