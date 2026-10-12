//! V8 Isolate Lifecycle: what the adapter keeps per isolate (and, for a
//! thread's host agent, per thread), and the order an agent's end releases it
//! in (protocol_agents.endAgent).
//!
//! The steps are a constant table, known when the program is compiled (design
//! 4.6 and B9: what is the same for every agent is never installed at run
//! time). They were a registry of 32 optional slots, written by
//! `registerBuiltinHandlers` - from initializeEngine, and from any createAgent
//! that found the table empty, on whichever Browser or worker thread made it -
//! and read by every agent's end on every thread, with no lock.
//!
//! ## Usage
//!
//! ```zig
//! // Before disposing an isolate (protocol_agents.endAgent)
//! isolate_lifecycle.cleanupAll(isolate, allocator);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const builtin = @import("builtin");

/// Cleanup step signature
/// Arguments:
///   - isolate: V8 isolate being disposed
///   - allocator: Allocator for any necessary deallocation
pub const CleanupFn = *const fn (*v8.Isolate, std.mem.Allocator) void;

/// Debug validator function signature
/// Returns true if state is clean, false if cleanup was incomplete
pub const ValidatorFn = *const fn () bool;

/// One step of an isolate's teardown.
pub const Handler = struct {
    name: []const u8,
    cleanup: CleanupFn,
    validator: ?ValidatorFn = null,
};

/// The steps, in the order they run: what depends on a thing ends before it.
/// The thread's context manager (its realms' wrapper caches) first, then the
/// isolate's templates - the registry's among them - then its allocator,
/// which their storage was allocated with.
pub const handlers = [_]Handler{
    .{ .name = "context_manager", .cleanup = cleanupContextManager },
    .{ .name = "isolate_templates", .cleanup = cleanupIsolateTemplates, .validator = validateTemplateRegistry },
    .{ .name = "isolate_allocator", .cleanup = cleanupIsolateAllocator },
};

/// Run every step, in order.
///
/// This function MUST be called BEFORE disposing the V8 isolate.
///
/// Arguments:
///   - isolate: V8 isolate being disposed
///   - allocator: Allocator for cleanup operations
pub fn cleanupAll(isolate: *v8.Isolate, allocator: std.mem.Allocator) void {
    inline for (handlers) |handler| handler.cleanup(isolate, allocator);

    // In debug mode, validate all cleanup was successful
    if (builtin.mode == .Debug) {
        inline for (handlers) |handler| {
            if (handler.validator) |validate| {
                if (!validate()) std.log.warn("Cleanup validation failed for: {s}", .{handler.name});
            }
        }
    }
}

// ============================================================================
// The steps
// ============================================================================

/// The isolate's template storage (slot 1), its registered templates
/// disposed: this isolate's only - no other isolate's storage is reachable
/// from it.
fn cleanupIsolateTemplates(isolate: *v8.Isolate, allocator: std.mem.Allocator) void {
    const isolate_templates = @import("isolate_templates.zig");
    isolate_templates.cleanupTemplateStorage(isolate, allocator);
}

/// The current isolate's registry is empty once its storage has ended.
fn validateTemplateRegistry() bool {
    const template_registry = @import("template_registry.zig");
    return template_registry.getTemplate("Document") == null;
}

/// The isolate's allocator (slot 0)
fn cleanupIsolateAllocator(isolate: *v8.Isolate, _: std.mem.Allocator) void {
    const isolate_allocator = @import("isolate_allocator.zig");
    isolate_allocator.deinitIsolateAllocator(isolate);
}

/// The thread's context manager
fn cleanupContextManager(_: *v8.Isolate, _: std.mem.Allocator) void {
    const context_manager = @import("context_manager.zig");
    context_manager.deinit();
}
