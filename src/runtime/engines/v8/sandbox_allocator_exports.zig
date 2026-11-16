//! Crane's in-sandbox allocator (sandbox_allocator.zig) as V8 uses it: the
//! functions v8_wrapper.cpp's CraneInSandboxAllocator calls, and the page
//! operations it gives back, made on V8's sandbox address space
//! (v8::VirtualAddressSpace, V8's public API: SetPagePermissions,
//! DiscardSystemPages, RecommitPages, DecommitPages). Crane makes no OS call
//! for these pages: V8 owns the sandbox's reservation.
//!
//! One allocator per process, made by v8_Platform_Start after V8::Initialize
//! and handed to V8 (v8::V8::SetInSandboxAllocator); the C++ object keeps the
//! state this file makes and holds the one lock every call here runs under.

const std = @import("std");
const sandbox_allocator = @import("sandbox_allocator.zig");
const ffi = @import("ffi.zig");

/// The sandbox's address space (a v8::VirtualAddressSpace), BORROWED: V8's,
/// alive until V8::Dispose.
const AddressSpace = opaque {};

/// The four page operations on the sandbox's address space, as v8_wrapper.cpp
/// gives them (CraneSandboxPageOps): functions of the C++ side, handed over
/// when the state is made, so that this file names no symbol of the wrapper -
/// a test executable that compiles the adapter's Zig without linking V8
/// (src/dom's own tests) still links.
const PageOps = extern struct {
    set_read_write: *const fn (space: *AddressSpace, address: usize, size: usize) callconv(.c) bool,
    discard: *const fn (space: *AddressSpace, address: usize, size: usize) callconv(.c) bool,
    recommit: *const fn (space: *AddressSpace, address: usize, size: usize) callconv(.c) bool,
    decommit: *const fn (space: *AddressSpace, address: usize, size: usize) callconv(.c) bool,
};

const SandboxPages = struct {
    space: *AddressSpace,
    /// BORROWED: a constant of the wrapper, alive for the process.
    ops: *const PageOps,

    pub fn setReadWrite(self: SandboxPages, address: usize, size: usize) bool {
        return self.ops.set_read_write(self.space, address, size);
    }
    pub fn discard(self: SandboxPages, address: usize, size: usize) bool {
        return self.ops.discard(self.space, address, size);
    }
    pub fn recommit(self: SandboxPages, address: usize, size: usize) bool {
        return self.ops.recommit(self.space, address, size);
    }
    pub fn decommit(self: SandboxPages, address: usize, size: usize) bool {
        return self.ops.decommit(self.space, address, size);
    }
};

const State = sandbox_allocator.Allocator(SandboxPages);

/// The records' memory: libc's, outside the sandbox.
const meta = std.heap.c_allocator;

/// The allocator's state over the reserved, inaccessible range `[base, base +
/// size)` of `space`, whose pages - of `page_size` bytes - `ops` works on, or
/// null with no memory for it. The process's, never
/// destroyed (v8_wrapper.cpp PlatformStart::sandbox_allocator).
export fn crane_SandboxAllocator_create(space: *AddressSpace, ops: *const PageOps, base: usize, size: usize, page_size: usize) ?*State {
    const state = meta.create(State) catch return null;
    state.* = State.init(meta, .{ .space = space, .ops = ops }, base, size, page_size) catch {
        meta.destroy(state);
        return null;
    };
    return state;
}

/// A block of at least `size` bytes aligned to 16, or null. `zeroed.*` says
/// whether every byte of it is known to be zero; the caller fills it
/// otherwise, where it must.
export fn crane_SandboxAllocator_allocate(state: *State, size: usize, zeroed: *bool) ?*anyopaque {
    const block = state.allocate(size) orelse return null;
    zeroed.* = block.zeroed;
    return @ptrFromInt(block.address);
}

/// Free a block `crane_SandboxAllocator_allocate` returned. A pointer that
/// is not a live block of this allocator - freed twice, or never allocated
/// here - ends the process: going on would hand one block to two owners.
export fn crane_SandboxAllocator_free(state: *State, block: *anyopaque) void {
    state.free(@intFromPtr(block)) catch @panic("the in-sandbox allocator was asked to free a pointer that is not one of its live blocks");
}

/// Give back every emptied chunk the allocator keeps for reuse.
export fn crane_SandboxAllocator_releaseRetained(state: *State) void {
    state.releaseRetained();
}

export fn crane_SandboxAllocator_stats(state: *const State, out: *sandbox_allocator.Stats) void {
    out.* = state.stats();
}

/// tests/v8: the process's in-sandbox allocator's figures, under its lock.
/// False when V8 has not started or runs without Crane's allocator.
pub extern fn v8_test_SandboxAllocator_Stats(out: *sandbox_allocator.Stats) bool;

/// tests/v8: give back every emptied chunk the process's in-sandbox
/// allocator keeps, under its lock.
pub extern fn v8_test_SandboxAllocator_ReleaseRetained() void;

/// tests/v8: a block of the process's in-sandbox allocator, zero-filled when
/// `zero`, as V8's own in-sandbox users take one; null with no memory or no
/// allocator. OWNED: `v8_test_SandboxAllocator_Free`. Any thread.
pub extern fn v8_test_SandboxAllocator_Allocate(size: usize, zero: bool) ?[*]u8;
/// tests/v8: free a block `v8_test_SandboxAllocator_Allocate` returned.
pub extern fn v8_test_SandboxAllocator_Free(block: [*]u8) void;

/// tests/v8: `buffer`'s BackingStore, held as a transferred ArrayBuffer's is -
/// by a reference that is no isolate's. Call with the buffer's isolate
/// entered. OWNED: `v8_test_BackingStore_Release`, on any thread, before or
/// after that isolate ends.
pub extern fn v8_test_BackingStore_Hold(buffer: *ffi.ArrayBuffer) *HeldBackingStore;
/// tests/v8: the address of a held store's first byte.
pub extern fn v8_test_BackingStore_Data(held: *HeldBackingStore) ?*anyopaque;
/// tests/v8: drop a held store's reference; the last one frees its memory.
pub extern fn v8_test_BackingStore_Release(held: *HeldBackingStore) void;
pub const HeldBackingStore = opaque {};
