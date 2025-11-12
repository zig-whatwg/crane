//! XPath 1.0 Abstract Syntax Tree (AST)
//!
//! This module defines the AST node types for XPath 1.0 expressions as specified by
//! the W3C XPath 1.0 Recommendation.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§2 Location Paths**: https://www.w3.org/TR/xpath-10/#location-paths
//! - **§3 Expressions**: https://www.w3.org/TR/xpath-10/#section-Expressions
//! - **Grammar**: https://www.w3.org/TR/xpath-10/#NT-Expr
//!
//! ## AST Structure
//!
//! The AST represents the hierarchical structure of XPath expressions:
//!
//! ### Expression Hierarchy (§3)
//! ```
//! Expr
//!   ├─ OrExpr (or)
//!   │    └─ AndExpr (and)
//!   │         └─ EqualityExpr (=, !=)
//!   │              └─ RelationalExpr (<, >, <=, >=)
//!   │                   └─ AdditiveExpr (+, -)
//!   │                        └─ MultiplicativeExpr (*, div, mod)
//!   │                             └─ UnaryExpr (-)
//!   │                                  └─ UnionExpr (|)
//!   │                                       └─ PathExpr
//!   │                                            └─ PrimaryExpr
//!   └─ LocationPath
//! ```
//!
//! ### Location Path Structure (§2)
//! ```
//! LocationPath
//!   ├─ AbsoluteLocationPath (/RelativeLocationPath?)
//!   └─ RelativeLocationPath (Step/Step/...)
//!        └─ Step
//!             ├─ Axis (child, descendant, attribute, etc.)
//!             ├─ NodeTest (name, *, node(), text(), etc.)
//!             └─ Predicates ([Expr])
//! ```
//!
//! ## Memory Management
//!
//! AST nodes are allocated from arena allocator:
//! ```zig
//! var arena = std.heap.ArenaAllocator.init(allocator);
//! defer arena.deinit();
//!
//! const expr = try Expr.create(arena.allocator(), .or_expr, ...);
//! // expr and all children freed by arena.deinit()
//! ```

const std = @import("std");

/// XPath 1.0 Expression node
///
/// Represents any XPath expression (Expr production §3.1)
pub const Expr = union(enum) {
    or_expr: BinaryExpr,
    and_expr: BinaryExpr,
    equality_expr: BinaryExpr,
    relational_expr: BinaryExpr,
    additive_expr: BinaryExpr,
    multiplicative_expr: BinaryExpr,
    unary_expr: UnaryExpr,
    union_expr: BinaryExpr,
    path_expr: PathExpr,
    filter_expr: FilterExpr,
    primary_expr: PrimaryExpr,
    location_path: LocationPath,

    pub const BinaryExpr = struct {
        operator: Operator,
        left: *Expr,
        right: *Expr,

        pub const Operator = enum {
            // OrExpr
            @"or",
            // AndExpr
            @"and",
            // EqualityExpr
            equals,
            not_equals,
            // RelationalExpr
            less_than,
            less_than_or_equal,
            greater_than,
            greater_than_or_equal,
            // AdditiveExpr
            plus,
            minus,
            // MultiplicativeExpr
            multiply,
            div,
            mod,
            // UnionExpr
            union_pipe,
        };
    };

    pub const UnaryExpr = struct {
        operator: Operator,
        operand: *Expr,

        pub const Operator = enum {
            negate,
        };
    };
};

/// XPath 1.0 Primary Expression (§3.1)
///
/// Base expressions: variables, literals, numbers, function calls, grouped expressions
pub const PrimaryExpr = union(enum) {
    variable_reference: []const u8, // $QName
    literal: []const u8, // "..." or '...'
    number: f64,
    function_call: FunctionCall,
    grouped: *Expr, // (Expr)

    pub const FunctionCall = struct {
        name: []const u8, // QName
        arguments: []const *Expr,
    };
};

/// XPath 1.0 Path Expression (§3.3)
///
/// Combines filter expressions with location paths
pub const PathExpr = union(enum) {
    location_path: *LocationPath,
    filter: *FilterExpr,
    filter_with_path: struct {
        filter: *FilterExpr,
        path: *LocationPath,
        absolute: bool, // true for //, false for /
    },
};

