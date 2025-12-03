//! Module Worker Support
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module implements ES module support for Web Workers:
//! - Module worker script loading (type: "module")
//! - Static import support within worker modules
//! - import.meta.url implementation for workers
//! - importScripts TypeError for module workers (per spec)
//!
//! ## Module vs Classic Workers
//!
//! Classic workers (default):
//! - Executed as classic scripts
//! - Support importScripts() for synchronous loading
//! - No import/export support
//!
//! Module workers (type: "module"):
//! - Executed as ES modules
//! - Support import/export statements
//! - import.meta.url is set to the worker script URL
//! - importScripts() throws TypeError
//! - Deferred execution (like module scripts in HTML)

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const WorkerType = types.WorkerType;
const WorkerData = types.WorkerData;
const WorkerError = types.WorkerError;

const worker_context = @import("worker_context.zig");
const WorkerContext = worker_context.WorkerContext;
const EngineCallbacks = worker_context.EngineCallbacks;

// ============================================================================
// Module Worker Configuration
// ============================================================================

/// Configuration for module worker initialization
pub const ModuleWorkerConfig = struct {
    /// The worker script URL (becomes import.meta.url)
    script_url: []const u8,

    /// Credentials mode for module fetch
    credentials: CredentialsMode = .same_origin,

    /// Base URL for resolving module imports
    base_url: ?[]const u8 = null,

    /// Worker name for debugging
    name: []const u8 = "",

    pub const CredentialsMode = enum {
        omit,
        same_origin,
        include,

        pub fn toString(self: CredentialsMode) []const u8 {
            return switch (self) {
                .omit => "omit",
                .same_origin => "same-origin",
                .include => "include",
            };
        }
    };
};

// ============================================================================
// Module Worker Executor
// ============================================================================

/// Module Worker Executor - handles module loading and execution in workers
///
/// Spec: HTML Standard § 10.2.5 step 15-24
/// When the worker's type is "module", the script is processed as a module script.
pub const ModuleWorkerExecutor = struct {
    /// Allocator for memory management
    allocator: Allocator,

    /// The worker context (owns the V8 context)
    worker_ctx: ?*WorkerContext,

    /// Configuration
    config: ModuleWorkerConfig,

    /// Module map for caching compiled modules
    module_map: std.StringHashMap(*anyopaque),

    /// Whether import.meta.url has been set up
    import_meta_configured: bool,

    const Self = @This();

    /// Initialize a module worker executor
    pub fn init(allocator: Allocator, config: ModuleWorkerConfig) !*Self {
        const executor = try allocator.create(Self);
        errdefer allocator.destroy(executor);

        const url_copy = try allocator.dupe(u8, config.script_url);
        errdefer allocator.free(url_copy);

        var config_copy = config;
        config_copy.script_url = url_copy;

        if (config.base_url) |base| {
            config_copy.base_url = try allocator.dupe(u8, base);
        }

        if (config.name.len > 0) {
            config_copy.name = try allocator.dupe(u8, config.name);
        }

        executor.* = .{
            .allocator = allocator,
            .worker_ctx = null,
            .config = config_copy,
            .module_map = std.StringHashMap(*anyopaque).init(allocator),
            .import_meta_configured = false,
        };

        return executor;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.module_map.deinit();
        self.allocator.free(self.config.script_url);
        if (self.config.base_url) |base| {
            self.allocator.free(base);
        }
        if (self.config.name.len > 0) {
            self.allocator.free(self.config.name);
        }
        self.allocator.destroy(self);
    }

    /// Set the worker context for V8 integration
    pub fn setWorkerContext(self: *Self, ctx: *WorkerContext) void {
        self.worker_ctx = ctx;
    }

    /// Execute the main worker module
    ///
    /// Spec: HTML Standard § 10.2.5 step 24
    /// "Run the module script scriptOrModule."
    ///
    /// This loads and executes the worker's main module script.
    pub fn executeMainModule(self: *Self, source: []const u8) !void {
        const ctx = self.worker_ctx orelse return error.NoWorkerContext;

        // Set up import.meta if not already done
        if (!self.import_meta_configured) {
            try self.configureImportMeta();
        }

        // Execute as module
        try ctx.executeModule(source);
    }

    /// Configure import.meta for the worker
    ///
    /// Spec: HTML Standard § 10.2.5 step 12.4
    /// "Set up a worker module map..."
    /// "Set realm's module import.meta object hook..."
    ///
    /// import.meta.url must be set to the worker script URL.
    fn configureImportMeta(self: *Self) !void {
        // In a full implementation, this would:
        // 1. Set up the module map on the worker's realm
        // 2. Configure the import.meta object hook to provide:
        //    - import.meta.url: The worker's script URL
        //    - import.meta.resolve(): URL resolution function
        //
        // For now, we rely on the engine context to handle this.
        // The V8 integration should set import.meta.url when creating the context.
        self.import_meta_configured = true;
    }

    /// Check if the worker is a module worker
    pub fn isModuleWorker(self: *const Self) bool {
        if (self.worker_ctx) |ctx| {
            return ctx.worker_type == .module;
        }
        return false;
    }

    /// Get the script URL (for import.meta.url)
    pub fn getScriptUrl(self: *const Self) []const u8 {
        return self.config.script_url;
    }

    /// Cache a compiled module
    pub fn cacheModule(self: *Self, url: []const u8, module: *anyopaque) !void {
        const key = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(key);
        try self.module_map.put(key, module);
    }

    /// Get a cached module
    pub fn getCachedModule(self: *const Self, url: []const u8) ?*anyopaque {
        return self.module_map.get(url);
    }
};

