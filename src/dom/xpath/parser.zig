//! XPath 1.0 Parser
//!
//! This module implements parsing for XPath 1.0 expressions as specified by
//! the W3C XPath 1.0 Recommendation.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§2 Location Paths**: https://www.w3.org/TR/xpath-10/#location-paths
//! - **§3 Expressions**: https://www.w3.org/TR/xpath-10/#section-Expressions
//! - **Grammar Productions**: https://www.w3.org/TR/xpath-10/#NT-Expr
//!
//! ## Parsing Strategy
//!
//! Recursive descent parser following XPath 1.0 grammar productions.
//! Uses infra List for dynamic arrays (inline storage for small lists).

const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const ast = @import("ast.zig");
const Expr = ast.Expr;
const PrimaryExpr = ast.PrimaryExpr;
const LocationPath = ast.LocationPath;
const Step = ast.Step;
const Axis = ast.Axis;
const NodeTest = ast.NodeTest;
const infra = @import("infra");
const List = infra.List;

/// Parse errors
pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEndOfInput,
    ExpectedAbsolutePath,
    ExpectedAxis,
    ExpectedDoubleColon,
    ExpectedLeftParen,
    ExpectedRightParen,
    ExpectedRightBracket,
    ExpectedNameTest,
    ExpectedNodeTest,
    ExpectedNodeType,
    ExpectedPrimaryExpression,
    // Tokenizer errors
    UnexpectedColon,
    UnexpectedExclamation,
    UnexpectedCharacter,
    InvalidNameTest,
    UnterminatedLiteral,
    InvalidVariableReference,
    InvalidAxisName,
    InvalidQName,
} || std.mem.Allocator.Error || std.fmt.ParseFloatError;

