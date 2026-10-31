//! DOM XPathExpression: XPath 1.0 compilation and evaluation.
//!
//! Algorithms: specs/w3c/REC-xpath-19991116.md §§2–5 and DOM Level 3 XPath §1.4.
//! Each compiled expression owns its grammar arena; each evaluation owns a
//! separate short-lived arena. No node or callback survives evaluation here.
//! Results cross the generated XPathResult construction chain, never its impl.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const infra = @import("infra");
const engine = @import("engine");
const Allocator = std.mem.Allocator;
const Node = runtime.Instance;
const List = infra.List;
const ast = dom.xpath.ast;
const Axis = ast.Axis;

pub const State = interfaces.XPathExpression.State;
pub const ImplError = error{ SyntaxError, NamespaceError, TypeError, NotSupportedError, InvalidStateError, OutOfMemory };
pub const construction_args = .{ "expression", "resolver" };

/// Parsed immutable expression. Namespace callbacks run only during construction.
pub const InternalState = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    expression: ?*const Expr = null,
};

pub fn initOwn(instance: *Node, allocator: Allocator, comptime StateType: type, args: anytype) !void {
    const state = instance.getState(StateType);
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer internal.arena.deinit();
    if (comptime @hasField(@TypeOf(args), "expression")) {
        const source = try internal.arena.allocator().dupe(u8, args.expression.asSlice());
        const wrapper: ?*runtime.CallbackWrapper = if (comptime @hasField(@TypeOf(args), "resolver"))
            (args.resolver.getOrDefault(null) orelse null)
        else
            null;
        const callback: ?engine.CallbackInterface = if (wrapper) |value| engine.takeCallbackInterface(value) else null;
        defer if (callback) |value| value.release();
        var parser = Parser{ .allocator = internal.arena.allocator(), .source = source, .realm = instance.ctx, .resolver = callback };
        try parser.advance();
        internal.expression = try parser.expression(0);
        if (parser.token.kind != .end) return error.SyntaxError;
    }
    state.own._internal = internal;
}

