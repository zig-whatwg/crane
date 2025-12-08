//! External Script Loader for HTML Parsing
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//! HTML Standard §4.12.1.1 "Prepare the script element"
//!
//! This module provides infrastructure for loading and handling external scripts
//! during HTML parsing. It handles:
//! - Parser-blocking scripts (default `<script src="...">`)
//! - Async scripts (`<script src="..." async>`)
//! - Deferred scripts (`<script src="..." defer>`)
//! - Module scripts (`<script type="module" src="...">`)
//!
//! ## Architecture
//!
//! For WPT tests, scripts are local files read from disk. For production use,
//! this would need to be extended with network fetching.
//!
//! The loader maintains:
//! - Lists of pending async/defer scripts
//! - Base URL for resolving relative paths
//! - Script loader callback for custom loading (e.g., WPT file reading)
//!
//! ## Usage
//!
//! ```zig
//! var loader = ExternalScriptLoader.init(allocator, wpt_root, test_path);
//! defer loader.deinit();
//!
//! // Handle an external script
//! try loader.handleExternalScript(script_element, dom_adapter.getDomNode(script_tree_node));
//!
//! // After parsing completes, execute deferred scripts
//! try loader.executeDeferredScripts(executeScriptFn);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Runtime types
const runtime = @import("runtime");

// Imports for interface types (Golden Rule #12)
const interfaces = @import("interfaces");
const Element = interfaces.Element;
const HTMLScriptElement = interfaces.HTMLScriptElement;

// Import impls for internal state access (Golden Rule #12 exception)
const impls = @import("impls");
const HTMLScriptElementImpl = impls.HTMLScriptElement;
const DocumentImpl = impls.Document;
const ElementImpl = impls.Element;

// HTML parser types
const html_core = @import("html_core");
const TreeNode = html_core.parser.TreeNode;

/// Script execution type based on script attributes
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
pub const ScriptType = enum {
    /// Default parser-blocking script - parsing must wait
    classic_blocking,
    /// Async script - parser continues, execute when ready
    classic_async,
    /// Deferred script - parser continues, execute after parsing
    classic_defer,
    /// Module script - deferred by default
    module,
};

/// Information about a pending external script
pub const PendingScript = struct {
    /// URL/path of the script
    url: []const u8,
    /// The DOM script element instance
    script_element: *runtime.Instance,
    /// Whether URL is owned by this struct
    url_owned: bool,
    /// Allocator for cleanup
    allocator: Allocator,

    pub fn deinit(self: *PendingScript) void {
        if (self.url_owned) {
            self.allocator.free(self.url);
        }
    }
};

/// Callback signature for script execution
pub const ScriptExecutor = *const fn (
    allocator: Allocator,
    script_element: *runtime.Instance,
    script_content: []const u8,
) anyerror!void;

/// Callback signature for custom script loading
pub const ScriptLoaderFn = *const fn (
    context: ?*anyopaque,
    url: []const u8,
    allocator: Allocator,
) anyerror![]const u8;

/// Maximum script file size (10 MB)
pub const MAX_SCRIPT_SIZE: usize = 10 * 1024 * 1024;

