//! XPath 1.0 Evaluation Context
//!
//! This module implements the evaluation context for XPath 1.0 expressions.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§2.1 Location Paths**: https://www.w3.org/TR/xpath-10/#location-paths
//! - **Expression Evaluation Context**: https://www.w3.org/TR/xpath-10/#corelib
//!
//! ## Evaluation Context (§2.1)
//!
//! An expression is evaluated with respect to a context. The context consists of:
//! - A **context node** (the node currently being processed)
//! - A **context position** (the position of the context node in the context node list)
//! - A **context size** (the size of the context node list)
//! - A set of **variable bindings** (mapping names to values)
//! - A **function library** (available functions)
//! - A set of **namespace declarations** (mapping prefixes to namespace URIs)

const std = @import("std");
const Node = @import("node").Node;
const Value = @import("value.zig").Value;
const infra = @import("infra");

/// XPath 1.0 Evaluation Context
///
/// Provides context for evaluating expressions
pub const Context = struct {
    /// Current node being processed
    context_node: *Node,

    /// Position in context node list (1-based, per XPath spec)
    context_position: usize,

    /// Size of context node list
    context_size: usize,

    /// Variable bindings (name → value)
    variables: std.StringHashMap(Value),

    /// Function library (name → function)
    functions: FunctionLibrary,

    /// Namespace declarations (prefix → URI)
    namespaces: std.StringHashMap([]const u8),

    /// Allocator for context resources
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, context_node: *Node) !Context {
        return Context{
            .context_node = context_node,
            .context_position = 1,
            .context_size = 1,
            .variables = std.StringHashMap(Value).init(allocator),
            .functions = try FunctionLibrary.init(allocator),
            .namespaces = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Context) void {
        // Free variables
        var var_iter = self.variables.iterator();
        while (var_iter.next()) |entry| {
            var val = entry.value_ptr.*;
            val.deinit(self.allocator);
        }
        self.variables.deinit();

        // Free functions
        self.functions.deinit();

        // Free namespaces
        var ns_iter = self.namespaces.iterator();
        while (ns_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.namespaces.deinit();
    }

    /// Set a variable binding
    pub fn setVariable(self: *Context, name: []const u8, value: Value) !void {
        try self.variables.put(name, value);
    }

    /// Get a variable value
    pub fn getVariable(self: *const Context, name: []const u8) ?Value {
        return self.variables.get(name);
    }

    /// Bind a namespace prefix to URI
    pub fn bindNamespace(self: *Context, prefix: []const u8, uri: []const u8) !void {
        const uri_copy = try self.allocator.dupe(u8, uri);
        try self.namespaces.put(prefix, uri_copy);
    }

    /// Lookup namespace URI for prefix
    pub fn lookupNamespace(self: *const Context, prefix: []const u8) ?[]const u8 {
        return self.namespaces.get(prefix);
    }

    /// Create a new context for a different node (preserves other settings)
    pub fn withNode(self: *const Context, node: *Node) Context {
        return Context{
            .context_node = node,
            .context_position = self.context_position,
            .context_size = self.context_size,
            .variables = self.variables,
            .functions = self.functions,
            .namespaces = self.namespaces,
            .allocator = self.allocator,
        };
    }

    /// Create a new context with different position/size
    pub fn withPosition(self: *const Context, position: usize, size: usize) Context {
        return Context{
            .context_node = self.context_node,
            .context_position = position,
            .context_size = size,
            .variables = self.variables,
            .functions = self.functions,
            .namespaces = self.namespaces,
            .allocator = self.allocator,
        };
    }
};

/// Function signature for XPath functions
pub const XPathFunction = *const fn (
    allocator: std.mem.Allocator,
    context: *const Context,
    args: []const Value,
) anyerror!Value;

/// Function library containing all available XPath functions
pub const FunctionLibrary = struct {
    functions: std.StringHashMap(XPathFunction),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !FunctionLibrary {
        var lib = FunctionLibrary{
            .functions = std.StringHashMap(XPathFunction).init(allocator),
            .allocator = allocator,
        };

        // Register core functions (will be implemented in functions.zig)
        // Node-set functions
        try lib.register("last", coreFunctionStub);
        try lib.register("position", coreFunctionStub);
        try lib.register("count", coreFunctionStub);
        try lib.register("id", coreFunctionStub);
        try lib.register("local-name", coreFunctionStub);
        try lib.register("namespace-uri", coreFunctionStub);
        try lib.register("name", coreFunctionStub);

        // String functions
        try lib.register("string", coreFunctionStub);
        try lib.register("concat", coreFunctionStub);
        try lib.register("starts-with", coreFunctionStub);
        try lib.register("contains", coreFunctionStub);
        try lib.register("substring-before", coreFunctionStub);
        try lib.register("substring-after", coreFunctionStub);
        try lib.register("substring", coreFunctionStub);
        try lib.register("string-length", coreFunctionStub);
        try lib.register("normalize-space", coreFunctionStub);
        try lib.register("translate", coreFunctionStub);

        // Boolean functions
        try lib.register("boolean", coreFunctionStub);
        try lib.register("not", coreFunctionStub);
        try lib.register("true", coreFunctionStub);
        try lib.register("false", coreFunctionStub);
        try lib.register("lang", coreFunctionStub);

        // Number functions
        try lib.register("number", coreFunctionStub);
        try lib.register("sum", coreFunctionStub);
        try lib.register("floor", coreFunctionStub);
        try lib.register("ceiling", coreFunctionStub);
        try lib.register("round", coreFunctionStub);

        return lib;
    }

    pub fn deinit(self: *FunctionLibrary) void {
        self.functions.deinit();
    }

    /// Register a function
    pub fn register(self: *FunctionLibrary, name: []const u8, func: XPathFunction) !void {
        try self.functions.put(name, func);
    }

    /// Lookup a function by name
    pub fn lookup(self: *const FunctionLibrary, name: []const u8) ?XPathFunction {
        return self.functions.get(name);
    }
};

/// Stub function for core functions (will be replaced with real implementations)
fn coreFunctionStub(
    _: std.mem.Allocator,
    _: *const Context,
    _: []const Value,
) anyerror!Value {
    return error.FunctionNotImplemented;
}

// ============================================================================
// Tests
// ============================================================================

test "context - initialization" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    try std.testing.expectEqual(&node, ctx.context_node);
    try std.testing.expectEqual(@as(usize, 1), ctx.context_position);
    try std.testing.expectEqual(@as(usize, 1), ctx.context_size);
}

