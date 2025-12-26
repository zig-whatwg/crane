//! Runtime Context for WebIDL operations
//!
//! Context is passed to all namespace operations and stored in instances.
//! It provides access to the JavaScript execution environment, logging,
//! and other runtime services.
//!
//! ## Design
//!
//! The Context is a pointer to a ContextData struct that contains:
//! - Logger: For console output (console.log, console.error, etc.)
//! - Engine Interface: Abstract interface to JS engine (V8, JSC, etc.)
//! - Engine Context: Opaque pointer to engine-specific context
//! - Allocator: For memory management
//!
//! By using a pointer (`*ContextData`), we keep the Context small (8 bytes)
//! which is important for passing through generated code.
//!
//! ## Engine Abstraction
//!
//! The context holds an optional `EngineInterface` pointer which provides
//! engine-agnostic operations like wrapping async iterators, creating promises,
//! etc. This allows impl files to work with any JS engine without direct imports.
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // Create context with logger (no engine)
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .colored = true,
//! });
//! defer ctx_data.deinit();
//!
//! const ctx: runtime.Context = &ctx_data;
//!
//! // Use in namespace operations
//! console.log(ctx, "Hello from WebIDL!");
//!
//! // For engine operations, check if engine is available
//! if (ctx.getEngine()) |engine| {
//!     const wrapped = try engine.wrapAsyncIterator(ctx.engine_ctx.?, iterator);
//! }
//! ```

const std = @import("std");
const Logger = @import("logger.zig").Logger;
const LoggerConfig = @import("logger.zig").LoggerConfig;
const EngineInterface = @import("engine_interface.zig").EngineInterface;
const infra = @import("infra");
const timer_mod = @import("timer.zig");

// Realm infrastructure for context type and exposure checking
const realm_mod = @import("realm.zig");
pub const RealmInfo = realm_mod.RealmInfo;
pub const ContextType = realm_mod.ContextType;
pub const Exposure = realm_mod.Exposure;
pub const Realm = realm_mod.Realm;
pub const Intrinsics = realm_mod.Intrinsics;

// Import event loop for streams and async operations
// Note: This is an optional dependency - event_loop is only needed for async features
const event_loop_mod = @import("event_loop");

// Import storage backend for IndexedDB and Storage Standard
const storage = @import("storage");
const StorageBackend = storage.StorageBackend;
const BackendType = storage.BackendType;

// Import network pollable for async HTTP
const network_pollable_mod = @import("network_pollable.zig");
const NetworkPollable = network_pollable_mod.NetworkPollable;

/// Storage configuration for IndexedDB and Storage Standard
///
/// Configures the storage backend selection and parameters.
/// Used by the runtime to initialize storage for the origin.
pub const StorageConfig = struct {
    /// Backend type to use (sqlite, leveldb, memory)
    backend_type: BackendType = .memory,

    /// Base path for storage data (e.g., "/data/storage" or "~/.app/storage")
    /// For memory backend, this is ignored
    data_path: []const u8 = "",

    /// Storage quota in bytes (null = unlimited)
    /// Per WHATWG Storage Standard, this is per-origin quota
    quota_bytes: ?u64 = null,

    /// Enable encryption at rest (requires backend support)
    encryption_enabled: bool = false,

    /// Create default config for testing (in-memory, no quota)
    pub fn forTesting() StorageConfig {
        return .{
            .backend_type = .memory,
            .data_path = "",
            .quota_bytes = null,
        };
    }

    /// Create default config for production (SQLite, reasonable quota)
    pub fn forProduction(data_path: []const u8) StorageConfig {
        return .{
            .backend_type = .sqlite,
            .data_path = data_path,
            .quota_bytes = 50 * 1024 * 1024, // 50MB default quota
        };
    }
};

