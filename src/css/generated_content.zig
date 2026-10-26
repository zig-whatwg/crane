//! CSS Content 3 sections 1-2, CSS Lists 3 4.7 and Counter Styles 3 4.
//! Immutable typed content. Strings and raw-string attr() are resolved;
//! counters, quotes, images and leaders remain distinct from textual output.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const css_serialize = @import("serialize.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const properties = @import("properties.zig");
const random_values = @import("random_values.zig");
const Allocator = std.mem.Allocator;
const Token = tokenizer.Token;

pub const AttributeLookup = struct {
    context: *const anyopaque,
    get: *const fn (*const anyopaque, []const u8) ?[]const u8,
};

pub const UrlResolver = resources.UrlResolver;

pub const Kind = enum { text, attribute, counter, quote, image, leader, contents, target, substitution };
pub const Item = struct {
    kind: Kind,
    /// Text for strings, attribute name for attr(), serialization otherwise.
    text: []const u8,
    explicit_raw: bool = false,
    fallback: ?[]const u8 = null,
    /// Owned by the containing Content, with ranges relative to item.text.
    resource_urls: []const resources.ResourceUrl = &.{},
    /// Owned typed image, retained independently of the Content arena.
    /// Raw legacy images remain null until their complete grammar exists.
    image: ?values.Value = null,
};

