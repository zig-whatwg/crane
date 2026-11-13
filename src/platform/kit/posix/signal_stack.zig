//! kit/posix: a thread's alternate signal stack (docs/platform-protocol.md
//! 6.4, `attachSignalStack` / `detachSignalStack`; lane tls1, 2026-11-11).
//!
//! WHAT IT IS FOR. A fault handler runs on the stack of the thread that
//! faulted - unless that thread has an alternate signal stack and the handler
//! was installed SA_ONSTACK. When the fault IS the thread's stack running out,
//! there is no room to run the handler on it: without an alternate stack the
//! kernel kills the process and nothing is reported. Zig std's fault handler
//! (std.debug.attachSegfaultHandler, on in every build with runtime safety:
//! Debug and ReleaseSafe, so the release console and both WPT runners) is
//! installed SA_ONSTACK for exactly this, and it is what prints "Segmentation
//! fault at address ..." and the trace of a stack overflow.
//!
//! WHY NOT STD'S. Std supplies that stack itself when
//! `std.Options.signal_stack_size` is set (default 1 << 18):
//! `std.Thread.maybeAttachSignalStack` declares
//! `threadlocal var signal_stack: [size]u8` and runs on the main thread and
//! on every `std.Thread.spawn` thread. A thread-local array is paid for by
//! threads that never use it: on macOS the first touch of ANY thread-local of
//! an image makes dyld allocate and fill that image's whole thread-local
//! block for the thread (278,528 bytes with this array in it), and glibc
//! allocates and clears the block with every thread it creates. V8's worker
//! threads are not std threads - they never had an alternate stack - yet each
//! one that touched a thread-local paid for the array: +3.6 MB per process on
//! a 14-core host once V8 15.7's threads did (tmp/plans/tls1-evidence.md).
//! Std offers no hook for a caller-supplied stack (the size is its only
//! setting), so Crane's roots set `signal_stack_size = null` and the stack is
//! mapped here.
//!
//! HOW, AS THE BROWSERS DO. Chromium's Crashpad, on Linux, Android and
//! ChromeOS, gives each thread its alternate stack explicitly:
//! CrashpadClient::InitializeSignalStackForThread
//! (third_party/crashpad/crashpad/client/crashpad_client_linux.cc) maps the
//! stack with a guard page on each side (mmap PROT_NONE, then mprotect of the
//! middle), installs it with sigaltstack, leaves a thread alone that already
//! has one large enough, and unmaps it when the thread ends; its handler is
//! installed SA_ONSTACK (SignalHandler::Install), and pthread_create_linux.cc
//! runs the set-up at the start of every thread. That is the design here.
//! Neither Chromium nor WebKit keeps a signal stack in thread-local storage;
//! on macOS both take faults through a Mach exception port on another thread
//! (WebKit: Source/WTF/wtf/threads/Signals.cpp) and need no alternate stack.
//!
//! A mapped stack is committed lazily: one that is never used - every one,
//! in a process that does not crash - costs address space and no memory.
//!
//! This file imports only std: build.zig also compiles it into the
//! stack-overflow fixture (tests/platform/stack_overflow_fixture.zig), which
//! proves the report end to end.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

/// The stack's usable bytes: what Zig std gives the same handler by default
/// (`std.Options.signal_stack_size`, 1 << 18; std.zig says 1 << 17 was
/// observed to be enough to trace a stack with the self-hosted x86_64
/// backend). The handler walks DWARF unwind information on it.
pub const stack_bytes: usize = 1 << 18;

/// Targets with POSIX alternate signal stacks. Std's own attach skips the
/// same two: Windows runs vectored exception handlers on the faulting
/// thread's stack, and WASI has no signals.
const supported = switch (builtin.os.tag) {
    .windows, .wasi => false,
    else => true,
};

/// The mapping's parts, for the running system's page size: a guard page,
/// the stack (whole pages), a guard page.
const Layout = struct {
    guard: usize,
    usable: usize,

    fn now() Layout {
        const page = std.heap.pageSize();
        return .{ .guard = page, .usable = std.mem.alignForward(usize, stack_bytes, page) };
    }

    fn total(self: Layout) usize {
        return self.usable + 2 * self.guard;
    }
};

/// The calling thread's alternate signal stack, as the kernel has it: null
/// when it has none (or the target has no such thing).
pub const Current = struct { base: usize, size: usize };

pub fn current() ?Current {
    if (!supported) return null;
    var old: posix.stack_t = undefined;
    posix.sigaltstack(null, &old) catch return null;
    if (old.flags & std.c.SS.DISABLE != 0) return null;
    return .{ .base = @intFromPtr(old.sp), .size = @intCast(old.size) };
}

/// Give the calling thread an alternate signal stack of `stack_bytes`,
/// unless it has one at least that large. Returns the mapping's address -
/// the handle `detach` takes - or 0 when it made nothing: the thread kept
/// the stack it had, the target has none, or the system refused the
/// mapping (the thread then runs as a thread nobody attached: a stack
/// overflow on it is not reported).
pub fn attach() usize {
    if (!supported) return 0;
    // 1. A thread that already has a stack large enough keeps it (Crashpad:
    //    `if (stack.ss_flags & SS_DISABLE || stack.ss_size < kStackSize)`):
    //    a root that kept std's, an embedder's own.
    if (current()) |existing| {
        if (existing.size >= stack_bytes) return 0;
    }
    // 2. Map guard page + stack + guard page with no access, then open the
    //    stack: running off either end of it faults instead of writing over
    //    a neighbouring mapping.
    const layout = Layout.now();
    const mapping = posix.mmap(null, layout.total(), .{}, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0) catch return 0;
    const stack: [*]u8 = mapping.ptr + layout.guard;
    if (std.c.mprotect(@ptrCast(@alignCast(stack)), layout.usable, .{ .READ = true, .WRITE = true }) != 0) {
        posix.munmap(mapping);
        return 0;
    }
    // 3. Install it. The handler that uses it is the root's (std's fault
    //    handler, SA_ONSTACK).
    var installed: posix.stack_t = undefined;
    installed.sp = stack;
    installed.flags = 0;
    installed.size = @intCast(layout.usable);
    posix.sigaltstack(&installed, null) catch {
        posix.munmap(mapping);
        return 0;
    };
    return @intFromPtr(mapping.ptr);
}

/// Release what `attach` returned, on the thread that attached it, before
/// the thread ends. 0 is nothing.
pub fn detach(handle: usize) void {
    if (handle == 0) return;
    const layout = Layout.now();
    const mapping: [*]align(std.heap.page_size_min) u8 = @ptrFromInt(handle);
    const stack: [*]u8 = mapping + layout.guard;
    // The kernel must stop naming the stack before it is unmapped. As
    // Crashpad's thread-exit destructor does: disable, and if the stack that
    // was installed is not this one - something replaced it since - put that
    // one back.
    var disable: posix.stack_t = undefined;
    disable.sp = stack;
    disable.flags = std.c.SS.DISABLE;
    disable.size = @intCast(layout.usable);
    var old: posix.stack_t = undefined;
    if (posix.sigaltstack(&disable, &old)) |_| {
        if (old.flags & std.c.SS.DISABLE == 0 and old.sp != stack) {
            // Only "enabled" is put back: the kernel refuses the status bits
            // it reports (SS_ONSTACK) as settings.
            old.flags = 0;
            posix.sigaltstack(&old, null) catch {};
        }
    } else |_| {}
    posix.munmap(mapping[0..layout.total()]);
}
