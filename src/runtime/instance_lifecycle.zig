//! Instance Lifecycle Tracking
//!
//! This module provides lifecycle state tracking for runtime.Instance objects
//! to coordinate cleanup between different paths (context teardown vs GC).
//!
//! ## Problem (RC2)
//!
//! Without lifecycle tracking, there's no way to know if an instance:
//! - Has already been cleaned up (preventing double-free)
//! - Is currently being cleaned up (preventing recursive cleanup)
//! - Is attached to the DOM tree (affecting cleanup order)
//!
//! ## Solution
//!
//! Track lifecycle flags per instance, in the instance's own slab slot
//! (runtime.SlabAllocator, beside its generation): no registry, no lookup,
//! and the flags belong to the instance's Browser like the slot does
//! (docs/instances.md). Flags are stored outside the Instance to preserve its
//! 24-byte size constraint. They survive the instance's free - a teardown
//! still asks whether a freed node's cleanup ran - and start empty when the
//! slot is issued again.
//!
//! Only for instances `Instance.init` made (every slab-issued one).
//!
//! ## Flags
//!
//! - `cleanup_started`: Cleanup has begun (prevents re-entry)
//! - `cleanup_complete`: Cleanup is done (prevents double-free)
//! - `attached_to_dom`: Instance is in the DOM tree (affects cleanup order)
//! - `gc_weak_callback_pending`: V8 weak callback may fire
//! - `wrapped`: an engine object was bound to it in some realm (sticky)
//! - `wrapper_gone`: the last one bound is gone (until the next bind)
//!
//! ## Usage
//!
//! ```zig
//! const lifecycle = @import("runtime").instance_lifecycle;
//!
//! // In deinit function
//! pub fn deinit(instance: *runtime.Instance) void {
//!     // Check if already cleaned up
//!     if (lifecycle.isCleanedUp(instance)) return;
//!
//!     // Mark cleanup started (prevents re-entry)
//!     lifecycle.markCleanupStarted(instance);
//!
//!     // ... do actual cleanup ...
//!
//!     // Mark cleanup complete
//!     lifecycle.markCleanupComplete(instance);
//! }
//! ```

const std = @import("std");
const Instance = @import("instance.zig").Instance;

/// Lifecycle flags for an instance
pub const LifecycleFlags = packed struct(u8) {
    /// Cleanup has started (prevents recursive cleanup)
    cleanup_started: bool = false,

    /// Cleanup is complete (prevents double-free)
    cleanup_complete: bool = false,

    /// Instance is attached to DOM tree
    attached_to_dom: bool = false,

    /// V8 weak callback is registered and may fire
    gc_weak_callback_pending: bool = false,

    /// An engine object was bound to the instance - a wrapper, a realm's
    /// global object - in some realm, at some point since the slab issued
    /// this slot. Sticky: nothing clears it but the slot's next issue. An
    /// adapter with `engine.capabilities.wrap_tracking` sets it on every
    /// path that binds one (`markWrapped`), so on such an engine an
    /// instance WITHOUT it was never reachable from script, in any realm:
    /// no wrapper can reach its slot (`provablyUnwrapped`).
    wrapped: bool = false,

    /// The engine objects that were bound to the instance are gone: the
    /// adapter finalized its last wrapper - collected, in no other realm's
    /// cache - while the host kept the instance (a node in its tree, a
    /// window's document). Set only by such an adapter (`markWrapperGone`);
    /// the next bind clears it (`markWrapped`). With it, `wrapped` is the
    /// history and this the present: no wrapper reaches the slot now
    /// (`provablyUnwrapped`). Lane pageretention1: a removed frame's
    /// collected realm left every wrapped node of its document - and the
    /// document - keeping its slot when the realm's end tore them down.
    wrapper_gone: bool = false,

    /// Reserved for future use
    _reserved: u2 = 0,
};

const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;

fn read(instance: *const Instance) LifecycleFlags {
    return @bitCast(SlabAllocator.lifecycleBitsOf(instance));
}

fn write(instance: *const Instance, flags: LifecycleFlags) void {
    SlabAllocator.setLifecycleBits(instance, @bitCast(flags));
}

/// Get lifecycle flags for an instance: all false for one nothing marked.
pub fn get(instance: *const Instance) ?LifecycleFlags {
    return read(instance);
}

/// Forget an instance's lifecycle flags.
pub fn remove(instance: *const Instance) void {
    write(instance, .{});
}

// ============================================================================
// Convenience Functions for Common Operations
// ============================================================================

/// Check if cleanup has started for an instance
pub fn isCleanupStarted(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.cleanup_started;
}

/// Check if cleanup is complete for an instance
pub fn isCleanedUp(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.cleanup_complete;
}

/// Check if instance is attached to DOM
pub fn isAttachedToDOM(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.attached_to_dom;
}

/// Check if GC weak callback is pending
pub fn hasGCWeakCallbackPending(instance: *const Instance) bool {
    const flags = get(instance) orelse return false;
    return flags.gc_weak_callback_pending;
}