pub const Content = struct {
    /// UA sheets are shared between threads. Unlike their immortal
    /// SharedText values, Content owns a typed arena; use atomic references
    /// so declaration copies do not mutate an ordinary shared counter.
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    items: []const Item = &.{},
    alternate: ?usize = null,
    serialization: []const u8 = "",
    /// Borrowed copies of the items' occurrences, offset into serialization.
    resource_urls: []const resources.ResourceUrl = &.{},

    fn create(allocator: Allocator) !*Content {
        const result = try allocator.create(Content);
        result.* = .{ .allocator = allocator, .arena = .init(allocator) };
        return result;
    }

    pub fn ref(self: *Content) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Content) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        for (self.items) |item| {
            resources.releaseAll(self.arena.allocator(), item.resource_urls);
            if (item.image) |image| image.release();
        }
        self.arena.deinit();
        allocator.destroy(self);
    }

    pub fn eql(self: *const Content, other: *const Content) bool {
        if (self == other) return true;
        if (!std.mem.eql(u8, self.serialization, other.serialization) or self.items.len != other.items.len) return false;
        // Images4 §2.4: omitted resolution and explicit 1x serialize alike,
        // but have different natural-resolution behavior.
        for (self.items, other.items) |a, b| {
            if (a.image) |image| {
                if (b.image == null or !image.eql(b.image.?)) return false;
            } else if (b.image != null) return false;
        }
        return true;
    }

    pub fn needsUnavailableMetrics(self: *const Content, geometry_length: bool) bool {
        for (self.items) |item| if (item.image) |image| {
            if (image.needsUnavailableMetrics(geometry_length)) return true;
        };
        return false;
    }

    pub fn needsTreeCounts(self: *const Content) bool {
        for (self.items) |item| if (item.image) |image| {
            if (image.needsTreeCounts()) return true;
        };
        return false;
    }

    pub fn needsRandomBase(self: *const Content) bool {
        for (self.items) |item| if (item.image) |image| {
            if (image.needsRandomBase()) return true;
        };
        return false;
    }

    /// CSS Values 5 8.7.1: substitution against the originating element,
    /// before inheritance. The lookup is never saved in a computed value.
    pub fn compute(self: *Content, allocator: Allocator, lookup: ?AttributeLookup) Allocator.Error!?*Content {
        var has_attribute = false;
        for (self.items) |item| if (item.kind == .attribute) {
            has_attribute = true;
            break;
        };
        if (!has_attribute) {
            self.ref();
            return self;
        }
        const result = try create(allocator);
        errdefer result.unref();
        const a = result.arena.allocator();
        const items = try a.alloc(Item, self.items.len);
        for (self.items, items, 0..) |item, *copy, i| {
            copy.* = item;
            copy.resource_urls = &.{};
            if (copy.image) |image| image.retain();
            // Publish only initialized slots so every error path can unref.
            result.items = items[0 .. i + 1];
            const text = if (item.kind == .attribute) blk: {
                const value = if (lookup) |l| l.get(l.context, item.text) else null;
                // Values 5 8.7: only the omitted type has an implicit empty
                // string fallback. An explicit type defaults to invalid.
                if (value == null and item.explicit_raw and item.fallback == null) {
                    result.unref();
                    return null;
                }
                copy.kind = .text;
                copy.fallback = null;
                copy.explicit_raw = false;
                break :blk value orelse item.fallback orelse "";
            } else item.text;
            copy.text = try a.dupe(u8, text);
            if (copy.fallback) |f| copy.fallback = try a.dupe(u8, f);
            copy.resource_urls = try resources.cloneAll(a, item.resource_urls, 0);
        }
        result.items = items;
        result.alternate = self.alternate;
        try result.serialize();
        return result;
    }

    /// Color5 §7 and Images4 §2.4: compute images before inheritance.
    /// Existing image text and occurrence ranges remain usable by loaders.
    pub fn computeImages(self: *Content, allocator: Allocator, context: anytype) Allocator.Error!*Content {
        var needs_computation = false;
        for (self.items) |item| if (item.image) |image| {
            if (image == .image) {
                needs_computation = true;
                break;
            }
        };
        if (!needs_computation) {
            self.ref();
            return self;
        }
        const result = try create(allocator);
        errdefer result.unref();
        const a = result.arena.allocator();
        const items = try a.alloc(Item, self.items.len);
        for (self.items, items, 0..) |item, *copy, i| {
            copy.* = item;
            copy.image = null;
            copy.resource_urls = &.{};
            result.items = items[0 .. i + 1];
            if (item.image) |image| {
                const computed = try context.component(.list_style_image, image);
                copy.image = computed;
                var out: std.ArrayList(u8) = .empty;
                try properties.serializeValue(.list_style_image, computed, &out, a);
                copy.text = out.items;
                copy.resource_urls = try resources.cloneAll(a, computed.resourceUrls(), 0);
            } else {
                copy.text = try a.dupe(u8, item.text);
                copy.resource_urls = try resources.cloneAll(a, item.resource_urls, 0);
            }
            if (item.fallback) |fallback| copy.fallback = try a.dupe(u8, fallback);
        }
        result.alternate = self.alternate;
        try result.serialize();
        return result;
    }

    /// Content 3 1.2: an alternative replaces the visual sequence, even
    /// when empty. Unresolved layout values never become invented text.
    pub fn appendAccessible(self: *const Content, out: *std.ArrayList(u8), allocator: Allocator) !void {
        const start = self.alternate orelse 0;
        for (self.items[start..]) |item| if (item.kind == .text) try out.appendSlice(allocator, item.text);
    }

    fn serialize(self: *Content) !void {
        const a = self.arena.allocator();
        var out: std.ArrayList(u8) = .empty;
        var urls: std.ArrayList(resources.ResourceUrl) = .empty;
        for (self.items, 0..) |item, i| {
            if (i > 0) try out.appendSlice(a, if (self.alternate == i) " / " else " ");
            for (item.resource_urls) |url| {
                var occurrence = url;
                occurrence.range.start += out.items.len;
                occurrence.range.end += out.items.len;
                if (occurrence.argument_range) |*argument| {
                    argument.start += out.items.len;
                    argument.end += out.items.len;
                }
                try urls.append(a, occurrence);
            }
            switch (item.kind) {
                .text => try values.appendString(item.text, &out, a),
                .attribute => {
                    try out.appendSlice(a, "attr(");
                    try out.appendSlice(a, try css_serialize.serializeIdentifier(a, item.text));
                    if (item.explicit_raw) try out.appendSlice(a, " raw-string");
                    if (item.fallback) |fallback| {
                        try out.appendSlice(a, ", ");
                        try values.appendString(fallback, &out, a);
                    }
                    try out.append(a, ')');
                },
                else => try out.appendSlice(a, item.text),
            }
        }
        self.serialization = out.items;
        self.resource_urls = urls.items;
    }
};

