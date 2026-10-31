//! CSS Values 5 §8.7: attr-specific names, primitive types and conversion.
//! The shared substitution engine owns argument evaluation, cycle contexts
//! and taint propagation. Attribute lookup belongs to its originating-element
//! host; this module delegates all substitution to the shared resolver.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const math = @import("math_values.zig");
const values = @import("style_values.zig");
const Range = @import("resource_values.zig").ResourceUrl.Range;
const Allocator = std.mem.Allocator;

pub const Name = struct {
    /// Decoded stylesheet prefix. null means the null namespace, whether the
    /// source was `name` or `|name`; the default namespace never applies.
    namespace_prefix: ?[]const u8,
    /// Preserve case: attribute-selector matching rules belong to the host.
    local_name: []const u8,

    pub fn deinit(self: Name, allocator: Allocator) void {
        if (self.namespace_prefix) |prefix| allocator.free(prefix);
        allocator.free(self.local_name);
    }
};

/// §8.7 <attr-name>: no whitespace between its components. Tokenization
/// removes comments, but an escape's terminating whitespace is part of its
/// ident token. The returned names are owned; invalid input allocates nothing.
pub fn parseName(allocator: Allocator, text: []const u8) Allocator.Error!?Name {
    var stream = tokenizer.Tokenizer.init(text);
    stream.skipWhitespace();
    const first = stream.next();
    var prefix: ?[]const u8 = null;
    var local: []const u8 = undefined;
    if (isBar(first)) {
        const name = stream.next();
        if (name.token_type != .ident) return null;
        local = name.value;
    } else if (first.token_type == .ident) {
        if (isBar(stream.peek())) {
            _ = stream.next();
            const name = stream.next();
            if (name.token_type != .ident) return null;
            prefix = first.value;
            local = name.value;
        } else local = first.value;
    } else return null;
    stream.skipWhitespace();
    if (stream.next().token_type != .eof) return null;

    const decoded_prefix = if (prefix) |raw| try tokenizer.decode(allocator, raw) else null;
    errdefer if (decoded_prefix) |p| allocator.free(p);
    const decoded_local = try tokenizer.decode(allocator, local);
    return .{ .namespace_prefix = decoded_prefix, .local_name = decoded_local };
}

fn isBar(token: tokenizer.Token) bool {
    return token.token_type == .delim and std.mem.eql(u8, token.value, "|");
}

/// The non-type() forms of <attr-type>. Unknown custom-ident units parse
/// successfully and fail conversion, so a future unit can use a fallback.
pub const SimpleType = union(enum) {
    omitted,
    raw_string,
    number,
    unit: math.Unit,
    unknown_unit,
};

/// A helper for the simple forms, not the attr() argument-grammar parser.
/// type(<syntax>) is parsed by the shared syntax-definition implementation.
pub fn parseSimpleType(text: []const u8) ?SimpleType {
    var stream = tokenizer.Tokenizer.init(text);
    stream.skipWhitespace();
    const token = stream.next();
    if (token.token_type == .eof) return .omitted;
    stream.skipWhitespace();
    if (stream.next().token_type != .eof) return null;
    if (token.token_type == .delim and std.mem.eql(u8, token.value, "%")) return .{ .unit = .percent };
    if (token.token_type != .ident) return null;
    if (tokenizer.nameEql(token.value, "raw-string")) return .raw_string;
    if (tokenizer.nameEql(token.value, "number")) return .number;
    // Values 4 <custom-ident> excludes the CSS-wide and default keywords.
    if (tokenizer.nameEql(token.value, "default")) return null;
    inline for (@typeInfo(values.CssWide).@"enum".field_values) |field_value| {
        const wide: values.CssWide = @enumFromInt(field_value);
        if (tokenizer.nameEql(token.value, wide.name())) return null;
    }
    if (math.Unit.parse(token.value)) |unit| {
        // Chrome 155 and Firefox 158 both fall back for resolution units.
        // Golden rule 2, row 122 Q2: these behave like unknown units.
        if (unit.base() != .resolution) return .{ .unit = unit };
    }
    return .unknown_unit;
}

/// §8.7.1 steps 4–5, for an attribute that exists. Return owned CSS tokens,
/// or null for conversion failure. Literal strings bypass CSS tokenization;
/// primitive numeric forms never invoke arbitrary substitution functions.
pub fn convertSimple(allocator: Allocator, kind: SimpleType, attribute: []const u8) Allocator.Error!?[]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    switch (kind) {
        .omitted, .raw_string => try values.appendString(attribute, &out, allocator),
        .unknown_unit => return null,
        .number, .unit => {
            var stream = tokenizer.Tokenizer.init(attribute);
            stream.skipWhitespace();
            const token = stream.next();
            if (token.token_type != .number) return null;
            stream.skipWhitespace();
            if (stream.next().token_type != .eof) return null;
            // Values 4 §5.1: clamp overflow to the engine's finite range,
            // matching numeric_values.Number.compute before serialization.
            const number = std.math.clamp(token.numeric_value.?, -std.math.floatMax(f64), std.math.floatMax(f64));
            try values.appendNumber(number, &out, allocator);
            if (kind == .unit) try out.appendSlice(allocator, kind.unit.name());
        },
    }
    return try out.toOwnedSlice(allocator);
}