/// Mark cleanup as started
/// Returns true if this is the first call (cleanup should proceed)
/// Returns false if cleanup was already started (should skip)
pub fn markCleanupStarted(instance: *const Instance) bool {
    var flags = read(instance);
    if (flags.cleanup_started) {
        return false; // Already started, skip
    }
    flags.cleanup_started = true;
    write(instance, flags);
    return true; // First call, proceed with cleanup
}

/// Mark cleanup as complete. The flags stay with the slot until it is
/// issued again, when they start empty.
pub fn markCleanupComplete(instance: *const Instance) void {
    // Keep the record: a node torn down by its tree is still in its wrapper
    // cache, whose teardown skips an instance only while this says "started".
    // Removing it made that instance look untouched, and its deinit ran a
    // second time (an iframe's IFrameIntegration freed twice). A reissued
    // slot starts fresh anyway - the slab clears its flags when it issues it.
    var flags = read(instance);
    flags.cleanup_started = true;
    flags.cleanup_complete = true;
    write(instance, flags);
}

/// Mark instance as attached to DOM
pub fn markAttachedToDOM(instance: *const Instance) void {
    var flags = read(instance);
    flags.attached_to_dom = true;
    write(instance, flags);
}

/// Mark instance as detached from DOM
pub fn markDetachedFromDOM(instance: *const Instance) void {
    var flags = read(instance);
    flags.attached_to_dom = false;
    write(instance, flags);
}

/// Mark that GC weak callback is registered
pub fn markGCWeakCallbackPending(instance: *const Instance) void {
    var flags = read(instance);
    flags.gc_weak_callback_pending = true;
    write(instance, flags);
}

/// Clear GC weak callback pending flag
pub fn clearGCWeakCallbackPending(instance: *const Instance) void {
    var flags = read(instance);
    flags.gc_weak_callback_pending = false;
    write(instance, flags);
}

/// An engine object was bound to `instance` (see `LifecycleFlags.wrapped`).
/// The adapter calls it where it writes the instance into the object, before
/// any step that can fail: a mark on an instance whose wrapper was then
/// discarded only keeps its storage, which is the safe answer.
pub fn markWrapped(instance: *const Instance) void {
    var flags = read(instance);
    flags.wrapped = true;
    flags.wrapper_gone = false;
    write(instance, flags);
}

/// The adapter finalized the last engine object bound to `instance`, which
/// the host keeps (see `LifecycleFlags.wrapper_gone`). Only an adapter with
/// `wrap_tracking` calls it, and only when no other realm's wrapper and no
/// global object is bound to the instance; the next `markWrapped` undoes it.
/// On an instance never marked wrapped it changes nothing anyone reads.
pub fn markWrapperGone(instance: *const Instance) void {
    var flags = read(instance);
    if (!flags.wrapped) return;
    flags.wrapper_gone = true;
    write(instance, flags);
}

/// Whether an engine object was ever bound to `instance` since its slot was
/// issued. Meaningful only on an engine whose adapter tracks wraps: read it
/// through `provablyUnwrapped`.
pub fn wasWrapped(instance: *const Instance) bool {
    return read(instance).wrapped;
}

/// Whether `instance` can be PROVEN unreachable from script now: its engine
/// tracks wraps (`tracked` - the host passes
/// `engine.capabilities.wrap_tracking != .unsupported`) and either no wrap
/// ever marked it, or the last engine object bound to it is gone
/// (`markWrapperGone`: its wrapper finalized while the host kept it, no other
/// realm's wrapper bound). The default - an engine that does not track, an
/// instance marked and not released since - is "it may be": nothing is freed
/// on the strength of a missing mark (tests/runtime pins it).
///
/// "Gone" proves as much as "never" for every reader (lane pageretention1):
/// wrapped nodes are upward-closed - a wrap and an insertion wrap every
/// unwrapped ancestor and draw the edges (wrapper_cache.drawTreeEdges) - and
/// the wrapped part of a tree is one cycle the collector keeps or takes
/// whole, so a node whose wrapper was finalized has no wrapped descendant
/// left either: a subtree under it is no more reachable than a never-wrapped
/// one. A later wrap clears the release before anything reads it again.
pub fn provablyUnwrapped(tracked: bool, instance: *const Instance) bool {
    if (!tracked) return false;
    const flags = read(instance);
    return !flags.wrapped or flags.wrapper_gone;
}

/// Check if cleanup should proceed (not already started/complete)
/// This is the main guard function for deinit implementations
pub fn shouldCleanup(instance: *const Instance) bool {
    const flags = get(instance) orelse return true; // No flags = never cleaned
    return !flags.cleanup_started and !flags.cleanup_complete;
}

/// Check if cleanup has been started (but not necessarily complete)
/// Used to detect if an instance is currently being cleaned up
pub fn isBeingCleanedUp(instance: *const Instance) bool {
    const flags = get(instance) orelse return false; // No flags = not being cleaned
    return flags.cleanup_started;
}

/// Reset all flags for an instance.
pub fn reset(instance: *const Instance) void {
    write(instance, .{});
}

// Tests: tests/runtime/ (instance_lifecycle_test.zig, browser_scope_allocators_test.zig).
