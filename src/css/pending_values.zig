//! Values 5 §9.2 and Appendix A: owned, token-preserving random-item()
//! substitution. The declaration's source survives; no resolver or DOM does.
//! WebKit StyleSubstitutionResolver supplies the selected-branch design.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const properties = @import("properties.zig");
const resources = @import("resource_values.zig");
const math = @import("math_values.zig");
const random = @import("random_values.zig");
const Allocator = std.mem.Allocator;
const Error = Allocator.Error || error{ Invalid, Unavailable };

const Node = struct {
    kind: tokens.TokenType,
    raw: []const u8,
    value: []const u8 = "",
    children: []const Node = &.{},
    close: ?u8 = null,
    item_index: ?usize = null,
};

const CapturedUrl = struct { raw: []const u8, resolved: ?[]const u8 };

pub const Pending = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    property: properties.Property,
    text: []const u8 = "",
    nodes: []const Node = &.{},
    quirks: bool,
    source: ?*resources.ResourceSource,
    urls: []const CapturedUrl = &.{},
    had_resolver: bool,

    pub fn create(options: properties.ParseOptions, property: properties.Property, text: []const u8) Allocator.Error!?*Pending {
        const self = try options.allocator.create(Pending);
        self.* = .{
            .allocator = options.allocator,
            .arena = std.heap.ArenaAllocator.init(options.allocator),
            .property = property,
            .quirks = options.quirks,
            .source = options.resource_source,
            .had_resolver = options.url_resolver != null,
        };
        if (self.source) |source| source.ref();
        var success = false;
        defer if (!success) self.unref();
        const arena = self.arena.allocator();
        self.text = try arena.dupe(u8, std.mem.trim(u8, text, " \n\r\t\x0c"));
        var parser = Parser{ .allocator = arena, .tokenizer = tokens.Tokenizer.init(self.text) };
        self.nodes = parser.sequence(null) catch |err| switch (err) {
            error.Invalid, error.Unavailable => return null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        // Capture possible URL strings while the original resolver is alive.
        // An image-set string can become a URL only AFTER substitution, so
        // capture strings too; none is exposed as a resource before selection.
        var captured: std.ArrayList(CapturedUrl) = .empty;
        var tokenizer = tokens.Tokenizer.init(self.text);
        while (true) {
            const token = tokenizer.next();
            if (token.token_type == .eof) break;
            const encoded = switch (token.token_type) {
                .url => token.value,
                .string => token.stringContents(),
                else => continue,
            };
            const raw = try tokens.decode(arena, encoded);
            const resolved = if (options.url_resolver) |resolver|
                resolver.resolve(resolver.context, arena, raw)
            else
                null;
            try captured.append(arena, .{ .raw = raw, .resolved = resolved });
        }
        self.urls = try captured.toOwnedSlice(arena);
        success = true;
        return self;
    }

    pub fn ref(self: *Pending) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Pending) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.source) |source| source.unref();
        const allocator = self.allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }
    pub fn eql(self: *const Pending, other: *const Pending) bool {
        return self == other or (std.meta.eql(self.property, other.property) and std.mem.eql(u8, self.text, other.text));
    }

    /// Q88's three outcomes are distinct: missing input skips a candidate;
    /// invalid substitution remains the winning declaration, as unset.
    pub fn resolve(self: *const Pending, allocator: Allocator, context: math.Context) Allocator.Error!Outcome {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        var resolver = Resolver{ .allocator = arena.allocator(), .context = context, .property = switch (self.property) {
            .longhand => |l| l.name(),
            .shorthand => |s| s.name(),
        } };
        const nodes = resolver.substitute(self.nodes, false) catch |err| switch (err) {
            error.Invalid => return .invalid,
            error.Unavailable => return .unavailable,
            error.OutOfMemory => return error.OutOfMemory,
        };
        const text = try render(arena.allocator(), nodes);
        var assignments: std.ArrayList(properties.Assignment) = .empty;
        errdefer {
            for (assignments.items) |a| a.value.release();
            assignments.deinit(allocator);
        }
        // The normal numeric ordinal scope is built here, AFTER selection.
        const options = properties.ParseOptions{
            .allocator = allocator,
            .quirks = self.quirks,
            .resource_source = self.source,
            .url_resolver = if (self.had_resolver) .{ .context = self, .resolve = capturedUrl } else null,
        };
        if (!try properties.parseDeclaration(options, self.property, text, &assignments)) {
            assignments.deinit(allocator);
            return .invalid;
        }
        return .{ .resolved = try assignments.toOwnedSlice(allocator) };
    }

    fn capturedUrl(raw_context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
        const self: *const Pending = @ptrCast(@alignCast(raw_context));
        for (self.urls) |entry| if (std.mem.eql(u8, raw, entry.raw)) {
            return allocator.dupe(u8, entry.resolved orelse return null) catch null;
        };
        return null;
    }
};

