//! Compiled for a 32-bit target, never run: a Browser heap's pointer32
//! profile (src/runtime/browser_heap.zig; lane h1, the integrator's 15:09 UTC
//! addition - watchOS arm64_32, wasm32 and 32-bit ARM have pointers of 4
//! bytes already, so no cage and no reservation: a Link is the plain
//! pointer). Not a `_test.zig` file, so no suite collects it; the merge gate
//! builds it alone, for each triple:
//!
//!     zig build-obj -target arm-linux-musleabihf -OReleaseSafe \
//!         --dep browser_heap -Mroot=tests/runtime/h1_heap_32bit_check.zig \
//!         -Mbrowser_heap=src/runtime/browser_heap.zig
//!     (and -target wasm32-freestanding)
//!
//! Each export makes the compiler generate the code the profile runs.

const heap = @import("browser_heap");

comptime {
    if (@sizeOf(usize) != 4) @compileError("h1_heap_32bit_check: pass a 32-bit -target");
    if (heap.profile != .pointer32) @compileError("a 32-bit target's profile is pointer32");
    if (@sizeOf(heap.Link(u64)) != 4) @compileError("a pointer32 Link is the 4-byte pointer");
    if (heap.layout.window_bytes != 0) @compileError("pointer32 reserves nothing");
}

export fn h1_link_get(value: u32, holder: *const anyopaque) ?*u64 {
    const link: heap.Link(u64) = @fromBackingInt(value);
    return link.get(holder);
}

export fn h1_link_to(target: ?*const u64, holder: *const anyopaque) u32 {
    return @backingInt(heap.Link(u64).to(target, holder));
}

export fn h1_link_eql(value: u32, target: ?*const u64, holder: *const anyopaque) bool {
    const link: heap.Link(u64) = @fromBackingInt(value);
    return link.eql(target, holder);
}

export fn h1_heap_of(ptr: *const anyopaque) *heap.BrowserHeap {
    return heap.heapOf(ptr);
}

// The reservation and release paths, analyzed for a 32-bit target (no C ABI
// for an Allocator, so referenced rather than exported).
comptime {
    _ = &heap.BrowserHeap.reserve;
    _ = &heap.BrowserHeap.release;
    _ = &heap.BrowserHeap.commit;
}
