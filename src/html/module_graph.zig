//! Module Graph and Async Fetching
//!
//! Implements spec-compliant async fetching of ES module dependency graphs.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-graph
//!
//! This module provides:
//! - ModuleGraph: Data structure for tracking module dependencies
//! - Async module fetching with event loop integration
//! - Circular dependency detection
//! - Parallel fetching of module dependencies

const std = @import("std");
const Allocator = std.mem.Allocator;

// Infra primitives (for spec-compliant lists)
const infra = @import("infra");

// Event loop for async task scheduling
const event_loop = @import("event_loop/root.zig");
const EventLoop = event_loop.EventLoop;
const TaskSource = event_loop.TaskSource;

// Fetch infrastructure
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;

// Runtime for module compilation
const runtime = @import("runtime");

/// Module fetch status
pub const ModuleStatus = enum {
    /// Module is being fetched
    fetching,
    /// Module is fetched but not yet compiled
    fetched,
    /// Module is compiled and instantiated
    instantiated,
    /// Module has been evaluated
    evaluated,
    /// Module fetch/compile/evaluation failed
    failed,
};

/// Error information for a module
pub const ModuleError = struct {
    message: []const u8,
    specifier: []const u8,
    line: ?u32,
    column: ?u32,

    pub fn deinit(self: *ModuleError, allocator: Allocator) void {
        allocator.free(self.message);
        allocator.free(self.specifier);
    }
};

/// A single module in the graph
pub const ModuleNode = struct {
    /// The resolved URL of this module
    url: []const u8,

    /// The specifier used to import this module (for error messages)
    specifier: []const u8,

    /// Current status of the module
    status: ModuleStatus,

    /// The fetched source text (null until fetched)
    source_text: ?[]const u8,

    /// The compiled module handle (null until compiled)
    module_handle: ?*anyopaque,

    /// Dependencies (URLs of modules this module imports)
    dependencies: infra.List([]const u8),

    /// Error if status is failed
    @"error": ?ModuleError,

    /// Referrer URL (the module that imported this one)
    referrer_url: ?[]const u8,

    /// Allocator for cleanup
    allocator: Allocator,

    pub fn init(allocator: Allocator, url: []const u8, specifier: []const u8, referrer: ?[]const u8) !*ModuleNode {
        const node = try allocator.create(ModuleNode);
        errdefer allocator.destroy(node);

        node.* = ModuleNode{
            .url = try allocator.dupe(u8, url),
            .specifier = try allocator.dupe(u8, specifier),
            .status = .fetching,
            .source_text = null,
            .module_handle = null,
            .dependencies = infra.List([]const u8).init(allocator),
            .@"error" = null,
            .referrer_url = if (referrer) |r| try allocator.dupe(u8, r) else null,
            .allocator = allocator,
        };

        return node;
    }

    pub fn deinit(self: *ModuleNode) void {
        self.allocator.free(self.url);
        self.allocator.free(self.specifier);

        if (self.source_text) |src| {
            self.allocator.free(src);
        }

        for (self.dependencies.toSlice()) |dep| {
            self.allocator.free(dep);
        }
        self.dependencies.deinit();

        if (self.@"error") |*err| {
            err.deinit(self.allocator);
        }

        if (self.referrer_url) |ref| {
            self.allocator.free(ref);
        }

        self.allocator.destroy(self);
    }

    /// Add a dependency to this module
    pub fn addDependency(self: *ModuleNode, dep_url: []const u8) !void {
        const owned = try self.allocator.dupe(u8, dep_url);
        try self.dependencies.append(owned);
    }

    /// Mark the module as failed with an error
    pub fn setFailed(self: *ModuleNode, message: []const u8) !void {
        self.status = .failed;
        self.@"error" = ModuleError{
            .message = try self.allocator.dupe(u8, message),
            .specifier = try self.allocator.dupe(u8, self.specifier),
            .line = null,
            .column = null,
        };
    }
};

