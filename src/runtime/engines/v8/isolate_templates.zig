//! V8 Isolate-Local Template Storage
//!
//! Stores V8 FunctionTemplates per-isolate using V8's embedder data slots.
//! This is the canonical approach used by Node.js and Chrome for embedder data.
//!
//! ## Architecture
//!
//! V8 FunctionTemplates are bound to specific isolates. When an isolate is disposed,
//! its templates become invalid. This module stores templates in V8's isolate data
//! slots, ensuring they are automatically scoped to the isolate's lifetime.
//!
//! ## Slot Usage
//!
//! - Slot 0: IsolateAllocator (see isolate_allocator.zig)
//! - Slot 1: IsolateTemplates (this module)
//!
//! ## Problem Solved
//!
//! Before this implementation, templates were cached in Zig static variables.
//! When running multiple WPT tests, each test creates/disposes an isolate.
//! The stale template pointers caused "Bus error" crashes on the second test.
//!
//! This module stores templates per-isolate, ensuring:
//! 1. Automatic invalidation when isolate is disposed
//! 2. No stale pointer possibility
//! 3. Proper scoping to isolate lifetime

const std = @import("std");
const v8 = @import("ffi.zig");

/// Embedder data slot for template storage
/// V8 allows storing arbitrary data per-isolate using slot indices
/// Slot 0 is used by isolate_allocator.zig for allocator storage
pub const TEMPLATE_SLOT: c_int = 1;

/// Maximum number of templates that can be stored per isolate
const MAX_TEMPLATES = 2048;

/// Template entry in the per-isolate storage
const TemplateEntry = struct {
    name: []const u8,
    template: *v8.FunctionTemplate,
};

/// Per-isolate template storage
pub const IsolateTemplates = struct {
    allocator: std.mem.Allocator,
    templates: std.StringHashMap(*v8.FunctionTemplate),
    generation: u64,

    /// Initialize isolate-local template storage
    pub fn init(allocator: std.mem.Allocator, generation: u64) IsolateTemplates {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(*v8.FunctionTemplate).init(allocator),
            .generation = generation,
        };
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *IsolateTemplates) void {
        // Clear the hashmap - templates themselves are owned by V8
        self.templates.deinit();
    }

    /// Get a template by interface name
    pub fn get(self: *IsolateTemplates, name: []const u8) ?*v8.FunctionTemplate {
        return self.templates.get(name);
    }

    /// Store a template for an interface name
    pub fn put(self: *IsolateTemplates, name: []const u8, template: *v8.FunctionTemplate) !void {
        try self.templates.put(name, template);
    }

    /// Check if a template exists for an interface name
    pub fn contains(self: *IsolateTemplates, name: []const u8) bool {
        return self.templates.contains(name);
    }

    /// Get the number of stored templates
    pub fn count(self: *IsolateTemplates) usize {
        return self.templates.count();
    }

    /// Clear all templates (but keep the storage allocated)
    pub fn clear(self: *IsolateTemplates) void {
        self.templates.clearRetainingCapacity();
    }
};

/// Get or create template storage for an isolate
///
/// If storage doesn't exist for this isolate, creates new storage.
/// If storage exists but has a different generation, recreates it.
///
/// Arguments:
/// - isolate: V8 isolate to get/create storage for
/// - allocator: Allocator to use for creating storage
/// - generation: Current global generation counter (from template_registry)
///
/// Returns: Pointer to the isolate's template storage
pub fn getOrCreateTemplateStorage(
    isolate: *v8.Isolate,
    allocator: std.mem.Allocator,
    generation: u64,
) !*IsolateTemplates {
    // Check for existing storage
    if (v8.v8_Isolate_GetData(isolate, TEMPLATE_SLOT)) |existing_ptr| {
        const existing: *IsolateTemplates = @ptrCast(@alignCast(existing_ptr));

        // Check if generation matches
        if (existing.generation == generation) {
            return existing;
        }

        // Generation mismatch - storage is stale, clean it up
        existing.deinit();
        allocator.destroy(existing);
        v8.v8_Isolate_SetData(isolate, TEMPLATE_SLOT, null);
    }

    // Create new storage
    const storage = try allocator.create(IsolateTemplates);
    errdefer allocator.destroy(storage);

    storage.* = IsolateTemplates.init(allocator, generation);

    // Store in isolate data slot
    v8.v8_Isolate_SetData(isolate, TEMPLATE_SLOT, storage);

    return storage;
}

/// Get template storage for an isolate (returns null if not initialized)
pub fn getTemplateStorage(isolate: *v8.Isolate) ?*IsolateTemplates {
    const data_ptr = v8.v8_Isolate_GetData(isolate, TEMPLATE_SLOT) orelse return null;
    return @ptrCast(@alignCast(data_ptr));
}

/// Cleanup template storage for an isolate
///
/// MUST be called BEFORE disposing the isolate to prevent memory leaks.
/// This clears the template hashmap and frees the storage struct.
///
/// Arguments:
/// - isolate: V8 isolate to cleanup storage for
/// - allocator: Allocator used when creating the storage
pub fn cleanupTemplateStorage(isolate: *v8.Isolate, allocator: std.mem.Allocator) void {
    const data_ptr = v8.v8_Isolate_GetData(isolate, TEMPLATE_SLOT) orelse return;
    const storage: *IsolateTemplates = @ptrCast(@alignCast(data_ptr));

    // Deinitialize and free
    storage.deinit();
    allocator.destroy(storage);

    // Clear isolate data slot
    v8.v8_Isolate_SetData(isolate, TEMPLATE_SLOT, null);
}

// ============================================================================
// Tests
// ============================================================================

test "IsolateTemplates - basic operations" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var storage = IsolateTemplates.init(allocator, 1);
    defer storage.deinit();

    // Initially empty
    try testing.expectEqual(@as(usize, 0), storage.count());
    try testing.expect(!storage.contains("Element"));
    try testing.expectEqual(@as(?*v8.FunctionTemplate, null), storage.get("Element"));
}

test "IsolateTemplates module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
