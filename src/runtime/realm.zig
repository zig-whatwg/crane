//! Realm and Context Type Infrastructure
//!
//! Per WHATWG HTML spec, a Realm is a JavaScript execution environment.
//! Each Realm has an associated global object that determines API exposure.
//!
//! This module provides:
//! - ContextType enum for identifying execution environments
//! - RealmInfo struct for context metadata
//! - Realm struct for full realm implementation with V8 context and intrinsics
//! - Intrinsics struct for caching JavaScript built-in constructors
//! - Exposure checking for WebIDL [Exposed] attributes
//!
//! ## Specification References
//! - HTML Realms: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//! - HTML §8.1.5: Realms, settings objects, and global objects
//! - WebIDL §3.3: Platform objects and realms
//! - WebIDL Exposed: https://webidl.spec.whatwg.org/#Exposed

const std = @import("std");
const Allocator = std.mem.Allocator;

/// JavaScript execution context type
///
/// Per HTML spec, these correspond to different global object types.
/// Each type has different API exposure per WebIDL [Exposed] attributes.
pub const ContextType = enum {
    /// Browser window context (global = Window)
    /// Most APIs are exposed here
    window,

    /// Dedicated Web Worker (global = DedicatedWorkerGlobalScope)
    /// Subset of APIs, no DOM access
    dedicated_worker,

    /// Shared Web Worker (global = SharedWorkerGlobalScope)
    /// Similar to dedicated but shared across contexts
    shared_worker,

    /// Service Worker (global = ServiceWorkerGlobalScope)
    /// Background worker for offline/caching
    service_worker,

    /// Worklet (AudioWorklet, PaintWorklet, etc.)
    /// Highly restricted execution environment
    worklet,

    /// Unknown/unspecified context (for testing)
    /// Should not be used in production
    unknown,

    /// Get human-readable name for debugging
    pub fn name(self: ContextType) []const u8 {
        return switch (self) {
            .window => "Window",
            .dedicated_worker => "DedicatedWorkerGlobalScope",
            .shared_worker => "SharedWorkerGlobalScope",
            .service_worker => "ServiceWorkerGlobalScope",
            .worklet => "Worklet",
            .unknown => "Unknown",
        };
    }
};

/// WebIDL [Exposed] attribute values
///
/// Maps to WebIDL extended attribute:
/// - [Exposed=Window]
/// - [Exposed=Worker]
/// - [Exposed=(Window,Worker)]
/// - [Exposed=*]
pub const Exposure = enum {
    /// Exposed only in Window context
    window,

    /// Exposed only in Worker contexts (all worker types)
    worker,

    /// Exposed in both Window and Worker contexts
    window_and_worker,

    /// Exposed in all contexts
    all,
};