/// Module graph for tracking dependencies
pub const ModuleGraph = struct {
    /// Map from URL to module node
    modules: std.StringHashMap(*ModuleNode),

    /// The root module URL
    root_url: []const u8,

    /// Modules currently being fetched (for cycle detection)
    fetching_stack: infra.List([]const u8),

    /// Callbacks waiting for graph completion
    completion_callbacks: infra.List(CompletionCallback),

    /// Whether the graph has failed
    has_error: bool,

    /// First error encountered (if any)
    first_error: ?ModuleError,

    /// Number of pending fetches
    pending_fetches: usize,

    /// Allocator
    allocator: Allocator,

    /// Callback for graph completion
    pub const CompletionCallback = struct {
        callback: *const fn (context: ?*anyopaque, graph: *ModuleGraph, success: bool) void,
        context: ?*anyopaque,
    };

    /// Initialize a new module graph
    pub fn init(allocator: Allocator, root_url: []const u8) !*ModuleGraph {
        const graph = try allocator.create(ModuleGraph);
        errdefer allocator.destroy(graph);

        graph.* = ModuleGraph{
            .modules = std.StringHashMap(*ModuleNode).init(allocator),
            .root_url = try allocator.dupe(u8, root_url),
            .fetching_stack = infra.List([]const u8).init(allocator),
            .completion_callbacks = infra.List(CompletionCallback).init(allocator),
            .has_error = false,
            .first_error = null,
            .pending_fetches = 0,
            .allocator = allocator,
        };

        return graph;
    }

    /// Free all resources
    pub fn deinit(self: *ModuleGraph) void {
        // Free all module nodes
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.modules.deinit();

        // Free fetching stack
        for (self.fetching_stack.toSlice()) |url| {
            self.allocator.free(url);
        }
        self.fetching_stack.deinit();

        self.completion_callbacks.deinit();

        self.allocator.free(self.root_url);

        if (self.first_error) |*err| {
            err.deinit(self.allocator);
        }

        self.allocator.destroy(self);
    }

    /// Get a module by URL
    pub fn getModule(self: *const ModuleGraph, url: []const u8) ?*ModuleNode {
        return self.modules.get(url);
    }

    /// Check if a URL is in the fetching stack (circular dependency)
    pub fn isInFetchingStack(self: *const ModuleGraph, url: []const u8) bool {
        for (self.fetching_stack.toSlice()) |stack_url| {
            if (std.mem.eql(u8, stack_url, url)) {
                return true;
            }
        }
        return false;
    }

    /// Add URL to fetching stack
    pub fn pushFetchingStack(self: *ModuleGraph, url: []const u8) !void {
        const owned = try self.allocator.dupe(u8, url);
        try self.fetching_stack.append(owned);
    }

    /// Remove URL from fetching stack
    pub fn popFetchingStack(self: *ModuleGraph) void {
        const len = self.fetching_stack.size();
        if (len > 0) {
            const url = self.fetching_stack.remove(len - 1) catch return;
            self.allocator.free(url);
        }
    }

    /// Add a module to the graph
    pub fn addModule(self: *ModuleGraph, node: *ModuleNode) !void {
        try self.modules.put(node.url, node);
    }

    /// Register a completion callback
    pub fn onComplete(
        self: *ModuleGraph,
        callback: *const fn (context: ?*anyopaque, graph: *ModuleGraph, success: bool) void,
        context: ?*anyopaque,
    ) !void {
        try self.completion_callbacks.append(.{
            .callback = callback,
            .context = context,
        });
    }

    /// Notify completion callbacks
    fn notifyCompletion(self: *ModuleGraph) void {
        const success = !self.has_error;
        for (self.completion_callbacks.toSlice()) |cb| {
            cb.callback(cb.context, self, success);
        }
    }

    /// Record an error in the graph
    pub fn recordError(self: *ModuleGraph, message: []const u8, specifier: []const u8) !void {
        if (!self.has_error) {
            self.has_error = true;
            self.first_error = ModuleError{
                .message = try self.allocator.dupe(u8, message),
                .specifier = try self.allocator.dupe(u8, specifier),
                .line = null,
                .column = null,
            };
        }
    }

    /// Check if graph is complete (all modules fetched)
    pub fn isComplete(self: *const ModuleGraph) bool {
        if (self.pending_fetches > 0) return false;

        var it = self.modules.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            switch (node.status) {
                .fetching => return false,
                else => {},
            }
        }
        return true;
    }

    /// Get all module URLs in topological order (dependencies first)
    pub fn getTopologicalOrder(self: *const ModuleGraph, allocator: Allocator) ![][]const u8 {
        var result = infra.List([]const u8).init(allocator);
        errdefer {
            for (result.toSlice()) |url| allocator.free(url);
            result.deinit();
        }

        var visited = std.StringHashMap(void).init(allocator);
        defer visited.deinit();

        // Start from root
        try self.visitForTopologicalSort(self.root_url, &result, &visited, allocator);

        return result.toOwnedSlice();
    }

    fn visitForTopologicalSort(
        self: *const ModuleGraph,
        url: []const u8,
        result: *infra.List([]const u8),
        visited: *std.StringHashMap(void),
        allocator: Allocator,
    ) !void {
        if (visited.contains(url)) return;
        try visited.put(url, {});

        // Visit dependencies first
        if (self.modules.get(url)) |node| {
            for (node.dependencies.toSlice()) |dep_url| {
                try self.visitForTopologicalSort(dep_url, result, visited, allocator);
            }
        }

        // Add this module after its dependencies
        try result.append(try allocator.dupe(u8, url));
    }
};

