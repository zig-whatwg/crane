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
const NodeBase = @import("../node_base.zig").NodeBase;
const Value = @import("value.zig").Value;
const infra = @import("infra");

/// XPath 1.0 Evaluation Context
///
/// Provides context for evaluating expressions
pub const Context = struct {
    /// Current node being processed
    context_node: *NodeBase,

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

    pub fn init(allocator: std.mem.Allocator, context_node: *NodeBase) !Context {
        var ctx = Context{
            .context_node = context_node,
            .context_position = 1,
            .context_size = 1,
            .variables = std.StringHashMap(Value).init(allocator),
            .functions = try FunctionLibrary.init(allocator),
            .namespaces = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };

        // Register core functions
        const functions = @import("functions.zig");
        try functions.registerCoreFunctions(&ctx.functions);

        return ctx;
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
    pub fn withNode(self: *const Context, node: *NodeBase) Context {
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
        return FunctionLibrary{
            .functions = std.StringHashMap(XPathFunction).init(allocator),
            .allocator = allocator,
        };
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

// ============================================================================
// Tests
// ============================================================================






