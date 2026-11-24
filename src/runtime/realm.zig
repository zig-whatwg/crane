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
//!
//! Bindings check WebIDL [Exposed] through src/webidl/helpers.zig's
//! GlobalScope.matchesExposure.
//!
//! ## Specification References
//! - HTML Realms: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//! - HTML §8.1.5: Realms, settings objects, and global objects
//! - WebIDL §3.3: Platform objects and realms
//! - WebIDL Exposed: https://webidl.spec.whatwg.org/#Exposed

const std = @import("std");
const Allocator = std.mem.Allocator;

const Agent = @import("engine_types.zig").Agent;

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
};

// ============================================================================
// Tests
// ============================================================================

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

    /// %Promise%: the realm's own Promise constructor, as it was when the
    /// realm was made - V8's API has no accessor for the intrinsic, so the
    /// adapter records it here (realm_v8.populateIntrinsics). The protocol's
    /// promise operations can take it from `realm.getIntrinsics().promise`
    /// instead of reaching it indirectly.
    promise: ?*anyopaque,

    /// %AsyncIteratorPrototype% (ECMA-262 27.1.3): the [[Prototype]] of
    /// %AsyncGeneratorPrototype%, which no global names; the adapter asks V8
    /// for it by name (v8::Intrinsic::kAsyncIteratorPrototype, through a
    /// template) and records it here, as `promise` is, for the protocol's
    /// async iterators (WebIDL's %AsyncIteratorPrototype% is this object).
    async_iterator_prototype: ?*anyopaque,

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
            .promise = null,
            .async_iterator_prototype = null,
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
        self.promise = null;
        self.async_iterator_prototype = null;
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
/// Values are made in a realm through the engine protocol's operations, which
/// take the realm as a runtime.Context (AGENTS.md, "The engine boundary").
///
/// ## Usage
///
/// ```zig
/// // Create the realm record for an engine context
/// const realm = try Realm.init(allocator, .{
///     .engine_realm = context,
///     .agent = agent,
///     .context_type = .window,
/// });
/// defer realm.deinit();
/// ```
pub const Realm = struct {
    /// Memory allocator for realm-owned resources
    allocator: Allocator,

    /// The engine's handle to this realm's execution context - opaque here,
    /// the adapter's to read (V8's: a Global<Context>*).
    engine_realm: ?*anyopaque,

    /// The agent the realm belongs to (ECMAScript 9.7), shared by every realm
    /// in it - V8's is an isolate.
    agent: ?*Agent,

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
        /// The engine's handle to the realm's execution context (opaque)
        engine_realm: ?*anyopaque = null,

        /// The realm's agent
        agent: ?*Agent = null,

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
    /// Intrinsics start unpopulated; the engine adapter fills them
    /// (realm_v8.zig's populateIntrinsics).
    pub fn init(allocator: Allocator, options: InitOptions) !*Self {
        const realm = try allocator.create(Self);
        errdefer allocator.destroy(realm);

        realm.* = .{
            .allocator = allocator,
            .engine_realm = options.engine_realm,
            .agent = options.agent,
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

    /// The engine's handle to this realm's execution context
    pub fn getEngineRealm(self: *const Self) ?*anyopaque {
        return self.engine_realm;
    }

    /// The realm's agent
    pub fn getAgent(self: *const Self) ?*Agent {
        return self.agent;
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
};