/// Module graph fetcher - handles async fetching of module graphs
pub const ModuleGraphFetcher = struct {
    /// The module graph being built
    graph: *ModuleGraph,

    /// The event loop for async scheduling
    loop: ?*EventLoop,

    /// Base URL for resolving relative imports
    base_url: []const u8,

    /// Import map for bare specifier resolution (optional)
    import_map: ?*anyopaque, // TODO: Use proper ImportMap type

    /// Allocator
    allocator: Allocator,

    pub fn init(
        allocator: Allocator,
        root_url: []const u8,
        loop: ?*EventLoop,
    ) !*ModuleGraphFetcher {
        const fetcher = try allocator.create(ModuleGraphFetcher);
        errdefer allocator.destroy(fetcher);

        const graph = try ModuleGraph.init(allocator, root_url);
        errdefer graph.deinit();

        fetcher.* = ModuleGraphFetcher{
            .graph = graph,
            .loop = loop,
            .base_url = try allocator.dupe(u8, root_url),
            .import_map = null,
            .allocator = allocator,
        };

        return fetcher;
    }

    pub fn deinit(self: *ModuleGraphFetcher) void {
        self.graph.deinit();
        self.allocator.free(self.base_url);
        self.allocator.destroy(self);
    }

    /// Start fetching the module graph from the root URL
    pub fn fetchGraph(
        self: *ModuleGraphFetcher,
        completion_callback: *const fn (context: ?*anyopaque, graph: *ModuleGraph, success: bool) void,
        context: ?*anyopaque,
    ) !void {
        // Register completion callback
        try self.graph.onComplete(completion_callback, context);

        // Start fetching the root module
        try self.fetchModule(self.graph.root_url, self.graph.root_url, null);
    }

    /// Fetch a single module and its dependencies
    fn fetchModule(
        self: *ModuleGraphFetcher,
        url: []const u8,
        specifier: []const u8,
        referrer: ?[]const u8,
    ) !void {
        // Check if already fetched or fetching
        if (self.graph.getModule(url) != null) {
            return; // Already in graph
        }

        // Check for circular dependency
        if (self.graph.isInFetchingStack(url)) {
            // Circular dependency detected - this is allowed for modules
            // The module will be linked during instantiation
            std.debug.print("Circular dependency detected: {s}\n", .{url});
            return;
        }

        // Create module node
        const node = try ModuleNode.init(self.allocator, url, specifier, referrer);
        errdefer node.deinit();

        try self.graph.addModule(node);
        try self.graph.pushFetchingStack(url);
        self.graph.pending_fetches += 1;

        // Schedule the fetch
        if (self.loop) |loop| {
            // Async fetch via event loop
            const fetch_context = try self.allocator.create(FetchContext);
            fetch_context.* = .{
                .fetcher = self,
                .url = try self.allocator.dupe(u8, url),
                .node = node,
            };

            _ = try loop.queueTask(
                .networking,
                fetchModuleTask,
                fetch_context,
                null,
            );
        } else {
            // Synchronous fetch
            try self.performFetch(url, node);
        }
    }

    /// Context for async fetch task
    const FetchContext = struct {
        fetcher: *ModuleGraphFetcher,
        url: []const u8,
        node: *ModuleNode,
    };

    /// Task callback for async fetch
    fn fetchModuleTask(context: ?*anyopaque) void {
        const ctx: *FetchContext = @ptrCast(@alignCast(context.?));
        const fetcher = ctx.fetcher;

        fetcher.performFetch(ctx.url, ctx.node) catch |err| {
            std.debug.print("Module fetch error: {}\n", .{err});
            ctx.node.setFailed("Network error during fetch") catch {};
            fetcher.graph.recordError("Network error during fetch", ctx.url) catch {};
        };

        // Clean up context
        fetcher.allocator.free(ctx.url);
        fetcher.allocator.destroy(ctx);
    }

    /// Perform the actual fetch operation
    fn performFetch(self: *ModuleGraphFetcher, url: []const u8, node: *ModuleNode) !void {
        defer {
            self.graph.popFetchingStack();
            self.graph.pending_fetches -= 1;

            // Check if graph is complete
            if (self.graph.isComplete()) {
                self.graph.notifyCompletion();
            }
        }

        // Fetch the module source
        const response = fetch.fetchSimple(self.allocator, url) catch |err| {
            try node.setFailed("Network error");
            try self.graph.recordError("Failed to fetch module", url);
            std.debug.print("Failed to fetch module {s}: {}\n", .{ url, err });
            return;
        };
        defer response.deinit();

        // Check response status
        if (response.status < 200 or response.status >= 300) {
            try node.setFailed("HTTP error");
            try self.graph.recordError("Module returned non-OK status", url);
            return;
        }

        // Extract source text
        var source: ?[]const u8 = null;
        if (response.body) |body| {
            if (body.data.items.len > 0) {
                source = try self.allocator.dupe(u8, body.data.items);
            }
        }

        if (source == null) {
            try node.setFailed("Empty module source");
            try self.graph.recordError("Module source is empty", url);
            return;
        }

        node.source_text = source;
        node.status = .fetched;

        // Parse import statements to find dependencies
        const dependencies = try self.parseImportStatements(source.?, url);
        defer {
            for (dependencies) |dep| {
                self.allocator.free(dep);
            }
            self.allocator.free(dependencies);
        }

        // Fetch dependencies
        for (dependencies) |dep_specifier| {
            const resolved_url = try self.resolveModuleSpecifier(dep_specifier, url);
            defer if (resolved_url.ptr != dep_specifier.ptr) self.allocator.free(resolved_url);

            try node.addDependency(resolved_url);
            try self.fetchModule(resolved_url, dep_specifier, url);
        }
    }

    /// Parse import statements from module source
    /// Returns a list of import specifiers (not resolved URLs)
    pub fn parseImportStatements(self: *ModuleGraphFetcher, source: []const u8, url: []const u8) ![][]const u8 {
        _ = url;
        var imports = infra.List([]const u8).init(self.allocator);
        errdefer {
            for (imports.toSlice()) |imp| self.allocator.free(imp);
            imports.deinit();
        }

        // Simple regex-free parser for import statements
        // This handles:
        // - import x from "specifier"
        // - import { x } from "specifier"
        // - import * as x from "specifier"
        // - export { x } from "specifier"
        // - export * from "specifier"
        // - import("specifier")

        var i: usize = 0;
        while (i < source.len) {
            // Skip whitespace and comments
            if (std.ascii.isWhitespace(source[i])) {
                i += 1;
                continue;
            }

            // Skip single-line comments
            if (i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
                while (i < source.len and source[i] != '\n') {
                    i += 1;
                }
                continue;
            }

            // Skip multi-line comments
            if (i + 1 < source.len and source[i] == '/' and source[i + 1] == '*') {
                i += 2;
                while (i + 1 < source.len) {
                    if (source[i] == '*' and source[i + 1] == '/') {
                        i += 2;
                        break;
                    }
                    i += 1;
                }
                continue;
            }

            // Look for import keyword
            if (self.matchKeyword(source, i, "import")) {
                i += 6;
                // Skip to the specifier
                const specifier = self.extractImportSpecifier(source, &i);
                if (specifier) |spec| {
                    try imports.append(try self.allocator.dupe(u8, spec));
                }
                continue;
            }

            // Look for export keyword with from
            if (self.matchKeyword(source, i, "export")) {
                i += 6;
                // Look for "from" after export
                const specifier = self.extractExportFromSpecifier(source, &i);
                if (specifier) |spec| {
                    try imports.append(try self.allocator.dupe(u8, spec));
                }
                continue;
            }

            i += 1;
        }

        return imports.toOwnedSlice();
    }

    fn matchKeyword(self: *ModuleGraphFetcher, source: []const u8, pos: usize, keyword: []const u8) bool {
        _ = self;
        if (pos + keyword.len > source.len) return false;
        if (!std.mem.eql(u8, source[pos .. pos + keyword.len], keyword)) return false;

        // Check that it's not part of a larger identifier
        if (pos > 0 and isIdentifierChar(source[pos - 1])) return false;
        if (pos + keyword.len < source.len and isIdentifierChar(source[pos + keyword.len])) return false;

        return true;
    }

    fn extractImportSpecifier(self: *ModuleGraphFetcher, source: []const u8, pos: *usize) ?[]const u8 {
        _ = self;
        // Skip whitespace
        while (pos.* < source.len and std.ascii.isWhitespace(source[pos.*])) {
            pos.* += 1;
        }

        // Check for dynamic import: import(
        if (pos.* < source.len and source[pos.*] == '(') {
            pos.* += 1;
            return extractStringLiteral(source, pos);
        }

        // Skip until we find "from" or a string literal
        while (pos.* < source.len) {
            // Check for "from" keyword
            if (pos.* + 4 <= source.len and std.mem.eql(u8, source[pos.* .. pos.* + 4], "from")) {
                pos.* += 4;
                // Skip whitespace
                while (pos.* < source.len and std.ascii.isWhitespace(source[pos.*])) {
                    pos.* += 1;
                }
                return extractStringLiteral(source, pos);
            }

            // Check for direct string (import "specifier")
            if (source[pos.*] == '"' or source[pos.*] == '\'') {
                return extractStringLiteral(source, pos);
            }

            // Skip semicolon or newline (end of statement without from)
            if (source[pos.*] == ';' or source[pos.*] == '\n') {
                pos.* += 1;
                return null;
            }

            pos.* += 1;
        }

        return null;
    }

    fn extractExportFromSpecifier(self: *ModuleGraphFetcher, source: []const u8, pos: *usize) ?[]const u8 {
        _ = self;
        // Skip whitespace
        while (pos.* < source.len and std.ascii.isWhitespace(source[pos.*])) {
            pos.* += 1;
        }

        // Look for "from" keyword
        while (pos.* < source.len) {
            if (pos.* + 4 <= source.len and std.mem.eql(u8, source[pos.* .. pos.* + 4], "from")) {
                pos.* += 4;
                // Skip whitespace
                while (pos.* < source.len and std.ascii.isWhitespace(source[pos.*])) {
                    pos.* += 1;
                }
                return extractStringLiteral(source, pos);
            }

            // Skip semicolon or newline (end of statement without from)
            if (source[pos.*] == ';' or source[pos.*] == '\n') {
                pos.* += 1;
                return null;
            }

            pos.* += 1;
        }

        return null;
    }

    /// Resolve a module specifier to a URL
    fn resolveModuleSpecifier(self: *ModuleGraphFetcher, specifier: []const u8, referrer: []const u8) ![]const u8 {
        // TODO: Use import_map if available

        // Check if it's a URL-like specifier
        if (isUrlLikeSpecifier(specifier)) {
            return self.resolveRelativeUrl(specifier, referrer);
        }

        // Bare specifier - must be in import map
        // For now, return as-is (will fail during fetch)
        return specifier;
    }

    fn resolveRelativeUrl(self: *ModuleGraphFetcher, url: []const u8, base: []const u8) ![]const u8 {
        // Absolute URL
        if (std.mem.indexOf(u8, url, "://") != null) {
            return url;
        }

        // Root-relative URL
        if (std.mem.startsWith(u8, url, "/")) {
            // Extract origin from base
            if (std.mem.indexOf(u8, base, "://")) |scheme_end| {
                const after_scheme = scheme_end + 3;
                const origin_end = if (std.mem.indexOfPos(u8, base, after_scheme, "/")) |slash|
                    slash
                else
                    base.len;

                const result = try self.allocator.alloc(u8, origin_end + url.len);
                @memcpy(result[0..origin_end], base[0..origin_end]);
                @memcpy(result[origin_end..], url);
                return result;
            }
            return url;
        }

        // Relative URL (./xxx or ../xxx or plain)
        // Find the base path (everything up to and including the last /)
        var base_path_end: usize = 0;
        if (std.mem.lastIndexOf(u8, base, "/")) |last_slash| {
            base_path_end = last_slash + 1;
        }

        const result = try self.allocator.alloc(u8, base_path_end + url.len);
        @memcpy(result[0..base_path_end], base[0..base_path_end]);
        @memcpy(result[base_path_end..], url);
        return result;
    }
};

