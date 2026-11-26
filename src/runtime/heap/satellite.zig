//! The satellite allocator (allocator-hardening batch B2, item 3): a Browser's
//! `std.mem.Allocator` over its heap's `.satellite` partition inside the node
//! cage (tmp/plans/allocator-hardening-design.md §§1.2, 3.1, 3.4, 3.5, 3.7, 7).
//!
//! Serves pointer-bearing and node-linked satellite blocks (rare blocks & their
//! own blocks, node targets' event listener lists, attribute entry blocks &
//! sharing cache, observer registrations, slot state lists, ElementStyle):
//! window-agent-only (lock-free, with owner-thread check), class-stable spans
//! inside the cage (ready for N10's 32-bit Links), full-block zero-on-free &
//! verify-on-issue (0xdd in poisoning builds), task-scoped quarantine, and
//! idle decommit.

const std = @import("std");
const heap = @import("root.zig");

pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

/// `engine`'s satellite allocator (window agent's thread only).
pub fn allocatorOf(engine: *heap.Engine) std.mem.Allocator {
    return .{ .ptr = engine, .vtable = &vtable };
}

/// The engine `allocator` allocates satellites from, when it is a satellite
/// allocator.
pub fn engineOf(allocator: std.mem.Allocator) ?*heap.Engine {
    if (allocator.vtable == &vtable) return @ptrCast(@alignCast(allocator.ptr));
    return null;
}

fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    return engine.allocSatellite(len, alignment.toByteUnits(), return_address) catch null;
}

fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = return_address;
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    return engine.resizesSatelliteInPlace(memory.len, new_len, alignment.toByteUnits());
}

fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
    return if (resize(context, memory, alignment, new_len, return_address)) memory.ptr else null;
}

fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
    _ = return_address;
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    engine.freeSatellite(memory.ptr, memory.len, alignment.toByteUnits());
}
