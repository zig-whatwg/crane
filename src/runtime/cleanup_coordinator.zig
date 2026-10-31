//! Cleanup Coordinator - Single Source of Truth for Lifecycle Management
//!
//! This module coordinates cleanup between multiple paths to prevent:
//! - Double-free: Multiple cleanup paths trying to free the same resource
//! - Missed cleanup: Resources escaping all cleanup paths
//! - Race conditions: GC callbacks racing with context teardown
//!
//! ## Problem (RC2)
//!
//! Without coordination, there are two competing cleanup paths:
//! 1. **Context teardown**: context_manager.deinit → wrapper_cache.deinit → individual deinit
//! 2. **GC-driven cleanup**: V8 GC → weak callback → onObjectFreed → individual deinit
//!
//! These can conflict when:
//! - Context teardown starts while GC callbacks are pending
//! - Individual deinit is called via both paths
//! - Resources are freed in inconsistent order
//!
//! ## Solution
//!
//! The CleanupCoordinator provides:
//! 1. **State tracking**: Know what has/hasn't been cleaned up
//! 2. **Ordering**: Ensure cleanup happens in correct order
//! 3. **Guard rails**: Prevent double-cleanup via state checks
//!
//! ## Architecture
//!
//! ```
//! Context Teardown Path:
//!   context_manager.deinit()
//!     → CleanupCoordinator.beginContextCleanup()
//!     → [ordered cleanup via coordinator]
//!     → CleanupCoordinator.endContextCleanup()
//!
//! GC-Driven Path:
//!   V8 weak callback fires
//!     → check CleanupCoordinator.isContextTearingDown()
//!     → if true: skip (context teardown handles it)
//!     → if false: proceed with GC cleanup
//! ```
//!
//! ## Usage
//!
//! ```zig
//! // During context teardown
//! const coordinator = CleanupCoordinator.getForContext(ctx) orelse return;
//! coordinator.beginContextCleanup();
//! defer coordinator.endContextCleanup();
//!
//! // Cleanup in order...
//! coordinator.cleanupPhase(.dom_tree);
//! coordinator.cleanupPhase(.wrapper_cache);
//! coordinator.cleanupPhase(.static_registries);
//! ```

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const instance_lifecycle = @import("instance_lifecycle.zig");
const gc_integration = @import("gc_integration.zig");

/// Cleanup phases in order of execution
/// These must be cleaned up in this order to avoid use-after-free
pub const CleanupPhase = enum(u8) {
    /// Phase 0: Not started
    not_started = 0,

    /// Phase 1: DOM tree cleanup (Document → children → grandchildren)
    /// Must happen first to clear DOM references before wrapper cache
    dom_tree = 1,

    /// Phase 2: Wrapper cache cleanup (V8 handles and cache entries)
    /// After DOM tree so DOM nodes can unregister themselves
    wrapper_cache = 2,

    /// Phase 3: Static registries (ObservableArray, Intl, etc.)
    /// After wrapper cache since some may have V8 weak callbacks
    static_registries = 3,

    /// Phase 4: Event loop and timers
    /// After everything that might schedule timers
    event_loop = 4,

    /// Phase 5: Realm cleanup
    realm = 5,

    /// Phase 6: Context data cleanup
    /// Last phase, cleans up the context itself
    context_data = 6,

    /// Phase 7: Complete
    complete = 7,
};

/// Handler for a specific cleanup phase
pub const CleanupHandler = struct {
    phase: CleanupPhase,
    handler: *const fn (*anyopaque) void,
    context: *anyopaque,
};

