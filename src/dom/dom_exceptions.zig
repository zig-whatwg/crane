//! lint-impls: hook for DOMException
//! Initialize the base slots of a DOMException-derived object.

const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

pub const Implementation = struct {
    initialize: *const fn (instance: *runtime.Instance, name: []const u8, message: []const u8) anyerror!void,
};

// process-wide: hook table written once at process start by DOMException.installHooks (B0); comptime in B9
var implementation: Hook(?Implementation) = .init(null);

pub fn install(value: Implementation) void {
    implementation.install(value);
}

pub fn initialize(instance: *runtime.Instance, name: []const u8, message: []const u8) !void {
    const hooks = implementation.get() orelse return error.NotSupportedError;
    return hooks.initialize(instance, name, message);
}
