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
//! Two kinds of allocator value: an ENGINE's (`allocatorOf`), the shared
//! path under each partition's lock (Engine.allocGeneral), and an AGENT's
//! (`agentAllocator`, heap.AgentCache): on its agent's thread a class block
//! comes from and goes back to the agent's cache with no lock (design 3.7);
//! on any other thread - a block an agent made, freed by another - the call
//! takes the shared path. No threadlocal: the value names its cache.

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

/// `cache`'s agent's general allocator.
pub fn agentAllocator(cache: *heap.AgentCache) std.mem.Allocator {
    return .{ .ptr = cache, .vtable = &agent_vtable };
}

pub const agent_vtable: std.mem.Allocator.VTable = .{
    .alloc = agentAlloc,
    .resize = agentResize,
    .remap = agentRemap,
    .free = agentFree,
};

/// The engine `allocator` allocates from, when it is a general allocator
/// (an engine's or an agent's).
pub fn engineOf(allocator: std.mem.Allocator) ?*heap.Engine {
    if (allocator.vtable == &vtable) return @ptrCast(@alignCast(allocator.ptr));
    if (allocator.vtable == &agent_vtable) {
        const cache: *heap.AgentCache = @ptrCast(@alignCast(allocator.ptr));
        return cache.engine;
    }
    return null;
}

inline fn onAgentThread(cache: *heap.AgentCache) bool {
    return cache.owner.load(.monotonic) == std.Thread.getCurrentId();
}

fn agentAlloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
    const cache: *heap.AgentCache = @ptrCast(@alignCast(context));
    const pid = partitionFor(alignment);
    if (onAgentThread(cache)) return cache.engine.cacheAlloc(cache, pid, len, alignment.toByteUnits(), return_address) catch null;
    return cache.engine.allocGeneral(pid, len, alignment.toByteUnits(), return_address) catch null;
}

fn agentResize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = return_address;
    const cache: *heap.AgentCache = @ptrCast(@alignCast(context));
    return cache.engine.resizesInPlace(memory.ptr, memory.len, new_len, alignment.toByteUnits());
}

fn agentRemap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
    return if (agentResize(context, memory, alignment, new_len, return_address)) memory.ptr else null;
}

fn agentFree(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
    _ = return_address;
    const cache: *heap.AgentCache = @ptrCast(@alignCast(context));
    if (onAgentThread(cache)) return cache.engine.cacheFree(cache, memory.ptr, memory.len, alignment.toByteUnits());
    cache.engine.freeGeneral(memory.ptr, memory.len, alignment.toByteUnits());
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