/// XPath 1.0 Filter Expression (§3.3)
///
/// Primary expression with optional predicates
pub const FilterExpr = struct {
    primary: *PrimaryExpr,
    predicates: []const *Expr,
};

/// XPath 1.0 Location Path (§2)
///
/// Selects a set of nodes using steps
pub const LocationPath = union(enum) {
    absolute: struct {
        steps: []const Step,
    },
    relative: struct {
        steps: []const Step,
    },

    pub fn isAbsolute(self: LocationPath) bool {
        return switch (self) {
            .absolute => true,
            .relative => false,
        };
    }
};

/// XPath 1.0 Location Step (§2.1)
///
/// Axis + NodeTest + Predicates
pub const Step = struct {
    axis: Axis,
    node_test: NodeTest,
    predicates: []const *Expr,
};

/// XPath 1.0 Axes (§2.2)
///
/// Thirteen axes for navigating the XML tree
pub const Axis = enum {
    child,
    descendant,
    parent,
    ancestor,
    following_sibling,
    preceding_sibling,
    following,
    preceding,
    attribute,
    namespace,
    self,
    descendant_or_self,
    ancestor_or_self,

    /// Check if axis is a forward axis (§2.4)
    pub fn isForward(self: Axis) bool {
        return switch (self) {
            .child,
            .descendant,
            .following_sibling,
            .following,
            .attribute,
            .namespace,
            .self,
            .descendant_or_self,
            => true,
            .parent,
            .ancestor,
            .preceding_sibling,
            .preceding,
            .ancestor_or_self,
            => false,
        };
    }

    /// Check if axis is a reverse axis (§2.4)
    pub fn isReverse(self: Axis) bool {
        return !self.isForward();
    }

    /// Get principal node type for axis (§2.3)
    pub fn principalNodeType(self: Axis) PrincipalNodeType {
        return switch (self) {
            .attribute => .attribute,
            .namespace => .namespace,
            else => .element,
        };
    }

    pub const PrincipalNodeType = enum {
        element,
        attribute,
        namespace,
    };
};

/// XPath 1.0 Node Test (§2.3)
///
/// Tests which nodes are selected by a location step
pub const NodeTest = union(enum) {
    name_test: NameTest,
    node_type: NodeType,

    pub const NameTest = union(enum) {
        wildcard, // *
        qname: QName, // NCName or prefix:local
        namespace_wildcard: []const u8, // prefix:*

        pub const QName = struct {
            prefix: ?[]const u8,
            local: []const u8,
        };
    };

    pub const NodeType = union(enum) {
        comment, // comment()
        text, // text()
        processing_instruction: ?[]const u8, // processing-instruction(Literal?)
        node, // node()
    };
};

// ============================================================================
// AST Construction Helpers
// ============================================================================

/// Create a binary expression node
pub fn createBinaryExpr(
    allocator: std.mem.Allocator,
    operator: Expr.BinaryExpr.Operator,
    left: *Expr,
    right: *Expr,
) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = switch (operator) {
        .@"or" => .{ .or_expr = .{ .operator = operator, .left = left, .right = right } },
        .@"and" => .{ .and_expr = .{ .operator = operator, .left = left, .right = right } },
        .equals, .not_equals => .{ .equality_expr = .{ .operator = operator, .left = left, .right = right } },
        .less_than, .less_than_or_equal, .greater_than, .greater_than_or_equal => .{ .relational_expr = .{ .operator = operator, .left = left, .right = right } },
        .plus, .minus => .{ .additive_expr = .{ .operator = operator, .left = left, .right = right } },
        .multiply, .div, .mod => .{ .multiplicative_expr = .{ .operator = operator, .left = left, .right = right } },
        .union_pipe => .{ .union_expr = .{ .operator = operator, .left = left, .right = right } },
    };
    return expr;
}

/// Create a unary expression node
pub fn createUnaryExpr(
    allocator: std.mem.Allocator,
    operator: Expr.UnaryExpr.Operator,
    operand: *Expr,
) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = .{ .unary_expr = .{ .operator = operator, .operand = operand } };
    return expr;
}

