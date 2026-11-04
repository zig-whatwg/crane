//! Construction of copied DOMStringList snapshots, owned by DOMStringList.
//!
//! lint-impls: hook for DOMStringList
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

pub const Implementation = struct {
    create: *const fn (runtime.Context, []const []const u8) anyerror!*runtime.Instance,
};

// process-wide: hook table written once at process start by DOMStringList.installHooks (B0); comptime in B9
var implementation: Hook(?Implementation) = .init(null);

pub fn install(steps: Implementation) void {
    implementation.install(steps);
}

/// The owner copies strings; the caller retains the input storage.
pub fn create(ctx: runtime.Context, strings: []const []const u8) !*runtime.Instance {
    return (implementation.get() orelse return error.NotSupported).create(ctx, strings);
}