pub const Outcome = union(enum) {
    resolved: []properties.Assignment,
    unavailable,
    invalid,

    pub fn deinit(self: Outcome, allocator: Allocator) void {
        if (self == .resolved) {
            for (self.resolved) |a| a.value.release();
            allocator.free(self.resolved);
        }
    }
};

const Parser = struct {
    allocator: Allocator,
    tokenizer: tokens.Tokenizer,
    depth: usize = 0,
    count: usize = 0,
    item_index: usize = 0,

    fn sequence(self: *Parser, closing: ?tokens.TokenType) Error![]const Node {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > 128) return error.Invalid;
        var nodes: std.ArrayList(Node) = .empty;
        while (true) {
            const start = self.tokenizer.pos;
            const token = self.tokenizer.next();
            if (token.token_type == .eof) break; // Syntax 3 closes blocks at EOF.
            if (closing != null and token.token_type == closing.?) break;
            switch (token.token_type) {
                .right_paren, .right_bracket, .right_brace, .bad_string, .bad_url => return error.Invalid,
                else => {},
            }
            self.count += 1;
            if (self.count > 65536) return error.Invalid;
            var node = Node{ .kind = token.token_type, .raw = self.tokenizer.input[start..self.tokenizer.pos], .value = token.value };
            const close: ?tokens.TokenType = switch (token.token_type) {
                .function => blk: {
                    if (self.tokenizer.next().token_type != .left_paren) return error.Invalid;
                    node.raw = self.tokenizer.input[start..self.tokenizer.pos];
                    if (tokens.nameEql(token.value, "random-item")) {
                        self.item_index += 1;
                        node.item_index = self.item_index;
                    }
                    break :blk .right_paren;
                },
                .left_paren => .right_paren,
                .left_bracket => .right_bracket,
                .left_brace => .right_brace,
                else => null,
            };
            if (close) |end| {
                node.close = switch (end) {
                    .right_paren => ')',
                    .right_bracket => ']',
                    .right_brace => '}',
                    else => unreachable,
                };
                node.children = try self.sequence(end);
                if (node.item_index != null and !hasSpread(node.children)) _ = try arguments(self.allocator, node.children);
            }
            try nodes.append(self.allocator, node);
        }
        return nodes.toOwnedSlice(self.allocator);
    }
};

fn isSpace(node: Node) bool {
    return node.kind == .whitespace;
}
fn trim(nodes: []const Node) []const Node {
    var start: usize = 0;
    var end = nodes.len;
    while (start < end and isSpace(nodes[start])) start += 1;
    while (end > start and isSpace(nodes[end - 1])) end -= 1;
    return nodes[start..end];
}
fn spreadAt(nodes: []const Node, index: usize) bool {
    if (index < 3 or nodes[index].item_index == null) return false;
    for (nodes[index - 3 .. index]) |node| if (node.kind != .delim or !std.mem.eql(u8, node.raw, ".")) return false;
    // Comments and whitespace between tokens do not count as adjacency.
    for (index - 3..index) |i| if (@intFromPtr(nodes[i].raw.ptr) + nodes[i].raw.len != @intFromPtr(nodes[i + 1].raw.ptr)) return false;
    return true;
}
fn hasSpread(nodes: []const Node) bool {
    for (nodes, 0..) |node, index| {
        if (node.item_index != null) {
            if (spreadAt(nodes, index)) return true;
        } else if (hasSpread(node.children)) return true;
    }
    return false;
}

/// §3.1.1: a free-form argument is either one {} block or a sequence with
/// no top-level block. Its top-level ! and semicolon restrictions survive
/// unwrapping. Only the key argument must be nonempty at parse time.
fn unwrap(raw: []const Node) Error![]const Node {
    const nodes = trim(raw);
    const value = if (nodes.len == 1 and nodes[0].kind == .left_brace) nodes[0].children else nodes;
    for (value) |node| {
        if (node.kind == .semicolon or (node.kind == .delim and std.mem.eql(u8, node.value, "!"))) return error.Invalid;
        if (value.ptr == nodes.ptr) switch (node.kind) {
            .left_brace, .left_bracket, .left_paren => return error.Invalid,
            else => {},
        };
    }
    return trim(value);
}
fn arguments(allocator: Allocator, nodes: []const Node) Error![]const []const Node {
    var list: std.ArrayList([]const Node) = .empty;
    var start: usize = 0;
    for (nodes, 0..) |node, index| if (node.kind == .comma) {
        try list.append(allocator, try unwrap(nodes[start..index]));
        start = index + 1;
    };
    try list.append(allocator, try unwrap(nodes[start..]));
    if (list.items.len < 2 or list.items[0].len == 0) return error.Invalid;
    return list.toOwnedSlice(allocator);
}