/// External Script Loader for handling scripts during HTML parsing
///
/// This maintains lists of async and deferred scripts, and provides
/// infrastructure for loading and executing external scripts during parsing.
pub const ExternalScriptLoader = struct {
    /// Memory allocator
    allocator: Allocator,

    /// Base directory for relative URL resolution
    /// For WPT, this is the WPT root directory
    base_dir: []const u8,

    /// Current test/document directory for relative paths
    /// For WPT, this is the directory containing the test file
    test_dir: []const u8,

    /// List of async scripts waiting to execute
    /// These execute in any order when ready
    async_scripts: std.ArrayListUnmanaged(PendingScript),

    /// List of deferred scripts
    /// These execute in order after parsing completes
    defer_scripts: std.ArrayListUnmanaged(PendingScript),

    /// Custom script loader callback (optional)
    /// If set, uses this instead of default file reading
    custom_loader: ?ScriptLoaderFn,
    custom_loader_context: ?*anyopaque,

    /// Set of already-loaded scripts to prevent double-loading
    /// Key is the resolved URL, value is unused
    loaded_scripts: std.StringHashMap(void),

    /// Whether testharness.js has been loaded (to avoid double-loading)
    testharness_loaded: bool,

    /// Initialize a new external script loader
    pub fn init(
        allocator: Allocator,
        base_dir: []const u8,
        test_dir: []const u8,
    ) ExternalScriptLoader {
        return .{
            .allocator = allocator,
            .base_dir = base_dir,
            .test_dir = test_dir,
            .async_scripts = .{},
            .defer_scripts = .{},
            .custom_loader = null,
            .custom_loader_context = null,
            .loaded_scripts = std.StringHashMap(void).init(allocator),
            .testharness_loaded = false,
        };
    }

    /// Free all resources
    pub fn deinit(self: *ExternalScriptLoader) void {
        // Clean up async scripts
        for (self.async_scripts.items) |*script| {
            script.deinit();
        }
        self.async_scripts.deinit(self.allocator);

        // Clean up defer scripts
        for (self.defer_scripts.items) |*script| {
            script.deinit();
        }
        self.defer_scripts.deinit(self.allocator);

        // Clean up loaded scripts map
        var iter = self.loaded_scripts.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.loaded_scripts.deinit();
    }

    /// Set a custom script loader function
    /// This allows the WPT runner to provide its own file reading logic
    pub fn setCustomLoader(
        self: *ExternalScriptLoader,
        loader: ScriptLoaderFn,
        context: ?*anyopaque,
    ) void {
        self.custom_loader = loader;
        self.custom_loader_context = context;
    }

    /// Mark testharness.js as already loaded
    /// Called by WPT runner to prevent double-loading
    pub fn markTestharnessLoaded(self: *ExternalScriptLoader) void {
        self.testharness_loaded = true;
    }

    /// Determine script type from script element attributes
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#attr-script-async
    pub fn determineScriptType(self: *ExternalScriptLoader, script_element: *runtime.Instance) ScriptType {
        _ = self;

        // Check for type="module"
        const type_attr = getAttributeValue(script_element, "type");
        if (type_attr) |t| {
            if (std.ascii.eqlIgnoreCase(t, "module")) {
                return .module; // Module scripts are always deferred
            }
        }

        // Check async attribute
        if (hasAttribute(script_element, "async")) {
            return .classic_async;
        }

        // Check defer attribute
        if (hasAttribute(script_element, "defer")) {
            return .classic_defer;
        }

        // Default: parser-blocking
        return .classic_blocking;
    }

    /// Resolve a script URL relative to the current document
    /// Handles both absolute paths (/resources/...) and relative paths
    pub fn resolveScriptPath(self: *ExternalScriptLoader, src: []const u8) ![]const u8 {
        // Already absolute URL - return as-is (will need network fetch in production)
        if (std.mem.startsWith(u8, src, "http://") or
            std.mem.startsWith(u8, src, "https://") or
            std.mem.startsWith(u8, src, "file://"))
        {
            return try self.allocator.dupe(u8, src);
        }

        // Absolute path from root (e.g., /resources/testharness.js)
        if (std.mem.startsWith(u8, src, "/")) {
            return try std.fs.path.join(self.allocator, &.{ self.base_dir, src[1..] });
        }

        // Relative path - resolve against test directory
        return try std.fs.path.join(self.allocator, &.{ self.base_dir, self.test_dir, src });
    }

    /// Load script content from a resolved path
    pub fn loadScriptContent(self: *ExternalScriptLoader, path: []const u8) ![]const u8 {
        // Use custom loader if set
        if (self.custom_loader) |loader| {
            return try loader(self.custom_loader_context, path, self.allocator);
        }

        // Default: read from file system
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        return try file.readToEndAlloc(self.allocator, MAX_SCRIPT_SIZE);
    }

    /// Check if a script has already been loaded
    fn isScriptLoaded(self: *ExternalScriptLoader, resolved_path: []const u8) bool {
        return self.loaded_scripts.contains(resolved_path);
    }

    /// Mark a script as loaded
    fn markScriptLoaded(self: *ExternalScriptLoader, resolved_path: []const u8) !void {
        const path_copy = try self.allocator.dupe(u8, resolved_path);
        try self.loaded_scripts.put(path_copy, {});
    }

    /// Check if a path is testharness.js or testharnessreport.js
    fn isTestharnessScript(self: *ExternalScriptLoader, resolved_path: []const u8) bool {
        _ = self;
        return std.mem.endsWith(u8, resolved_path, "testharness.js") or
            std.mem.endsWith(u8, resolved_path, "testharnessreport.js");
    }

    /// Handle an external script during parsing
    /// This is the main entry point called when <script src="..."> is encountered
    ///
    /// For blocking scripts: loads and returns content immediately
    /// For async scripts: queues for later execution
    /// For deferred scripts: queues for execution after parsing
    ///
    /// Returns: script content if this is a blocking script and should execute now, null otherwise
    pub fn handleExternalScript(
        self: *ExternalScriptLoader,
        tree_node: *TreeNode,
        script_element: *runtime.Instance,
    ) !?[]const u8 {
        // Get src attribute
        const src = getScriptSrc(tree_node) orelse return null;

        // Resolve the path
        const resolved_path = try self.resolveScriptPath(src);
        errdefer self.allocator.free(resolved_path);

        // Check if this is testharness and should be skipped
        if (self.testharness_loaded and self.isTestharnessScript(resolved_path)) {
            self.allocator.free(resolved_path);
            return null; // Skip, already loaded
        }

        // Check if already loaded (prevent double-loading)
        if (self.isScriptLoaded(resolved_path)) {
            self.allocator.free(resolved_path);
            return null;
        }

        // Determine script type
        const script_type = self.determineScriptType(script_element);

        switch (script_type) {
            .classic_async => {
                // Queue for async execution
                try self.async_scripts.append(self.allocator, .{
                    .url = resolved_path,
                    .script_element = script_element,
                    .url_owned = true,
                    .allocator = self.allocator,
                });
                // Mark as from external file
                HTMLScriptElementImpl.setFromExternalFile(script_element, true);
                return null; // Parser continues
            },

            .classic_defer, .module => {
                // Queue for deferred execution
                try self.defer_scripts.append(self.allocator, .{
                    .url = resolved_path,
                    .script_element = script_element,
                    .url_owned = true,
                    .allocator = self.allocator,
                });
                // Mark as from external file
                HTMLScriptElementImpl.setFromExternalFile(script_element, true);
                return null; // Parser continues
            },

            .classic_blocking => {
                // Parser-blocking: load and execute now
                const content = self.loadScriptContent(resolved_path) catch |err| {
                    std.debug.print("Failed to load external script {s}: {}\n", .{ resolved_path, err });
                    self.allocator.free(resolved_path);
                    return null;
                };

                // Mark as loaded and from external file
                try self.markScriptLoaded(resolved_path);
                self.allocator.free(resolved_path);
                HTMLScriptElementImpl.setFromExternalFile(script_element, true);

                return content; // Caller should execute this
            },
        }
    }

    /// Execute all deferred scripts in order
    /// Called after parsing completes
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end (step 3)
    pub fn executeDeferredScripts(
        self: *ExternalScriptLoader,
        executor: ScriptExecutor,
    ) !void {
        for (self.defer_scripts.items) |*pending| {
            // Skip if already executed
            if (self.isScriptLoaded(pending.url)) {
                continue;
            }

            // Load content
            const content = self.loadScriptContent(pending.url) catch |err| {
                std.debug.print("Failed to load deferred script {s}: {}\n", .{ pending.url, err });
                continue;
            };
            defer self.allocator.free(content);

            // Mark as loaded
            try self.markScriptLoaded(pending.url);

            // Execute
            executor(self.allocator, pending.script_element, content) catch |err| {
                std.debug.print("Failed to execute deferred script {s}: {}\n", .{ pending.url, err });
            };
        }

        // Clear the list
        for (self.defer_scripts.items) |*script| {
            script.deinit();
        }
        self.defer_scripts.clearRetainingCapacity();
    }

    /// Execute any ready async scripts
    /// These can execute in any order
    pub fn executeReadyAsyncScripts(
        self: *ExternalScriptLoader,
        executor: ScriptExecutor,
    ) !void {
        var i: usize = 0;
        while (i < self.async_scripts.items.len) {
            const pending = &self.async_scripts.items[i];

            // Skip if already executed
            if (self.isScriptLoaded(pending.url)) {
                _ = self.async_scripts.orderedRemove(i);
                continue;
            }

            // Try to load content
            const content = self.loadScriptContent(pending.url) catch |err| {
                std.debug.print("Failed to load async script {s}: {}\n", .{ pending.url, err });
                i += 1;
                continue;
            };
            defer self.allocator.free(content);

            // Mark as loaded
            self.markScriptLoaded(pending.url) catch {};

            // Execute
            executor(self.allocator, pending.script_element, content) catch |err| {
                std.debug.print("Failed to execute async script {s}: {}\n", .{ pending.url, err });
            };

            // Remove from list (cleanup happens in deinit)
            var removed = self.async_scripts.orderedRemove(i);
            removed.deinit();
            // Don't increment i since we removed an element
        }
    }

    /// Get count of pending async scripts
    pub fn getPendingAsyncCount(self: *const ExternalScriptLoader) usize {
        return self.async_scripts.items.len;
    }

    /// Get count of pending defer scripts
    pub fn getPendingDeferCount(self: *const ExternalScriptLoader) usize {
        return self.defer_scripts.items.len;
    }
};