pub const Fallback = union(enum) {
    empty_string,
    invalid,
    /// Borrowed, unevaluated fallback, including an explicit empty sequence.
    substitute: []const u8,
};

/// §8.7.1 FAILURE steps 1–3. Only the shared engine evaluates a selected
/// fallback; a failure never treats an empty fallback as an absent one.
pub fn fallbackFor(type_omitted: bool, fallback: ?[]const u8) Fallback {
    if (fallback) |text| return .{ .substitute = text };
    return if (type_omitted) .empty_string else .invalid;
}

/// §8.7.2: reject taint used as or in a URL component, including image-set
/// strings. Both ranges refer to the same substituted declaration text,
/// before a consumer serializes it. The shared engine propagates function
/// and substitution taint; neighboring untainted URLs remain valid.
pub fn urlIsTainted(url: Range, tainted_ranges: []const Range) bool {
    if (url.start >= url.end) return false;
    for (tainted_ranges) |taint| {
        if (taint.start < taint.end and url.start < taint.end and taint.start < url.end) return true;
    }
    return false;
}

const substitution = @import("substitution.zig");
const syntax = @import("syntax_definitions.zig");
const Node = substitution.Node;
const Error = substitution.Error;

const Header = struct {
    name: Name,
    kind: union(enum) { simple: SimpleType, typed: syntax.Definition },

    fn deinit(self: *Header, allocator: Allocator) void {
        self.name.deinit(allocator);
        if (self.kind == .typed) self.kind.typed.deinit();
    }

    fn omitted(self: *const Header) bool {
        return self.kind == .simple and self.kind.simple == .omitted;
    }
};

/// §8.7 and §3.3.1: parse the name and optional type after substitution.
/// Components of the qualified name are adjacent; comments are trivia.
fn header(allocator: Allocator, raw: []const Node) Error!Header {
    const nodes = substitution.trim(raw);
    if (nodes.len == 0) return error.Invalid;
    const name_end: usize = if (bar(nodes[0])) blk: {
        if (nodes.len < 2 or nodes[1].kind != .ident) return error.Invalid;
        break :blk 2;
    } else if (nodes[0].kind == .ident) blk: {
        if (nodes.len > 1 and bar(nodes[1])) {
            if (nodes.len < 3 or nodes[2].kind != .ident) return error.Invalid;
            break :blk 3;
        }
        break :blk 1;
    } else return error.Invalid;
    const name_text = try substitution.render(allocator, nodes[0..name_end]);
    const name = try parseName(allocator, name_text.text) orelse return error.Invalid;
    errdefer name.deinit(allocator);
    const type_nodes = substitution.trim(nodes[name_end..]);
    if (type_nodes.len == 0) return .{ .name = name, .kind = .{ .simple = .omitted } };
    if (type_nodes.len != 1) return error.Invalid;
    const type_node = type_nodes[0];
    if (type_node.kind == .function and tokenizer.nameEql(type_node.value, "type")) {
        const contents = substitution.trim(type_node.children);
        var definition = if (contents.len == 1 and contents[0].kind == .string) blk: {
            var stream = tokenizer.Tokenizer.init(contents[0].raw);
            const token = stream.next();
            const decoded = try tokenizer.decode(allocator, token.stringContents());
            defer allocator.free(decoded);
            break :blk syntax.parse(allocator, decoded) catch |err| switch (err) {
                error.InvalidSyntax => return error.Invalid,
                error.OutOfMemory => return error.OutOfMemory,
            };
        } else blk: {
            const text = try substitution.render(allocator, contents);
            var stream = tokenizer.Tokenizer.init(text.text);
            break :blk syntax.parseTokens(allocator, &stream) catch |err| switch (err) {
                error.InvalidSyntax => return error.Invalid,
                error.OutOfMemory => return error.OutOfMemory,
            };
        };
        errdefer definition.deinit();
        for (definition.components) |component| {
            if (component.name == .data_type and component.name.data_type == .url) return error.Invalid;
        }
        return .{ .name = name, .kind = .{ .typed = definition } };
    }
    if (type_node.kind != .ident and !(type_node.kind == .delim and std.mem.eql(u8, type_node.value, "%"))) return error.Invalid;
    const text = try substitution.render(allocator, type_nodes);
    // Q2 browser majority: a CSS-wide/default type selects the fallback,
    // like an unknown unit; it does not discard the declaration at parse time.
    return .{ .name = name, .kind = .{ .simple = parseSimpleType(text.text) orelse .unknown_unit } };
}

fn bar(node: Node) bool {
    return node.kind == .delim and std.mem.eql(u8, node.value, "|");
}