/// XPath 1.0 Parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokenizer: Tokenizer,
    current_token: ?Token,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) !Parser {
        var tokenizer = Tokenizer.init(input);
        const first_token = try tokenizer.next();

        return Parser{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .current_token = first_token,
        };
    }

    /// Parse complete XPath expression (Entry point)
    ///
    /// Grammar: Expr ::= OrExpr
    pub fn parse(self: *Parser) ParseError!*Expr {
        const expr = try self.parseOrExpr();
        if (self.current_token) |token| {
            if (token.tag != .eof) {
                return error.UnexpectedToken;
            }
        }
        return expr;
    }

    // ========================================================================
    // Expression Parsing (§3 - Operator Precedence)
    // ========================================================================

    /// Parse OR expression (lowest precedence)
    /// Grammar: OrExpr ::= AndExpr ('or' AndExpr)*
    fn parseOrExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseAndExpr();

        while (self.match(.operator_or)) {
            try self.advance();
            const right = try self.parseAndExpr();
            left = try ast.createBinaryExpr(self.allocator, .@"or", left, right);
        }

        return left;
    }

    /// Parse AND expression
    /// Grammar: AndExpr ::= EqualityExpr ('and' EqualityExpr)*
    fn parseAndExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseEqualityExpr();

        while (self.match(.operator_and)) {
            try self.advance();
            const right = try self.parseEqualityExpr();
            left = try ast.createBinaryExpr(self.allocator, .@"and", left, right);
        }

        return left;
    }

    /// Parse equality expression
    /// Grammar: EqualityExpr ::= RelationalExpr (('=' | '!=') RelationalExpr)*
    fn parseEqualityExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseRelationalExpr();

        while (true) {
            const op: ?Expr.BinaryExpr.Operator = if (self.match(.equals))
                .equals
            else if (self.match(.not_equals))
                .not_equals
            else
                null;

            if (op) |operator| {
                try self.advance();
                const right = try self.parseRelationalExpr();
                left = try ast.createBinaryExpr(self.allocator, operator, left, right);
            } else {
                break;
            }
        }

        return left;
    }

    /// Parse relational expression
    /// Grammar: RelationalExpr ::= AdditiveExpr (('<' | '<=' | '>' | '>=') AdditiveExpr)*
    fn parseRelationalExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseAdditiveExpr();

        while (true) {
            const op: ?Expr.BinaryExpr.Operator = if (self.match(.less_than))
                .less_than
            else if (self.match(.less_than_or_equal))
                .less_than_or_equal
            else if (self.match(.greater_than))
                .greater_than
            else if (self.match(.greater_than_or_equal))
                .greater_than_or_equal
            else
                null;

            if (op) |operator| {
                try self.advance();
                const right = try self.parseAdditiveExpr();
                left = try ast.createBinaryExpr(self.allocator, operator, left, right);
            } else {
                break;
            }
        }

        return left;
    }

    /// Parse additive expression
    /// Grammar: AdditiveExpr ::= MultiplicativeExpr (('+' | '-') MultiplicativeExpr)*
    fn parseAdditiveExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseMultiplicativeExpr();

        while (true) {
            const op: ?Expr.BinaryExpr.Operator = if (self.match(.plus))
                .plus
            else if (self.match(.minus))
                .minus
            else
                null;

            if (op) |operator| {
                try self.advance();
                const right = try self.parseMultiplicativeExpr();
                left = try ast.createBinaryExpr(self.allocator, operator, left, right);
            } else {
                break;
            }
        }

        return left;
    }

    /// Parse multiplicative expression
    /// Grammar: MultiplicativeExpr ::= UnaryExpr (('*' | 'div' | 'mod') UnaryExpr)*
    fn parseMultiplicativeExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parseUnaryExpr();

        while (true) {
            const op: ?Expr.BinaryExpr.Operator = if (self.match(.multiply))
                .multiply
            else if (self.match(.operator_div))
                .div
            else if (self.match(.operator_mod))
                .mod
            else
                null;

            if (op) |operator| {
                try self.advance();
                const right = try self.parseUnaryExpr();
                left = try ast.createBinaryExpr(self.allocator, operator, left, right);
            } else {
                break;
            }
        }

        return left;
    }

    /// Parse unary expression
    /// Grammar: UnaryExpr ::= UnionExpr | '-' UnaryExpr
    fn parseUnaryExpr(self: *Parser) ParseError!*Expr {
        if (self.match(.minus)) {
            try self.advance();
            const operand = try self.parseUnaryExpr();
            return ast.createUnaryExpr(self.allocator, .negate, operand);
        }

        return try self.parseUnionExpr();
    }

    /// Parse union expression (node-set union with |)
    /// Grammar: UnionExpr ::= PathExpr ('|' PathExpr)*
    fn parseUnionExpr(self: *Parser) ParseError!*Expr {
        var left = try self.parsePathExpr();

        while (self.match(.pipe)) {
            try self.advance();
            const right = try self.parsePathExpr();
            left = try ast.createBinaryExpr(self.allocator, .union_pipe, left, right);
        }

        return left;
    }

    /// Parse path expression
    /// Grammar: PathExpr ::= LocationPath | FilterExpr | FilterExpr '/' RelativeLocationPath | FilterExpr '//' RelativeLocationPath
    fn parsePathExpr(self: *Parser) ParseError!*Expr {
        // Absolute location path (starts with / or //)
        if (self.match(.slash) or self.match(.slash_slash)) {
            return try self.parseLocationPathExpr();
        }

        // Try primary expression first
        if (self.matchPrimaryExpr()) {
            const primary_expr = try self.parsePrimaryExprOnly();
            const predicates = try self.parsePredicates();

            // FilterExpr followed by path
            if (self.match(.slash) or self.match(.slash_slash)) {
                const is_descendant = self.match(.slash_slash);
                try self.advance();

                const filter = try ast.createFilterExpr(self.allocator, primary_expr, predicates);
                const relative_path = try self.parseRelativeLocationPath();
                const path_ptr = try self.allocator.create(LocationPath);
                path_ptr.* = relative_path;

                const path_expr = ast.PathExpr{
                    .filter_with_path = .{
                        .filter = filter,
                        .path = path_ptr,
                        .absolute = is_descendant,
                    },
                };
                return ast.createPathExpr(self.allocator, path_expr);
            }

            // Just filter expression
            if (predicates.len > 0) {
                const filter = try ast.createFilterExpr(self.allocator, primary_expr, predicates);
                const path_expr = ast.PathExpr{ .filter = filter };
                return ast.createPathExpr(self.allocator, path_expr);
            }

            // Just primary expression
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .primary_expr = primary_expr.* };
            return expr;
        }

        // Relative location path
        return try self.parseLocationPathExpr();
    }

    // ========================================================================
    // Location Path Parsing (§2)
    // ========================================================================

    fn parseLocationPathExpr(self: *Parser) ParseError!*Expr {
        const path = try self.parseLocationPath();
        return ast.createLocationPath(self.allocator, path);
    }

    /// Parse location path
    fn parseLocationPath(self: *Parser) ParseError!LocationPath {
        if (self.match(.slash) or self.match(.slash_slash)) {
            return try self.parseAbsoluteLocationPath();
        }
        return try self.parseRelativeLocationPath();
    }

    /// Parse absolute location path
    /// Grammar: AbsoluteLocationPath ::= '/' RelativeLocationPath? | '//' RelativeLocationPath
    fn parseAbsoluteLocationPath(self: *Parser) ParseError!LocationPath {
        if (self.match(.slash_slash)) {
            try self.advance();
            // // is short for /descendant-or-self::node()/
            const descendant_step = try self.createDescendantOrSelfStep();
            const relative_path = try self.parseRelativeLocationPath();

            // Prepend descendant-or-self step
            var steps = List(Step).init(self.allocator);
            defer steps.deinit();
            try steps.append(descendant_step);
            for (relative_path.relative.steps) |step| {
                try steps.append(step);
            }

            return LocationPath{ .absolute = .{ .steps = try self.listToSlice(Step, &steps) } };
        }

        if (self.match(.slash)) {
            try self.advance();

            // Check if followed by relative path
            if (self.matchStep()) {
                const relative_path = try self.parseRelativeLocationPath();
                return LocationPath{ .absolute = .{ .steps = relative_path.relative.steps } };
            }

            // Just / (document root)
            return LocationPath{ .absolute = .{ .steps = &[_]Step{} } };
        }

        return error.ExpectedAbsolutePath;
    }

    /// Parse relative location path
    /// Grammar: RelativeLocationPath ::= Step ('/' Step)* | Step ('//' Step)*
    fn parseRelativeLocationPath(self: *Parser) ParseError!LocationPath {
        var steps = List(Step).init(self.allocator);
        defer steps.deinit();

        // Parse first step
        const first_step = try self.parseStep();
        try steps.append(first_step);

        // Parse remaining steps
        while (self.match(.slash) or self.match(.slash_slash)) {
            const is_descendant = self.match(.slash_slash);
            try self.advance();

            // // is shorthand for /descendant-or-self::node()/
            if (is_descendant) {
                const descendant_step = try self.createDescendantOrSelfStep();
                try steps.append(descendant_step);
            }

            const step = try self.parseStep();
            try steps.append(step);
        }

        return LocationPath{ .relative = .{ .steps = try self.listToSlice(Step, &steps) } };
    }

    /// Parse location step
    /// Grammar: Step ::= AxisSpecifier NodeTest Predicate* | AbbreviatedStep
    fn parseStep(self: *Parser) ParseError!Step {
        // Abbreviated step: .
        if (self.match(.dot)) {
            try self.advance();
            return ast.createStep(
                self.allocator,
                .self,
                .{ .node_type = .node },
                &[_]*Expr{},
            );
        }

        // Abbreviated step: ..
        if (self.match(.dot_dot)) {
            try self.advance();
            return ast.createStep(
                self.allocator,
                .parent,
                .{ .node_type = .node },
                &[_]*Expr{},
            );
        }

        // Abbreviated axis: @
        if (self.match(.at_sign)) {
            try self.advance();
            const node_test = try self.parseNodeTest(.attribute);
            const predicates = try self.parsePredicates();
            return ast.createStep(self.allocator, .attribute, node_test, predicates);
        }

        // Full axis specification or default child axis
        var axis: Axis = .child;

        if (self.matchAxis()) {
            axis = try self.parseAxis();
            if (!self.match(.double_colon)) {
                return error.ExpectedDoubleColon;
            }
            try self.advance();
        }

        const node_test = try self.parseNodeTest(axis);
        const predicates = try self.parsePredicates();

        return ast.createStep(self.allocator, axis, node_test, predicates);
    }

    /// Parse axis name
    fn parseAxis(self: *Parser) ParseError!Axis {
        const token = self.current_token orelse return error.ExpectedAxis;

        const axis: Axis = switch (token.tag) {
            .axis_child => .child,
            .axis_descendant => .descendant,
            .axis_parent => .parent,
            .axis_ancestor => .ancestor,
            .axis_following_sibling => .following_sibling,
            .axis_preceding_sibling => .preceding_sibling,
            .axis_following => .following,
            .axis_preceding => .preceding,
            .axis_attribute => .attribute,
            .axis_namespace => .namespace,
            .axis_self => .self,
            .axis_descendant_or_self => .descendant_or_self,
            .axis_ancestor_or_self => .ancestor_or_self,
            else => return error.ExpectedAxis,
        };

        try self.advance();
        return axis;
    }

    /// Parse node test
    fn parseNodeTest(self: *Parser, axis: Axis) ParseError!NodeTest {
        _ = axis;

        // Node type tests
        if (self.matchNodeType()) {
            return try self.parseNodeTypeTest();
        }

        // Name test
        if (self.match(.name_test) or self.match(.multiply)) {
            return try self.parseNameTest();
        }

        return error.ExpectedNodeTest;
    }

    /// Parse node type test
    fn parseNodeTypeTest(self: *Parser) ParseError!NodeTest {
        const token = self.current_token orelse return error.ExpectedNodeType;

        const node_type: NodeTest.NodeType = switch (token.tag) {
            .node_type_comment => .comment,
            .node_type_text => .text,
            .node_type_node => .node,
            .node_type_processing_instruction => {
                try self.advance();
                if (!self.match(.lparen)) return error.ExpectedLeftParen;
                try self.advance();

                var target: ?[]const u8 = null;
                if (self.match(.literal)) {
                    target = self.current_token.?.value;
                    try self.advance();
                }

                if (!self.match(.rparen)) return error.ExpectedRightParen;
                try self.advance();

                return NodeTest{ .node_type = .{ .processing_instruction = target } };
            },
            else => return error.ExpectedNodeType,
        };

        try self.advance();

        if (!self.match(.lparen)) return error.ExpectedLeftParen;
        try self.advance();

        if (!self.match(.rparen)) return error.ExpectedRightParen;
        try self.advance();

        return NodeTest{ .node_type = node_type };
    }

    /// Parse name test
    fn parseNameTest(self: *Parser) ParseError!NodeTest {
        const token = self.current_token orelse return error.ExpectedNameTest;

        if (self.match(.multiply)) {
            try self.advance();
            return NodeTest{ .name_test = .wildcard };
        }

        if (self.match(.name_test)) {
            const name = token.value;
            try self.advance();

            // Check for namespace wildcard (prefix:*)
            if (std.mem.indexOf(u8, name, ":*")) |_| {
                const prefix = name[0 .. name.len - 2];
                return NodeTest{ .name_test = .{ .namespace_wildcard = prefix } };
            }

            // Check for QName (prefix:local)
            if (std.mem.indexOf(u8, name, ":")) |colon_idx| {
                const prefix = name[0..colon_idx];
                const local = name[colon_idx + 1 ..];
                return NodeTest{
                    .name_test = .{
                        .qname = .{
                            .prefix = prefix,
                            .local = local,
                        },
                    },
                };
            }

            // Simple NCName
            return NodeTest{
                .name_test = .{
                    .qname = .{
                        .prefix = null,
                        .local = name,
                    },
                },
            };
        }

        return error.ExpectedNameTest;
    }

    /// Parse predicates
    fn parsePredicates(self: *Parser) ParseError![]const *Expr {
        var predicates = List(*Expr).init(self.allocator);
        defer predicates.deinit();

        while (self.match(.lbracket)) {
            try self.advance();
            const pred_expr = try self.parseOrExpr();
            if (!self.match(.rbracket)) return error.ExpectedRightBracket;
            try self.advance();
            try predicates.append(pred_expr);
        }

        return self.listToSlice(*Expr, &predicates);
    }

    // ========================================================================
    // Primary Expression Parsing
    // ========================================================================

    fn parsePrimaryExprOnly(self: *Parser) ParseError!*PrimaryExpr {
        // Variable reference
        if (self.match(.variable_reference)) {
            const name = self.current_token.?.value;
            try self.advance();
            const primary = try self.allocator.create(PrimaryExpr);
            primary.* = .{ .variable_reference = name };
            return primary;
        }

        // Literal
        if (self.match(.literal)) {
            const value = self.current_token.?.value;
            try self.advance();
            const primary = try self.allocator.create(PrimaryExpr);
            primary.* = .{ .literal = value };
            return primary;
        }

        // Number
        if (self.match(.number)) {
            const value_str = self.current_token.?.value;
            const value = try std.fmt.parseFloat(f64, value_str);
            try self.advance();
            const primary = try self.allocator.create(PrimaryExpr);
            primary.* = .{ .number = value };
            return primary;
        }

        // Function call
        if (self.match(.function_name)) {
            const name = self.current_token.?.value;
            try self.advance();

            if (!self.match(.lparen)) return error.ExpectedLeftParen;
            try self.advance();

            var arguments = List(*Expr).init(self.allocator);
            defer arguments.deinit();

            // Parse arguments
            if (!self.match(.rparen)) {
                while (true) {
                    const arg = try self.parseOrExpr();
                    try arguments.append(arg);

                    if (self.match(.comma)) {
                        try self.advance();
                    } else {
                        break;
                    }
                }
            }

            if (!self.match(.rparen)) return error.ExpectedRightParen;
            try self.advance();

            const primary = try self.allocator.create(PrimaryExpr);
            primary.* = .{
                .function_call = .{
                    .name = name,
                    .arguments = try self.listToSlice(*Expr, &arguments),
                },
            };
            return primary;
        }

        // Grouped expression
        if (self.match(.lparen)) {
            try self.advance();
            const expr = try self.parseOrExpr();
            if (!self.match(.rparen)) return error.ExpectedRightParen;
            try self.advance();
            const primary = try self.allocator.create(PrimaryExpr);
            primary.* = .{ .grouped = expr };
            return primary;
        }

        return error.ExpectedPrimaryExpression;
    }

    // ========================================================================
    // Helper Functions
    // ========================================================================

    fn createDescendantOrSelfStep(self: *Parser) ParseError!Step {
        return ast.createStep(
            self.allocator,
            .descendant_or_self,
            .{ .node_type = .node },
            &[_]*Expr{},
        );
    }

    fn advance(self: *Parser) ParseError!void {
        self.current_token = try self.tokenizer.next();
    }

    fn match(self: *Parser, tag: Token.Tag) bool {
        if (self.current_token) |token| {
            return token.tag == tag;
        }
        return false;
    }

    fn matchAxis(self: *Parser) bool {
        if (self.current_token) |token| {
            return switch (token.tag) {
                .axis_child,
                .axis_descendant,
                .axis_parent,
                .axis_ancestor,
                .axis_following_sibling,
                .axis_preceding_sibling,
                .axis_following,
                .axis_preceding,
                .axis_attribute,
                .axis_namespace,
                .axis_self,
                .axis_descendant_or_self,
                .axis_ancestor_or_self,
                => true,
                else => false,
            };
        }
        return false;
    }

    fn matchNodeType(self: *Parser) bool {
        if (self.current_token) |token| {
            return switch (token.tag) {
                .node_type_comment,
                .node_type_text,
                .node_type_processing_instruction,
                .node_type_node,
                => true,
                else => false,
            };
        }
        return false;
    }

    fn matchStep(self: *Parser) bool {
        if (self.current_token) |token| {
            return switch (token.tag) {
                .dot,
                .dot_dot,
                .at_sign,
                .name_test,
                .multiply,
                => true,
                else => self.matchAxis() or self.matchNodeType(),
            };
        }
        return false;
    }

    fn matchPrimaryExpr(self: *Parser) bool {
        if (self.current_token) |token| {
            return switch (token.tag) {
                .variable_reference,
                .literal,
                .number,
                .function_name,
                .lparen,
                => true,
                else => false,
            };
        }
        return false;
    }

    /// Convert infra List to owned slice
    fn listToSlice(self: *Parser, comptime T: type, list: *List(T)) ![]const T {
        const slice = try self.allocator.alloc(T, list.size());
        for (0..list.size()) |i| {
            slice[i] = list.get(i).?;
        }
        return slice;
    }
};

// ============================================================================
// Tests
// ============================================================================












