//! Implementation for the NavigatorConcurrentHardware mixin (HTML 8.9.1.7):
//! hardwareConcurrency, shared by Navigator and WorkerNavigator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NavigatorConcurrentHardware = interfaces.NavigatorConcurrentHardware;

pub const State = NavigatorConcurrentHardware.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for hardwareConcurrency (HTML 8.9.1.7): returns the number of
/// logical processors available to run threads.
pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    const cpu_count = std.Thread.getCpuCount() catch 1;
    return @intCast(cpu_count);
}
