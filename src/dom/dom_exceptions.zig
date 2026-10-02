//! lint-impls: hook for DOMException
//! Initialize the base slots of a DOMException-derived object.

const runtime = @import("runtime");
const process_start = @import("process_start.zig");

pub const Implementation = struct {
    initialize: *const fn (instance: *runtime.Instance, name: []const u8, message: []const u8) anyerror!void,
};

// process-wide: hook table written once at process start by DOMException.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

pub fn install(value: Implementation) void {
    process_start.assertInstalling();
    implementation = value;
}

pub fn initialize(instance: *runtime.Instance, name: []const u8, message: []const u8) !void {
    const hooks = implementation orelse return error.NotSupportedError;
    return hooks.initialize(instance, name, message);
}
