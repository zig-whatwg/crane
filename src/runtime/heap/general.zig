//! The general allocator (allocator-hardening batch B, item 2): a Browser's
//! `std.mem.Allocator` - what its realms (`ctx.allocator`), its agents, its
//! tables and its states (`allocatorOf`) allocate with - over its heap's
//! objects and bytes partitions (tmp/plans/allocator-hardening-design.md 3.1,
//! 4.1, section 7 batch B).
//!
//! ROUTING WITH NO CHANGE AT THE CALL SITES: a call is routed by its
//! alignment. Below a pointer's (1, 2 or 4 bytes) the block cannot hold a
//! pointer, so it goes to BYTES - Zig gives a struct with a pointer field at
//! least a pointer's alignment, so `u8`/`u16` buffers, `dupe(u8, ...)` and
//! counted value records go there by themselves; at a pointer's or more it
//! goes to OBJECTS. A free and a resize carry the allocation's alignment, so
//! they route the same way - and a free is routed by its ADDRESS besides,
//! then validated against the size and alignment it gives (Engine.
//! freeGeneral). The one exception, a pointer field declared align(1) or
//! align(2), is batch C's lint.
//!
//! This is the shared path, under each partition's lock (Engine.
//! allocGeneral).

const std = @import("std");
const heap = @import("root.zig");

pub const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

/// `engine`'s general allocator.
pub fn allocatorOf(engine: *heap.Engine) std.mem.Allocator {
    return .{ .ptr = engine, .vtable = &vtable };
}

/// The engine `allocator` allocates from, when it is a general allocator.
pub fn engineOf(allocator: std.mem.Allocator) ?*heap.Engine {
    if (allocator.vtable != &vtable) return null;
    return @ptrCast(@alignCast(allocator.ptr));
}

/// The partition a call of `alignment` is routed to.
pub inline fn partitionFor(alignment: std.mem.Alignment) heap.PartitionId {
    return if (alignment.toByteUnits() < @alignOf(usize)) .bytes else .objects;
}

fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    return engine.allocGeneral(partitionFor(alignment), len, alignment.toByteUnits(), return_address) catch null;
}

fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = return_address;
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    return engine.resizesInPlace(memory.ptr, memory.len, new_len, alignment.toByteUnits());
}

fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
    return if (resize(context, memory, alignment, new_len, return_address)) memory.ptr else null;
}

fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
    _ = return_address;
    const engine: *heap.Engine = @ptrCast(@alignCast(context));
    engine.freeGeneral(memory.ptr, memory.len, alignment.toByteUnits());
}