const Resolver = struct {
    allocator: Allocator,
    context: math.Context,
    property: []const u8,
    early_numeric: usize = 0,
    depth: usize = 0,
    emitted: usize = 0,

    fn substitute(self: *Resolver, nodes: []const Node, early_only: bool) Error![]const Node {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > 128) return error.Invalid;
        var result: std.ArrayList(Node) = .empty;
        for (nodes, 0..) |node, index| {
            if (node.item_index != null) {
                const spread = early_only and spreadAt(nodes, index);
                if (early_only and !spread) {
                    try result.append(self.allocator, node);
                    continue;
                }
                if (spread) result.items.len -= 3;
                const chosen = try self.replace(node);
                // Appendix A: substitution is at token boundaries. A comment
                // stops an adjacent number and ident becoming one dimension.
                const barrier = Node{ .kind = .whitespace, .raw = "/**/" };
                try result.append(self.allocator, barrier);
                try result.appendSlice(self.allocator, chosen);
                try result.append(self.allocator, barrier);
            } else {
                var copy = node;
                if (node.close != null) copy.children = try self.substitute(node.children, early_only);
                try result.append(self.allocator, copy);
            }
            self.emitted += 1;
            if (self.emitted > 65536) return error.Invalid;
        }
        return result.toOwnedSlice(self.allocator);
    }

    fn replace(self: *Resolver, node: Node) Error![]const Node {
        // Appendix A substitution step 2.1 precedes the argument split.
        const early = try self.substitute(node.children, true);
        const args = try arguments(self.allocator, early);
        // §9.2 step 2: evaluate the key only; unused items remain untouched.
        const key_nodes = try self.substitute(args[0], false);
        const key_text = try render(self.allocator, key_nodes);
        var stream = properties.Stream.init(key_text);
        const first = stream.peek();
        const base = if (first.token_type == .ident and tokens.nameEql(first.value, "fixed")) blk: {
            _ = stream.next();
            var scope = try random.ParseScope.init(self.allocator, key_text, self.property, .{ .early = true, .numeric_offset = self.early_numeric });
            defer scope.deinit();
            for (scope.entries) |entry| if (entry.source.function == .numeric) {
                self.early_numeric += 1;
            };
            const number = try @import("numeric_values.zig").Number.consume(.{ .allocator = self.allocator, .random_scope = &scope }, &stream, .{ .kind = .number, .minimum = 0, .maximum = 1 }, false) orelse return error.Invalid;
            defer number.unref();
            if (!stream.atEnd()) return error.Invalid;
            if ((number.needsRandomBase() and self.context.random_base == null) or number.needsUnavailableMetrics(false)) return error.Unavailable;
            const computed = try number.compute(self.allocator, self.context);
            defer computed.unref();
            const scalar = computed.known() orelse return error.Unavailable;
            break :blk random.fixedBase(scalar.value);
        } else blk: {
            const key = try random.parseCacheKey(self.allocator, key_text, .{ .property = self.property, .index = node.item_index.?, .function = .item }) orelse return error.Invalid;
            defer key.deinit(self.allocator);
            const provider = self.context.random_base orelse return error.Unavailable;
            break :blk random.fixedBase(try provider.get(provider.context, key));
        };
        // §§9.2 step 3, 9.3: equal-width [0,1) buckets, then resolve ONLY
        // the chosen item. An empty item is a real option, not a missing one.
        const count = args.len - 1;
        const selected = @min(count - 1, @as(usize, @intFromFloat(@floor(base * @as(f64, @floatFromInt(count))))));
        return self.substitute(args[selected + 1], false);
    }
};

fn render(allocator: Allocator, nodes: []const Node) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try appendNodes(allocator, nodes, &out);
    return out.toOwnedSlice(allocator);
}
fn appendNodes(allocator: Allocator, nodes: []const Node, out: *std.ArrayList(u8)) Allocator.Error!void {
    for (nodes) |node| {
        try out.appendSlice(allocator, node.raw);
        if (node.close) |close| {
            try appendNodes(allocator, node.children, out);
            try out.append(allocator, close);
        }
    }
}