/// Console state for console namespace operations
///
/// This state is per-context (one instance per ContextData).
/// Stores count maps, timers, and group stack for console operations.
pub const ConsoleState = struct {
    /// Map of labels to counts (for console.count/console.countReset)
    count_map: std.StringHashMap(u32),

    /// Map of labels to start times (for console.time/console.timeLog/console.timeEnd)
    timer_table: std.StringHashMap(i64),

    /// Stack of active groups (for console.group/console.groupCollapsed/console.groupEnd)
    /// Stores indent level as u32
    group_stack: std.ArrayList(u32),

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .count_map = std.StringHashMap(u32).init(allocator),
            .timer_table = std.StringHashMap(i64).init(allocator),
            .group_stack = .{}, // ArrayList has default empty initialization
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Free all keys in count_map
        var count_iter = self.count_map.keyIterator();
        while (count_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.count_map.deinit();

        // Free all keys in timer_table
        var timer_iter = self.timer_table.keyIterator();
        while (timer_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.timer_table.deinit();

        self.group_stack.deinit(allocator);
    }

    /// Get current indent level based on group stack depth
    pub fn getIndentLevel(self: *const Self) u32 {
        return @intCast(self.group_stack.items.len);
    }
};

/// Runtime context data structure
///
/// This struct contains all runtime services: logging, memory management,
/// JS engine integration, and event loop for async operations.
pub const ContextData = struct {
    allocator: std.mem.Allocator,
    logger: Logger,

    /// Abstract engine interface (provides engine-agnostic operations)
    engine: ?*const EngineInterface,

    /// Engine-specific opaque context (V8 Isolate, JSC VM, etc.)
    engine_ctx: ?*anyopaque,

    console_state: ConsoleState,

    /// Event loop for async operations (streams, promises, etc.)
    /// Optional - only needed for async features like ReadableStream
    event_loop: ?event_loop_mod.EventLoop,

    /// Timer interface for setTimeout/clearTimeout (AbortSignal.timeout, etc.)
    /// Optional - only available with engines that support timers (V8+libuv)
    timer: ?timer_mod.TimerInterface,

    /// Storage backend for IndexedDB and Storage Standard
    /// Optional - only needed for IndexedDB, localStorage, sessionStorage, etc.
    storage_backend: ?*StorageBackend,

    /// Storage configuration
    storage_config: StorageConfig,

    /// Network pollable for async HTTP requests (fetch API)
    /// Optional - only needed for non-blocking fetch() operations
    network_pollable: ?NetworkPollable,

    /// Network manager pointer (AsyncCurlManager or similar)
    /// This is the concrete manager that call_fetch can use directly
    /// Stored separately from network_pollable because impl needs direct access
    _network_manager: ?*anyopaque,

    /// Internal: Engine-created event loop storage (if created during init)
    /// This is owned by the context and must be cleaned up via engine interface
    _engine_event_loop_storage: ?*anyopaque,

    /// V8 wrapper cache (optional, only used with V8 engine)
    /// Maintains 1:1 mapping between Zig instances and V8 wrappers for identity
    _v8_wrapper_cache_storage: ?*anyopaque,

    /// Realm information for this context
    /// Identifies execution environment (Window, Worker, etc.)
    /// Used for WebIDL [Exposed] attribute checking
    realm_info: RealmInfo,

    /// Full Realm object for cross-realm support
    /// Contains V8 context, intrinsics, and global object references.
    /// Optional - only set for contexts that need cross-realm functionality.
    /// This enables proper cross-realm TypeError throwing, object creation, etc.
    realm: ?*Realm,

    const Self = @This();

    /// Context initialization options
    pub const Options = struct {
        /// Logger configuration
        colored: bool = true,
        show_timestamp: bool = false,
        show_labels: bool = false,

        /// Abstract engine interface
        /// Provides engine-agnostic operations (async iterators, promises, etc.)
        engine: ?*const EngineInterface = null,

        /// JS engine context (V8 Isolate, JSC VM, etc.)
        /// This is an opaque pointer to the engine-specific context
        engine_ctx: ?*anyopaque = null,

        /// Event loop for async operations
        /// Optional - only needed for async features like streams, promises
        /// If not provided and engine supports it, engine will create one
        /// If not provided and no engine, async operations will fail with error.NoEventLoop
        event_loop: ?event_loop_mod.EventLoop = null,

        /// Timer interface for setTimeout/clearTimeout
        /// Optional - only needed for AbortSignal.timeout() and similar APIs
        /// If not provided, timer operations will return error.NoTimerSupport
        timer: ?timer_mod.TimerInterface = null,

        /// Storage backend for IndexedDB and Storage Standard
        /// Optional - only needed for storage APIs
        /// If not provided, storage operations will return error.NoStorageBackend
        storage_backend: ?*StorageBackend = null,

        /// Storage configuration
        /// Default is memory backend with no quota (for testing)
        storage_config: ?StorageConfig = null,

        /// Network pollable for async HTTP requests
        /// Optional - only needed for non-blocking fetch() operations
        /// If not provided, fetch() will use synchronous path (blocking)
        network_pollable: ?NetworkPollable = null,

        /// Realm information for this context
        /// Defaults to unknown (for testing)
        realm_info: ?RealmInfo = null,

        /// Full Realm object for cross-realm support
        /// Optional - only needed for multi-context scenarios (iframes, etc.)
        realm: ?*Realm = null,
    };

    /// Initialize a new runtime context
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        const logger = Logger.init(allocator, .{
            .colored = options.colored,
            .show_timestamp = options.show_timestamp,
            .show_labels = options.show_labels,
        });

        // Determine event loop:
        // 1. If event_loop provided explicitly → use it
        // 2. If engine can create one → use engine's event loop
        // 3. Otherwise → no event loop (async operations will fail)
        var engine_event_loop_storage: ?*anyopaque = null;
        const ev_loop: ?event_loop_mod.EventLoop = if (options.event_loop) |el|
            el
        else if (options.engine) |engine| blk: {
            if (engine.createEventLoop) |create_fn| {
                if (options.engine_ctx) |engine_ctx| {
                    const loop_ptr = create_fn(engine_ctx, allocator) catch break :blk null;
                    engine_event_loop_storage = loop_ptr;
                    // Engine must provide a way to get EventLoop from its storage
                    // For now, we assume the engine stores it and we query later
                    break :blk null; // TODO: Engine should return EventLoop directly
                }
            }
            break :blk null;
        } else null;

        return .{
            .allocator = allocator,
            .logger = logger,
            .engine = options.engine,
            .engine_ctx = options.engine_ctx,
            .console_state = ConsoleState.init(allocator),
            .event_loop = ev_loop,
            .timer = options.timer,
            .storage_backend = options.storage_backend,
            .storage_config = options.storage_config orelse StorageConfig.forTesting(),
            .network_pollable = options.network_pollable,
            ._network_manager = null, // Set via setNetworkManager()
            ._engine_event_loop_storage = engine_event_loop_storage,
            ._v8_wrapper_cache_storage = null, // Initialized later via initV8WrapperCache
            .realm_info = options.realm_info orelse RealmInfo.forTesting(),
            .realm = options.realm,
        };
    }

    /// Deinitialize context and cleanup resources
    pub fn deinit(self: *Self) void {
        // NOTE: V8 wrapper cache cleanup is handled by context_manager
        // before calling this function (to avoid circular module dependencies)

        // Clean up engine-created event loop if we have one
        if (self._engine_event_loop_storage) |loop_storage| {
            if (self.engine) |engine| {
                if (engine.destroyEventLoop) |destroy_fn| {
                    destroy_fn(loop_storage, self.allocator);
                }
            }
        }

        self.console_state.deinit(self.allocator);
        self.logger.deinit();
    }

    /// Get V8 wrapper cache storage (returns null if not initialized)
    ///
    /// This is used by template_registry.wrapInstanceAsV8Object to access the cache.
    /// The cache is initialized and cleaned up by context_manager.
    pub fn getV8WrapperCacheStorage(self: *Self) ?*anyopaque {
        return self._v8_wrapper_cache_storage;
    }

    /// Set V8 wrapper cache storage (called by context_manager during init)
    ///
    /// This is an internal method used by context_manager to inject the cache.
    pub fn setV8WrapperCacheStorage(self: *Self, cache_storage: *anyopaque) void {
        self._v8_wrapper_cache_storage = cache_storage;
    }

    /// Clear V8 wrapper cache storage (called by context_manager during cleanup)
    ///
    /// This is an internal method used by context_manager.
    pub fn clearV8WrapperCacheStorage(self: *Self) void {
        self._v8_wrapper_cache_storage = null;
    }

    /// Check if this context has a JS engine
    pub fn hasEngine(self: *const Self) bool {
        return self.engine != null and self.engine_ctx != null;
    }

    /// Get the abstract engine interface
    pub fn getEngine(self: *const Self) ?*const EngineInterface {
        return self.engine;
    }

    /// Get the JS engine context (opaque pointer to V8 Isolate, JSC VM, etc.)
    pub fn getEngineContext(self: *const Self) ?*anyopaque {
        return self.engine_ctx;
    }

    /// Get the JS engine context as a specific type (type-safe cast)
    ///
    /// This is a convenience method for getting the engine context as a typed pointer,
    /// avoiding the need for @ptrCast(@alignCast(...)) at call sites.
    ///
    /// Usage:
    /// ```zig
    /// const v8_ctx = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return error.NoEngineContext;
    /// ```
    pub fn getEngineContextAs(self: *const Self, comptime T: type) ?*T {
        const ptr = self.engine_ctx orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// Get the allocator for this context
    pub fn getAllocator(self: *const Self) std.mem.Allocator {
        return self.allocator;
    }

    /// Check if this context has an event loop
    pub fn hasEventLoop(self: *const Self) bool {
        return self.event_loop != null;
    }

    /// Get the event loop (returns error if not available)
    pub fn getEventLoop(self: *const Self) !event_loop_mod.EventLoop {
        return self.event_loop orelse error.NoEventLoop;
    }

    /// Get optional event loop
    pub fn getOptionalEventLoop(self: *const Self) ?event_loop_mod.EventLoop {
        return self.event_loop;
    }

    /// Check if this context has timer support
    pub fn hasTimer(self: *const Self) bool {
        return self.timer != null;
    }

    /// Get the timer interface (returns error if not available)
    pub fn getTimer(self: *const Self) timer_mod.TimerError!timer_mod.TimerInterface {
        return self.timer orelse timer_mod.TimerError.NoTimerSupport;
    }

    /// Get optional timer interface
    pub fn getOptionalTimer(self: *const Self) ?timer_mod.TimerInterface {
        return self.timer;
    }

    /// Set the timer interface (called by external code during setup)
    ///
    /// This allows setting timer support after context creation,
    /// useful when the timer manager is created separately.
    pub fn setTimer(self: *Self, timer_interface: timer_mod.TimerInterface) void {
        self.timer = timer_interface;
    }

    /// Check if this context has storage backend support
    pub fn hasStorageBackend(self: *const Self) bool {
        return self.storage_backend != null;
    }

    /// Get the storage backend (returns error if not available)
    pub fn getStorageBackend(self: *const Self) error{NoStorageBackend}!*StorageBackend {
        return self.storage_backend orelse error.NoStorageBackend;
    }

    /// Get optional storage backend
    pub fn getOptionalStorageBackend(self: *const Self) ?*StorageBackend {
        return self.storage_backend;
    }

    /// Get the storage configuration
    pub fn getStorageConfig(self: *const Self) StorageConfig {
        return self.storage_config;
    }

    /// Set the storage backend (called by external code during setup)
    ///
    /// This allows setting storage backend after context creation,
    /// useful when the backend is created separately.
    pub fn setStorageBackend(self: *Self, backend: *StorageBackend) void {
        self.storage_backend = backend;
    }

    /// Set the storage configuration
    pub fn setStorageConfig(self: *Self, config: StorageConfig) void {
        self.storage_config = config;
    }

    // ========================================================================
    // Network Pollable Methods (for async fetch)
    // ========================================================================

    /// Check if this context has network pollable support
    pub fn hasNetworkPollable(self: *const Self) bool {
        return self.network_pollable != null;
    }

    /// Get the network pollable (returns error if not available)
    pub fn getNetworkPollable(self: *const Self) error{NoNetworkPollable}!NetworkPollable {
        return self.network_pollable orelse error.NoNetworkPollable;
    }

    /// Get optional network pollable
    pub fn getOptionalNetworkPollable(self: *const Self) ?NetworkPollable {
        return self.network_pollable;
    }

    /// Set the network pollable (called by Browser during setup)
    ///
    /// This allows setting network pollable after context creation,
    /// useful when the AsyncCurlManager is created separately.
    pub fn setNetworkPollable(self: *Self, pollable: NetworkPollable) void {
        self.network_pollable = pollable;
    }

    /// Get network manager pointer (for call_fetch to use directly)
    /// Returns opaque pointer that must be cast to the correct type
    pub fn getNetworkManager(self: *const Self) ?*anyopaque {
        return self._network_manager;
    }

    /// Set network manager pointer (called by Browser during setup)
    /// Pass the AsyncCurlManager pointer that call_fetch will use
    pub fn setNetworkManager(self: *Self, manager: *anyopaque) void {
        self._network_manager = manager;
    }

    // ========================================================================
    // Realm and Context Type Methods
    // ========================================================================

    /// Get the realm info for this context
    pub fn getRealmInfo(self: *const Self) RealmInfo {
        return self.realm_info;
    }

    /// Check if an API with given exposure is available in this context
    ///
    /// Per WebIDL spec, [Exposed] attribute determines availability:
    /// - [Exposed=Window] -> only in Window
    /// - [Exposed=Worker] -> only in Workers
    /// - [Exposed=(Window,Worker)] -> both
    /// - [Exposed=*] -> all contexts
    pub fn isExposedTo(self: *const Self, exposure: Exposure) bool {
        return self.realm_info.isExposedTo(exposure);
    }

    /// Check if this is a Window context
    pub fn isWindow(self: *const Self) bool {
        return self.realm_info.isWindow();
    }

    /// Check if this is any Worker context (Dedicated, Shared, or Service)
    pub fn isWorker(self: *const Self) bool {
        return self.realm_info.isWorker();
    }

    /// Check if this is a Worklet context
    pub fn isWorklet(self: *const Self) bool {
        return self.realm_info.isWorklet();
    }

    /// Get human-readable context name for debugging
    pub fn contextName(self: *const Self) []const u8 {
        return self.realm_info.contextName();
    }

    // ========================================================================
    // Full Realm Access (Cross-Realm Support)
    // ========================================================================

    /// Check if this context has a full Realm object
    ///
    /// Returns true if cross-realm functionality is available.
    pub fn hasRealm(self: *const Self) bool {
        return self.realm != null;
    }

    /// Get the full Realm object
    ///
    /// Returns the Realm for cross-realm operations (creating errors,
    /// objects in correct realm, etc.), or null if not available.
    pub fn getRealm(self: *const Self) ?*Realm {
        return self.realm;
    }

    /// Set the Realm object
    ///
    /// Called during context setup to associate a Realm with this context.
    pub fn setRealm(self: *Self, realm: *Realm) void {
        self.realm = realm;
        // Sync realm_info with the realm's info
        self.realm_info = realm.info;
    }

    /// Clear the Realm object
    ///
    /// Called during cleanup. Does NOT deinit the Realm - that must be
    /// done separately by the owner.
    pub fn clearRealm(self: *Self) void {
        self.realm = null;
    }

    /// Create a TypeError from this context's realm
    ///
    /// If a full Realm is available, creates the error from that realm.
    /// Otherwise returns null.
    pub fn createTypeError(self: *const Self, message: []const u8) ?*anyopaque {
        if (self.realm) |realm| {
            return realm.createTypeError(message);
        }
        return null;
    }

    /// Throw a TypeError from this context's realm
    ///
    /// If a full Realm is available, throws from that realm.
    /// Otherwise does nothing.
    pub fn throwTypeError(self: *const Self, message: []const u8) void {
        if (self.realm) |realm| {
            realm.throwTypeError(message);
        }
    }

    /// Create a plain object in this context's realm
    ///
    /// If a full Realm is available, creates the object in that realm
    /// (with correct prototype chain). Otherwise returns null.
    pub fn createObject(self: *const Self) ?*anyopaque {
        if (self.realm) |realm| {
            return realm.createObject();
        }
        return null;
    }
};

/// Runtime context - pointer to ContextData
///
/// This is what gets passed to all namespace operations.
/// By keeping it as a simple pointer, we maintain small size and
/// compatibility with generated code.
pub const Context = *ContextData;

/// Null context helper for testing
///
/// Creates a minimal context without a JS engine.
/// Uses unknown context type (for testing).
/// Useful for testing WebIDL implementations in isolation.
pub fn createNullContext(allocator: std.mem.Allocator) !ContextData {
    return ContextData.init(allocator, .{
        .colored = false,
        .engine_ctx = null,
        .realm_info = RealmInfo.forTesting(),
    });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "ContextData - basic initialization" {
    var ctx_data = try ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    try testing.expectEqual(testing.allocator, ctx_data.allocator);
    try testing.expect(!ctx_data.hasEngine());
}

test "ContextData - with engine context" {
    const stub = @import("engine_interface.zig").stub_engine;
    var dummy_engine: u32 = 42;
    var ctx_data = try ContextData.init(testing.allocator, .{
        .engine = &stub,
        .engine_ctx = @ptrCast(&dummy_engine),
    });
    defer ctx_data.deinit();

    try testing.expect(ctx_data.hasEngine());
    const engine_ctx = ctx_data.getEngineContext();
    try testing.expect(engine_ctx != null);
    const engine = ctx_data.getEngine();
    try testing.expect(engine != null);
}

test "Context - is a pointer" {
    var ctx_data = try ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    const ctx: Context = &ctx_data;
    try testing.expect(@TypeOf(ctx) == Context);
    try testing.expectEqual(@sizeOf(Context), @sizeOf(*ContextData));
}

test "Context - null context helper" {
    var ctx_data = try createNullContext(testing.allocator);
    defer ctx_data.deinit();

    try testing.expect(!ctx_data.hasEngine());
}

test "Context - logger is accessible" {
    var ctx_data = try ContextData.init(testing.allocator, .{ .colored = false });
    defer ctx_data.deinit();

    const ctx: Context = &ctx_data;

    // Should be able to log through context
    try ctx.logger.log("Test message", .{});
}

// ============================================================================
// Realm Integration Tests
// ============================================================================

test "ContextData - realm info default" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    // Default should be testing/unknown context
    try testing.expectEqual(ContextType.unknown, ctx.realm_info.context_type);
    try testing.expectEqual(ContextType.unknown, ctx.getRealmInfo().context_type);
}

test "ContextData - window context" {
    var ctx = try ContextData.init(testing.allocator, .{
        .realm_info = RealmInfo.forWindow(),
    });
    defer ctx.deinit();

    try testing.expect(ctx.isWindow());
    try testing.expect(!ctx.isWorker());
    try testing.expect(!ctx.isWorklet());
    try testing.expect(ctx.isExposedTo(.window));
    try testing.expect(!ctx.isExposedTo(.worker));
    try testing.expect(ctx.isExposedTo(.window_and_worker));
    try testing.expect(ctx.isExposedTo(.all));
    try testing.expectEqualStrings("Window", ctx.contextName());
}

test "ContextData - dedicated worker context" {
    var ctx = try ContextData.init(testing.allocator, .{
        .realm_info = RealmInfo.forDedicatedWorker(),
    });
    defer ctx.deinit();

    try testing.expect(!ctx.isWindow());
    try testing.expect(ctx.isWorker());
    try testing.expect(!ctx.isWorklet());
    try testing.expect(!ctx.isExposedTo(.window));
    try testing.expect(ctx.isExposedTo(.worker));
    try testing.expect(ctx.isExposedTo(.window_and_worker));
    try testing.expect(ctx.isExposedTo(.all));
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", ctx.contextName());
}

test "ContextData - service worker context" {
    var ctx = try ContextData.init(testing.allocator, .{
        .realm_info = RealmInfo.forServiceWorker(),
    });
    defer ctx.deinit();

    try testing.expect(!ctx.isWindow());
    try testing.expect(ctx.isWorker());
    try testing.expect(ctx.isExposedTo(.worker));
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", ctx.contextName());
}

test "ContextData - worklet context" {
    var ctx = try ContextData.init(testing.allocator, .{
        .realm_info = RealmInfo.forWorklet(),
    });
    defer ctx.deinit();

    try testing.expect(!ctx.isWindow());
    try testing.expect(!ctx.isWorker());
    try testing.expect(ctx.isWorklet());
    try testing.expect(!ctx.isExposedTo(.window));
    try testing.expect(!ctx.isExposedTo(.worker));
    try testing.expect(!ctx.isExposedTo(.window_and_worker));
    try testing.expect(ctx.isExposedTo(.all)); // Only .all exposes to worklets
    try testing.expectEqualStrings("Worklet", ctx.contextName());
}

test "createNullContext - has testing realm" {
    var ctx = try createNullContext(testing.allocator);
    defer ctx.deinit();

    try testing.expectEqual(ContextType.unknown, ctx.realm_info.context_type);
}

// ============================================================================
// Full Realm Integration Tests
// ============================================================================

test "ContextData - realm default is null" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    try testing.expect(!ctx.hasRealm());
    try testing.expect(ctx.getRealm() == null);
}

