//! Subprocess fixture for tests/cli/crash_handler_test.zig: exercises the real
//! panic handler and fatal signal handler in a standalone binary built with
//! `strip = false`.

const std = @import("std");
const crash_handler = @import("crash_handler");

pub const build_info: crash_handler.BuildInfo = .{
    .version = "0.1.0-test",
    .git_sha = "deadbeef0",
};

pub const panic = crash_handler.PanicHandler(build_info);

pub const debug = struct {
    pub const handleSegfault = crash_handler.handleSegfault;
};

noinline fn triggerPanic() noreturn {
    @panic("intentional crash fixture panic");
}

noinline fn triggerAbort() noreturn {
    std.c.abort();
}

pub fn main(init: std.process.Init) !void {
    crash_handler.installSignalHandlers(build_info);
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) return;
    if (std.mem.eql(u8, args[1], "panic")) {
        triggerPanic();
    } else if (std.mem.eql(u8, args[1], "abort")) {
        triggerAbort();
    }
}