/// Cleanup Coordinator
///
/// Per-context coordinator for managing cleanup lifecycle.
/// Ensures cleanup happens in correct order and prevents double-cleanup.
pub const CleanupCoordinator = struct {
    /// Current cleanup phase
    current_phase: CleanupPhase = .not_started,

    /// Whether context teardown has started
    /// When true, GC callbacks should skip cleanup (context handles it)
    context_teardown_started: bool = false,

    /// Whether context teardown is complete
    context_teardown_complete: bool = false,

    /// Allocator for internal structures
    allocator: std.mem.Allocator,

    /// Registered cleanup handlers (called in phase order)
    handlers: std.ArrayListUnmanaged(CleanupHandler) = .empty,

    /// Debug: count of instances cleaned up per phase
    phase_cleanup_counts: [8]usize = @splat(0),

    /// The storage of instances this teardown tore down that no engine
    /// object ever reached (runtime.instance_lifecycle.provablyUnwrapped: a
    /// node no wrapper of any realm was bound to), returned by
    /// `releaseDeferredStorage` once the teardown's last phase is done. Not
    /// inline: every phase after the one that tore the instance down still
    /// sees exactly what it saw before (lane unwrapped1). What the owner
    /// never releases stays with its Browser's slab, as before.
    deferred_storage: std.ArrayListUnmanaged(DeferredStorage) = .empty,

    const Self = @This();

    /// Initialize a new cleanup coordinator
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// An instance whose storage `releaseDeferredStorage` returns, as it was
    /// when its teardown handed it over.
    pub const DeferredStorage = struct {
        instance: *Instance,
        generation: u64,
    };

    /// Deinitialize the coordinator. Storage still deferred is left to the
    /// Browser's slab, which frees it with itself.
    pub fn deinit(self: *Self) void {
        self.handlers.deinit(self.allocator);
        self.deferred_storage.deinit(self.allocator);
    }

    /// `instance`, torn down by this teardown and provably never reached by
    /// an engine object, gives its storage back at the teardown's end. Out
    /// of memory, it keeps the storage until its Browser ends - what every
    /// such instance did before.
    pub fn deferStorageRelease(self: *Self, instance: *Instance, generation: u64) void {
        self.deferred_storage.append(self.allocator, .{ .instance = instance, .generation = generation }) catch return;
    }

    /// The teardown's last phase is done: return the storage handed over,
    /// each only while its slot still holds the instance handed over (the
    /// generation) and its cleanup completed - never twice, never a newcomer's.
    pub fn releaseDeferredStorage(self: *Self) void {
        for (self.deferred_storage.items) |deferred| {
            if (SlabAllocator.generationOf(deferred.instance) != deferred.generation) continue;
            if (!instance_lifecycle.isCleanedUp(deferred.instance)) continue;
            gc_integration.releaseStorage(deferred.instance);
        }
        self.deferred_storage.clearAndFree(self.allocator);
    }

    /// Register a cleanup handler for a specific phase
    ///
    /// Handlers are called in phase order during context teardown.
    /// Multiple handlers can be registered for the same phase.
    pub fn registerHandler(
        self: *Self,
        phase: CleanupPhase,
        handler: *const fn (*anyopaque) void,
        context: *anyopaque,
    ) !void {
        try self.handlers.append(self.allocator, .{
            .phase = phase,
            .handler = handler,
            .context = context,
        });
    }

    /// Begin context teardown
    ///
    /// Sets the teardown flag to signal GC callbacks to skip cleanup.
    /// Must be paired with endContextCleanup().
    pub fn beginContextCleanup(self: *Self) void {
        self.context_teardown_started = true;
        self.current_phase = .not_started;
    }

    /// Check if context is currently tearing down
    ///
    /// GC callbacks should check this and skip cleanup if true.
    /// Context teardown handles all cleanup in correct order.
    pub fn isContextTearingDown(self: *const Self) bool {
        return self.context_teardown_started and !self.context_teardown_complete;
    }

    /// Check if cleanup is complete
    pub fn isCleanupComplete(self: *const Self) bool {
        return self.context_teardown_complete;
    }

    /// Execute cleanup for a specific phase
    ///
    /// Calls all registered handlers for the phase in registration order.
    /// Tracks the current phase for debugging and validation.
    pub fn cleanupPhase(self: *Self, phase: CleanupPhase) void {
        // Validate phase ordering
        if (@backingInt(phase) <= @backingInt(self.current_phase)) {
            // Phase already executed or going backwards - skip
            return;
        }

        // Update current phase
        self.current_phase = phase;

        // Call all handlers for this phase
        for (self.handlers.items) |handler| {
            if (handler.phase == phase) {
                handler.handler(handler.context);
            }
        }
    }

    /// Execute all cleanup phases in order
    ///
    /// Convenience method that runs all phases sequentially.
    /// Used by context_manager.deinit().
    pub fn executeAllPhases(self: *Self) void {
        self.beginContextCleanup();

        self.cleanupPhase(.dom_tree);
        self.cleanupPhase(.wrapper_cache);
        self.cleanupPhase(.static_registries);
        self.cleanupPhase(.event_loop);
        self.cleanupPhase(.realm);
        self.cleanupPhase(.context_data);

        self.endContextCleanup();
    }

    /// End context teardown
    ///
    /// Marks cleanup as complete. After this, isContextTearingDown() returns false.
    pub fn endContextCleanup(self: *Self) void {
        self.current_phase = .complete;
        self.context_teardown_complete = true;
    }

    /// Record a cleanup in the current phase
    ///
    /// Used for debugging to track how many instances are cleaned per phase.
    pub fn recordCleanup(self: *Self) void {
        const phase_idx = @backingInt(self.current_phase);
        if (phase_idx < self.phase_cleanup_counts.len) {
            self.phase_cleanup_counts[phase_idx] += 1;
        }
    }

    /// Get cleanup statistics for debugging
    pub fn getStats(self: *const Self) CleanupStats {
        var total: usize = 0;
        for (self.phase_cleanup_counts) |count| {
            total += count;
        }
        return .{
            .total_cleaned = total,
            .per_phase = self.phase_cleanup_counts,
            .current_phase = self.current_phase,
            .is_complete = self.context_teardown_complete,
        };
    }

    /// Reset for testing
    pub fn reset(self: *Self) void {
        self.current_phase = .not_started;
        self.context_teardown_started = false;
        self.context_teardown_complete = false;
        self.phase_cleanup_counts = @splat(0);
        self.handlers.clearRetainingCapacity();
        self.deferred_storage.clearRetainingCapacity();
    }
};