test "context - variable bindings" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    // Set variable
    const val = Value{ .number = 42.0 };
    try ctx.setVariable("myVar", val);

    // Get variable
    const retrieved = ctx.getVariable("myVar");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(f64, 42.0), retrieved.?.number);

    // Get non-existent variable
    const missing = ctx.getVariable("notFound");
    try std.testing.expect(missing == null);
}

test "context - namespace bindings" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    // Bind namespace
    try ctx.bindNamespace("xhtml", "http://www.w3.org/1999/xhtml");

    // Lookup namespace
    const uri = ctx.lookupNamespace("xhtml");
    try std.testing.expect(uri != null);
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xhtml", uri.?);

    // Lookup non-existent namespace
    const missing = ctx.lookupNamespace("notFound");
    try std.testing.expect(missing == null);
}

test "context - withNode" {
    const allocator = std.testing.allocator;
    var node1: Node = undefined;
    var node2: Node = undefined;

    var ctx = try Context.init(allocator, &node1);
    defer ctx.deinit();

    const new_ctx = ctx.withNode(&node2);
    try std.testing.expectEqual(&node2, new_ctx.context_node);
    try std.testing.expectEqual(ctx.context_position, new_ctx.context_position);
}

test "context - withPosition" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    const new_ctx = ctx.withPosition(5, 10);
    try std.testing.expectEqual(ctx.context_node, new_ctx.context_node);
    try std.testing.expectEqual(@as(usize, 5), new_ctx.context_position);
    try std.testing.expectEqual(@as(usize, 10), new_ctx.context_size);
}

test "function library - registration and lookup" {
    const allocator = std.testing.allocator;

    var lib = try FunctionLibrary.init(allocator);
    defer lib.deinit();

    // Core functions should be registered
    const position_fn = lib.lookup("position");
    try std.testing.expect(position_fn != null);

    const not_fn = lib.lookup("not");
    try std.testing.expect(not_fn != null);

    // Non-existent function
    const missing = lib.lookup("notAFunction");
    try std.testing.expect(missing == null);
}