/// Parse a content-list (normal and none are handled by the property).
pub fn parse(allocator: Allocator, text: []const u8, resolver: ?UrlResolver) !?*Content {
    return parseWithSource(allocator, text, resolver, null);
}

pub fn parseWithSource(allocator: Allocator, text: []const u8, resolver: ?UrlResolver, source: ?*resources.ResourceSource) !?*Content {
    return parseWithSourceAndScope(allocator, text, resolver, source, null);
}

/// Values 5 §9.4.1: borrow the declaration's original token ordinals while
/// parsing. Text must be from the scope's original buffer; parsed keys own
/// their strings, and neither Content nor its images retain the scope.
pub fn parseWithSourceAndScope(allocator: Allocator, text: []const u8, resolver: ?UrlResolver, source: ?*resources.ResourceSource, scope: ?*const random_values.ParseScope) !?*Content {
    const result = try Content.create(allocator);
    var success = false;
    defer if (!success) result.unref();
    var parser: Parser = .{ .allocator = result.arena.allocator(), .backing_allocator = allocator, .tok = .init(text), .input = text, .resolver = resolver, .source = source, .random_scope = scope };
    var items: std.ArrayList(Item) = .empty;
    while (parser.peek().token_type != .eof) {
        const token = parser.peek();
        if (token.token_type == .delim and std.mem.eql(u8, token.value, "/")) {
            if (items.items.len == 0 or result.alternate != null) return null;
            result.alternate = items.items.len;
            _ = parser.next();
            continue;
        }
        const item = (try parser.item()) orelse return null;
        var item_kept = false;
        defer if (!item_kept) {
            resources.releaseAll(parser.allocator, item.resource_urls);
            if (item.image) |image| image.release();
        };
        if (result.alternate != null and item.kind != .text and item.kind != .attribute and item.kind != .counter and item.kind != .substitution) return null;
        try items.append(parser.allocator, item);
        result.items = items.items;
        item_kept = true;
    }
    if (items.items.len == 0 or result.alternate == items.items.len) return null;
    result.items = items.items;
    try result.serialize();
    success = true;
    return result;
}

