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

// Import environment settings object (circular reference avoided via opaque pointers)
const EnvironmentSettingsObject = @import("environment_settings.zig").EnvironmentSettingsObject;

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

/// Unified global scope kind for all execution contexts
///
/// This enum provides a single source of truth for all global scope types
/// defined by WHATWG specifications. It covers:
/// - Window (HTML Standard)
/// - Workers (HTML Standard): DedicatedWorker, SharedWorker, ServiceWorker
/// - Worklets (various specs): Audio, Paint, Animation, Layout, SharedStorage
/// - ShadowRealm (TC39 Stage 3)
///
/// ## Specification References
/// - HTML §8.1.5: Realms, settings objects, and global objects
/// - HTML §10.2: Workers
/// - CSS Painting API §4: Paint Worklet
/// - CSS Animation Worklet API §4: Animation Worklet
/// - CSS Layout API §4: Layout Worklet
/// - Web Audio API §4: AudioWorklet
/// - Shared Storage API: SharedStorageWorklet
/// - TC39 ShadowRealm Proposal
///
/// ## Usage
///
/// ```zig
/// const scope = GlobalScopeKind.window;
/// std.debug.print("Scope: {s}\n", .{scope.name()});
/// std.debug.print("Implemented: {}\n", .{scope.isImplemented()});
/// ```
pub const GlobalScopeKind = enum {
    // ========================================================================
    // Window Context (HTML Standard)
    // ========================================================================

    /// Browser window context (global = Window)
    /// The primary execution context for web pages.
    /// Most APIs are exposed here, including full DOM access.
    window,

    // ========================================================================
    // Worker Contexts (HTML Standard §10.2)
    // ========================================================================

    /// Dedicated Web Worker (global = DedicatedWorkerGlobalScope)
    /// Runs scripts in background threads, one-to-one with creator.
    /// No DOM access, subset of APIs.
    dedicated_worker,

    /// Shared Web Worker (global = SharedWorkerGlobalScope)
    /// Shared across multiple contexts (windows, iframes, workers).
    /// Communication via MessagePort.
    shared_worker,

    /// Service Worker (global = ServiceWorkerGlobalScope)
    /// Background worker for offline support, caching, push notifications.
    /// Intercepts network requests via fetch event.
    service_worker,

    // ========================================================================
    // Worklet Contexts (Various Specifications)
    // ========================================================================

    /// Audio Worklet (global = AudioWorkletGlobalScope)
    /// Web Audio API - custom audio processing in real-time thread.
    /// https://webaudio.github.io/web-audio-api/#audioworklet
    audio_worklet,

    /// Paint Worklet (global = PaintWorkletGlobalScope)
    /// CSS Painting API - custom CSS image painting.
    /// https://drafts.css-houdini.org/css-paint-api/
    paint_worklet,

    /// Animation Worklet (global = AnimationWorkletGlobalScope)
    /// CSS Animation Worklet API - custom animation effects.
    /// https://drafts.css-houdini.org/css-animationworklet/
    animation_worklet,

    /// Layout Worklet (global = LayoutWorkletGlobalScope)
    /// CSS Layout API - custom layout algorithms.
    /// https://drafts.css-houdini.org/css-layout-api/
    layout_worklet,

    /// Shared Storage Worklet (global = SharedStorageWorkletGlobalScope)
    /// Shared Storage API - cross-site storage with privacy protections.
    /// https://wicg.github.io/shared-storage/
    shared_storage_worklet,

    // ========================================================================
    // ShadowRealm Context (TC39 Stage 3)
    // ========================================================================

    /// ShadowRealm (global = ShadowRealm)
    /// TC39 Stage 3 proposal for isolated JavaScript execution.
    /// https://github.com/tc39/proposal-shadowrealm
    shadow_realm,

    // ========================================================================
    // Testing/Internal
    // ========================================================================

    /// Unknown/unspecified context (for testing only)
    /// Should not be used in production code.
    unknown,

    /// Get human-readable name matching WHATWG specification names
    pub fn name(self: GlobalScopeKind) []const u8 {
        return switch (self) {
            .window => "Window",
            .dedicated_worker => "DedicatedWorkerGlobalScope",
            .shared_worker => "SharedWorkerGlobalScope",
            .service_worker => "ServiceWorkerGlobalScope",
            .audio_worklet => "AudioWorkletGlobalScope",
            .paint_worklet => "PaintWorkletGlobalScope",
            .animation_worklet => "AnimationWorkletGlobalScope",
            .layout_worklet => "LayoutWorkletGlobalScope",
            .shared_storage_worklet => "SharedStorageWorkletGlobalScope",
            .shadow_realm => "ShadowRealm",
            .unknown => "Unknown",
        };
    }

    /// Get short name for WPT and logging
    pub fn shortName(self: GlobalScopeKind) []const u8 {
        return switch (self) {
            .window => "window",
            .dedicated_worker => "worker",
            .shared_worker => "sharedworker",
            .service_worker => "serviceworker",
            .audio_worklet => "audioworklet",
            .paint_worklet => "paintworklet",
            .animation_worklet => "animationworklet",
            .layout_worklet => "layoutworklet",
            .shared_storage_worklet => "sharedstorageworklet",
            .shadow_realm => "shadowrealm",
            .unknown => "unknown",
        };
    }

    /// Check if this scope kind is currently implemented
    ///
    /// Returns true only for scopes with full implementation.
    /// Use this to skip tests for unimplemented contexts.
    pub fn isImplemented(self: GlobalScopeKind) bool {
        return switch (self) {
            // Fully implemented
            .window => true,
            .dedicated_worker => true,

            // Partially implemented or in progress
            .shared_worker => false,
            .service_worker => false,

            // Not implemented
            .audio_worklet => false,
            .paint_worklet => false,
            .animation_worklet => false,
            .layout_worklet => false,
            .shared_storage_worklet => false,
            .shadow_realm => false,
            .unknown => false,
        };
    }

    /// Check if this is any Worker context
    pub fn isWorker(self: GlobalScopeKind) bool {
        return switch (self) {
            .dedicated_worker, .shared_worker, .service_worker => true,
            else => false,
        };
    }

    /// Check if this is any Worklet context
    pub fn isWorklet(self: GlobalScopeKind) bool {
        return switch (self) {
            .audio_worklet,
            .paint_worklet,
            .animation_worklet,
            .layout_worklet,
            .shared_storage_worklet,
            => true,
            else => false,
        };
    }

    /// Check if this is a ShadowRealm context
    pub fn isShadowRealm(self: GlobalScopeKind) bool {
        return self == .shadow_realm;
    }

    /// Convert to legacy ContextType for backward compatibility
    ///
    /// Note: This loses information for specific worklet types.
    /// New code should use GlobalScopeKind directly.
    pub fn toContextType(self: GlobalScopeKind) ContextType {
        return switch (self) {
            .window => .window,
            .dedicated_worker => .dedicated_worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            .audio_worklet,
            .paint_worklet,
            .animation_worklet,
            .layout_worklet,
            .shared_storage_worklet,
            => .worklet,
            .shadow_realm => .unknown, // ShadowRealm not in legacy enum
            .unknown => .unknown,
        };
    }

    /// Create from legacy ContextType
    ///
    /// Note: Converts generic .worklet to .audio_worklet as default.
    /// This is lossy - specific worklet type is unknown.
    pub fn fromContextType(ctx: ContextType) GlobalScopeKind {
        return switch (ctx) {
            .window => .window,
            .dedicated_worker => .dedicated_worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            .worklet => .audio_worklet, // Default to audio_worklet
            .unknown => .unknown,
        };
    }

    /// Parse from WPT global string
    ///
    /// Handles WPT-specific format including ShadowRealm variants.
    /// See: https://web-platform-tests.org/writing-tests/testharness.html
    pub fn fromWptGlobalString(str: []const u8) ?GlobalScopeKind {
        // Standard contexts
        if (std.mem.eql(u8, str, "window")) return .window;
        if (std.mem.eql(u8, str, "worker")) return .dedicated_worker;
        if (std.mem.eql(u8, str, "dedicatedworker")) return .dedicated_worker;
        if (std.mem.eql(u8, str, "sharedworker")) return .shared_worker;
        if (std.mem.eql(u8, str, "serviceworker")) return .service_worker;

        // Worklets
        if (std.mem.eql(u8, str, "audioworklet")) return .audio_worklet;
        if (std.mem.eql(u8, str, "paintworklet")) return .paint_worklet;
        if (std.mem.eql(u8, str, "animationworklet")) return .animation_worklet;
        if (std.mem.eql(u8, str, "layoutworklet")) return .layout_worklet;
        if (std.mem.eql(u8, str, "sharedstorageworklet")) return .shared_storage_worklet;

        // ShadowRealm (including nested variants)
        // WPT uses: shadowrealm, shadowrealm-in-window, shadowrealm-in-dedicatedworker, etc.
        if (std.mem.eql(u8, str, "shadowrealm")) return .shadow_realm;
        if (std.mem.startsWith(u8, str, "shadowrealm-in-")) return .shadow_realm;

        return null;
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

    /// Environment settings object for this realm
    /// Provides origin, API base URL, policies, etc.
    /// This is created lazily when needed.
    settings_object: ?*EnvironmentSettingsObject,

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
            .settings_object = null, // Lazily created when needed
        };

        return realm;
    }

    /// Deinitialize realm and free resources
    ///
    /// Note: V8 handles (context, global, intrinsics) must be disposed
    /// by the V8-specific code before calling this.
    pub fn deinit(self: *Self) void {
        // Free environment settings object if we created it
        if (self.settings_object) |settings| {
            settings.deinit();
        }

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
    // Environment Settings Object
    // ========================================================================

    /// Get or create the environment settings object for this realm
    ///
    /// Per HTML §8.1.5, each realm has an associated environment settings object.
    /// This is created lazily on first access.
    pub fn getSettingsObject(self: *Self) !*EnvironmentSettingsObject {
        if (self.settings_object) |settings| {
            return settings;
        }

        // Create a new settings object for this realm
        const settings = try EnvironmentSettingsObject.init(self.allocator, .{
            .realm = self,
            // Other options will be set based on the context type
        });
        errdefer settings.deinit();

        self.settings_object = settings;
        return settings;
    }

    /// Get the settings object if already created (no allocation)
    pub fn getExistingSettingsObject(self: *const Self) ?*EnvironmentSettingsObject {
        return self.settings_object;
    }

    /// Set a pre-created settings object
    ///
    /// This takes ownership of the settings object.
    /// Any existing settings object will be freed.
    pub fn setSettingsObject(self: *Self, settings: *EnvironmentSettingsObject) void {
        if (self.settings_object) |old| {
            old.deinit();
        }
        self.settings_object = settings;
    }

    // ========================================================================
    // V8-Specific Operations
    // ========================================================================
    // These methods provide the interface for realm-specific operations.
    // The actual V8 implementation is in src/runtime/engines/v8/realm_v8.zig
    //
    // NOTE: V8 is a separate module, imported via @import("v8").
    // We use comptime detection to conditionally use V8-specific functions.

    /// Create a TypeError from this realm
    ///
    /// The returned value is from THIS realm's TypeError constructor,
    /// ensuring correct cross-realm behavior per WebIDL spec.
    ///
    /// Per WebIDL, when a method throws TypeError for invalid `this`,
    /// the error must come from the method's realm (callee's realm).
    pub fn createTypeError(self: *const Self, message: []const u8) ?*anyopaque {
        // Import V8 module at comptime - this is the SEPARATE v8 module
        const v8 = @import("v8");
        return @ptrCast(v8.realm_v8.createTypeErrorInRealm(self, message));
    }

    /// Throw a TypeError from this realm
    ///
    /// Creates a TypeError and throws it as a V8 exception.
    /// The error comes from THIS realm, not the caller's.
    pub fn throwTypeError(self: *const Self, message: []const u8) void {
        const v8 = @import("v8");
        v8.realm_v8.throwTypeErrorFromRealm(self, message);
    }

    /// Create a plain object {} in this realm
    ///
    /// The object's prototype is THIS realm's Object.prototype,
    /// ensuring correct cross-realm behavior for toJSON, etc.
    ///
    /// Per WebIDL §4.3, toJSON must create result objects in the method's realm:
    /// ```javascript
    /// const other = iframe.contentWindow;
    /// const rect = new DOMRectReadOnly(1, 2, 3, 4);
    /// const json = other.DOMRectReadOnly.prototype.toJSON.call(rect);
    /// // json's prototype must be other.Object.prototype
    /// ```
    pub fn createObject(self: *const Self) ?*anyopaque {
        const v8 = @import("v8");
        return @ptrCast(v8.realm_v8.createObjectInRealm(self));
    }

    /// Create an array [] in this realm
    ///
    /// The array's prototype is THIS realm's Array.prototype.
    pub fn createArray(self: *const Self) ?*anyopaque {
        return createArrayWithLength(self, 0);
    }

    /// Create an array with specified length in this realm
    ///
    /// The array's prototype is THIS realm's Array.prototype.
    pub fn createArrayWithLength(self: *const Self, length: u32) ?*anyopaque {
        const v8 = @import("v8");
        return @ptrCast(v8.realm_v8.createArrayInRealm(self, length));
    }

    /// Populate this realm's intrinsics from its V8 context
    ///
    /// This caches built-in constructors (TypeError, Object, Array, etc.)
    /// for efficient access. Call this after the V8 context is created.
    pub fn populateIntrinsics(self: *Self) bool {
        const v8 = @import("v8");
        return v8.realm_v8.populateIntrinsics(self);
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

// ============================================================================
// GlobalScopeKind Tests
// ============================================================================

test "GlobalScopeKind - name returns WHATWG spec names" {
    try std.testing.expectEqualStrings("Window", GlobalScopeKind.window.name());
    try std.testing.expectEqualStrings("DedicatedWorkerGlobalScope", GlobalScopeKind.dedicated_worker.name());
    try std.testing.expectEqualStrings("SharedWorkerGlobalScope", GlobalScopeKind.shared_worker.name());
    try std.testing.expectEqualStrings("ServiceWorkerGlobalScope", GlobalScopeKind.service_worker.name());
    try std.testing.expectEqualStrings("AudioWorkletGlobalScope", GlobalScopeKind.audio_worklet.name());
    try std.testing.expectEqualStrings("PaintWorkletGlobalScope", GlobalScopeKind.paint_worklet.name());
    try std.testing.expectEqualStrings("AnimationWorkletGlobalScope", GlobalScopeKind.animation_worklet.name());
    try std.testing.expectEqualStrings("LayoutWorkletGlobalScope", GlobalScopeKind.layout_worklet.name());
    try std.testing.expectEqualStrings("SharedStorageWorkletGlobalScope", GlobalScopeKind.shared_storage_worklet.name());
    try std.testing.expectEqualStrings("ShadowRealm", GlobalScopeKind.shadow_realm.name());
    try std.testing.expectEqualStrings("Unknown", GlobalScopeKind.unknown.name());
}

test "GlobalScopeKind - shortName returns WPT-compatible names" {
    try std.testing.expectEqualStrings("window", GlobalScopeKind.window.shortName());
    try std.testing.expectEqualStrings("worker", GlobalScopeKind.dedicated_worker.shortName());
    try std.testing.expectEqualStrings("sharedworker", GlobalScopeKind.shared_worker.shortName());
    try std.testing.expectEqualStrings("serviceworker", GlobalScopeKind.service_worker.shortName());
    try std.testing.expectEqualStrings("audioworklet", GlobalScopeKind.audio_worklet.shortName());
    try std.testing.expectEqualStrings("paintworklet", GlobalScopeKind.paint_worklet.shortName());
    try std.testing.expectEqualStrings("animationworklet", GlobalScopeKind.animation_worklet.shortName());
    try std.testing.expectEqualStrings("layoutworklet", GlobalScopeKind.layout_worklet.shortName());
    try std.testing.expectEqualStrings("sharedstorageworklet", GlobalScopeKind.shared_storage_worklet.shortName());
    try std.testing.expectEqualStrings("shadowrealm", GlobalScopeKind.shadow_realm.shortName());
    try std.testing.expectEqualStrings("unknown", GlobalScopeKind.unknown.shortName());
}

test "GlobalScopeKind - isImplemented reflects current status" {
    // Implemented contexts
    try std.testing.expect(GlobalScopeKind.window.isImplemented());
    try std.testing.expect(GlobalScopeKind.dedicated_worker.isImplemented());

    // Not implemented contexts
    try std.testing.expect(!GlobalScopeKind.shared_worker.isImplemented());
    try std.testing.expect(!GlobalScopeKind.service_worker.isImplemented());
    try std.testing.expect(!GlobalScopeKind.audio_worklet.isImplemented());
    try std.testing.expect(!GlobalScopeKind.paint_worklet.isImplemented());
    try std.testing.expect(!GlobalScopeKind.animation_worklet.isImplemented());
    try std.testing.expect(!GlobalScopeKind.layout_worklet.isImplemented());
    try std.testing.expect(!GlobalScopeKind.shared_storage_worklet.isImplemented());
    try std.testing.expect(!GlobalScopeKind.shadow_realm.isImplemented());
    try std.testing.expect(!GlobalScopeKind.unknown.isImplemented());
}

test "GlobalScopeKind - isWorker" {
    // Workers
    try std.testing.expect(GlobalScopeKind.dedicated_worker.isWorker());
    try std.testing.expect(GlobalScopeKind.shared_worker.isWorker());
    try std.testing.expect(GlobalScopeKind.service_worker.isWorker());

    // Not workers
    try std.testing.expect(!GlobalScopeKind.window.isWorker());
    try std.testing.expect(!GlobalScopeKind.audio_worklet.isWorker());
    try std.testing.expect(!GlobalScopeKind.shadow_realm.isWorker());
    try std.testing.expect(!GlobalScopeKind.unknown.isWorker());
}

test "GlobalScopeKind - isWorklet" {
    // Worklets
    try std.testing.expect(GlobalScopeKind.audio_worklet.isWorklet());
    try std.testing.expect(GlobalScopeKind.paint_worklet.isWorklet());
    try std.testing.expect(GlobalScopeKind.animation_worklet.isWorklet());
    try std.testing.expect(GlobalScopeKind.layout_worklet.isWorklet());
    try std.testing.expect(GlobalScopeKind.shared_storage_worklet.isWorklet());

    // Not worklets
    try std.testing.expect(!GlobalScopeKind.window.isWorklet());
    try std.testing.expect(!GlobalScopeKind.dedicated_worker.isWorklet());
    try std.testing.expect(!GlobalScopeKind.shadow_realm.isWorklet());
    try std.testing.expect(!GlobalScopeKind.unknown.isWorklet());
}

test "GlobalScopeKind - isShadowRealm" {
    try std.testing.expect(GlobalScopeKind.shadow_realm.isShadowRealm());

    try std.testing.expect(!GlobalScopeKind.window.isShadowRealm());
    try std.testing.expect(!GlobalScopeKind.dedicated_worker.isShadowRealm());
    try std.testing.expect(!GlobalScopeKind.audio_worklet.isShadowRealm());
    try std.testing.expect(!GlobalScopeKind.unknown.isShadowRealm());
}

test "GlobalScopeKind - toContextType conversion" {
    try std.testing.expectEqual(ContextType.window, GlobalScopeKind.window.toContextType());
    try std.testing.expectEqual(ContextType.dedicated_worker, GlobalScopeKind.dedicated_worker.toContextType());
    try std.testing.expectEqual(ContextType.shared_worker, GlobalScopeKind.shared_worker.toContextType());
    try std.testing.expectEqual(ContextType.service_worker, GlobalScopeKind.service_worker.toContextType());

    // All worklets map to generic worklet
    try std.testing.expectEqual(ContextType.worklet, GlobalScopeKind.audio_worklet.toContextType());
    try std.testing.expectEqual(ContextType.worklet, GlobalScopeKind.paint_worklet.toContextType());
    try std.testing.expectEqual(ContextType.worklet, GlobalScopeKind.animation_worklet.toContextType());
    try std.testing.expectEqual(ContextType.worklet, GlobalScopeKind.layout_worklet.toContextType());
    try std.testing.expectEqual(ContextType.worklet, GlobalScopeKind.shared_storage_worklet.toContextType());

    // ShadowRealm not in legacy enum, maps to unknown
    try std.testing.expectEqual(ContextType.unknown, GlobalScopeKind.shadow_realm.toContextType());
    try std.testing.expectEqual(ContextType.unknown, GlobalScopeKind.unknown.toContextType());
}

test "GlobalScopeKind - fromContextType conversion" {
    try std.testing.expectEqual(GlobalScopeKind.window, GlobalScopeKind.fromContextType(.window));
    try std.testing.expectEqual(GlobalScopeKind.dedicated_worker, GlobalScopeKind.fromContextType(.dedicated_worker));
    try std.testing.expectEqual(GlobalScopeKind.shared_worker, GlobalScopeKind.fromContextType(.shared_worker));
    try std.testing.expectEqual(GlobalScopeKind.service_worker, GlobalScopeKind.fromContextType(.service_worker));

    // Generic worklet defaults to audio_worklet
    try std.testing.expectEqual(GlobalScopeKind.audio_worklet, GlobalScopeKind.fromContextType(.worklet));
    try std.testing.expectEqual(GlobalScopeKind.unknown, GlobalScopeKind.fromContextType(.unknown));
}

test "GlobalScopeKind - fromWptGlobalString standard contexts" {
    // Window
    try std.testing.expectEqual(GlobalScopeKind.window, GlobalScopeKind.fromWptGlobalString("window").?);

    // Workers (both forms)
    try std.testing.expectEqual(GlobalScopeKind.dedicated_worker, GlobalScopeKind.fromWptGlobalString("worker").?);
    try std.testing.expectEqual(GlobalScopeKind.dedicated_worker, GlobalScopeKind.fromWptGlobalString("dedicatedworker").?);
    try std.testing.expectEqual(GlobalScopeKind.shared_worker, GlobalScopeKind.fromWptGlobalString("sharedworker").?);
    try std.testing.expectEqual(GlobalScopeKind.service_worker, GlobalScopeKind.fromWptGlobalString("serviceworker").?);
}

test "GlobalScopeKind - fromWptGlobalString worklets" {
    try std.testing.expectEqual(GlobalScopeKind.audio_worklet, GlobalScopeKind.fromWptGlobalString("audioworklet").?);
    try std.testing.expectEqual(GlobalScopeKind.paint_worklet, GlobalScopeKind.fromWptGlobalString("paintworklet").?);
    try std.testing.expectEqual(GlobalScopeKind.animation_worklet, GlobalScopeKind.fromWptGlobalString("animationworklet").?);
    try std.testing.expectEqual(GlobalScopeKind.layout_worklet, GlobalScopeKind.fromWptGlobalString("layoutworklet").?);
    try std.testing.expectEqual(GlobalScopeKind.shared_storage_worklet, GlobalScopeKind.fromWptGlobalString("sharedstorageworklet").?);
}

test "GlobalScopeKind - fromWptGlobalString shadowrealm" {
    // Base shadowrealm
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm").?);

    // Nested variants all map to shadow_realm
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-window").?);
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-dedicatedworker").?);
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-sharedworker").?);
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-shadowrealm").?);
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-audioworklet").?);
    try std.testing.expectEqual(GlobalScopeKind.shadow_realm, GlobalScopeKind.fromWptGlobalString("shadowrealm-in-serviceworker").?);
}

test "GlobalScopeKind - fromWptGlobalString invalid returns null" {
    try std.testing.expectEqual(@as(?GlobalScopeKind, null), GlobalScopeKind.fromWptGlobalString("invalid"));
    try std.testing.expectEqual(@as(?GlobalScopeKind, null), GlobalScopeKind.fromWptGlobalString(""));
    try std.testing.expectEqual(@as(?GlobalScopeKind, null), GlobalScopeKind.fromWptGlobalString("Window")); // case-sensitive
    try std.testing.expectEqual(@as(?GlobalScopeKind, null), GlobalScopeKind.fromWptGlobalString("WORKER"));
}
