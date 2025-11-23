//! V8 Context for WebIDL Bindings
//!
//! Manages V8 integration for WebIDL interfaces, providing:
//! - V8 Isolate, Context, and HandleScope management
//! - Bidirectional mapping between Instance and JS Object
//! - FunctionTemplate cache for all interfaces
//! - Internal field storage for Instance pointers
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## Architecture
//!
//! ```
//! WebIDL Interface → FunctionTemplate → V8 Object
//!        ↕                                   ↕
//!   Instance ← Bidirectional Mapping → Internal Field
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const v8_ctx = @import("runtime").V8Context;
//!
//! // Initialize V8 context
//! var ctx = try v8_ctx.init(allocator);
//! defer ctx.deinit();
//!
//! // Create V8 binding for WebIDL interface
//! const v8_obj = try ctx.bindInstance(instance, "Element");
//!
//! // Get Instance from V8 object
//! const inst = try ctx.getInstance(v8_obj);
//! ```

const std = @import("std");
const Instance = @import("../../instance.zig").Instance;

/// V8 Context state
///
/// Manages the V8 execution environment and bidirectional mappings
/// between WebIDL instances and V8 objects.
pub const V8Context = struct {
    allocator: std.mem.Allocator,

    /// Mapping from Instance pointer → V8 Object handle
    /// Used to find existing V8 object for a given Instance
    instance_to_js: std.AutoHashMap(usize, usize),

    /// Mapping from V8 Object handle → Instance pointer
    /// Used to retrieve Instance from V8 object internal field
    js_to_instance: std.AutoHashMap(usize, *Instance),

    /// FunctionTemplate cache: interface name → template handle
    /// Stores V8 FunctionTemplate for each WebIDL interface
    template_cache: std.StringHashMap(usize),

    /// Initialize V8 context
    pub fn init(allocator: std.mem.Allocator) !*V8Context {
        const self = try allocator.create(V8Context);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .instance_to_js = std.AutoHashMap(usize, usize).init(allocator),
            .js_to_instance = std.AutoHashMap(usize, *Instance).init(allocator),
            .template_cache = std.StringHashMap(usize).init(allocator),
        };

        return self;
    }

    /// Deinitialize V8 context
    pub fn deinit(self: *V8Context) void {
        self.template_cache.deinit();
        self.js_to_instance.deinit();
        self.instance_to_js.deinit();
        self.allocator.destroy(self);
    }

    /// Bind WebIDL Instance to V8 Object
    ///
    /// Creates bidirectional mapping between Instance and V8 Object.
    /// If Instance already has a V8 Object, returns existing mapping.
    ///
    /// In real V8 integration:
    /// - js_obj_handle would be v8::Local<v8::Object> handle
    /// - Instance pointer stored in V8 object internal field #0
    /// - Uses v8::Persistent to prevent GC
    pub fn bindInstance(
        self: *V8Context,
        instance: *Instance,
        js_obj_handle: usize,
    ) !void {
        const inst_addr = @intFromPtr(instance);

        // Check if Instance already has V8 object
        if (self.instance_to_js.get(inst_addr)) |existing| {
            // Already bound, verify consistency
            if (existing != js_obj_handle) {
                return error.InstanceAlreadyBound;
            }
            return;
        }

        // Create bidirectional mapping
        try self.instance_to_js.put(inst_addr, js_obj_handle);
        try self.js_to_instance.put(js_obj_handle, instance);
    }

    /// Get V8 Object for WebIDL Instance
    ///
    /// Returns the V8 object handle if Instance is bound, null otherwise.
    pub fn getJSObject(self: *const V8Context, instance: *const Instance) ?usize {
        const inst_addr = @intFromPtr(instance);
        return self.instance_to_js.get(inst_addr);
    }

    /// Get WebIDL Instance from V8 Object
    ///
    /// Retrieves Instance from V8 object internal field.
    /// In real V8 integration, this extracts from v8::External.
    pub fn getInstance(self: *const V8Context, js_obj_handle: usize) !*Instance {
        return self.js_to_instance.get(js_obj_handle) orelse error.InstanceNotFound;
    }

    /// Unbind Instance from V8 Object
    ///
    /// Removes bidirectional mapping. Called during GC or manual cleanup.
    pub fn unbindInstance(self: *V8Context, instance: *const Instance) void {
        const inst_addr = @intFromPtr(instance);

        if (self.instance_to_js.fetchRemove(inst_addr)) |kv| {
            const js_obj_handle = kv.value;
            _ = self.js_to_instance.remove(js_obj_handle);
        }
    }

    /// Cache FunctionTemplate for interface
    ///
    /// Stores V8 FunctionTemplate handle by interface name.
    /// Allows reusing templates instead of creating new ones.
    pub fn cacheTemplate(
        self: *V8Context,
        interface_name: []const u8,
        template_handle: usize,
    ) !void {
        // Duplicate the string since StringHashMap doesn't own keys
        const name_copy = try self.allocator.dupe(u8, interface_name);
        try self.template_cache.put(name_copy, template_handle);
    }

    /// Get cached FunctionTemplate for interface
    ///
    /// Returns template handle if cached, null otherwise.
    pub fn getTemplate(self: *const V8Context, interface_name: []const u8) ?usize {
        return self.template_cache.get(interface_name);
    }

    /// Clear all bindings
    ///
    /// Removes all Instance ↔ JS Object mappings.
    /// Used during context cleanup or GC sweep.
    pub fn clearBindings(self: *V8Context) void {
        self.instance_to_js.clearRetainingCapacity();
        self.js_to_instance.clearRetainingCapacity();
    }

    /// Get binding statistics
    pub fn getStats(self: *const V8Context) Stats {
        return .{
            .instance_count = self.instance_to_js.count(),
            .js_object_count = self.js_to_instance.count(),
            .template_count = self.template_cache.count(),
        };
    }

    pub const Stats = struct {
        instance_count: u32,
        js_object_count: u32,
        template_count: u32,
    };
};