/// Realm information for a JavaScript execution context
///
/// Contains metadata about the current Realm, used for:
/// - API exposure checking ([Exposed] attributes)
/// - Security origin checks (future)
/// - Settings object access (future)
pub const RealmInfo = struct {
    /// Type of execution context
    context_type: ContextType,

    // Future fields:
    // origin: ?Origin,           // Security origin
    // settings_object: ?*EnvironmentSettingsObject,
    // global_object: ?*anyopaque,  // Reference to global (Window, Worker, etc.)

    const Self = @This();

    /// Create RealmInfo for a Window context
    pub fn forWindow() Self {
        return .{ .context_type = .window };
    }

    /// Create RealmInfo for a DedicatedWorker context
    pub fn forDedicatedWorker() Self {
        return .{ .context_type = .dedicated_worker };
    }

    /// Create RealmInfo for a SharedWorker context
    pub fn forSharedWorker() Self {
        return .{ .context_type = .shared_worker };
    }

    /// Create RealmInfo for a ServiceWorker context
    pub fn forServiceWorker() Self {
        return .{ .context_type = .service_worker };
    }

    /// Create RealmInfo for a Worklet context
    pub fn forWorklet() Self {
        return .{ .context_type = .worklet };
    }

    /// Create RealmInfo for testing (unknown context)
    pub fn forTesting() Self {
        return .{ .context_type = .unknown };
    }

    /// Check if this is a Window context
    pub fn isWindow(self: Self) bool {
        return self.context_type == .window;
    }

    /// Check if this is any Worker context
    pub fn isWorker(self: Self) bool {
        return switch (self.context_type) {
            .dedicated_worker, .shared_worker, .service_worker => true,
            else => false,
        };
    }

    /// Check if this is a Worklet context
    pub fn isWorklet(self: Self) bool {
        return self.context_type == .worklet;
    }

    /// Check if an API with given exposure is available in this context
    ///
    /// Per WebIDL spec, [Exposed] attribute determines availability:
    /// - [Exposed=Window] -> only in Window
    /// - [Exposed=Worker] -> only in Workers
    /// - [Exposed=(Window,Worker)] -> both
    /// - [Exposed=*] -> all contexts
    pub fn isExposedTo(self: Self, exposure: Exposure) bool {
        return switch (exposure) {
            .window => self.isWindow(),
            .worker => self.isWorker(),
            .window_and_worker => self.isWindow() or self.isWorker(),
            .all => true,
        };
    }

    /// Get human-readable context name
    pub fn contextName(self: Self) []const u8 {
        return self.context_type.name();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ContextType - names" {
    const testing = std.testing;

    try testing.expectEqualStrings("Window", ContextType.window.name());
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", ContextType.dedicated_worker.name());
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", ContextType.service_worker.name());
}

test "RealmInfo - factory methods" {
    const testing = std.testing;

    const window = RealmInfo.forWindow();
    try testing.expect(window.isWindow());
    try testing.expect(!window.isWorker());

    const worker = RealmInfo.forDedicatedWorker();
    try testing.expect(!worker.isWindow());
    try testing.expect(worker.isWorker());

    const service = RealmInfo.forServiceWorker();
    try testing.expect(service.isWorker());
}

test "RealmInfo - exposure checking" {
    const testing = std.testing;

    const window = RealmInfo.forWindow();
    try testing.expect(window.isExposedTo(.window));
    try testing.expect(!window.isExposedTo(.worker));
    try testing.expect(window.isExposedTo(.window_and_worker));
    try testing.expect(window.isExposedTo(.all));

    const worker = RealmInfo.forDedicatedWorker();
    try testing.expect(!worker.isExposedTo(.window));
    try testing.expect(worker.isExposedTo(.worker));
    try testing.expect(worker.isExposedTo(.window_and_worker));
    try testing.expect(worker.isExposedTo(.all));
}

test "RealmInfo - worklet not exposed to worker" {
    const testing = std.testing;

    const worklet = RealmInfo.forWorklet();
    try testing.expect(!worklet.isWindow());
    try testing.expect(!worklet.isWorker());
    try testing.expect(!worklet.isExposedTo(.window));
    try testing.expect(!worklet.isExposedTo(.worker));
    try testing.expect(!worklet.isExposedTo(.window_and_worker));
    try testing.expect(worklet.isExposedTo(.all));
}

// ============================================================================
// Full Realm Implementation (Phase 1a: Cross-Realm Support)
// ============================================================================

/// JavaScript Intrinsics - Cached built-in constructors and prototypes
///
/// Per HTML spec §8.1.5, each realm has its own set of intrinsic objects.
/// These are cached for efficient access when creating errors, objects, etc.
/// from the correct realm (important for cross-realm instanceof behavior).
///
/// The intrinsics are stored as opaque pointers to V8 Global handles.
/// They must be properly disposed when the realm is destroyed.
pub const Intrinsics = struct {
    /// TypeError constructor (for throwing type errors from this realm)
    type_error: ?*anyopaque,

    /// RangeError constructor
    range_error: ?*anyopaque,

    /// SyntaxError constructor
    syntax_error: ?*anyopaque,

    /// Object constructor
    object: ?*anyopaque,

    /// Array constructor
    array: ?*anyopaque,

    /// Object.prototype
    object_prototype: ?*anyopaque,

    /// Array.prototype
    array_prototype: ?*anyopaque,

    /// Function.prototype
    function_prototype: ?*anyopaque,

    const Self = @This();

    /// Create uninitialized intrinsics (all null)
    ///
    /// Intrinsics are populated lazily when first needed or during
    /// realm initialization with a V8 context.
    pub fn init() Self {
        return .{
            .type_error = null,
            .range_error = null,
            .syntax_error = null,
            .object = null,
            .array = null,
            .object_prototype = null,
            .array_prototype = null,
            .function_prototype = null,
        };
    }

    /// Check if intrinsics have been populated
    pub fn isPopulated(self: *const Self) bool {
        // Check if at least TypeError is populated (minimum requirement)
        return self.type_error != null;
    }

    /// Deinitialize intrinsics and release V8 Global handles
    ///
    /// Note: The actual V8 Global handle disposal must be done by
    /// the V8-specific code that populated these handles.
    /// This function just clears the pointers.
    pub fn deinit(self: *Self) void {
        // Clear all pointers (actual V8 handle cleanup is external)
        self.type_error = null;
        self.range_error = null;
        self.syntax_error = null;
        self.object = null;
        self.array = null;
        self.object_prototype = null;
        self.array_prototype = null;
        self.function_prototype = null;
    }
};

/// Full Realm implementation for cross-realm support
///
/// Per HTML spec §8.1.5, a Realm is a JavaScript execution environment with:
/// - A V8 context (execution environment)
/// - A global object (Window, WorkerGlobalScope, etc.)
/// - Intrinsic objects (TypeError, Object, Array constructors)
/// - An associated browsing context (for Window realms)
///
/// This struct enables proper cross-realm behavior:
/// - TypeError thrown from method's realm, not caller's
/// - Objects created in method's realm for toJSON
/// - instanceof checks work correctly across realms
///
/// ## Usage
///
/// ```zig
/// // Create realm for a V8 context
/// const realm = try Realm.init(allocator, .{
///     .v8_context = v8_ctx,
///     .isolate = isolate,
///     .context_type = .window,
/// });
/// defer realm.deinit();
///
/// // Create TypeError from this realm
/// const error = realm.createTypeError("Illegal invocation");
///
/// // Create plain object in this realm
/// const obj = realm.createObject();
/// ```
pub const Realm = struct {
    /// Memory allocator for realm-owned resources
    allocator: Allocator,

    /// V8 context handle (opaque pointer to Global<Context>*)
    /// This is the execution context for this realm.
    v8_context: ?*anyopaque,

    /// V8 isolate (shared across all realms in same isolate)
    /// Opaque pointer to v8::Isolate*
    isolate: ?*anyopaque,

    /// Global object handle (opaque pointer to Global<Object>*)
    /// This is the Window or WorkerGlobalScope for this realm.
    global_object: ?*anyopaque,

    /// Cached intrinsic objects (TypeError, Object, Array constructors)
    intrinsics: Intrinsics,

    /// Context type information (Window, Worker, etc.)
    info: RealmInfo,

    /// Associated browsing context (for Window realms only)
    /// Opaque pointer to BrowsingContext*
    browsing_context: ?*anyopaque,

    const Self = @This();

    /// Realm initialization options
    pub const InitOptions = struct {
        /// V8 context handle (opaque pointer)
        v8_context: ?*anyopaque = null,

        /// V8 isolate (opaque pointer)
        isolate: ?*anyopaque = null,

        /// Global object handle (opaque pointer)
        global_object: ?*anyopaque = null,

        /// Context type (defaults to window)
        context_type: ContextType = .window,

        /// Browsing context (for Window realms)
        browsing_context: ?*anyopaque = null,
    };

    /// Initialize a new Realm
    ///
    /// Creates a realm with the given V8 context and configuration.
    /// Intrinsics are not populated until populateIntrinsics() is called
    /// or they are lazily initialized on first use.
    pub fn init(allocator: Allocator, options: InitOptions) !*Self {
        const realm = try allocator.create(Self);
        errdefer allocator.destroy(realm);

        realm.* = .{
            .allocator = allocator,
            .v8_context = options.v8_context,
            .isolate = options.isolate,
            .global_object = options.global_object,
            .intrinsics = Intrinsics.init(),
            .info = switch (options.context_type) {
                .window => RealmInfo.forWindow(),
                .dedicated_worker => RealmInfo.forDedicatedWorker(),
                .shared_worker => RealmInfo.forSharedWorker(),
                .service_worker => RealmInfo.forServiceWorker(),
                .worklet => RealmInfo.forWorklet(),
                .unknown => RealmInfo.forTesting(),
            },
            .browsing_context = options.browsing_context,
        };

        return realm;
    }

    /// Deinitialize realm and free resources
    ///
    /// Note: V8 handles (context, global, intrinsics) must be disposed
    /// by the V8-specific code before calling this.
    pub fn deinit(self: *Self) void {
        self.intrinsics.deinit();
        self.allocator.destroy(self);
    }

    // ========================================================================
    // Context and Global Object Access
    // ========================================================================

    /// Get the V8 context for this realm
    pub fn getV8Context(self: *const Self) ?*anyopaque {
        return self.v8_context;
    }

    /// Get the V8 isolate for this realm
    pub fn getIsolate(self: *const Self) ?*anyopaque {
        return self.isolate;
    }

    /// Get the global object (Window, WorkerGlobalScope) for this realm
    pub fn getGlobalObject(self: *const Self) ?*anyopaque {
        return self.global_object;
    }

    /// Get the browsing context (for Window realms)
    pub fn getBrowsingContext(self: *const Self) ?*anyopaque {
        return self.browsing_context;
    }

    /// Set the global object handle
    ///
    /// Called during realm setup when the Window/Worker is created.
    pub fn setGlobalObject(self: *Self, global: *anyopaque) void {
        self.global_object = global;
    }

    /// Set the browsing context
    ///
    /// Called when associating this realm with a browsing context.
    pub fn setBrowsingContext(self: *Self, ctx: *anyopaque) void {
        self.browsing_context = ctx;
    }

    // ========================================================================
    // Intrinsics Access
    // ========================================================================

    /// Get the intrinsics for this realm
    pub fn getIntrinsics(self: *const Self) *const Intrinsics {
        return &self.intrinsics;
    }

    /// Get mutable intrinsics (for population)
    pub fn getIntrinsicsMut(self: *Self) *Intrinsics {
        return &self.intrinsics;
    }

    /// Check if intrinsics have been populated
    pub fn hasIntrinsics(self: *const Self) bool {
        return self.intrinsics.isPopulated();
    }

    // ========================================================================
    // Context Type Helpers
    // ========================================================================

    /// Get the context type
    pub fn getContextType(self: *const Self) ContextType {
        return self.info.context_type;
    }

    /// Check if this is a Window realm
    pub fn isWindow(self: *const Self) bool {
        return self.info.isWindow();
    }

    /// Check if this is a Worker realm (any type)
    pub fn isWorker(self: *const Self) bool {
        return self.info.isWorker();
    }

    /// Check if this is a Worklet realm
    pub fn isWorklet(self: *const Self) bool {
        return self.info.isWorklet();
    }

    /// Check if an API with given exposure is available in this realm
    pub fn isExposedTo(self: *const Self, exposure: Exposure) bool {
        return self.info.isExposedTo(exposure);
    }

    /// Get human-readable context name
    pub fn contextName(self: *const Self) []const u8 {
        return self.info.contextName();
    }

    // ========================================================================
    // V8-Specific Operations (Placeholders)
    // ========================================================================
    // These methods provide the interface for realm-specific operations.
    // The actual V8 implementation is in src/runtime/engines/v8/realm_v8.zig

    /// Create a TypeError from this realm
    ///
    /// The returned value is from THIS realm's TypeError constructor,
    /// ensuring correct cross-realm behavior per WebIDL spec.
    ///
    /// Note: Actual implementation in V8-specific code.
    /// This is a placeholder that returns null until V8 integration.
    pub fn createTypeError(self: *const Self, message: []const u8) ?*anyopaque {
        _ = self;
        _ = message;
        // Placeholder - actual implementation in realm_v8.zig
        return null;
    }

    /// Throw a TypeError from this realm
    ///
    /// Creates a TypeError and throws it as a V8 exception.
    /// The error comes from THIS realm, not the caller's.
    ///
    /// Note: Actual implementation in V8-specific code.
    pub fn throwTypeError(self: *const Self, message: []const u8) void {
        _ = self;
        _ = message;
        // Placeholder - actual implementation in realm_v8.zig
    }

    /// Create a plain object {} in this realm
    ///
    /// The object's prototype is THIS realm's Object.prototype,
    /// ensuring correct cross-realm behavior for toJSON, etc.
    ///
    /// Note: Actual implementation in V8-specific code.
    pub fn createObject(self: *const Self) ?*anyopaque {
        _ = self;
        // Placeholder - actual implementation in realm_v8.zig
        return null;
    }

    /// Create an array [] in this realm
    ///
    /// The array's prototype is THIS realm's Array.prototype.
    ///
    /// Note: Actual implementation in V8-specific code.
    pub fn createArray(self: *const Self) ?*anyopaque {
        _ = self;
        // Placeholder - actual implementation in realm_v8.zig
        return null;
    }
};

// ============================================================================
// Realm Tests
// ============================================================================

test "Intrinsics - init creates unpopulated intrinsics" {
    const intrinsics = Intrinsics.init();
    try std.testing.expect(!intrinsics.isPopulated());
    try std.testing.expect(intrinsics.type_error == null);
    try std.testing.expect(intrinsics.object == null);
}

test "Realm - init creates realm with default values" {
    const allocator = std.testing.allocator;

    const realm = try Realm.init(allocator, .{});
    defer realm.deinit();

    try std.testing.expect(realm.isWindow()); // Default is window
    try std.testing.expect(realm.v8_context == null);
    try std.testing.expect(realm.isolate == null);
    try std.testing.expect(realm.global_object == null);
    try std.testing.expect(!realm.hasIntrinsics());
}

test "Realm - init with worker context type" {
    const allocator = std.testing.allocator;

    const realm = try Realm.init(allocator, .{
        .context_type = .dedicated_worker,
    });
    defer realm.deinit();

    try std.testing.expect(!realm.isWindow());
    try std.testing.expect(realm.isWorker());
    try std.testing.expectEqual(ContextType.dedicated_worker, realm.getContextType());
}

test "Realm - exposure checking" {
    const allocator = std.testing.allocator;

    // Window realm
    const window_realm = try Realm.init(allocator, .{
        .context_type = .window,
    });
    defer window_realm.deinit();

    try std.testing.expect(window_realm.isExposedTo(.window));
    try std.testing.expect(!window_realm.isExposedTo(.worker));
    try std.testing.expect(window_realm.isExposedTo(.window_and_worker));
    try std.testing.expect(window_realm.isExposedTo(.all));

    // Worker realm
    const worker_realm = try Realm.init(allocator, .{
        .context_type = .dedicated_worker,
    });
    defer worker_realm.deinit();

    try std.testing.expect(!worker_realm.isExposedTo(.window));
    try std.testing.expect(worker_realm.isExposedTo(.worker));
    try std.testing.expect(worker_realm.isExposedTo(.window_and_worker));
    try std.testing.expect(worker_realm.isExposedTo(.all));
}

test "Realm - set and get global object" {
    const allocator = std.testing.allocator;

    const realm = try Realm.init(allocator, .{});
    defer realm.deinit();

    // Initially null
    try std.testing.expect(realm.getGlobalObject() == null);

    // Set a dummy global object
    var dummy: u64 = 0x12345678;
    realm.setGlobalObject(@ptrCast(&dummy));

    // Should be retrievable
    try std.testing.expect(realm.getGlobalObject() != null);
}

test "Realm - set and get browsing context" {
    const allocator = std.testing.allocator;

    const realm = try Realm.init(allocator, .{});
    defer realm.deinit();

    // Initially null
    try std.testing.expect(realm.getBrowsingContext() == null);

    // Set a dummy browsing context
    var dummy: u64 = 0xDEADBEEF;
    realm.setBrowsingContext(@ptrCast(&dummy));

    // Should be retrievable
    try std.testing.expect(realm.getBrowsingContext() != null);
}

test "Realm - contextName returns correct name" {
    const allocator = std.testing.allocator;

    const window = try Realm.init(allocator, .{ .context_type = .window });
    defer window.deinit();
    try std.testing.expectEqualStrings("Window", window.contextName());

    const worker = try Realm.init(allocator, .{ .context_type = .dedicated_worker });
    defer worker.deinit();
    try std.testing.expectEqualStrings("DedicatedWorkerGlobalScope", worker.contextName());

    const service = try Realm.init(allocator, .{ .context_type = .service_worker });
    defer service.deinit();
    try std.testing.expectEqualStrings("ServiceWorkerGlobalScope", service.contextName());
}