pub fn deinitOwn(instance: *Node) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.arena.deinit();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// DOM Level 3 XPath §1.4 evaluate: evaluate, then convert to the requested kind.
pub fn call_evaluate(instance: *Node, contextNode: *Node, kind_arg: webidl.Opt(u16), result: webidl.Opt(?*Node)) anyerror!*Node {
    _ = result; // Reuse is optional; WebKit XPathExpression::evaluate also creates a result.
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const expression = internal.expression orelse return error.InvalidStateError;
    const node_type = try interfaces.Node.get_nodeType(contextNode);
    switch (node_type) {
        1, 2, 3, 4, 7, 8, 9 => {},
        else => return error.NotSupportedError,
    }
    const kind = kind_arg.getOrDefault(0);
    if (kind > 9) return error.NotSupportedError;
    var arena = std.heap.ArenaAllocator.init(internal.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var evaluator = Evaluation{ .allocator = allocator, .backing = internal.allocator };
    const value = try evaluator.evaluate(expression, .{ .node = contextNode });
    const actual: u16 = if (kind != 0) kind else switch (value) {
        .number => 1,
        .string => 2,
        .boolean => 3,
        .nodes => 4,
    };
    const realm = engine.currentRealm() orelse instance.ctx;
    if (actual <= 3) {
        return interfaces.XPathResult.initWith(realm.allocator, realm, .{
            .result_type = actual,
            .number_value = if (actual == 1) try evaluator.number(value) else 0,
            .string_value = if (actual == 2) try evaluator.string(value) else "",
            .boolean_value = if (actual == 3) boolean(value) else false,
        });
    }
    if (value != .nodes) return error.TypeError;
    const nodes = value.nodes;
    return interfaces.XPathResult.initWith(realm.allocator, realm, .{
        .result_type = actual,
        .nodes = if (actual >= 8 and nodes.len > 1) nodes[0..1] else nodes,
        .document = dom.live_collections.nodeDocument(contextNode),
    });
}

const Value = union(enum) { number: f64, string: []const u8, boolean: bool, nodes: []const *Node };
const Context = struct { node: *Node, position: usize = 1, size: usize = 1 };
const Op = enum { or_op, and_op, eq, ne, lt, le, gt, ge, add, sub, mul, div, mod, union_op };
const Test = union(enum) {
    any,
    text,
    comment,
    pi: ?[]const u8,
    name: NameTest,
};
const NameTest = struct { local: []const u8, namespace: ?[]const u8 = null, wildcard: bool = false };
const Step = struct { axis: Axis, test_node: Test, predicates: []const *const Expr = &.{} };
const Expr = union(enum) {
    number: f64,
    string: []const u8,
    /// XPath §3.1 VariableReference, by its QName (never resolved: no bindings).
    variable: []const u8,
    unary: *const Expr,
    binary: struct { op: Op, left: *const Expr, right: *const Expr },
    function: struct { name: []const u8, args: []const *const Expr },
    path: struct { start: ?*const Expr = null, absolute: bool = false, steps: []const Step },
    filter: struct { base: *const Expr, predicates: []const *const Expr },
};

// XPath §3.7: the lexer returns longest tokens; the parser distinguishes
// operator names from NameTests according to their grammatical position.
const Token = struct {
    kind: enum { end, name, variable, number, string, slash, slash2, dot, dot2, at, axis, lp, rp, lb, rb, comma, star, plus, minus, eq, ne, lt, le, gt, ge, pipe },
    text: []const u8 = "",
};
const Parser = struct {
    allocator: Allocator,
    source: []const u8,
    offset: usize = 0,
    token: Token = .{ .kind = .end },
    depth: usize = 0,
    realm: runtime.Context,
    resolver: ?engine.CallbackInterface,

    fn advance(p: *Parser) anyerror!void {
        while (p.offset < p.source.len and xmlSpace(p.source[p.offset])) p.offset += 1;
        const start = p.offset;
        if (start == p.source.len) {
            p.token = .{ .kind = .end };
            return;
        }
        const c = p.source[start];
        p.offset += 1;
        const pair = p.source[start..@min(start + 2, p.source.len)];
        inline for (.{ .{ "//", .slash2 }, .{ "..", .dot2 }, .{ "::", .axis }, .{ "!=", .ne }, .{ "<=", .le }, .{ ">=", .ge } }) |entry| {
            if (std.mem.eql(u8, pair, entry[0])) {
                p.offset += 1;
                p.token = .{ .kind = entry[1], .text = pair };
                return;
            }
        }
        if (c == '\'' or c == '"') {
            while (p.offset < p.source.len and p.source[p.offset] != c) p.offset += 1;
            if (p.offset == p.source.len) return error.SyntaxError;
            p.token = .{ .kind = .string, .text = p.source[start + 1 .. p.offset] };
            p.offset += 1;
            return;
        }
        if (std.ascii.isDigit(c) or (c == '.' and p.offset < p.source.len and std.ascii.isDigit(p.source[p.offset]))) {
            var dot = c == '.';
            while (p.offset < p.source.len) {
                const next = p.source[p.offset];
                if (std.ascii.isDigit(next)) {
                    p.offset += 1;
                    continue;
                }
                if (next == '.' and !dot) {
                    dot = true;
                    p.offset += 1;
                    continue;
                }
                break;
            }
            p.token = .{ .kind = .number, .text = p.source[start..p.offset] };
            return;
        }
        if (c == '$') {
            // XPath §3.7 [36] VariableReference ::= '$' QName, the QName lexed
            // as a NameTest's is, with nothing between it and '$' (WebKit and
            // Blink lexQName after '$'; a space there is an error in all three).
            p.token = .{ .kind = .variable, .text = try p.qname(false) };
            return;
        }
        if (c >= 0x80 or std.ascii.isAlphabetic(c) or c == '_') {
            p.offset = start;
            p.token = .{ .kind = .name, .text = try p.qname(true) };
            return;
        }
        p.token = .{ .kind = switch (c) {
            '/' => .slash,
            '.' => .dot,
            '@' => .at,
            '(' => .lp,
            ')' => .rp,
            '[' => .lb,
            ']' => .rb,
            ',' => .comma,
            '*' => .star,
            '+' => .plus,
            '-' => .minus,
            '=' => .eq,
            '<' => .lt,
            '>' => .gt,
            '|' => .pipe,
            else => return error.SyntaxError,
        }, .text = p.source[start..p.offset] };
    }

    /// The QName at the current offset (XPath §3.7 [37] and [36]); `*` may be
    /// the local part only of a NameTest.
    fn qname(p: *Parser, star_local: bool) ![]const u8 {
        const start = p.offset;
        try p.ncname();
        const prefix_end = p.offset;
        // XPath §3.7 [37], browser compatibility: Blink/WebKit skip XML
        // space around QName colons, while the axis separator stays "::".
        while (p.offset < p.source.len and xmlSpace(p.source[p.offset])) p.offset += 1;
        if (p.offset < p.source.len and p.source[p.offset] == ':' and !(p.offset + 1 < p.source.len and p.source[p.offset + 1] == ':')) {
            const colon = p.offset;
            p.offset += 1;
            while (p.offset < p.source.len and xmlSpace(p.source[p.offset])) p.offset += 1;
            const local_start = p.offset;
            if (star_local and p.offset < p.source.len and p.source[p.offset] == '*') p.offset += 1 else try p.ncname();
            return if (colon == prefix_end and local_start == colon + 1)
                p.source[start..p.offset]
            else
                try std.fmt.allocPrint(p.allocator, "{s}:{s}", .{ p.source[start..prefix_end], p.source[local_start..p.offset] });
        }
        return p.source[start..prefix_end];
    }

    fn ncname(p: *Parser) !void {
        var first = true;
        while (p.offset < p.source.len) {
            const len = std.unicode.utf8ByteSequenceLength(p.source[p.offset]) catch return error.SyntaxError;
            if (p.offset + len > p.source.len) return error.SyntaxError;
            const cp = std.unicode.utf8Decode(p.source[p.offset..][0..len]) catch return error.SyntaxError;
            const allowed = if (first) nameStart(cp) else nameStart(cp) or cp == '-' or cp == '.' or (cp >= '0' and cp <= '9') or cp == 0xb7 or (cp >= 0x300 and cp <= 0x36f) or (cp >= 0x203f and cp <= 0x2040);
            if (!allowed) break;
            p.offset += len;
            first = false;
        }
        if (first) return error.SyntaxError;
    }

    fn make(p: *Parser, value: Expr) !*const Expr {
        const expr = try p.allocator.create(Expr);
        expr.* = value;
        return expr;
    }
    fn consume(p: *Parser, kind: @TypeOf(p.token.kind)) !void {
        if (p.token.kind != kind) return error.SyntaxError;
        try p.advance();
    }

    // XPath §§3.3–3.5, productions [18], [21]–[27]. Union binds above unary -.
    // `depth` bounds NESTING (parentheses, predicates, arguments, unary minus),
    // which is all this recursion follows: an operator chain is built by the
    // loop below into a left-deep tree, so its length costs no parser frames,
    // evaluation folds it iteratively (Evaluation.operators), and the grammar
    // arena frees it without walking it.
    fn expression(p: *Parser, minimum: u8) anyerror!*const Expr {
        if (p.depth >= 256) return error.SyntaxError;
        p.depth += 1;
        defer p.depth -= 1;
        var left = if (p.token.kind == .minus) blk: {
            try p.advance();
            break :blk try p.make(.{ .unary = try p.expression(6) });
        } else try p.path();
        while (binaryOperator(p.token)) |operator| {
            if (operator.precedence < minimum) break;
            try p.advance();
            const right = try p.expression(operator.precedence + 1);
            left = try p.make(.{ .binary = .{ .op = operator.op, .left = left, .right = right } });
        }
        return left;
    }

    fn path(p: *Parser) anyerror!*const Expr {
        var steps = List(Step).init(p.allocator);
        defer steps.deinit();
        var start: ?*const Expr = null;
        var absolute = false;
        if (p.token.kind == .slash or p.token.kind == .slash2) {
            absolute = true;
            const descendant_path = p.token.kind == .slash2;
            try p.advance();
            if (descendant_path) try steps.append(.{ .axis = .descendant_or_self, .test_node = .any });
            if (isStep(p.token)) try appendStep(&steps, try p.step()) else if (descendant_path) return error.SyntaxError;
        } else {
            const saved = p.*;
            var is_primary = p.token.kind == .variable or p.token.kind == .string or p.token.kind == .number or p.token.kind == .lp;
            if (p.token.kind == .name) {
                const name = p.token.text;
                try p.advance();
                is_primary = p.token.kind == .lp and !nodeTypeName(name);
                p.* = saved;
            }
            if (is_primary) {
                start = try p.primary();
                const filters = try p.predicates();
                if (filters.len != 0) start = try p.make(.{ .filter = .{ .base = start.?, .predicates = filters } });
                if (p.token.kind != .slash and p.token.kind != .slash2) return start.?;
            } else try steps.append(try p.step());
        }
        while (p.token.kind == .slash or p.token.kind == .slash2) {
            const descendant_path = p.token.kind == .slash2;
            try p.advance();
            if (descendant_path) try steps.append(.{ .axis = .descendant_or_self, .test_node = .any });
            try appendStep(&steps, try p.step());
        }
        return p.make(.{ .path = .{ .start = start, .absolute = absolute, .steps = try steps.toOwnedSlice() } });
    }

    fn primary(p: *Parser) anyerror!*const Expr {
        const token = p.token;
        try p.advance();
        switch (token.kind) {
            .string => return p.make(.{ .string = token.text }),
            .variable => return p.make(.{ .variable = token.text }),
            .number => return p.make(.{ .number = std.fmt.parseFloat(f64, token.text) catch return error.SyntaxError }),
            .lp => {
                const result = try p.expression(0);
                try p.consume(.rp);
                return result;
            },
            .name => {
                try p.consume(.lp);
                var args = List(*const Expr).init(p.allocator);
                defer args.deinit();
                if (p.token.kind != .rp) {
                    while (true) {
                        try args.append(try p.expression(0));
                        if (p.token.kind != .comma) break;
                        try p.advance();
                    }
                }
                try p.consume(.rp);
                if (!validArity(token.text, args.len)) return error.SyntaxError;
                return p.make(.{ .function = .{ .name = token.text, .args = try args.toOwnedSlice() } });
            },
            else => return error.SyntaxError,
        }
    }

    fn step(p: *Parser) anyerror!Step {
        if (p.token.kind == .dot or p.token.kind == .dot2) {
            const axis: Axis = if (p.token.kind == .dot) .self else .parent;
            try p.advance();
            return .{ .axis = axis, .test_node = .any };
        }
        var axis: Axis = .child;
        if (p.token.kind == .at) {
            axis = .attribute;
            try p.advance();
        } else if (p.token.kind == .name) {
            const saved = p.*;
            const name = p.token.text;
            try p.advance();
            if (p.token.kind == .axis) {
                axis = axisName(name) orelse return error.SyntaxError;
                try p.advance();
            } else p.* = saved;
        }
        var test_node: Test = undefined;
        if (p.token.kind == .star) {
            test_node = .{ .name = .{ .local = "*", .wildcard = true } };
            try p.advance();
        } else if (p.token.kind == .name) {
            const name = p.token.text;
            try p.advance();
            if (p.token.kind == .lp) {
                if (!nodeTypeName(name)) return error.SyntaxError;
                try p.advance();
                if (std.mem.eql(u8, name, "processing-instruction")) {
                    var target: ?[]const u8 = null;
                    if (p.token.kind == .string) {
                        target = p.token.text;
                        try p.advance();
                    }
                    test_node = .{ .pi = target };
                } else test_node = if (std.mem.eql(u8, name, "node")) .any else if (std.mem.eql(u8, name, "text")) .text else .comment;
                try p.consume(.rp);
            } else if (std.mem.indexOfScalar(u8, name, ':')) |colon| {
                const uri = try p.resolve(name[0..colon]);
                const local = name[colon + 1 ..];
                test_node = .{ .name = .{ .local = local, .namespace = uri, .wildcard = std.mem.eql(u8, local, "*") } };
            } else test_node = .{ .name = .{ .local = name } };
        } else return error.SyntaxError;
        return .{ .axis = axis, .test_node = test_node, .predicates = try p.predicates() };
    }

    fn predicates(p: *Parser) anyerror![]const *const Expr {
        var list = List(*const Expr).init(p.allocator);
        defer list.deinit();
        while (p.token.kind == .lb) {
            try p.advance();
            try list.append(try p.expression(0));
            try p.consume(.rb);
        }
        return list.toOwnedSlice();
    }

    fn resolve(p: *Parser, prefix: []const u8) anyerror![]const u8 {
        const callback = p.resolver orelse return error.NamespaceError;
        const realm = engine.currentRealm() orelse p.realm;
        // Browser behavior: report callback exceptions, then raise NamespaceError.
        // wpt domxpath/resolver-callback-interface.html; WebKit XPathParser.
        const completion = try engine.callUserObjectOperation(realm, &callback, "lookupNamespaceURI", .undefined, &.{.{ .string = .{ .data = prefix, .owned = false } }}, .{ .report = .{ .report = reportException, .host = realm } });
        const returned = switch (completion) {
            inline else => |value| value,
        };
        defer returned.release();
        switch (engine.typeOf(realm, returned.value)) {
            .null, .undefined => return error.NamespaceError,
            else => {},
        }
        var conversion = StringConversion{ .realm = realm, .value = returned.value, .allocator = p.allocator };
        if (try engine.completionOf(realm, StringConversion.run, &conversion)) |exception| {
            defer exception.release();
            const info = try engine.extractErrorInformation(realm, exception.value, realm.allocator);
            defer realm.allocator.free(info.message);
            defer realm.allocator.free(info.filename);
            reportException(realm, &info);
            return error.NamespaceError;
        }
        return conversion.result.?;
    }
};

const StringConversion = struct {
    realm: runtime.Context,
    value: runtime.JSValue,
    allocator: Allocator,
    result: ?[]u8 = null,
    fn run(data: ?*anyopaque) engine.Error!void {
        const self: *StringConversion = @ptrCast(@alignCast(data.?));
        self.result = try engine.convertToDOMString(self.realm, self.value, self.allocator);
    }
};
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const record = realm.getRealm() orelse return;
    const global: *Node = @ptrCast(@alignCast(record.global_object orelse return));
    // HTML "report an exception": Window realms have no host override;
    // their global fires the ErrorEvent. The shared reporter handles both.
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}
fn nameStart(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z') or cp == '_' or
        (cp >= 0xc0 and cp <= 0xd6) or (cp >= 0xd8 and cp <= 0xf6) or (cp >= 0xf8 and cp <= 0x2ff) or
        (cp >= 0x370 and cp <= 0x37d) or (cp >= 0x37f and cp <= 0x1fff) or (cp >= 0x200c and cp <= 0x200d) or
        (cp >= 0x2070 and cp <= 0x218f) or (cp >= 0x2c00 and cp <= 0x2fef) or (cp >= 0x3001 and cp <= 0xd7ff) or
        (cp >= 0xf900 and cp <= 0xfdcf) or (cp >= 0xfdf0 and cp <= 0xfffd) or (cp >= 0x10000 and cp <= 0xeffff);
}
fn xmlSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}
/// XPath §2.5: `//` abbreviates /descendant-or-self::node()/. Followed by a
/// child step WITHOUT predicates the pair selects exactly descendant::<test>,
/// which one walk yields in document order; WebKit's LocationPath
/// optimizeStepPair makes the same rewrite. With predicates it may not:
/// //x[1] is every parent's first x child, not the first x descendant.
fn appendStep(steps: *List(Step), step: Step) !void {
    if (step.axis == .child and step.predicates.len == 0) {
        if (steps.getPtr(steps.len -% 1)) |previous| {
            if (previous.axis == .descendant_or_self and previous.test_node == .any and previous.predicates.len == 0) {
                previous.* = .{ .axis = .descendant, .test_node = step.test_node };
                return;
            }
        }
    }
    try steps.append(step);
}
fn nodeTypeName(name: []const u8) bool {
    return std.mem.eql(u8, name, "node") or std.mem.eql(u8, name, "text") or std.mem.eql(u8, name, "comment") or std.mem.eql(u8, name, "processing-instruction");
}
fn isStep(token: Token) bool {
    return switch (token.kind) {
        .name, .star, .dot, .dot2, .at => true,
        else => false,
    };
}
fn axisName(name: []const u8) ?Axis {
    inline for (std.meta.fieldNames(Axis), @typeInfo(Axis).@"enum".field_values) |field_name, field_value| {
        const converted = comptime blk: {
            var chars: [field_name.len]u8 = undefined;
            for (field_name, 0..) |c, i| chars[i] = if (c == '_') '-' else c;
            break :blk chars;
        };
        if (std.mem.eql(u8, name, &converted)) return @enumFromInt(field_value);
    }
    return null;
}
fn binaryOperator(token: Token) ?struct { op: Op, precedence: u8 } {
    return switch (token.kind) {
        .pipe => .{ .op = .union_op, .precedence = 7 },
        .star => .{ .op = .mul, .precedence = 5 },
        .plus => .{ .op = .add, .precedence = 4 },
        .minus => .{ .op = .sub, .precedence = 4 },
        .lt => .{ .op = .lt, .precedence = 3 },
        .le => .{ .op = .le, .precedence = 3 },
        .gt => .{ .op = .gt, .precedence = 3 },
        .ge => .{ .op = .ge, .precedence = 3 },
        .eq => .{ .op = .eq, .precedence = 2 },
        .ne => .{ .op = .ne, .precedence = 2 },
        .name => blk: {
            inline for (.{ .{ "or", Op.or_op, 0 }, .{ "and", Op.and_op, 1 }, .{ "div", Op.div, 5 }, .{ "mod", Op.mod, 5 } }) |entry| {
                if (std.mem.eql(u8, token.text, entry[0])) break :blk .{ .op = entry[1], .precedence = entry[2] };
            }
            break :blk null;
        },
        else => null,
    };
}
fn validArity(name: []const u8, count: usize) bool {
    inline for (.{
        .{ "last", 0, 0 },                        .{ "position", 0, 0 },      .{ "count", 1, 1 },         .{ "id", 1, 1 },
        .{ "local-name", 0, 1 },                  .{ "namespace-uri", 0, 1 }, .{ "name", 0, 1 },          .{ "string", 0, 1 },
        .{ "concat", 2, std.math.maxInt(usize) }, .{ "starts-with", 2, 2 },   .{ "contains", 2, 2 },      .{ "substring-before", 2, 2 },
        .{ "substring-after", 2, 2 },             .{ "substring", 2, 3 },     .{ "string-length", 0, 1 }, .{ "normalize-space", 0, 1 },
        .{ "translate", 3, 3 },                   .{ "boolean", 1, 1 },       .{ "not", 1, 1 },           .{ "true", 0, 0 },
        .{ "false", 0, 0 },                       .{ "lang", 1, 1 },          .{ "number", 0, 1 },        .{ "sum", 1, 1 },
        .{ "floor", 1, 1 },                       .{ "ceiling", 1, 1 },       .{ "round", 1, 1 },
    }) |entry| if (std.mem.eql(u8, name, entry[0])) return count >= entry[1] and count <= entry[2];
    return false;
}