/// Cleanup statistics for debugging
pub const CleanupStats = struct {
    total_cleaned: usize,
    per_phase: [8]usize,
    current_phase: CleanupPhase,
    is_complete: bool,
};

// ============================================================================
// Thread-local Coordinator Storage
// ============================================================================

/// Thread-local storage for the active cleanup coordinator
/// Each thread (V8 isolate) has its own coordinator
threadlocal var active_coordinator: ?*CleanupCoordinator = null;

/// Set the active coordinator for this thread
pub fn setActiveCoordinator(coordinator: ?*CleanupCoordinator) void {
    active_coordinator = coordinator;
}

/// Get the active coordinator for this thread
pub fn getActiveCoordinator() ?*CleanupCoordinator {
    return active_coordinator;
}

/// Hand `instance`'s storage to the teardown in progress
/// (`CleanupCoordinator.deferStorageRelease`); nothing when none is.
pub fn deferStorageRelease(instance: *Instance, generation: u64) void {
    const coordinator = active_coordinator orelse return;
    if (!coordinator.isContextTearingDown()) return;
    coordinator.deferStorageRelease(instance, generation);
}

/// Check if context teardown is in progress
///
/// Convenience function for GC callbacks to check if they should skip cleanup.
/// Returns false if no coordinator is active (safe to proceed with cleanup).
pub fn isContextTearingDown() bool {
    if (active_coordinator) |coordinator| {
        return coordinator.isContextTearingDown();
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "CleanupCoordinator - init and deinit" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    try testing.expect(!coordinator.isContextTearingDown());
    try testing.expect(!coordinator.isCleanupComplete());
}

test "CleanupCoordinator - begin/end context cleanup" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    // Before begin
    try testing.expect(!coordinator.isContextTearingDown());

    // During cleanup
    coordinator.beginContextCleanup();
    try testing.expect(coordinator.isContextTearingDown());

    // After end
    coordinator.endContextCleanup();
    try testing.expect(!coordinator.isContextTearingDown());
    try testing.expect(coordinator.isCleanupComplete());
}