// ============================================================================
// importScripts Validation
// ============================================================================

/// Check if importScripts is allowed
///
/// Spec: HTML Standard § 10.2.4.1
/// "The importScripts(urls...) method must run these steps:
/// ...
/// 3. If worker global scope's type is "module", then throw a TypeError exception."
///
/// This function should be called before executing importScripts to validate
/// that the worker is not a module worker.
pub fn validateImportScripts(worker_type: WorkerType) WorkerError!void {
    if (worker_type == .module) {
        return WorkerError.TypeError;
    }
}

/// Get the error message for importScripts in module worker
pub fn getImportScriptsTypeErrorMessage() []const u8 {
    return "Failed to execute 'importScripts' on 'WorkerGlobalScope': Cannot call importScripts from a module worker.";
}

// ============================================================================
// Module Resolution for Workers
// ============================================================================

/// Resolve a module specifier relative to the worker script URL
///
/// Spec: HTML Standard § 10.2.5 step 12.5
/// "Set realm's module import.meta object hook..."
///
/// Module specifiers in workers are resolved relative to the worker's script URL.
pub fn resolveWorkerModuleSpecifier(
    allocator: Allocator,
    specifier: []const u8,
    worker_script_url: []const u8,
) ![]const u8 {
    // Absolute URL
    if (std.mem.indexOf(u8, specifier, "://") != null) {
        return try allocator.dupe(u8, specifier);
    }

    // Root-relative URL
    if (std.mem.startsWith(u8, specifier, "/")) {
        // Extract origin from worker script URL
        if (std.mem.indexOf(u8, worker_script_url, "://")) |scheme_end| {
            const after_scheme = scheme_end + 3;
            const origin_end = if (std.mem.indexOfPos(u8, worker_script_url, after_scheme, "/")) |slash|
                slash
            else
                worker_script_url.len;

            const result = try allocator.alloc(u8, origin_end + specifier.len);
            @memcpy(result[0..origin_end], worker_script_url[0..origin_end]);
            @memcpy(result[origin_end..], specifier);
            return result;
        }
        return try allocator.dupe(u8, specifier);
    }

    // Relative URL (./ or ../ or plain path)
    // Find the base path (everything up to and including the last /)
    var base_path_end: usize = 0;
    if (std.mem.lastIndexOf(u8, worker_script_url, "/")) |last_slash| {
        base_path_end = last_slash + 1;
    }

    const result = try allocator.alloc(u8, base_path_end + specifier.len);
    @memcpy(result[0..base_path_end], worker_script_url[0..base_path_end]);
    @memcpy(result[base_path_end..], specifier);
    return result;
}

