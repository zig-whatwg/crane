//! A thread's alternate signal stack (docs/platform-protocol.md 6.4,
//! `attachSignalStack` / `detachSignalStack`; lane tls1): where the process's
//! fault handler runs when the thread's own stack is what ran out. The
//! platform maps it per thread - never thread-local storage, which every
//! thread that touches a thread-local pays for (Zig std's default,
//! `std.Options.signal_stack_size`, is a 256 KB threadlocal array).
//!
//! These tests read the kernel's own record of the calling thread's stack
//! (sigaltstack with no new stack). The report itself - a real stack overflow,
//! on the main thread and on a spawned one, in ReleaseSafe and in Debug - is
//! tls1_stack_overflow_test.zig's.
//!
//! This executable's root keeps std's signal stack (tests/test_runner: the
//! tests' own std.Thread.spawn threads rely on it), so a test that needs a
//! thread WITHOUT one starts a thread and takes std's away first.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

const testing = std.testing;
const posix = std.posix;

/// The size the platform's stack has at least: Zig std's own default.
const stack_bytes: usize = 1 << 18;

const supported = switch (builtin.os.tag) {
    .windows, .wasi => false,
    else => true,
};

const Stack = struct { base: usize, size: usize };

/// The calling thread's alternate signal stack as the kernel has it.
fn currentStack() ?Stack {
    var old: posix.stack_t = undefined;
    posix.sigaltstack(null, &old) catch return null;
    if (old.flags & std.c.SS.DISABLE != 0) return null;
    return .{ .base = @intFromPtr(old.sp), .size = @intCast(old.size) };
}

/// Take the calling thread's alternate signal stack away (std's, here).
fn disableStack() void {
    var disable: posix.stack_t = undefined;
    disable.sp = @ptrFromInt(std.heap.pageSize());
    disable.flags = std.c.SS.DISABLE;
    disable.size = @intCast(stack_bytes);
    posix.sigaltstack(&disable, null) catch {};
}

/// The exit status of a forked child whose read faulted.
const fault_exit = 42;

fn onFault(_: posix.SIG) callconv(.c) void {
    std.c._exit(fault_exit);
}

/// Whether reading one byte at `address` faults, in a forked child that
/// catches the fault and exits (h1_address_space_test.zig's probe: no crash
/// report is written for it).
fn faultsReading(address: usize) !bool {
    const pid = std.c.fork();
    if (pid < 0) return error.ForkFailed;
    if (pid == 0) {
        const act: posix.Sigaction = .{ .handler = .{ .handler = onFault }, .mask = posix.sigemptyset(), .flags = 0 };
        posix.sigaction(.SEGV, &act, null);
        posix.sigaction(.BUS, &act, null);
        const p: *const volatile u8 = @ptrFromInt(address);
        _ = p.*;
        std.c._exit(0);
    }
    var status: c_int = 0;
    if (std.c.waitpid(pid, &status, 0) != pid) return error.WaitFailed;
    const s: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(s)) return error.ChildDidNotExit;
    return switch (std.c.W.EXITSTATUS(s)) {
        0 => false,
        fault_exit => true,
        else => error.ChildFailed,
    };
}

/// What a platform thread saw of its own stack.
const Seen = struct {
    stack: ?Stack = null,
};

fn seeStack(context: ?*anyopaque) callconv(.c) void {
    const seen: *Seen = @ptrCast(@alignCast(context.?));
    seen.stack = currentStack();
}

test "a thread the platform starts has an alternate signal stack of at least 256 KB" {
    if (!supported) return error.SkipZigTest;
    var seen: Seen = .{};
    const thread = try platform.spawnThread(.{ .name = platform.Str.from("tls1-stack") }, seeStack, &seen);
    platform.joinThread(thread);
    const stack = seen.stack orelse return error.TestExpectedAlternateStack;
    try testing.expect(stack.size >= stack_bytes);
}