test "CleanupCoordinator - phase ordering" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    coordinator.beginContextCleanup();

    // Execute phases in order
    coordinator.cleanupPhase(.dom_tree);
    try testing.expect(coordinator.current_phase == .dom_tree);

    coordinator.cleanupPhase(.wrapper_cache);
    try testing.expect(coordinator.current_phase == .wrapper_cache);

    // Skip back shouldn't change phase
    coordinator.cleanupPhase(.dom_tree);
    try testing.expect(coordinator.current_phase == .wrapper_cache);

    coordinator.endContextCleanup();
}

test "CleanupCoordinator - handler registration and execution" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    var dom_called = false;
    var cache_called = false;

    const DomHandler = struct {
        fn handle(ctx: *anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx));
            flag.* = true;
        }
    };

    const CacheHandler = struct {
        fn handle(ctx: *anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx));
            flag.* = true;
        }
    };

    try coordinator.registerHandler(.dom_tree, DomHandler.handle, &dom_called);
    try coordinator.registerHandler(.wrapper_cache, CacheHandler.handle, &cache_called);

    coordinator.beginContextCleanup();

    // DOM handler should be called
    coordinator.cleanupPhase(.dom_tree);
    try testing.expect(dom_called);
    try testing.expect(!cache_called);

    // Cache handler should be called
    coordinator.cleanupPhase(.wrapper_cache);
    try testing.expect(cache_called);

    coordinator.endContextCleanup();
}

test "CleanupCoordinator - stats tracking" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    coordinator.beginContextCleanup();
    coordinator.cleanupPhase(.dom_tree);

    // Record some cleanups
    coordinator.recordCleanup();
    coordinator.recordCleanup();
    coordinator.recordCleanup();

    const stats = coordinator.getStats();
    try testing.expectEqual(@as(usize, 3), stats.total_cleaned);
    try testing.expectEqual(@as(usize, 3), stats.per_phase[@backingInt(CleanupPhase.dom_tree)]);

    coordinator.endContextCleanup();
}

test "CleanupCoordinator - thread-local storage" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    // No active coordinator initially
    try testing.expect(getActiveCoordinator() == null);
    try testing.expect(!isContextTearingDown());

    // Set active coordinator
    setActiveCoordinator(&coordinator);
    try testing.expect(getActiveCoordinator() != null);

    // Not tearing down yet
    try testing.expect(!isContextTearingDown());

    // Begin teardown
    coordinator.beginContextCleanup();
    try testing.expect(isContextTearingDown());

    // End teardown
    coordinator.endContextCleanup();
    try testing.expect(!isContextTearingDown());

    // Clear active coordinator
    setActiveCoordinator(null);
    try testing.expect(getActiveCoordinator() == null);
}

test "CleanupCoordinator - reset for testing" {
    var coordinator = CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();

    coordinator.beginContextCleanup();
    coordinator.cleanupPhase(.dom_tree);
    coordinator.recordCleanup();
    coordinator.endContextCleanup();

    try testing.expect(coordinator.isCleanupComplete());

    // Reset should clear everything
    coordinator.reset();

    try testing.expect(!coordinator.isCleanupComplete());
    try testing.expect(!coordinator.isContextTearingDown());
    try testing.expect(coordinator.current_phase == .not_started);
    try testing.expectEqual(@as(usize, 0), coordinator.getStats().total_cleaned);
}