test "ContextData - set and get realm" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    // Create a realm
    var realm = try Realm.init(testing.allocator, .{
        .context_type = .window,
    });
    defer realm.deinit();

    // Initially no realm
    try testing.expect(!ctx.hasRealm());

    // Set the realm
    ctx.setRealm(realm);

    // Now has realm
    try testing.expect(ctx.hasRealm());
    try testing.expect(ctx.getRealm() != null);
    try testing.expect(ctx.getRealm() == realm);

    // Realm info should be synced
    try testing.expect(ctx.isWindow());
}

test "ContextData - realm syncs context type" {
    var ctx = try ContextData.init(testing.allocator, .{
        .realm_info = RealmInfo.forTesting(), // unknown context
    });
    defer ctx.deinit();

    // Initially unknown
    try testing.expectEqual(ContextType.unknown, ctx.realm_info.context_type);

    // Create worker realm
    var realm = try Realm.init(testing.allocator, .{
        .context_type = .dedicated_worker,
    });
    defer realm.deinit();

    // Set realm syncs the context type
    ctx.setRealm(realm);
    try testing.expectEqual(ContextType.dedicated_worker, ctx.realm_info.context_type);
    try testing.expect(ctx.isWorker());
}

test "ContextData - clear realm" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    var realm = try Realm.init(testing.allocator, .{});
    defer realm.deinit();

    ctx.setRealm(realm);
    try testing.expect(ctx.hasRealm());

    ctx.clearRealm();
    try testing.expect(!ctx.hasRealm());
    try testing.expect(ctx.getRealm() == null);
}

test "ContextData - init with realm option" {
    var realm = try Realm.init(testing.allocator, .{
        .context_type = .service_worker,
    });
    defer realm.deinit();

    var ctx = try ContextData.init(testing.allocator, .{
        .realm = realm,
    });
    defer ctx.deinit();

    try testing.expect(ctx.hasRealm());
    try testing.expect(ctx.getRealm() == realm);
}

test "ContextData - createTypeError without realm returns null" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    // No realm, should return null
    const error_obj = ctx.createTypeError("test error");
    try testing.expect(error_obj == null);
}

test "ContextData - createObject without realm returns null" {
    var ctx = try ContextData.init(testing.allocator, .{});
    defer ctx.deinit();

    // No realm, should return null
    const obj = ctx.createObject();
    try testing.expect(obj == null);
}
