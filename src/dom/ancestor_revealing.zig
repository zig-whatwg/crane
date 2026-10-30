//! HTML ancestor revealing, installed by the details implementation.
//! lint-impls: hook for HTMLDetailsElement
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

// process-wide: immutable details revealing steps installed at process start, identical for every Browser and thread
var reveal_steps: ?*const fn (*runtime.Instance) void = null;

pub fn install(steps: *const fn (*runtime.Instance) void) void {
    process_start.assertInstalling();
    reveal_steps = steps;
}

pub fn reveal(target: *runtime.Instance) void {
    if (reveal_steps) |steps| steps(target);
}