/// One run on a thread of its own; `failure` is what went wrong, if anything.
const Run = struct {
    body: *const fn () anyerror!void,
    failure: ?anyerror = null,

    fn entry(self: *Run) void {
        self.body() catch |err| {
            self.failure = err;
        };
    }
};

/// Run `body` on a new thread and return its error.
fn onOwnThread(body: *const fn () anyerror!void) !void {
    var run: Run = .{ .body = body };
    const thread = try std.Thread.spawn(.{}, Run.entry, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn attachesAndDetaches() anyerror!void {
    disableStack();
    try testing.expectEqual(@as(?Stack, null), currentStack());

    const page = std.heap.pageSize();
    const attached = platform.attachSignalStack();
    try testing.expect(attached.handle != 0);
    {
        errdefer platform.detachSignalStack(attached);
        // The kernel names the stack: whole pages of at least 256 KB, one
        // guard page above the mapping's start.
        const stack = currentStack() orelse return error.TestExpectedAlternateStack;
        try testing.expectEqual(attached.handle + page, stack.base);
        try testing.expectEqual(std.mem.alignForward(usize, stack_bytes, page), stack.size);
        // All of it can be written...
        const bytes: [*]volatile u8 = @ptrFromInt(stack.base);
        bytes[0] = 1;
        bytes[stack.size - 1] = 1;
        // ...and the page on each side of it cannot even be read: running off
        // either end faults instead of reaching a neighbouring mapping.
        try testing.expect(try faultsReading(stack.base - 1));
        try testing.expect(try faultsReading(stack.base + stack.size));
        try testing.expect(!try faultsReading(stack.base));
    }
    platform.detachSignalStack(attached);
    // The kernel no longer names it.
    try testing.expectEqual(@as(?Stack, null), currentStack());
}

test "attachSignalStack maps a thread's stack between two guard pages, and detachSignalStack takes it away" {
    if (!supported) return error.SkipZigTest;
    try onOwnThread(attachesAndDetaches);
}

fn keepsALargeEnoughStack() anyerror!void {
    // std's, attached by std.Thread.spawn in this executable: 256 KB.
    const before = currentStack() orelse return error.TestExpectedAlternateStack;
    try testing.expect(before.size >= stack_bytes);
    const attached = platform.attachSignalStack();
    defer platform.detachSignalStack(attached);
    try testing.expectEqual(@as(usize, 0), attached.handle);
    try testing.expectEqual(@as(?Stack, before), currentStack());
}

test "a thread that already has a stack at least as large keeps it" {
    if (!supported) return error.SkipZigTest;
    try onOwnThread(keepsALargeEnoughStack);
}

fn replacesASmallerStackAndPutsItBack() anyerror!void {
    // A stack someone else installed, too small for the handler's trace.
    const small_bytes = 64 * 1024;
    const small = try testing.allocator.alloc(u8, small_bytes);
    defer testing.allocator.free(small);
    var install: posix.stack_t = undefined;
    install.sp = small.ptr;
    install.flags = 0;
    install.size = @intCast(small_bytes);
    try posix.sigaltstack(&install, null);
    defer disableStack();

    const attached = platform.attachSignalStack();
    try testing.expect(attached.handle != 0);
    {
        errdefer platform.detachSignalStack(attached);
        const stack = currentStack() orelse return error.TestExpectedAlternateStack;
        try testing.expect(stack.size >= stack_bytes);
    }
    platform.detachSignalStack(attached);
    // The platform's replaced the smaller one, and its detach leaves the
    // thread with none (Crashpad's destructor: it puts a stack back only
    // when something replaced the platform's AFTER the attach): the kernel
    // is never left naming unmapped memory.
    try testing.expectEqual(@as(?Stack, null), currentStack());
}

test "a thread whose stack is smaller gets the platform's, and has none after the detach" {
    if (!supported) return error.SkipZigTest;
    try onOwnThread(replacesASmallerStackAndPutsItBack);
}