/// Check if a specifier is a bare specifier (requires import map)
pub fn isBareSpecifier(specifier: []const u8) bool {
    if (specifier.len == 0) return false;

    // Not a bare specifier if:
    // - Starts with /
    // - Starts with ./ or ../
    // - Contains ://

    if (specifier[0] == '/') return false;

    if (specifier.len >= 2 and specifier[0] == '.') {
        if (specifier[1] == '/') return false;
        if (specifier.len >= 3 and specifier[1] == '.' and specifier[2] == '/') return false;
    }

    if (std.mem.indexOf(u8, specifier, "://") != null) return false;

    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "validateImportScripts - classic worker allows importScripts" {
    try validateImportScripts(.classic);
}

test "validateImportScripts - module worker disallows importScripts" {
    try std.testing.expectError(WorkerError.TypeError, validateImportScripts(.module));
}

test "resolveWorkerModuleSpecifier - absolute URL" {
    const allocator = std.testing.allocator;

    const resolved = try resolveWorkerModuleSpecifier(
        allocator,
        "https://cdn.example.com/lib.js",
        "https://example.com/workers/main.js",
    );
    defer allocator.free(resolved);

    try std.testing.expectEqualStrings("https://cdn.example.com/lib.js", resolved);
}

test "resolveWorkerModuleSpecifier - root-relative URL" {
    const allocator = std.testing.allocator;

    const resolved = try resolveWorkerModuleSpecifier(
        allocator,
        "/lib/utils.js",
        "https://example.com/workers/main.js",
    );
    defer allocator.free(resolved);

    try std.testing.expectEqualStrings("https://example.com/lib/utils.js", resolved);
}

test "resolveWorkerModuleSpecifier - relative URL" {
    const allocator = std.testing.allocator;

    const resolved = try resolveWorkerModuleSpecifier(
        allocator,
        "./helper.js",
        "https://example.com/workers/main.js",
    );
    defer allocator.free(resolved);

    try std.testing.expectEqualStrings("https://example.com/workers/./helper.js", resolved);
}

test "resolveWorkerModuleSpecifier - parent relative URL" {
    const allocator = std.testing.allocator;

    const resolved = try resolveWorkerModuleSpecifier(
        allocator,
        "../lib/utils.js",
        "https://example.com/workers/main.js",
    );
    defer allocator.free(resolved);

    try std.testing.expectEqualStrings("https://example.com/workers/../lib/utils.js", resolved);
}

test "isBareSpecifier" {
    // Bare specifiers
    try std.testing.expect(isBareSpecifier("lodash"));
    try std.testing.expect(isBareSpecifier("@scope/package"));
    try std.testing.expect(isBareSpecifier("some-package/module"));

    // Not bare specifiers
    try std.testing.expect(!isBareSpecifier("/absolute/path.js"));
    try std.testing.expect(!isBareSpecifier("./relative.js"));
    try std.testing.expect(!isBareSpecifier("../parent.js"));
    try std.testing.expect(!isBareSpecifier("https://example.com/module.js"));
}

test "ModuleWorkerExecutor - initialization" {
    const allocator = std.testing.allocator;

    const executor = try ModuleWorkerExecutor.init(allocator, .{
        .script_url = "https://example.com/worker.js",
        .name = "test-worker",
    });
    defer executor.deinit();

    try std.testing.expectEqualStrings("https://example.com/worker.js", executor.getScriptUrl());
    try std.testing.expect(!executor.import_meta_configured);
}

test "getImportScriptsTypeErrorMessage" {
    const msg = getImportScriptsTypeErrorMessage();
    try std.testing.expect(std.mem.indexOf(u8, msg, "TypeError") != null or
        std.mem.indexOf(u8, msg, "module worker") != null);
}