/// Create a primary expression node
pub fn createPrimaryExpr(
    allocator: std.mem.Allocator,
    primary: PrimaryExpr,
) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = .{ .primary_expr = primary };
    return expr;
}

/// Create a location path node
pub fn createLocationPath(
    allocator: std.mem.Allocator,
    path: LocationPath,
) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = .{ .location_path = path };
    return expr;
}

/// Create a filter expression node
pub fn createFilterExpr(
    allocator: std.mem.Allocator,
    primary: *PrimaryExpr,
    predicates: []const *Expr,
) !*FilterExpr {
    const filter = try allocator.create(FilterExpr);
    filter.* = .{ .primary = primary, .predicates = predicates };
    return filter;
}

/// Create a path expression node
pub fn createPathExpr(
    allocator: std.mem.Allocator,
    path: PathExpr,
) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = .{ .path_expr = path };
    return expr;
}

/// Create a function call primary expression
pub fn createFunctionCall(
    allocator: std.mem.Allocator,
    name: []const u8,
    arguments: []const *Expr,
) !*Expr {
    const primary = PrimaryExpr{
        .function_call = .{
            .name = name,
            .arguments = arguments,
        },
    };
    return try createPrimaryExpr(allocator, primary);
}

/// Create a step
pub fn createStep(
    allocator: std.mem.Allocator,
    axis: Axis,
    node_test: NodeTest,
    predicates: []const *Expr,
) !Step {
    _ = allocator; // Steps are value types
    return Step{
        .axis = axis,
        .node_test = node_test,
        .predicates = predicates,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ast - binary expression creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: 5 + 3
    const left = try createPrimaryExpr(allocator, .{ .number = 5.0 });
    const right = try createPrimaryExpr(allocator, .{ .number = 3.0 });
    const expr = try createBinaryExpr(allocator, .plus, left, right);

    try std.testing.expectEqual(Expr.additive_expr, std.meta.activeTag(expr.*));
}

test "ast - function call creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: position()
    const expr = try createFunctionCall(allocator, "position", &[_]*Expr{});

    try std.testing.expectEqual(Expr.primary_expr, std.meta.activeTag(expr.*));
    try std.testing.expectEqual(PrimaryExpr.function_call, std.meta.activeTag(expr.primary_expr));
    try std.testing.expectEqualStrings("position", expr.primary_expr.function_call.name);
    try std.testing.expectEqual(@as(usize, 0), expr.primary_expr.function_call.arguments.len);
}

test "ast - location path creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: child::para
    const steps = try allocator.alloc(Step, 1);
    steps[0] = try createStep(
        allocator,
        .child,
        .{ .name_test = .{ .qname = .{ .prefix = null, .local = "para" } } },
        &[_]*Expr{},
    );

    const path = LocationPath{ .relative = .{ .steps = steps } };
    const expr = try createLocationPath(allocator, path);

    try std.testing.expectEqual(Expr.location_path, std.meta.activeTag(expr.*));
    try std.testing.expect(!expr.location_path.isAbsolute());
}

test "ast - axis properties" {
    // Test forward/reverse axes
    try std.testing.expect(Axis.child.isForward());
    try std.testing.expect(Axis.parent.isReverse());

    // Test principal node types
    try std.testing.expectEqual(Axis.PrincipalNodeType.element, Axis.child.principalNodeType());
    try std.testing.expectEqual(Axis.PrincipalNodeType.attribute, Axis.attribute.principalNodeType());
    try std.testing.expectEqual(Axis.PrincipalNodeType.namespace, Axis.namespace.principalNodeType());
}

test "ast - node test types" {
    // Wildcard
    const wildcard = NodeTest{ .name_test = .wildcard };
    try std.testing.expectEqual(NodeTest.name_test, std.meta.activeTag(wildcard));

    // QName
    const qname = NodeTest{ .name_test = .{ .qname = .{ .prefix = null, .local = "para" } } };
    try std.testing.expectEqual(NodeTest.name_test, std.meta.activeTag(qname));

    // Node type
    const node_type = NodeTest{ .node_type = .text };
    try std.testing.expectEqual(NodeTest.node_type, std.meta.activeTag(node_type));
}