// =============================================================================
// Helper Functions
// =============================================================================

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '$';
}

fn extractStringLiteral(source: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* >= source.len) return null;

    const quote = source[pos.*];
    if (quote != '"' and quote != '\'') return null;

    pos.* += 1;
    const start = pos.*;

    while (pos.* < source.len) {
        if (source[pos.*] == quote) {
            const end = pos.*;
            pos.* += 1;
            return source[start..end];
        }
        // Handle escape sequences
        if (source[pos.*] == '\\' and pos.* + 1 < source.len) {
            pos.* += 2;
            continue;
        }
        pos.* += 1;
    }

    return null;
}

fn isUrlLikeSpecifier(specifier: []const u8) bool {
    if (specifier.len == 0) return false;

    // Starts with /
    if (specifier[0] == '/') return true;

    // Starts with ./ or ../
    if (specifier.len >= 2 and specifier[0] == '.') {
        if (specifier[1] == '/') return true;
        if (specifier.len >= 3 and specifier[1] == '.' and specifier[2] == '/') return true;
    }

    // Has a scheme (e.g., https://, http://)
    if (std.mem.indexOf(u8, specifier, "://") != null) return true;

    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "ModuleNode - initialization" {
    const allocator = std.testing.allocator;

    const node = try ModuleNode.init(allocator, "https://example.com/app.js", "app.js", null);
    defer node.deinit();

    try std.testing.expectEqualStrings("https://example.com/app.js", node.url);
    try std.testing.expectEqualStrings("app.js", node.specifier);
    try std.testing.expectEqual(ModuleStatus.fetching, node.status);
    try std.testing.expect(node.source_text == null);
}

test "ModuleGraph - initialization" {
    const allocator = std.testing.allocator;

    const graph = try ModuleGraph.init(allocator, "https://example.com/main.js");
    defer graph.deinit();

    try std.testing.expectEqualStrings("https://example.com/main.js", graph.root_url);
    try std.testing.expect(!graph.has_error);
}

test "ModuleGraph - circular dependency detection" {
    const allocator = std.testing.allocator;

    const graph = try ModuleGraph.init(allocator, "https://example.com/main.js");
    defer graph.deinit();

    try graph.pushFetchingStack("https://example.com/a.js");
    try graph.pushFetchingStack("https://example.com/b.js");

    try std.testing.expect(graph.isInFetchingStack("https://example.com/a.js"));
    try std.testing.expect(graph.isInFetchingStack("https://example.com/b.js"));
    try std.testing.expect(!graph.isInFetchingStack("https://example.com/c.js"));

    graph.popFetchingStack();
    try std.testing.expect(!graph.isInFetchingStack("https://example.com/b.js"));
}

test "parseImportStatements - simple imports" {
    const allocator = std.testing.allocator;

    const fetcher = try ModuleGraphFetcher.init(allocator, "https://example.com/main.js", null);
    defer fetcher.deinit();

    const source =
        \\import { foo } from "./foo.js";
        \\import bar from "../bar.js";
        \\import * as utils from "/utils.js";
    ;

    const imports = try fetcher.parseImportStatements(source, "https://example.com/app/main.js");
    defer {
        for (imports) |imp| allocator.free(imp);
        allocator.free(imports);
    }

    try std.testing.expectEqual(@as(usize, 3), imports.len);
    try std.testing.expectEqualStrings("./foo.js", imports[0]);
    try std.testing.expectEqualStrings("../bar.js", imports[1]);
    try std.testing.expectEqualStrings("/utils.js", imports[2]);
}

test "parseImportStatements - export from" {
    const allocator = std.testing.allocator;

    const fetcher = try ModuleGraphFetcher.init(allocator, "https://example.com/main.js", null);
    defer fetcher.deinit();

    const source =
        \\export { foo } from "./foo.js";
        \\export * from "./all.js";
    ;

    const imports = try fetcher.parseImportStatements(source, "https://example.com/main.js");
    defer {
        for (imports) |imp| allocator.free(imp);
        allocator.free(imports);
    }

    try std.testing.expectEqual(@as(usize, 2), imports.len);
    try std.testing.expectEqualStrings("./foo.js", imports[0]);
    try std.testing.expectEqualStrings("./all.js", imports[1]);
}

test "isUrlLikeSpecifier" {
    try std.testing.expect(isUrlLikeSpecifier("/absolute/path.js"));
    try std.testing.expect(isUrlLikeSpecifier("./relative.js"));
    try std.testing.expect(isUrlLikeSpecifier("../parent.js"));
    try std.testing.expect(isUrlLikeSpecifier("https://example.com/module.js"));

    try std.testing.expect(!isUrlLikeSpecifier("lodash"));
    try std.testing.expect(!isUrlLikeSpecifier("@scope/package"));
}