const Evaluation = struct {
    /// Holds every value of this evaluation; freed when it ends.
    allocator: Allocator,
    /// Backs the scratch arenas predicate evaluations run in (see `filter`).
    backing: Allocator,

    fn evaluate(e: *Evaluation, expr: *const Expr, ctx: Context) anyerror!Value {
        return switch (expr.*) {
            .number => |value| .{ .number = value },
            .string => |value| .{ .string = value },
            // XPath §3.1 makes an unbound variable an evaluation error, and
            // there are no bindings here. Browser majority: WebKit and Blink
            // VariableReference::evaluate return "" for an unbound name (Blink
            // xpath_variable_reference.cc); Gecko's getVariable throws.
            .variable => .{ .string = "" },
            .unary => |operand| .{ .number = -try e.number(try e.evaluate(operand, ctx)) },
            .function => |call| try e.function(call.name, call.args, ctx),
            .filter => |selection| .{ .nodes = try e.filter(try nodeSet(try e.evaluate(selection.base, ctx)), selection.predicates) },
            .path => |location| .{ .nodes = try e.path(location.start, location.absolute, location.steps, ctx) },
            .binary => try e.operators(expr, ctx),
        };
    }

    /// XPath §2 location paths. Every node-set VALUE is in document order
    /// (§5), but the sets between steps need not be: a step's predicates count
    /// along each context node's own axis (§2.4), never through the merged set.
    /// So, as WebKit LocationPath::evaluate does, carry what is known of the
    /// set from step to step and put it in order once, at the end, only when
    /// it may be out of order.
    fn path(e: *Evaluation, start: ?*const Expr, absolute: bool, steps: []const Step, ctx: Context) anyerror![]const *Node {
        var nodes: []const *Node = undefined;
        var shape: Shape = .{ .sorted = true, .disjoint = true };
        if (start) |expr| {
            nodes = try nodeSet(try e.evaluate(expr, ctx));
            shape.disjoint = nodes.len < 2;
        } else nodes = try e.singleton(if (absolute) try root(ctx.node) else ctx.node);
        // One axis is live at a time: these buffers serve every context node.
        var candidates: std.ArrayListUnmanaged(*Node) = .empty;
        var selected: std.ArrayListUnmanaged(*Node) = .empty;
        var last: []*Node = &.{};
        for (steps) |step| {
            const next = shape.after(step.axis, nodes.len);
            var merged: NodeSetBuilder = .{ .dedup = next.repeats };
            // XPath §2.1: predicates apply to each context node's axis,
            // BEFORE merging results (//i[1] differs from (//i)[1]).
            for (nodes) |node| {
                candidates.clearRetainingCapacity();
                try e.axis(step.axis, node, &candidates);
                selected.clearRetainingCapacity();
                for (candidates.items) |candidate| if (try matches(candidate, step.axis, step.test_node)) {
                    try selected.append(e.allocator, candidate);
                };
                for (try e.filter(selected.items, step.predicates)) |item| try merged.add(e.allocator, item);
            }
            // One context node on a reverse axis gave reverse document order.
            if (next.reversed) std.mem.reverse(*Node, merged.list.items);
            last = merged.list.items;
            nodes = last;
            shape = next;
        }
        return if (shape.sorted) nodes else try e.documentOrder(last);
    }

    /// XPath §§3.3–3.5 binary operators. All are left-associative, so a chain
    /// of N of them (`1+1+…`) is a left-deep tree N levels high at nesting
    /// depth one: the parser's nesting limit does not bound it, and recursing
    /// on `left` overflowed the native stack at 200,000 terms (review M1).
    /// Walk the left spine iteratively and fold upward, innermost first. Each
    /// right operand was parsed one nesting level deeper (`expression(prec+1)`),
    /// so recursion through right operands stays within the nesting limit.
    fn operators(e: *Evaluation, top: *const Expr, ctx: Context) anyerror!Value {
        var spine: std.ArrayListUnmanaged(*const Expr) = .empty;
        var leftmost = top;
        while (leftmost.* == .binary) : (leftmost = leftmost.binary.left) try spine.append(e.allocator, leftmost);
        var value = try e.evaluate(leftmost, ctx);
        var index = spine.items.len;
        while (index != 0) {
            index -= 1;
            const operation = spine.items[index].binary;
            // A fresh result location: `value = switch` would let Zig write the
            // new union tag into `value` before an operand still reads it
            // (`.{ .boolean = compare(value, ...) }` saw a corrupted left side).
            const folded: Value = switch (operation.op) {
                // XPath §3.4: boolean operators short circuit.
                .or_op => if (boolean(value)) .{ .boolean = true } else .{ .boolean = boolean(try e.evaluate(operation.right, ctx)) },
                .and_op => if (!boolean(value)) .{ .boolean = false } else .{ .boolean = boolean(try e.evaluate(operation.right, ctx)) },
                .eq, .ne, .lt, .le, .gt, .ge => .{ .boolean = try e.compare(value, try e.evaluate(operation.right, ctx), operation.op) },
                .union_op => blk: {
                    // XPath §3.3: merge every operand of a run of unions, then
                    // order the result once. Each operand is in document order
                    // already, so only a mix of two or more needs ordering.
                    const right = try e.evaluate(operation.right, ctx);
                    var merged: NodeSetBuilder = .{};
                    var sources: usize = 0;
                    for ([_][]const *Node{ try nodeSet(value), try nodeSet(right) }) |operand| {
                        if (operand.len != 0) sources += 1;
                        for (operand) |node| try merged.add(e.allocator, node);
                    }
                    while (index != 0 and spine.items[index - 1].binary.op == .union_op) {
                        index -= 1;
                        const operand = try nodeSet(try e.evaluate(spine.items[index].binary.right, ctx));
                        if (operand.len != 0) sources += 1;
                        for (operand) |node| try merged.add(e.allocator, node);
                    }
                    break :blk .{ .nodes = if (sources > 1) try e.documentOrder(merged.list.items) else merged.list.items };
                },
                .add, .sub, .mul, .div, .mod => blk: {
                    const right = try e.evaluate(operation.right, ctx);
                    const a = try e.number(value);
                    const b = try e.number(right);
                    break :blk .{
                        .number = switch (operation.op) {
                            .add => a + b,
                            .sub => a - b,
                            .mul => a * b,
                            .div => a / b,
                            // XPath §3.5: remainder from TRUNCATING division.
                            .mod => if (b == 0 or std.math.isInf(a)) std.math.nan(f64) else if (std.math.isInf(b)) a else @rem(a, b),
                            else => unreachable,
                        },
                    };
                },
            };
            value = folded;
        }
        return value;
    }

    fn singleton(e: *Evaluation, node: *Node) ![]const *Node {
        return e.allocator.dupe(*Node, &.{node});
    }

    /// XPath §2.4 and §3.3 predicates: keep the nodes for which each predicate
    /// holds, counting positions in `input`'s order. A predicate's value is
    /// used at once, so it is evaluated in a scratch arena reset for every
    /// node: memory stays that of one predicate evaluation, not their sum
    /// (`//*[following::x]` would otherwise hold N axes of N nodes each).
    fn filter(e: *Evaluation, input: []const *Node, predicates: []const *const Expr) anyerror![]const *Node {
        if (predicates.len == 0) return input;
        var scratch = std.heap.ArenaAllocator.init(e.backing);
        defer scratch.deinit();
        var inner = Evaluation{ .allocator = scratch.allocator(), .backing = e.backing };
        var current = input;
        for (predicates) |predicate| {
            var selected: std.ArrayListUnmanaged(*Node) = .empty;
            for (current, 0..) |node, i| {
                _ = scratch.reset(.retain_capacity);
                const value = try inner.evaluate(predicate, .{ .node = node, .position = i + 1, .size = current.len });
                const accepted = switch (value) {
                    .number => |n| n == @as(f64, @floatFromInt(i + 1)),
                    else => boolean(value),
                };
                if (accepted) try selected.append(e.allocator, node);
            }
            current = selected.items;
        }
        return current;
    }

    /// Appends `node`'s axis (XPath §2.2) in axis order: document order for a
    /// forward axis, reverse document order for a reverse one.
    fn axis(e: *Evaluation, which: Axis, node: *Node, result: *std.ArrayListUnmanaged(*Node)) anyerror!void {
        const allocator = e.allocator;
        switch (which) {
            .self => try result.append(allocator, node),
            .parent => if (try parent(node)) |p| {
                try result.append(allocator, p);
            },
            .ancestor, .ancestor_or_self => {
                var cursor: ?*Node = if (which == .ancestor_or_self) node else try parent(node);
                while (cursor) |p| : (cursor = try parent(p)) try result.append(allocator, p);
            },
            .child => {
                var cursor = try interfaces.Node.get_firstChild(node);
                while (cursor) |child| : (cursor = try interfaces.Node.get_nextSibling(child)) try result.append(allocator, child);
            },
            .descendant, .descendant_or_self => {
                if (which == .descendant_or_self) try result.append(allocator, node);
                try descendants(allocator, node, result);
            },
            .following_sibling, .preceding_sibling => if (try nodeKind(node) != 2) {
                var cursor = if (which == .following_sibling) try interfaces.Node.get_nextSibling(node) else try interfaces.Node.get_previousSibling(node);
                while (cursor) |sibling| {
                    try result.append(allocator, sibling);
                    cursor = if (which == .following_sibling) try interfaces.Node.get_nextSibling(sibling) else try interfaces.Node.get_previousSibling(sibling);
                }
            },
            .following => {
                // Everything after the node except its descendants, walked
                // directly: the subtrees of the next siblings of the node and
                // of each ancestor. An attribute's following nodes begin with
                // its owner's children (WebKit XPathStep.cpp FollowingAxis).
                var anchor = node;
                if (try nodeKind(node) == 2) {
                    anchor = try interfaces.Attr.get_ownerElement(node) orelse return;
                    try descendants(allocator, anchor, result);
                }
                var cursor: ?*Node = anchor;
                while (cursor) |current| : (cursor = try interfaces.Node.get_parentNode(current)) {
                    var sibling = try interfaces.Node.get_nextSibling(current);
                    while (sibling) |next| : (sibling = try interfaces.Node.get_nextSibling(next)) {
                        try result.append(allocator, next);
                        try descendants(allocator, next, result);
                    }
                }
            },
            .preceding => {
                // Everything before the node except its ancestors, nearest
                // first: the subtrees of the previous siblings of the node and
                // of each ancestor, each reversed. An attribute's ancestors
                // include its owner (XPath §2.2; WebKit PrecedingAxis).
                var anchor = node;
                if (try nodeKind(node) == 2) anchor = try interfaces.Attr.get_ownerElement(node) orelse return;
                var cursor: ?*Node = anchor;
                while (cursor) |current| : (cursor = try interfaces.Node.get_parentNode(current)) {
                    var sibling = try interfaces.Node.get_previousSibling(current);
                    while (sibling) |previous| : (sibling = try interfaces.Node.get_previousSibling(previous)) {
                        const begin = result.items.len;
                        try result.append(allocator, previous);
                        try descendants(allocator, previous, result);
                        std.mem.reverse(*Node, result.items[begin..]);
                    }
                }
            },
            .attribute => if (try nodeKind(node) == 1) {
                const attributes = try interfaces.Element.get_attributes(node);
                const count = try interfaces.NamedNodeMap.get_length(attributes);
                for (0..count) |index| {
                    if (try interfaces.NamedNodeMap.call_item(attributes, @intCast(index))) |attr| {
                        if (!try namespaceIs(attr, 2, xmlns_namespace)) try result.append(allocator, attr);
                    }
                }
            },
            .namespace => {
                // Browser majority deviates from XPath §5.4: Blink xpath_step.cc
                // kNamespaceAxis and WebKit XPathStep.cpp NamespaceAxis return empty.
            },
        }
    }

    /// Puts `nodes` in XPath §5 document order without repeats, in place, and
    /// returns the ordered prefix. No pair of nodes is compared: every member's
    /// ancestors are marked, then each tree is walked once, entering only
    /// marked subtrees and starting below the chain of single marked children
    /// above the members' common ancestor. The cost is the members' ancestors
    /// plus the children of the marked nodes walked (WebKit
    /// NodeSet::traversalSort walks the whole tree; review M2).
    ///
    /// An element's attributes follow it, in attribute-list order (DOM
    /// compareDocumentPosition step 5.2 orders them so), and precede its
    /// children. Separate trees stay contiguous, ordered by root address: an
    /// order consistent for as long as the trees exist, which is what the DOM
    /// asks of disconnected nodes (compareDocumentPosition step 6).
    fn documentOrder(e: *Evaluation, nodes: []*Node) anyerror![]*Node {
        if (nodes.len < 2) return nodes;
        const Mark = struct {
            member: bool = false,
            emitted: bool = false,
            /// Some member is an attribute of this element.
            attributes: bool = false,
            /// Marked children: how many, how many the walk has entered, one of them.
            children: u32 = 0,
            entered: u32 = 0,
            child: ?*Node = null,
        };
        var marks: std.AutoHashMapUnmanaged(*Node, Mark) = .empty;
        var members: std.ArrayListUnmanaged(*Node) = .empty;
        var roots: std.ArrayListUnmanaged(*Node) = .empty;
        for (nodes) |node| {
            const entry = try marks.getOrPut(e.allocator, node);
            if (entry.found_existing) {
                // Marked before as an ancestor, or a repeat: its ancestors are marked.
                if (!entry.value_ptr.member) try members.append(e.allocator, node);
                entry.value_ptr.member = true;
                continue;
            }
            entry.value_ptr.* = .{ .member = true };
            try members.append(e.allocator, node);
            // Mark ancestors up to the first one already marked.
            var below = node;
            var attribute = try nodeKind(node) == 2;
            while (true) {
                const above_or_null = if (attribute) try interfaces.Attr.get_ownerElement(below) else try interfaces.Node.get_parentNode(below);
                const above = above_or_null orelse {
                    try roots.append(e.allocator, below);
                    break;
                };
                const above_entry = try marks.getOrPut(e.allocator, above);
                if (!above_entry.found_existing) above_entry.value_ptr.* = .{};
                if (attribute) above_entry.value_ptr.attributes = true else {
                    above_entry.value_ptr.children += 1;
                    above_entry.value_ptr.child = below;
                }
                if (above_entry.found_existing) break;
                below = above;
                attribute = false;
            }
        }
        std.mem.sort(*Node, roots.items, {}, addressLess);

        var count: usize = 0;
        for (roots.items) |tree_root| {
            var top = tree_root;
            while (marks.get(top)) |mark| {
                if (mark.member or mark.attributes or mark.children != 1) break;
                top = mark.child orelse break;
            }
            var cursor = top;
            walk: while (true) {
                const mark = marks.getPtr(cursor) orelse break;
                if (mark.member and !mark.emitted) {
                    mark.emitted = true;
                    nodes[count] = cursor;
                    count += 1;
                }
                if (mark.attributes) {
                    // Every member attribute exists already, so reading the
                    // list's existing Attr nodes makes none.
                    for (0..dom.element_attributes.count(cursor)) |i| {
                        const attr = dom.element_attributes.existingNodeAt(cursor, i) orelse continue;
                        const attr_mark = marks.getPtr(attr) orelse continue;
                        if (!attr_mark.member or attr_mark.emitted) continue;
                        attr_mark.emitted = true;
                        nodes[count] = attr;
                        count += 1;
                    }
                }
                // Into the first marked child...
                if (mark.children != 0) {
                    var child = try interfaces.Node.get_firstChild(cursor);
                    while (child) |candidate| : (child = try interfaces.Node.get_nextSibling(candidate)) {
                        if (!marks.contains(candidate)) continue;
                        mark.entered = 1;
                        cursor = candidate;
                        continue :walk;
                    }
                }
                // ...else on to the next marked sibling of it or of an ancestor.
                while (cursor != top) {
                    const up = try interfaces.Node.get_parentNode(cursor) orelse break :walk;
                    const up_mark = marks.getPtr(up) orelse break :walk;
                    if (up_mark.entered < up_mark.children) {
                        var sibling = try interfaces.Node.get_nextSibling(cursor);
                        while (sibling) |candidate| : (sibling = try interfaces.Node.get_nextSibling(candidate)) {
                            if (!marks.contains(candidate)) continue;
                            up_mark.entered += 1;
                            cursor = candidate;
                            continue :walk;
                        }
                    }
                    cursor = up;
                }
                break;
            }
        }
        // Unreachable while the trees are intact - no script runs during an
        // evaluation - but a member is never dropped.
        if (count != members.items.len) for (members.items) |node| {
            const mark = marks.getPtr(node) orelse continue;
            if (mark.emitted) continue;
            mark.emitted = true;
            nodes[count] = node;
            count += 1;
        };
        return nodes[0..count];
    }

    fn number(e: *Evaluation, value: Value) anyerror!f64 {
        return switch (value) {
            .number => |n| n,
            .boolean => |b| if (b) 1 else 0,
            else => parseNumber(try e.string(value)),
        };
    }
    fn string(e: *Evaluation, value: Value) anyerror![]const u8 {
        return switch (value) {
            .string => |s| s,
            .boolean => |b| if (b) "true" else "false",
            .nodes => |nodes| if (nodes.len == 0) "" else try e.nodeString(nodes[0]),
            .number => |n| blk: {
                if (std.math.isNan(n)) break :blk "NaN";
                if (std.math.isInf(n)) break :blk if (n < 0) "-Infinity" else "Infinity";
                if (n == 0) break :blk "0";
                break :blk try std.fmt.allocPrint(e.allocator, "{d}", .{n});
            },
        };
    }
    /// XPath §5 string-value: an element's, document's or fragment's is its
    /// text descendants' data in document order; any other node's its value.
    fn nodeString(e: *Evaluation, node: *Node) anyerror![]const u8 {
        switch (try nodeKind(node)) {
            1, 9, 11 => {
                var text: std.ArrayListUnmanaged(u8) = .empty;
                var walk = try Descendants.init(node);
                while (try walk.next()) |child| {
                    const child_type = try nodeKind(child);
                    if (child_type != 3 and child_type != 4) continue;
                    var value = (try interfaces.Node.get_nodeValue(child)) orelse continue;
                    defer value.deinit(child.ctx.allocator);
                    try text.appendSlice(e.allocator, value.asSlice());
                }
                return text.items;
            },
            else => return e.nodeValue(node),
        }
    }
    fn nodeValue(e: *Evaluation, node: *Node) ![]const u8 {
        var value = (try interfaces.Node.get_nodeValue(node)) orelse return "";
        defer value.deinit(node.ctx.allocator);
        return e.allocator.dupe(u8, value.asSlice());
    }
    /// Each node's string-value, computed once.
    fn nodeStrings(e: *Evaluation, nodes: []const *Node) anyerror![]const []const u8 {
        const strings = try e.allocator.alloc([]const u8, nodes.len);
        for (nodes, strings) |node, *text| text.* = try e.nodeString(node);
        return strings;
    }

    // XPath §3.4: node-set equality AND inequality are existential comparisons.
    fn compare(e: *Evaluation, left: Value, right: Value, op: Op) anyerror!bool {
        const equality = op == .eq or op == .ne;
        if (left == .nodes and right == .nodes) return e.compareNodeSets(left.nodes, right.nodes, op);
        if (left == .nodes or right == .nodes) {
            const nodes = if (left == .nodes) left.nodes else right.nodes;
            const scalar = if (left == .nodes) right else left;
            // XPath §3.4: against a boolean, a node-set converts with boolean()
            // for EVERY operator, < <= > >= included (WebKit EqTestOp::compare).
            if (scalar == .boolean) return compareNumber(if (boolean(left)) 1 else 0, if (boolean(right)) 1 else 0, op);
            for (nodes) |node| {
                const value = Value{ .string = try e.nodeString(node) };
                if (try e.compare(if (left == .nodes) value else scalar, if (left == .nodes) scalar else value, op)) return true;
            }
            return false;
        }
        if (equality and (left == .boolean or right == .boolean)) return compareNumber(if (boolean(left)) 1 else 0, if (boolean(right)) 1 else 0, op);
        if (equality and left == .string and right == .string) return std.mem.eql(u8, left.string, right.string) == (op == .eq);
        return compareNumber(try e.number(left), try e.number(right), op);
    }

    /// XPath §3.4 for two node-sets: true when SOME pair of nodes compares true
    /// on their string-values. Each string-value is computed once and no pair
    /// is enumerated: `=` probes a hash set of one side's strings, `!=` fails
    /// only when every string on both sides is the same one, and `<` `<=` `>`
    /// `>=` compare numbers, where some pair holds exactly when the extremes
    /// do (NaN compares false with everything, so it never contributes).
    fn compareNodeSets(e: *Evaluation, left: []const *Node, right: []const *Node, op: Op) anyerror!bool {
        if (left.len == 0 or right.len == 0) return false;
        const a = try e.nodeStrings(left);
        const b = try e.nodeStrings(right);
        switch (op) {
            .eq => {
                const small = if (a.len <= b.len) a else b;
                const large = if (a.len <= b.len) b else a;
                var set: std.StringHashMapUnmanaged(void) = .empty;
                for (small) |text| try set.put(e.allocator, text, {});
                for (large) |text| if (set.contains(text)) return true;
                return false;
            },
            .ne => {
                for (a) |text| if (!equal(text, a[0])) return true;
                for (b) |text| if (!equal(text, a[0])) return true;
                return false;
            },
            .lt, .le, .gt, .ge => {
                const lhs = numberRange(a) orelse return false;
                const rhs = numberRange(b) orelse return false;
                return switch (op) {
                    .lt => lhs.min < rhs.max,
                    .le => lhs.min <= rhs.max,
                    .gt => lhs.max > rhs.min,
                    .ge => lhs.max >= rhs.min,
                    else => unreachable,
                };
            },
            else => unreachable,
        }
    }

    fn function(e: *Evaluation, name: []const u8, expressions: []const *const Expr, ctx: Context) anyerror!Value {
        const args = try e.allocator.alloc(Value, expressions.len);
        for (expressions, args) |expr, *arg| arg.* = try e.evaluate(expr, ctx);
        if (equal(name, "last")) return .{ .number = @floatFromInt(ctx.size) };
        if (equal(name, "position")) return .{ .number = @floatFromInt(ctx.position) };
        if (equal(name, "count")) return .{ .number = @floatFromInt((try nodeSet(args[0])).len) };
        if (equal(name, "true")) return .{ .boolean = true };
        if (equal(name, "false")) return .{ .boolean = false };
        if (equal(name, "boolean")) return .{ .boolean = boolean(args[0]) };
        if (equal(name, "not")) return .{ .boolean = !boolean(args[0]) };
        const first = if (args.len != 0) args[0] else Value{ .nodes = try e.singleton(ctx.node) };
        if (equal(name, "number")) return .{ .number = try e.number(first) };
        if (equal(name, "string")) return .{ .string = try e.string(first) };
        if (equal(name, "floor")) return .{ .number = @floor(try e.number(first)) };
        if (equal(name, "ceiling")) return .{ .number = @ceil(try e.number(first)) };
        if (equal(name, "round")) return .{ .number = round(try e.number(first)) };
        if (equal(name, "sum")) {
            // Blink/WebKit FunSum returns zero for a scalar argument.
            if (first != .nodes) return .{ .number = 0 };
            var sum: f64 = 0;
            for (first.nodes) |node| sum += parseNumber(try e.nodeString(node));
            return .{ .number = sum };
        }
        if (equal(name, "name") or equal(name, "local-name") or equal(name, "namespace-uri")) {
            // Blink/WebKit name functions return empty for a scalar argument.
            if (first != .nodes) return .{ .string = "" };
            const nodes = first.nodes;
            if (nodes.len == 0) return .{ .string = "" };
            return .{ .string = if (equal(name, "namespace-uri")) try namespaceUri(e.allocator, nodes[0]) else try nodeName(e.allocator, nodes[0], equal(name, "local-name")) };
        }
        if (equal(name, "id")) {
            var result: NodeSetBuilder = .{};
            // XPath §4.1 id(): browsers use TreeScope (Document or ShadowRoot),
            // including when the context is detached; not the detached subtree.
            const ancestor_root = try root(ctx.node);
            const tree_root = if (ancestor_root.stateAs(interfaces.ShadowRoot.State) != null)
                ancestor_root
            else
                dom.live_collections.nodeDocument(ctx.node) orelse ancestor_root;
            if (first == .nodes) {
                for (first.nodes) |node| try e.ids(tree_root, try e.nodeString(node), &result);
            } else try e.ids(tree_root, try e.string(first), &result);
            return .{ .nodes = try e.documentOrder(result.list.items) };
        }
        if (equal(name, "lang")) {
            const language = try e.string(first);
            var cursor: ?*Node = ctx.node;
            // Blink/WebKit FunLang walks DOM parents: Attr has none, unlike its
            // XPath parent axis. XPath §4.3 alone would suggest its owner.
            while (cursor) |node| : (cursor = try interfaces.Node.get_parentNode(node)) {
                if (try nodeKind(node) != 1) continue;
                if (try interfaces.Element.call_getAttributeNS(node, runtime.DOMString.initInterned(xml_namespace), runtime.DOMString.initInterned("lang"))) |value_const| {
                    var value = value_const;
                    defer value.deinit(node.ctx.allocator);
                    const code = value.asSlice();
                    return .{ .boolean = code.len >= language.len and std.ascii.eqlIgnoreCase(code[0..language.len], language) and (code.len == language.len or code[language.len] == '-') };
                }
            }
            return .{ .boolean = false };
        }
        if (equal(name, "concat")) {
            var text: std.ArrayListUnmanaged(u8) = .empty;
            defer text.deinit(e.allocator);
            for (args) |arg| try infra.wtf8.appendJoined(e.allocator, &text, try e.string(arg));
            return .{ .string = try text.toOwnedSlice(e.allocator) };
        }
        const text = try e.string(first);
        // XPath §3.6 describes Unicode characters, but Blink/WebKit
        // XPathFunctions index UTF-16 units. Preserve split surrogates as WTF-8.
        if (equal(name, "string-length")) return .{ .number = @floatFromInt(infra.wtf8.codeUnitLength(text)) };
        if (equal(name, "normalize-space")) {
            var normalized = List(u8).init(e.allocator);
            defer normalized.deinit();
            var tokens = std.mem.tokenizeAny(u8, text, " \t\r\n");
            while (tokens.next()) |token| {
                if (normalized.len != 0) try normalized.append(' ');
                try normalized.appendSlice(token);
            }
            return .{ .string = try normalized.toOwnedSlice() };
        }
        if (equal(name, "substring")) {
            const units = try std.unicode.wtf8ToWtf16LeAlloc(e.allocator, text);
            const start = round(try e.number(args[1]));
            const end = start + if (args.len == 3) round(try e.number(args[2])) else std.math.inf(f64);
            var out = List(u16).init(e.allocator);
            defer out.deinit();
            for (units, 0..) |unit, i| {
                const position: f64 = @floatFromInt(i + 1);
                if (position >= start and position < end) try out.append(unit);
            }
            return .{ .string = try std.unicode.wtf16LeToWtf8Alloc(e.allocator, out.items()) };
        }
        const source = try std.unicode.wtf8ToWtf16LeAlloc(e.allocator, text);
        const second = try std.unicode.wtf8ToWtf16LeAlloc(e.allocator, try e.string(args[1]));
        if (equal(name, "starts-with")) return .{ .boolean = std.mem.startsWith(u16, source, second) };
        if (equal(name, "contains")) return .{ .boolean = std.mem.indexOf(u16, source, second) != null };
        if (equal(name, "substring-before") or equal(name, "substring-after")) {
            const index = std.mem.indexOf(u16, source, second) orelse return .{ .string = "" };
            const units = if (equal(name, "substring-before")) source[0..index] else source[index + second.len ..];
            return .{ .string = try std.unicode.wtf16LeToWtf8Alloc(e.allocator, units) };
        }
        if (equal(name, "translate")) {
            const to = try std.unicode.wtf8ToWtf16LeAlloc(e.allocator, try e.string(args[2]));
            var out = List(u16).init(e.allocator);
            defer out.deinit();
            for (source) |unit| {
                if (std.mem.indexOfScalar(u16, second, unit)) |index| {
                    if (index < to.len) try out.append(to[index]);
                } else try out.append(unit);
            }
            return .{ .string = try std.unicode.wtf16LeToWtf8Alloc(e.allocator, out.items()) };
        }
        unreachable; // Parser validates the entire core function library and arities.
    }

    fn ids(e: *Evaluation, tree_root: *Node, text: []const u8, result: *NodeSetBuilder) !void {
        var tokens = std.mem.tokenizeAny(u8, text, " \t\r\n");
        while (tokens.next()) |id| {
            if (try nodeKind(tree_root) == 9) {
                if (try interfaces.Document.call_getElementById(tree_root, runtime.DOMString.initInterned(id))) |element| try result.add(e.allocator, element);
            } else if (tree_root.stateAs(interfaces.ShadowRoot.State) != null) {
                if (try interfaces.DocumentFragment.call_getElementById(tree_root, runtime.DOMString.initInterned(id))) |element| try result.add(e.allocator, element);
            }
        }
    }
};