// =============================================================================
// Helper Functions
// =============================================================================

/// Get the src attribute from a TreeNode
fn getScriptSrc(tree_node: *TreeNode) ?[]const u8 {
    const attrs = tree_node.attributes.toSlice();
    for (attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "src")) {
            return attr.value;
        }
    }
    return null;
}

/// Check if a DOM script element has a specific attribute
fn hasAttribute(script_element: *runtime.Instance, name: []const u8) bool {
    const name_str = runtime.DOMString.initInterned(name);
    return Element.call_hasAttribute(script_element, name_str) catch false;
}

/// Get attribute value from a DOM script element
fn getAttributeValue(script_element: *runtime.Instance, name: []const u8) ?[]const u8 {
    const name_str = runtime.DOMString.initInterned(name);
    const result = Element.call_getAttribute(script_element, name_str) catch return null;
    if (result) |r| {
        return r.asSlice();
    }
    return null;
}

// =============================================================================
// Tests
// =============================================================================

test "ExternalScriptLoader - determineScriptType" {
    // Note: Full tests require runtime initialization
    // These are placeholder tests for the parsing logic

    const allocator = std.testing.allocator;
    var loader = ExternalScriptLoader.init(allocator, "/wpt", "url");
    defer loader.deinit();

    // Test path resolution
    {
        const abs_path = try loader.resolveScriptPath("/resources/testharness.js");
        defer allocator.free(abs_path);
        try std.testing.expectEqualStrings("/wpt/resources/testharness.js", abs_path);
    }

    {
        const rel_path = try loader.resolveScriptPath("helper.js");
        defer allocator.free(rel_path);
        try std.testing.expectEqualStrings("/wpt/url/helper.js", rel_path);
    }
}

test "ExternalScriptLoader - isTestharnessScript" {
    const allocator = std.testing.allocator;
    var loader = ExternalScriptLoader.init(allocator, "/wpt", "url");
    defer loader.deinit();

    try std.testing.expect(loader.isTestharnessScript("/wpt/resources/testharness.js"));
    try std.testing.expect(loader.isTestharnessScript("testharness.js"));
    try std.testing.expect(loader.isTestharnessScript("/some/path/testharnessreport.js"));
    try std.testing.expect(!loader.isTestharnessScript("/wpt/resources/other.js"));
    try std.testing.expect(!loader.isTestharnessScript("testharness_utils.js"));
}