/// The argument callback only splits direct commas; shared freeForm strips
/// a syntactic {} wrapper exactly once. Q30/Q31 apply the newer spec, per
/// tmp/analysis/integrator-probes-1025r/RULINGS.md: strict attr fallback makes
/// attr(x, Arial, sans-serif) invalid; use attr(x, {Arial, sans-serif}).
/// Revisit on an engine decline, standards objection or contrary WPT.
/// Spread stays in the shared engine's early pass.
pub fn arguments(allocator: Allocator, contents: []const Node, phase: substitution.Phase) Error![]const []const Node {
    var comma: ?usize = null;
    for (contents, 0..) |node, i| if (node.kind == .comma) {
        if (comma != null) return error.Invalid;
        comma = i;
    };
    const first = try substitution.freeForm(contents[0 .. comma orelse contents.len]);
    if (first.len == 0) return error.Invalid;
    if (phase == .parse) {
        const rendered = try substitution.render(allocator, first);
        // Q18/Q22: only known substitution functions defer validation, at
        // any depth. The shared detector handles case and CSS escapes.
        if (!substitution.mentionsFunction(rendered.text)) {
            var parsed = try header(allocator, first);
            parsed.deinit(allocator);
        }
    }
    const args = try allocator.alloc([]const Node, if (comma != null) 2 else 1);
    args[0] = first;
    if (comma) |i| args[1] = try substitution.freeForm(contents[i + 1 ..]);
    return args;
}

/// §8.7.1: substitute the header, read the selected attribute, convert it,
/// then (only on failure) substitute the fallback. §8.7.2 taints all output,
/// including an empty direct replacement; stored values keep token ranges.
pub fn replace(resolver: *substitution.Resolver, _: Node, args: []const []const Node) Error!substitution.Replacement {
    var omitted = false;
    if (resolver.substituteWithTaint(args[0], false)) |first| {
        if (header(resolver.allocator, first.nodes)) |parsed_header| {
            var parsed = parsed_header;
            defer parsed.deinit(resolver.allocator);
            omitted = parsed.omitted();
            if (resolver.host.attribute) |lookup| {
                if (lookup(resolver.host.context, resolver.host.tree_scope, resolver.namespaces, parsed.name.namespace_prefix, parsed.name.local_name)) |attribute| {
                    if (try guardedValue(resolver, &parsed, attribute)) |nodes| return .{ .nodes = nodes, .tainted = true };
                }
            }
        } else |err| switch (err) {
            error.Invalid => {},
            else => return err,
        }
    } else |err| switch (err) {
        error.Invalid => {},
        else => return err,
    }
    // FAILURE: the attribute guard has already ended. Never guard a missing
    // name, or a fallback reading an attribute whose conversion failed.
    if (args.len == 2) {
        const fallback = try resolver.substituteWithTaint(args[1], false);
        return .{ .nodes = fallback.nodes, .tainted = true };
    }
    if (omitted) return .{ .nodes = try substitution.parse(resolver.allocator, "\"\""), .tainted = true };
    return error.Invalid;
}

fn guardedValue(resolver: *substitution.Resolver, parsed: *const Header, attribute: substitution.Attribute) Error!?[]const Node {
    const host = resolver.host;
    const ns = attribute.namespace orelse "";
    // Q25: the expanded name AND the actual originating element identify a
    // dependency. Length-prefix the namespace so names cannot alias it.
    const key = try std.fmt.allocPrint(resolver.allocator, "{x}:{d}:{s}:{s}", .{ attribute.origin, ns.len, ns, attribute.local_name });
    const repeated = if (host.would_cycle) |query| query(host.context, .attribute, key) else false;
    // Q24 browser ruling: guard EVERY successful lookup, before conversion.
    // See tmp/analysis/integrator-probes-1025q/RULINGS.md. Guard even a repeat
    // to mark intervening property contexts cyclic; query before pushing it.
    const token = if (host.guard) |guard| try guard(host.context, .attribute, key) else null;
    var active = token != null;
    defer if (active) if (host.unguard) |unguard| {
        _ = unguard(host.context, token.?);
    };
    if (repeated) return error.Invalid;
    const result = convertedValue(resolver, parsed, attribute.value) catch |err| switch (err) {
        error.Invalid => null,
        else => return err,
    };
    const cyclic = if (token) |t| (if (host.unguard) |unguard| unguard(host.context, t) else false) else false;
    active = false;
    return if (cyclic) null else result;
}

fn convertedValue(resolver: *substitution.Resolver, parsed: *const Header, attribute: []const u8) Error!?[]const Node {
    const allocator = resolver.allocator;
    switch (parsed.kind) {
        .simple => |kind| {
            const text = try convertSimple(allocator, kind, attribute) orelse return null;
            return try substitution.parse(allocator, text);
        },
        .typed => |*definition| {
            // Step 6: only type() tokenizes and substitutes the attribute.
            const nodes = try substitution.parse(allocator, attribute);
            const replaced = try resolver.substituteWithTaint(nodes, false);
            const text = try substitution.render(allocator, replaced.nodes);
            var value = try definition.parseValue(.{ .allocator = allocator }, text.text) orelse return null;
            defer value.deinit();
            // Keep specified values (e.g. em, currentcolor) for the consuming
            // property's computation; registered-property computation differs.
            var serialized: std.ArrayList(u8) = .empty;
            try value.serialize(&serialized, allocator);
            return try substitution.parse(allocator, serialized.items);
        },
    }
}
