//! HTML ancestor revealing, installed by the details implementation.
//! lint-impls: hook for HTMLDetailsElement
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

// process-wide: immutable details revealing steps installed at process start, identical for every Browser and thread
var reveal_steps: Hook(?*const fn (*runtime.Instance) void) = .init(null);

pub fn install(steps: *const fn (*runtime.Instance) void) void {
    reveal_steps.install(steps);
}

pub fn reveal(target: *runtime.Instance) void {
    if (reveal_steps.get()) |steps| steps(target);
}