// Unit tests

const testing = std.testing;

test "V8Context init and deinit" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const stats = ctx.getStats();
    try testing.expectEqual(@as(u32, 0), stats.instance_count);
    try testing.expectEqual(@as(u32, 0), stats.js_object_count);
    try testing.expectEqual(@as(u32, 0), stats.template_count);
}

test "V8Context bindInstance creates bidirectional mapping" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    // Create mock instance
    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const js_handle: usize = 0xDEADBEEF;

    // Bind instance
    try ctx.bindInstance(&instance, js_handle);

    // Verify bidirectional mapping
    const retrieved_js = ctx.getJSObject(&instance).?;
    try testing.expectEqual(js_handle, retrieved_js);

    const retrieved_inst = try ctx.getInstance(js_handle);
    try testing.expectEqual(&instance, retrieved_inst);
}

test "V8Context getJSObject returns null for unbound instance" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const js_obj = ctx.getJSObject(&instance);
    try testing.expectEqual(@as(?usize, null), js_obj);
}

test "V8Context getInstance returns error for invalid handle" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const invalid_handle: usize = 0xBADBAD;
    const result = ctx.getInstance(invalid_handle);
    try testing.expectError(error.InstanceNotFound, result);
}

test "V8Context bindInstance rejects double binding with different handle" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const handle1: usize = 0xAAAAAA;
    const handle2: usize = 0xBBBBBB;

    try ctx.bindInstance(&instance, handle1);

    const result = ctx.bindInstance(&instance, handle2);
    try testing.expectError(error.InstanceAlreadyBound, result);
}

test "V8Context bindInstance allows rebinding with same handle" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const handle: usize = 0xAAAAAA;

    try ctx.bindInstance(&instance, handle);
    try ctx.bindInstance(&instance, handle); // Should succeed
}

test "V8Context unbindInstance removes mappings" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const js_handle: usize = 0xCCCCCC;

    try ctx.bindInstance(&instance, js_handle);
    ctx.unbindInstance(&instance);

    // Verify mappings removed
    const js_obj = ctx.getJSObject(&instance);
    try testing.expectEqual(@as(?usize, null), js_obj);

    const result = ctx.getInstance(js_handle);
    try testing.expectError(error.InstanceNotFound, result);
}

test "V8Context cacheTemplate and getTemplate" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const interface_name = "Element";
    const template_handle: usize = 0x12345678;

    try ctx.cacheTemplate(interface_name, template_handle);

    const retrieved = ctx.getTemplate(interface_name).?;
    try testing.expectEqual(template_handle, retrieved);
}

test "V8Context getTemplate returns null for uncached interface" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const template = ctx.getTemplate("NonExistent");
    try testing.expectEqual(@as(?usize, null), template);
}

test "V8Context clearBindings removes all mappings" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var inst1 = Instance{ .vtable = undefined, .state = null, .ctx = null };
    var inst2 = Instance{ .vtable = undefined, .state = null, .ctx = null };

    try ctx.bindInstance(&inst1, 0x111);
    try ctx.bindInstance(&inst2, 0x222);

    var stats = ctx.getStats();
    try testing.expectEqual(@as(u32, 2), stats.instance_count);

    ctx.clearBindings();

    stats = ctx.getStats();
    try testing.expectEqual(@as(u32, 0), stats.instance_count);
    try testing.expectEqual(@as(u32, 0), stats.js_object_count);
}

test "V8Context getStats returns correct counts" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var inst1 = Instance{ .vtable = undefined, .state = null, .ctx = null };
    var inst2 = Instance{ .vtable = undefined, .state = null, .ctx = null };

    try ctx.bindInstance(&inst1, 0x111);
    try ctx.bindInstance(&inst2, 0x222);

    try ctx.cacheTemplate("Element", 0x1000);
    try ctx.cacheTemplate("Document", 0x2000);

    const stats = ctx.getStats();
    try testing.expectEqual(@as(u32, 2), stats.instance_count);
    try testing.expectEqual(@as(u32, 2), stats.js_object_count);
    try testing.expectEqual(@as(u32, 2), stats.template_count);
}