const html_namespace = "http://www.w3.org/1999/xhtml";
const xml_namespace = "http://www.w3.org/XML/1998/namespace";
const xmlns_namespace = "http://www.w3.org/2000/xmlns/";
fn equal(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
fn boolean(value: Value) bool {
    return switch (value) {
        .boolean => |b| b,
        .string => |s| s.len != 0,
        .nodes => |nodes| nodes.len != 0,
        .number => |n| n != 0 and !std.math.isNan(n),
    };
}
fn nodeSet(value: Value) ![]const *Node {
    return switch (value) {
        .nodes => |nodes| nodes,
        else => error.SyntaxError,
    };
}
fn nodeKind(node: *Node) !u16 {
    return interfaces.Node.get_nodeType(node);
}
fn parent(node: *Node) !?*Node {
    return if (try nodeKind(node) == 2) interfaces.Attr.get_ownerElement(node) else interfaces.Node.get_parentNode(node);
}
fn root(node: *Node) !*Node {
    var current = node;
    while (try parent(current)) |p| current = p;
    return current;
}
/// Preorder walk of a node's descendants, not the node itself. Iterative:
/// deeply nested trees consume no native call stack.
const Descendants = struct {
    top: *Node,
    pending: ?*Node,

    fn init(top: *Node) !Descendants {
        return .{ .top = top, .pending = try interfaces.Node.get_firstChild(top) };
    }
    fn next(walk: *Descendants) !?*Node {
        const current = walk.pending orelse return null;
        walk.pending = try interfaces.Node.get_firstChild(current);
        if (walk.pending == null) {
            var ancestor = current;
            while (ancestor != walk.top) {
                if (try interfaces.Node.get_nextSibling(ancestor)) |sibling| {
                    walk.pending = sibling;
                    break;
                }
                ancestor = try interfaces.Node.get_parentNode(ancestor) orelse break;
            }
        }
        return current;
    }
};
fn descendants(allocator: Allocator, node: *Node, result: *std.ArrayListUnmanaged(*Node)) !void {
    var walk = try Descendants.init(node);
    while (try walk.next()) |current| try result.append(allocator, current);
}

/// A node-set being merged: members in arrival order and, when one node may
/// arrive twice, a hash set, so an arrival costs O(1) rather than a scan of
/// the members (WebKit LocationPath::evaluate and Union::evaluate keep a
/// HashSet beside the vector; review M2).
const NodeSetBuilder = struct {
    list: std.ArrayListUnmanaged(*Node) = .empty,
    seen: std.AutoHashMapUnmanaged(*Node, void) = .empty,
    dedup: bool = true,

    fn add(builder: *NodeSetBuilder, allocator: Allocator, node: *Node) !void {
        if (builder.dedup and (try builder.seen.getOrPut(allocator, node)).found_existing) return;
        try builder.list.append(allocator, node);
    }
};

/// What is known of a node-set between location steps (WebKit tracks the same
/// as NodeSet::isSorted and subtreesAreDisjoint).
const Shape = struct {
    /// In document order.
    sorted: bool,
    /// No member is an ancestor of another; an Attr's parent is its owner.
    disjoint: bool,
    /// The step can reach one node from two context nodes: deduplicate.
    repeats: bool = false,
    /// One context node on a reverse axis: the step yields reverse document order.
    reversed: bool = false,

    /// The shape of what a step along `axis_kind` makes from `count` nodes of `set`'s shape.
    fn after(set: Shape, axis_kind: Axis, count: usize) Shape {
        if (count <= 1) return .{
            .sorted = true,
            .reversed = switch (axis_kind) {
                .ancestor, .ancestor_or_self, .preceding, .preceding_sibling => true,
                else => false,
            },
            .disjoint = switch (axis_kind) {
                .self, .parent, .child, .attribute, .namespace, .following_sibling, .preceding_sibling => true,
                else => false,
            },
        };
        return switch (axis_kind) {
            // One node has one parent and one owner: these never repeat a node.
            .self => .{ .sorted = set.sorted, .disjoint = set.disjoint },
            .child => .{ .sorted = set.sorted and set.disjoint, .disjoint = set.disjoint },
            // An element's attributes come right after it (XPath §5), so they
            // keep the order of their elements, nested or not.
            .attribute => .{ .sorted = set.sorted, .disjoint = true },
            .descendant, .descendant_or_self => .{ .sorted = set.sorted and set.disjoint, .disjoint = false, .repeats = !set.disjoint },
            else => .{ .sorted = false, .disjoint = false, .repeats = true },
        };
    }
};

/// XPath §2.3 node tests. Reads names in place: a step tests every node of its
/// axis, so a copy per candidate would grow the evaluation's memory with
/// every axis walked (`//*/following::*` walks N axes of up to N nodes).
fn matches(node: *Node, axis_kind: Axis, node_test: Test) anyerror!bool {
    const node_kind = try nodeKind(node);
    // XPath's node model has no DocumentType nodes.
    if (node_kind == 10) return false;
    return switch (node_test) {
        .any => true,
        .text => node_kind == 3 or node_kind == 4,
        .comment => node_kind == 8,
        // Blink/WebKit Step treat an empty PI target as unrestricted.
        .pi => |target| node_kind == 7 and (target == null or target.?.len == 0 or blk: {
            var name = try interfaces.ProcessingInstruction.get_target(node);
            defer name.deinit(node.ctx.allocator);
            break :blk std.mem.eql(u8, target.?, name.asSlice());
        }),
        .name => |name| try nameMatches(node, node_kind, axis_kind, name),
    };
}
fn nameMatches(node: *Node, node_kind: u16, axis_kind: Axis, name: NameTest) anyerror!bool {
    if (node_kind != (if (axis_kind == .attribute) @as(u16, 2) else @as(u16, 1))) return false;
    var ns_value = if (node_kind == 1) try interfaces.Element.get_namespaceURI(node) else try interfaces.Attr.get_namespaceURI(node);
    defer if (ns_value) |*value| value.deinit(node.ctx.allocator);
    const ns = if (ns_value) |value| value.asSlice() else "";
    // Browser Step matching also treats an empty wildcard namespace
    // as unrestricted, including one returned by a prefix resolver.
    if (name.wildcard) return name.namespace == null or name.namespace.?.len == 0 or std.mem.eql(u8, name.namespace.?, ns);
    var local_value = if (node_kind == 1) try interfaces.Element.get_localName(node) else try interfaces.Attr.get_localName(node);
    defer local_value.deinit(node.ctx.allocator);
    const local = local_value.asSlice();
    const doc = dom.live_collections.nodeDocument(node);
    const html_doc = if (doc) |document| dom.document_internals.getDocumentType(document) == .html else false;
    if (html_doc and node_kind == 1) {
        // Browser HTML integration, WebKit XPathStep.cpp nodeMatchesBasicTest.
        if (std.mem.eql(u8, ns, html_namespace))
            return std.ascii.eqlIgnoreCase(local, name.local) and (name.namespace == null or std.mem.eql(u8, name.namespace.?, ns));
        return name.namespace != null and std.mem.eql(u8, name.namespace.?, ns) and std.mem.eql(u8, local, name.local);
    }
    if (!std.mem.eql(u8, name.namespace orelse "", ns)) return false;
    if (html_doc and node_kind == 2 and name.namespace == null) {
        if (try interfaces.Attr.get_ownerElement(node)) |owner| {
            if (try namespaceIs(owner, 1, html_namespace)) return std.ascii.eqlIgnoreCase(local, name.local);
        }
    }
    return std.mem.eql(u8, local, name.local);
}
/// Whether an element's or attribute's namespace URI is `uri` ("" for none),
/// read in place.
fn namespaceIs(node: *Node, node_kind: u16, uri: []const u8) !bool {
    var ns = (if (node_kind == 1) try interfaces.Element.get_namespaceURI(node) else try interfaces.Attr.get_namespaceURI(node)) orelse return uri.len == 0;
    defer ns.deinit(node.ctx.allocator);
    return std.mem.eql(u8, ns.asSlice(), uri);
}
fn addressLess(_: void, a: *Node, b: *Node) bool {
    return @intFromPtr(a) < @intFromPtr(b);
}
const Range = struct { min: f64, max: f64 };
/// The least and greatest of the numbers `strings` convert to, NaN ignored;
/// null when every one is NaN.
fn numberRange(strings: []const []const u8) ?Range {
    var range: ?Range = null;
    for (strings) |text| {
        const n = parseNumber(text);
        if (std.math.isNan(n)) continue;
        if (range) |*r| {
            r.min = @min(r.min, n);
            r.max = @max(r.max, n);
        } else range = .{ .min = n, .max = n };
    }
    return range;
}
fn namespaceUri(allocator: Allocator, node: *Node) ![]const u8 {
    var ns = switch (try nodeKind(node)) {
        1 => try interfaces.Element.get_namespaceURI(node),
        2 => try interfaces.Attr.get_namespaceURI(node),
        else => null,
    } orelse return "";
    defer ns.deinit(node.ctx.allocator);
    return allocator.dupe(u8, ns.asSlice());
}
fn nodeName(allocator: Allocator, node: *Node, local: bool) ![]const u8 {
    const node_kind = try nodeKind(node);
    if (node_kind != 1 and node_kind != 2 and node_kind != 7) return "";
    var name = if (node_kind == 1) try interfaces.Element.get_localName(node) else if (node_kind == 2) try interfaces.Attr.get_localName(node) else try interfaces.ProcessingInstruction.get_target(node);
    defer name.deinit(node.ctx.allocator);
    if (local or node_kind == 7) return allocator.dupe(u8, name.asSlice());
    var prefix = if (node_kind == 1) try interfaces.Element.get_prefix(node) else try interfaces.Attr.get_prefix(node);
    defer if (prefix) |*value| value.deinit(node.ctx.allocator);
    if (prefix) |value| if (value.asSlice().len != 0) return std.fmt.allocPrint(allocator, "{s}:{s}", .{ value.asSlice(), name.asSlice() });
    return allocator.dupe(u8, name.asSlice());
}
fn parseNumber(input: []const u8) f64 {
    const text = std.mem.trim(u8, input, " \t\r\n");
    if (text.len == 0) return std.math.nan(f64);
    var i: usize = if (text[0] == '-') 1 else 0;
    var digits: usize = 0;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) digits += 1;
    if (i < text.len and text[i] == '.') {
        i += 1;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) digits += 1;
    }
    if (digits == 0 or i != text.len) return std.math.nan(f64);
    return std.fmt.parseFloat(f64, text) catch std.math.nan(f64);
}
fn round(n: f64) f64 {
    if (!std.math.isFinite(n) or n == 0) return n;
    if (n < 0 and n >= -0.5) return -0.0;
    const floor = @floor(n);
    return if (n - floor < 0.5) floor else floor + 1;
}
fn compareNumber(a: f64, b: f64, op: Op) bool {
    return switch (op) {
        .eq => a == b,
        .ne => a != b,
        .lt => a < b,
        .le => a <= b,
        .gt => a > b,
        .ge => a >= b,
        else => unreachable,
    };
}