const Parser = struct {
    allocator: Allocator,
    backing_allocator: Allocator,
    tok: tokenizer.Tokenizer,
    input: []const u8,
    peeked: ?Token = null,
    resolver: ?UrlResolver,
    source: ?*resources.ResourceSource,
    /// Borrowed only for this parse; retries use the same immutable scope.
    random_scope: ?*const random_values.ParseScope,

    fn peek(self: *Parser) Token {
        if (self.peeked) |token| return token;
        while (true) {
            const token = self.tok.next();
            if (token.token_type == .whitespace) continue;
            self.peeked = token;
            return token;
        }
    }

    fn next(self: *Parser) Token {
        const token = self.peek();
        self.peeked = null;
        return token;
    }

    fn take(self: *Parser, kind: tokenizer.TokenType) bool {
        if (self.peek().token_type != kind) return false;
        _ = self.next();
        return true;
    }

    /// CSS Syntax 3 5.5.10: EOF terminates each still-open function.
    fn closeFunction(self: *Parser) bool {
        return self.take(.right_paren) or self.peek().token_type == .eof;
    }

    fn ident(self: *Parser, token: Token) ![]const u8 {
        return tokenizer.decode(self.allocator, token.value);
    }

    fn string(self: *Parser, token: Token) ![]const u8 {
        return tokenizer.decode(self.allocator, token.stringContents());
    }

    fn item(self: *Parser) Allocator.Error!?Item {
        const token = self.next();
        if (token.token_type == .string) return .{ .kind = .text, .text = try self.string(token) };
        if (token.token_type == .url) return try self.url(try self.ident(token));
        if (token.token_type == .ident) {
            const name = try self.ident(token);
            inline for (.{ "open-quote", "close-quote", "no-open-quote", "no-close-quote" }) |quote| if (std.ascii.eqlIgnoreCase(name, quote)) return .{ .kind = .quote, .text = quote };
            if (std.ascii.eqlIgnoreCase(name, "contents")) return .{ .kind = .contents, .text = "contents" };
            inline for (.{ "disc", "circle", "square", "disclosure-open", "disclosure-closed" }) |glyph| if (std.ascii.eqlIgnoreCase(name, glyph)) return .{ .kind = .counter, .text = glyph };
            return null;
        }
        if (token.token_type != .function or !self.take(.left_paren)) return null;
        const name = try self.ident(token);
        if (std.ascii.eqlIgnoreCase(name, "attr")) return self.attribute(token);
        if (std.ascii.eqlIgnoreCase(name, "counter")) return self.counter(false);
        if (std.ascii.eqlIgnoreCase(name, "counters")) return self.counter(true);
        if (std.ascii.eqlIgnoreCase(name, "url") or std.ascii.eqlIgnoreCase(name, "src")) {
            const value = self.next();
            if (value.token_type != .string or !self.closeFunction()) return null;
            return try self.url(try self.string(value));
        }
        // Images4 §2.5 / Q168: sole-color image() uses the owned image bridge.
        // Q232: other image() forms keep their existing Syntax3 EOF grammar.
        if (std.ascii.eqlIgnoreCase(name, "image")) return self.solidColorImage(token);
        inline for (.{ "image-set", "-webkit-image-set", "light-dark", "-webkit-cross-fade", "linear-gradient", "radial-gradient", "conic-gradient", "repeating-linear-gradient", "repeating-radial-gradient", "repeating-conic-gradient" }) |image| if (std.ascii.eqlIgnoreCase(name, image)) return self.typedImage(token);
        // Q76/Q115: standard gradients now share the typed EOF grammar.
        // Unrelated raw functions retain their original Syntax handling.
        inline for (.{ "cross-fade", "element", "paint" }) |image| if (std.ascii.eqlIgnoreCase(name, image)) return self.remainingFunction(token, .image);
        if (std.ascii.eqlIgnoreCase(name, "leader")) {
            const value = self.next();
            if (value.token_type != .string and !(value.token_type == .ident and (tokenizer.nameEql(value.value, "dotted") or tokenizer.nameEql(value.value, "solid") or tokenizer.nameEql(value.value, "space")))) return null;
            const explicit_end = self.peek().token_type == .right_paren;
            if (!self.closeFunction()) return null;
            const raw = self.input[@intFromPtr(token.value.ptr) - @intFromPtr(self.input.ptr) .. self.tok.pos];
            return .{ .kind = .leader, .text = if (explicit_end) try self.allocator.dupe(u8, raw) else try std.mem.concat(self.allocator, u8, &.{ raw, ")" }) };
        }
        inline for (.{ "target-counter", "target-counters", "target-text", "string", "content" }) |target| if (std.ascii.eqlIgnoreCase(name, target)) return self.remainingFunction(token, .target);
        return null;
    }

    fn url(self: *Parser, raw: []const u8) !Item {
        return self.imageItem(try properties.urlValue(self.imageOptions(), raw));
    }

    fn imageOptions(self: *const Parser) properties.ParseOptions {
        return .{ .allocator = self.backing_allocator, .url_resolver = self.resolver, .resource_source = self.source, .random_scope = self.random_scope };
    }

    /// Takes ownership even on failure; the value never lives in our arena.
    fn imageItem(self: *Parser, image: values.Value) Allocator.Error!Item {
        errdefer image.release();
        var out: std.ArrayList(u8) = .empty;
        try properties.serializeValue(.list_style_image, image, &out, self.allocator);
        return .{ .kind = .image, .text = out.items, .resource_urls = try resources.cloneAll(self.allocator, image.resourceUrls(), 0), .image = image };
    }

    fn typedImage(self: *Parser, start: Token) Allocator.Error!?Item {
        var stream = properties.Stream{ .tok = self.tok, .text = self.input };
        stream.tok.pos = @intFromPtr(start.value.ptr) - @intFromPtr(self.input.ptr);
        stream.tok.line = start.line;
        stream.tok.column = start.column;
        const image = try @import("image_values.zig").parse(self.imageOptions(), &stream, .{}) orelse return null;
        self.tok = stream.tok;
        self.peeked = stream.peeked;
        return try self.imageItem(image);
    }

    fn solidColorImage(self: *Parser, start: Token) Allocator.Error!?Item {
        var stream = properties.Stream{ .tok = self.tok, .text = self.input };
        stream.tok.pos = @intFromPtr(start.value.ptr) - @intFromPtr(self.input.ptr);
        stream.tok.line = start.line;
        stream.tok.column = start.column;
        // Leave our post-'(' state intact on a non-match, so the legacy path
        // parses once and preserves its empty-body guard and EOF closure.
        const image = try @import("image_values.zig").parseSolidColor(self.imageOptions(), &stream) orelse
            return self.remainingFunction(start, .image);
        self.tok = stream.tok;
        self.peeked = stream.peeked;
        return try self.imageItem(image);
    }

    fn serializedItem(self: *Parser, kind: Kind, text: []const u8) !Item {
        return .{ .kind = kind, .text = text, .resource_urls = try resources.collect(self.allocator, text, self.resolver, self.source) };
    }

    fn remainingFunction(self: *Parser, start: Token, kind: Kind) !?Item {
        var depth: usize = 1;
        var any = kind == .substitution;
        while (depth > 0) {
            const token = self.next();
            switch (token.token_type) {
                .eof => {
                    if (!any) return null;
                    const begin = @intFromPtr(start.value.ptr) - @intFromPtr(self.input.ptr);
                    var closed: std.ArrayList(u8) = .empty;
                    try closed.appendSlice(self.allocator, self.input[begin..self.tok.pos]);
                    try closed.appendNTimes(self.allocator, ')', depth);
                    return try self.serializedItem(kind, closed.items);
                },
                .bad_string, .bad_url, .semicolon, .left_brace, .right_brace => return null,
                .left_paren => depth += 1,
                .right_paren => depth -= 1,
                else => any = true,
            }
        }
        if (!any) return null;
        const begin = @intFromPtr(start.value.ptr) - @intFromPtr(self.input.ptr);
        return try self.serializedItem(kind, try self.allocator.dupe(u8, self.input[begin..self.tok.pos]));
    }

    fn attribute(self: *Parser, start: Token) !?Item {
        const body = self.*;
        const name = self.next();
        if (name.token_type != .ident) return null;
        var item_value: Item = .{ .kind = .attribute, .text = try self.ident(name) };
        if (self.peek().token_type == .ident and tokenizer.nameEql(self.peek().value, "raw-string")) {
            _ = self.next();
            item_value.explicit_raw = true;
        }
        if (self.take(.comma)) {
            const fallback = self.next();
            if (fallback.token_type != .string) {
                self.* = body;
                return self.remainingFunction(start, .substitution);
            }
            item_value.fallback = try self.string(fallback);
        }
        if (self.closeFunction()) return item_value;
        // Typed, namespaced or general substitution forms need the generic
        // Values 5 substitution engine; preserve them as such, not as text.
        self.* = body;
        return self.remainingFunction(start, .substitution);
    }

    fn counter(self: *Parser, plural: bool) !?Item {
        const name_token = self.next();
        if (name_token.token_type != .ident) return null;
        const name = try self.ident(name_token);
        if (values.CssWide.parse(name) != null or std.ascii.eqlIgnoreCase(name, "none") or std.ascii.eqlIgnoreCase(name, "default")) return null;
        var out: std.ArrayList(u8) = .empty;
        var urls = resources.Builder{ .allocator = self.allocator };
        defer urls.deinit();
        try out.appendSlice(self.allocator, if (plural) "counters(" else "counter(");
        try out.appendSlice(self.allocator, try css_serialize.serializeIdentifier(self.allocator, name));
        if (plural) {
            if (!self.take(.comma)) return null;
            const separator = self.next();
            if (separator.token_type != .string) return null;
            try out.appendSlice(self.allocator, ", ");
            try values.appendString(try self.string(separator), &out, self.allocator);
        }
        if (self.take(.comma)) {
            const counter_style = self.next();
            if (counter_style.token_type == .ident) {
                const style_name = try self.ident(counter_style);
                if (values.CssWide.parse(style_name) != null or std.ascii.eqlIgnoreCase(style_name, "default")) return null;
                if (!std.ascii.eqlIgnoreCase(style_name, "decimal")) {
                    try out.appendSlice(self.allocator, ", ");
                    try out.appendSlice(self.allocator, try css_serialize.serializeIdentifier(self.allocator, style_name));
                }
            } else if (counter_style.token_type == .function and tokenizer.nameEql(counter_style.value, "symbols")) {
                const symbol_list = (try self.symbols()) orelse return null;
                defer resources.releaseAll(self.allocator, symbol_list.resource_urls);
                try out.appendSlice(self.allocator, ", ");
                try urls.append(symbol_list.resource_urls, out.items.len);
                try out.appendSlice(self.allocator, symbol_list.text);
            } else return null;
        }
        if (!self.closeFunction()) return null;
        try out.append(self.allocator, ')');
        return .{ .kind = .counter, .text = out.items, .resource_urls = try urls.take() };
    }

    fn symbols(self: *Parser) Allocator.Error!?Item {
        if (!self.take(.left_paren)) return null;
        var system: []const u8 = "symbolic";
        if (self.peek().token_type == .ident) {
            const token = self.next();
            const decoded = try self.ident(token);
            var valid = false;
            inline for (.{ "cyclic", "numeric", "alphabetic", "symbolic", "fixed" }) |s| if (std.ascii.eqlIgnoreCase(decoded, s)) {
                system = s;
                valid = true;
            };
            if (!valid) return null;
        }
        var out: std.ArrayList(u8) = .empty;
        var urls = resources.Builder{ .allocator = self.allocator };
        defer urls.deinit();
        try out.appendSlice(self.allocator, "symbols(");
        if (!std.mem.eql(u8, system, "symbolic")) {
            try out.appendSlice(self.allocator, system);
            try out.append(self.allocator, ' ');
        }
        var count: usize = 0;
        while (!self.closeFunction()) {
            const symbol = (try self.item()) orelse return null;
            defer resources.releaseAll(self.allocator, symbol.resource_urls);
            defer if (symbol.image) |image| image.release();
            if (symbol.kind != .text and symbol.kind != .image) return null;
            if (count > 0) try out.append(self.allocator, ' ');
            try urls.append(symbol.resource_urls, out.items.len);
            if (symbol.kind == .text) try values.appendString(symbol.text, &out, self.allocator) else try out.appendSlice(self.allocator, symbol.text);
            count += 1;
        }
        if (count == 0 or (count < 2 and (std.mem.eql(u8, system, "numeric") or std.mem.eql(u8, system, "alphabetic")))) return null;
        try out.append(self.allocator, ')');
        return .{ .kind = .counter, .text = out.items, .resource_urls = try urls.take() };
    }
};
