//! A CSS style sheet as the style engine holds it (CSSOM 6.1 "CSS style
//! sheet": its owner node, title, alternate and disabled flags, media,
//! location and origin-clean flag), and its rules compiled for matching.
//!
//! Blink's split: a CSSStyleSheet holds the sheet's state over a
//! StyleSheetContents, whose rules a RuleSet indexes. Here the state is a
//! `SheetRecord`, owned by what the sheet is associated with - the style or
//! link element (HTML "create a CSS style sheet"), or the UA - and the
//! parsed rules are its `Contents`, made the first time the cascade needs
//! them: a page that never reads style never parses its sheets beyond the
//! @import scan its loads already do (design section 5.4). The sheet keeps
//! its text, base URL and parser mode from its creation for that parse.
//!
//! Compiling (CSS Cascade 5 section 5 "Filtering", CSS Conditional 3): a
//! style rule whose selector list does not parse is dropped; each complex
//! selector becomes one `RuleData` with its specificity, its declarations,
//! its layer and its chain of @media conditions. @supports is decided at
//! parse time. @import rules are kept with their media; the sheets they
//! fetch are attached as `imports` by the loader.
//!
//! Stated deviations: @container (it needs layout), @scope and
//! @starting-style rules are skipped; a sheet whose @namespace declares the
//! HTML namespace as default matches only HTML elements, the approximation
//! the HTML UA sheet needs (every rule of it is in that namespace), and a
//! prefixed namespace makes its selectors invalid as before.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-style-sheets
//! Spec: https://drafts.csswg.org/css-cascade-5/#filtering
//! Spec: https://drafts.csswg.org/css-conditional-3/#processing

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const css = @import("css");
const selector = @import("selector");

const DeclarationBlock = css.declarations.DeclarationBlock;
const MediaQueryList = css.media_queries.MediaQueryList;
const MediaValues = css.media_queries.MediaValues;

const html_namespace = "http://www.w3.org/1999/xhtml";

/// What a sheet is parsed with, captured when it is created.
pub const ParseMode = struct {
    quirks: bool = false,
};

/// Resolves a url() in the sheet against its base URL; supplied by the
/// engine, which can parse URLs.
pub const UrlResolver = css.properties.UrlResolver;

pub const SheetRecord = struct {
    allocator: Allocator,
    /// CSSOM "owner node": the element the sheet is associated with, a raw
    /// back link (the element owns this record).
    owner_node: ?*runtime.Instance = null,
    /// CSSOM "title", "alternate flag", "disabled flag".
    title: []u8 = &.{},
    alternate: bool = false,
    disabled: bool = false,
    /// CSSOM "media", as text; parsed when first evaluated.
    media_text: []u8 = &.{},
    media: ?MediaQueryList = null,
    media_parsed: bool = false,
    /// The sheet's base URL ("style sheet base URL"): its location, or the
    /// node document's base URL when it has none.
    base_url: []u8 = &.{},
    /// CSSOM "origin-clean flag".
    origin_clean: bool = true,
    mode: ParseMode = .{},
    /// The text, until it is parsed.
    text: ?[]u8 = null,
    contents: ?*Contents = null,
    /// The sheets the @import rules fetched, by the rule's index among the
    /// sheet's @import rules; null until fetched (or never: a failure).
    imports: std.ArrayList(?*SheetRecord) = .empty,
    /// Moves whenever the rules change (an import arriving; CSSOM edits
    /// later): the engine compares it with what it built from.
    contents_version: u64 = 0,

    pub const Options = struct {
        owner_node: ?*runtime.Instance = null,
        title: []const u8 = "",
        alternate: bool = false,
        media: []const u8 = "",
        base_url: []const u8 = "",
        origin_clean: bool = true,
        mode: ParseMode = .{},
    };

    /// HTML "create a CSS style sheet" with `text` as its contents.
    pub fn create(allocator: Allocator, text: []const u8, options: Options) Allocator.Error!*SheetRecord {
        const self = try allocator.create(SheetRecord);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .owner_node = options.owner_node, .alternate = options.alternate, .origin_clean = options.origin_clean, .mode = options.mode };
        errdefer self.freeStrings();
        self.title = try allocator.dupe(u8, options.title);
        self.media_text = try allocator.dupe(u8, options.media);
        self.base_url = try allocator.dupe(u8, options.base_url);
        self.text = try allocator.dupe(u8, text);
        return self;
    }

    fn freeStrings(self: *SheetRecord) void {
        self.allocator.free(self.title);
        self.allocator.free(self.media_text);
        self.allocator.free(self.base_url);
        if (self.text) |t| self.allocator.free(t);
        self.text = null;
    }

    /// The sheet is removed ("remove a CSS style sheet") and its owner
    /// lets it go: its imports go with it.
    pub fn destroy(self: *SheetRecord) void {
        for (self.imports.items) |child| if (child) |c| c.destroy();
        self.imports.deinit(self.allocator);
        if (self.contents) |c| c.destroy();
        if (self.media) |*m| m.deinit();
        self.freeStrings();
        self.allocator.destroy(self);
    }

    /// The media changed (the owner's media attribute).
    pub fn setMedia(self: *SheetRecord, text: []const u8) Allocator.Error!void {
        const copy = try self.allocator.dupe(u8, text);
        self.allocator.free(self.media_text);
        self.media_text = copy;
        if (self.media) |*m| m.deinit();
        self.media = null;
        self.media_parsed = false;
    }

    /// Whether the sheet's media matches (an empty media list matches).
    pub fn mediaMatches(self: *SheetRecord, values: *const MediaValues) bool {
        if (!self.media_parsed) {
            self.media_parsed = true;
            if (std.mem.trim(u8, self.media_text, " \t\n\r\x0c").len != 0) {
                self.media = MediaQueryList.parse(self.allocator, self.media_text) catch null;
            }
        }
        const media = self.media orelse return true;
        return media.matches(values);
    }

    /// The sheet's rules, parsed and compiled on first use.
    pub fn contentsOf(self: *SheetRecord, resolver: ?UrlResolver) Allocator.Error!*Contents {
        if (self.contents) |c| return c;
        const text = self.text orelse "";
        const contents = try Contents.parse(self.allocator, text, .{ .quirks = self.mode.quirks, .url_resolver = resolver });
        self.contents = contents;
        if (self.text) |t| self.allocator.free(t);
        self.text = null;
        return contents;
    }

    /// The import at `index` was fetched: `child` is its sheet (taken).
    pub fn attachImport(self: *SheetRecord, index: usize, child: *SheetRecord) Allocator.Error!void {
        errdefer child.destroy();
        while (self.imports.items.len <= index) try self.imports.append(self.allocator, null);
        if (self.imports.items[index]) |old| old.destroy();
        self.imports.items[index] = child;
        self.contents_version +%= 1;
    }

    /// The import reached by `path` (indices of @import rules, outermost
    /// first), or null.
    pub fn importAt(self: *SheetRecord, path: []const u16) ?*SheetRecord {
        var record: *SheetRecord = self;
        for (path) |index| {
            if (index >= record.imports.items.len) return null;
            record = record.imports.items[index] orelse return null;
        }
        return record;
    }
};

/// One style rule's selectors and declarations, kept at a stable address.
pub const StyleRule = struct {
    /// The selector's text, owned: the parsed selectors' names are slices
    /// of it (selector.parse decodes only escaped tokens), so it lives as
    /// long as they do.
    prelude: []u8,
    selectors: selector.SelectorList,
    block: DeclarationBlock,
};

/// One complex selector of a style rule: what the cascade matches.
pub const RuleData = struct {
    complex: *const selector.ComplexSelector,
    specificity: css.cascade.Specificity,
    block: *const DeclarationBlock,
    /// The rule's position among the sheet's rules (order of appearance).
    position: u32,
    /// The rule's layer, an index into `Contents.layers`; null unlayered.
    layer: ?u16,
    /// The innermost @media condition around the rule, an index into
    /// `Contents.conditions`; null for none.
    condition: ?u32,
    /// The pseudo-element the subject compound names, if any.
    pseudo: ?[]const u8,
};

pub const Condition = struct {
    media: MediaQueryList,
    parent: ?u32,
};

/// An @import rule.
pub const ImportRule = struct {
    media: ?MediaQueryList,
    /// The rule's layer (`layer` / `layer(name)`), an index into `layers`.
    layer: ?u16,
};

pub const Contents = struct {
    allocator: Allocator,
    style_rules: std.ArrayList(*StyleRule) = .empty,
    rules: std.ArrayList(RuleData) = .empty,
    conditions: std.ArrayList(Condition) = .empty,
    /// The sheet's layer names, as dotted paths (anonymous layers get a
    /// name no author can write), in order of first declaration.
    layers: std.ArrayList([]u8) = .empty,
    imports: std.ArrayList(ImportRule) = .empty,
    /// The sheet's default namespace is HTML's: it matches HTML elements
    /// only (stated in the file comment).
    html_only: bool = false,
    buckets: Buckets,

    pub const Buckets = struct {
        id: std.StringHashMapUnmanaged(std.ArrayList(u32)) = .empty,
        class: std.StringHashMapUnmanaged(std.ArrayList(u32)) = .empty,
        tag: std.StringHashMapUnmanaged(std.ArrayList(u32)) = .empty,
        attribute: std.StringHashMapUnmanaged(std.ArrayList(u32)) = .empty,
        universal: std.ArrayList(u32) = .empty,
        pseudo: std.ArrayList(u32) = .empty,

        fn deinit(self: *Buckets, allocator: Allocator) void {
            inline for (.{ &self.id, &self.class, &self.tag, &self.attribute }) |map| {
                var it = map.valueIterator();
                while (it.next()) |list| list.deinit(allocator);
                map.deinit(allocator);
            }
            self.universal.deinit(allocator);
            self.pseudo.deinit(allocator);
        }
    };

    pub fn parse(allocator: Allocator, text: []const u8, options: struct { quirks: bool = false, url_resolver: ?UrlResolver = null }) Allocator.Error!*Contents {
        const self = try allocator.create(Contents);
        self.* = .{ .allocator = allocator, .buckets = .{} };
        errdefer self.destroy();
        var parsed = try css.rules.parseStyleSheetContents(allocator, text);
        defer parsed.deinit();
        var compiler: Compiler = .{ .contents = self, .options = .{ .allocator = allocator, .quirks = options.quirks, .url_resolver = options.url_resolver } };
        try compiler.ruleList(parsed.items, null, null, true);
        return self;
    }

    pub fn destroy(self: *Contents) void {
        const a = self.allocator;
        for (self.style_rules.items) |rule| {
            rule.selectors.deinit();
            rule.block.deinit();
            a.free(rule.prelude);
            a.destroy(rule);
        }
        self.style_rules.deinit(a);
        self.rules.deinit(a);
        for (self.conditions.items) |*c| c.media.deinit();
        self.conditions.deinit(a);
        for (self.layers.items) |name| a.free(name);
        self.layers.deinit(a);
        for (self.imports.items) |*i| if (i.media) |*m| m.deinit();
        self.imports.deinit(a);
        self.buckets.deinit(a);
        a.destroy(self);
    }

    /// Whether the condition chain ending at `condition` holds.
    pub fn conditionHolds(self: *const Contents, condition: ?u32, values: *const MediaValues) bool {
        var current = condition;
        while (current) |index| {
            const c = &self.conditions.items[index];
            if (!c.media.matches(values)) return false;
            current = c.parent;
        }
        return true;
    }

    /// The rules that can match an element with these id, classes, local
    /// name and attribute names (Blink's RuleSet buckets: a rule is filed
    /// under the most selective simple selector of its subject compound).
    /// In quirks mode ids and classes match case-insensitively, so every id
    /// and class rule is a candidate.
    pub fn collectCandidates(self: *const Contents, element: ElementKeys, pseudo: bool, quirks: bool, out: *std.ArrayList(u32), allocator: Allocator) Allocator.Error!void {
        if (pseudo) return out.appendSlice(allocator, self.buckets.pseudo.items);
        try out.appendSlice(allocator, self.buckets.universal.items);
        if (quirks) {
            inline for (.{ &self.buckets.id, &self.buckets.class }) |map| {
                var it = map.valueIterator();
                while (it.next()) |list| try out.appendSlice(allocator, list.items);
            }
        } else {
            if (element.id.len != 0) if (self.buckets.id.get(element.id)) |list| try out.appendSlice(allocator, list.items);
            var classes = std.mem.tokenizeAny(u8, element.class_name, " \t\n\r\x0c");
            while (classes.next()) |class| {
                if (self.buckets.class.get(class)) |list| try out.appendSlice(allocator, list.items);
            }
        }
        if (self.buckets.tag.get(element.local_name_lower)) |list| try out.appendSlice(allocator, list.items);
        for (element.attribute_names) |name| {
            if (self.buckets.attribute.get(name)) |list| try out.appendSlice(allocator, list.items);
        }
    }
};

/// What the buckets key on, of one element.
pub const ElementKeys = struct {
    id: []const u8,
    class_name: []const u8,
    local_name_lower: []const u8,
    /// Lowercased attribute local names.
    attribute_names: []const []const u8,
};

const Compiler = struct {
    contents: *Contents,
    options: css.properties.ParseOptions,
    position: u32 = 0,
    anonymous_layers: u32 = 0,

    /// Compile a list of rules. `imports_allowed`: still at the sheet's
    /// start, where @import may stand (after @charset and @layer
    /// statements only).
    fn ruleList(self: *Compiler, items: []const css.rules.Rule, condition: ?u32, layer: ?u16, top: bool) Allocator.Error!void {
        var imports_allowed = top;
        for (items) |*rule| {
            switch (rule.kind) {
                .qualified => {
                    imports_allowed = false;
                    try self.styleRule(rule, condition, layer);
                },
                .at_rule => {
                    const name = rule.name;
                    if (std.mem.eql(u8, name, "import")) {
                        if (imports_allowed and !rule.has_block) try self.importRule(rule);
                        continue;
                    }
                    if (std.mem.eql(u8, name, "charset")) continue;
                    if (std.mem.eql(u8, name, "namespace")) {
                        if (top) self.namespaceRule(rule);
                        continue;
                    }
                    if (std.mem.eql(u8, name, "layer") and !rule.has_block) {
                        // A statement: declares its layers' order.
                        var names = std.mem.splitScalar(u8, rule.prelude, ',');
                        while (names.next()) |n| _ = try self.declareLayer(layer, std.mem.trim(u8, n, " \t\n\r\x0c"));
                        continue;
                    }
                    imports_allowed = false;
                    if (std.mem.eql(u8, name, "media")) {
                        const media = try MediaQueryList.parse(self.contents.allocator, rule.prelude);
                        const index: u32 = @intCast(self.contents.conditions.items.len);
                        self.contents.conditions.append(self.contents.allocator, .{ .media = media, .parent = condition }) catch |err| {
                            var m = media;
                            m.deinit();
                            return err;
                        };
                        try self.ruleList(rule.children, index, layer, false);
                    } else if (std.mem.eql(u8, name, "supports")) {
                        // CSS Conditional 3 6.1: decided once, when parsed.
                        if (css.supports.supportsCondition(self.contents.allocator, rule.prelude, &selectorSupported))
                            try self.ruleList(rule.children, condition, layer, false);
                    } else if (std.mem.eql(u8, name, "layer")) {
                        const sub = try self.declareLayer(layer, std.mem.trim(u8, rule.prelude, " \t\n\r\x0c"));
                        try self.ruleList(rule.children, condition, sub, false);
                    }
                    // Every other at-rule (@font-face, @keyframes, @page,
                    // @container, @scope, ...) has no style rules the
                    // cascade applies here.
                },
            }
        }
    }

    /// Cascade 5 6.4.2: a layer named `name` inside `parent` - its index,
    /// declared now if it is new. An empty name is a new anonymous layer.
    fn declareLayer(self: *Compiler, parent: ?u16, name: []const u8) Allocator.Error!?u16 {
        const a = self.contents.allocator;
        var full: std.ArrayList(u8) = .empty;
        defer full.deinit(a);
        if (parent) |p| {
            try full.appendSlice(a, self.contents.layers.items[p]);
            try full.append(a, '.');
        }
        if (name.len == 0) {
            self.anonymous_layers += 1;
            try full.print(a, "\x00anonymous{d}", .{self.anonymous_layers});
        } else {
            for (name) |c| if (c == ' ' or c == '\t' or c == '\n') return parent;
            try full.appendSlice(a, name);
        }
        // Declaring "a.b" also declares "a".
        var start: usize = 0;
        var result: ?u16 = parent;
        while (true) {
            const dot = std.mem.indexOfScalarPos(u8, full.items, start, '.');
            const prefix = if (dot) |d| full.items[0..d] else full.items;
            result = try self.layerIndex(prefix);
            start = (dot orelse break) + 1;
        }
        return result;
    }

    fn layerIndex(self: *Compiler, path: []const u8) Allocator.Error!u16 {
        for (self.contents.layers.items, 0..) |existing, i| if (std.mem.eql(u8, existing, path)) return @intCast(i);
        const copy = try self.contents.allocator.dupe(u8, path);
        errdefer self.contents.allocator.free(copy);
        try self.contents.layers.append(self.contents.allocator, copy);
        return @intCast(self.contents.layers.items.len - 1);
    }

    /// CSS Namespaces 3: `@namespace "http://www.w3.org/1999/xhtml"` or
    /// `@namespace url(...)` with no prefix.
    fn namespaceRule(self: *Compiler, rule: *const css.rules.Rule) void {
        const prelude = std.mem.trim(u8, rule.prelude, " \t\n\r\x0c");
        if (std.mem.indexOf(u8, prelude, html_namespace) == null) return;
        // A prefix before the URL: a prefixed declaration, not the default.
        const first = prelude[0];
        if (first == '"' or first == '\'' or std.ascii.startsWithIgnoreCase(prelude, "url(")) self.contents.html_only = true;
    }

    /// `@import <url> [layer | layer(<name>)]? <media-query-list>?` (the
    /// supports() condition is not evaluated: stated).
    fn importRule(self: *Compiler, rule: *const css.rules.Rule) Allocator.Error!void {
        const a = self.contents.allocator;
        var rest = std.mem.trim(u8, rule.prelude, " \t\n\r\x0c");
        // Skip the URL: a string or url(...).
        if (rest.len == 0) return;
        if (rest[0] == '"' or rest[0] == '\'') {
            const end = std.mem.indexOfScalarPos(u8, rest, 1, rest[0]) orelse return;
            rest = rest[end + 1 ..];
        } else if (std.ascii.startsWithIgnoreCase(rest, "url(")) {
            const end = std.mem.indexOfScalar(u8, rest, ')') orelse return;
            rest = rest[end + 1 ..];
        } else return;
        rest = std.mem.trim(u8, rest, " \t\n\r\x0c");
        // Every valid @import is kept, at its index among them (the
        // loader's css.import_rules counts the same ones); a remainder that
        // does not parse leaves its layer and media unset.
        var layer: ?u16 = null;
        if (std.ascii.startsWithIgnoreCase(rest, "layer(")) {
            if (std.mem.indexOfScalar(u8, rest, ')')) |end| {
                layer = try self.declareLayer(null, std.mem.trim(u8, rest["layer(".len..end], " "));
                rest = std.mem.trim(u8, rest[end + 1 ..], " \t\n\r\x0c");
            } else rest = "";
        } else if (rest.len >= 5 and std.ascii.eqlIgnoreCase(rest[0..5], "layer") and (rest.len == 5 or rest[5] == ' ')) {
            layer = try self.declareLayer(null, "");
            rest = std.mem.trim(u8, rest[5..], " \t\n\r\x0c");
        }
        if (std.ascii.startsWithIgnoreCase(rest, "supports(")) {
            rest = if (std.mem.lastIndexOfScalar(u8, rest, ')')) |end| std.mem.trim(u8, rest[end + 1 ..], " \t\n\r\x0c") else "";
        }
        const media: ?MediaQueryList = if (rest.len == 0) null else try MediaQueryList.parse(a, rest);
        self.contents.imports.append(a, .{ .media = media, .layer = layer }) catch |err| {
            if (media) |m| {
                var copy = m;
                copy.deinit();
            }
            return err;
        };
    }

    fn styleRule(self: *Compiler, rule: *const css.rules.Rule, condition: ?u32, layer: ?u16) Allocator.Error!void {
        const a = self.contents.allocator;
        if (rule.prelude.len == 0) return;
        const prelude = try a.dupe(u8, rule.prelude);
        errdefer a.free(prelude);
        var selectors = selector.parse(a, prelude) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // "a style rule whose selector is invalid is dropped"
            else => {
                a.free(prelude);
                return;
            },
        };
        errdefer selectors.deinit();
        var block = try DeclarationBlock.fromDeclarations(self.options, rule.declarations);
        errdefer block.deinit();
        const stored = try a.create(StyleRule);
        stored.* = .{ .prelude = prelude, .selectors = selectors, .block = block };
        self.contents.style_rules.append(a, stored) catch |err| {
            a.destroy(stored);
            return err;
        };
        const position = self.position;
        self.position += 1;
        for (stored.selectors.selectors) |*complex| {
            const spec = complex.calculateSpecificity();
            const index: u32 = @intCast(self.contents.rules.items.len);
            try self.contents.rules.append(a, .{
                .complex = complex,
                .specificity = .{ .a = spec.id, .b = spec.class, .c = spec.element },
                .block = &stored.block,
                .position = position,
                .layer = layer,
                .condition = condition,
                .pseudo = pseudoElementOf(&complex.compound),
            });
            try self.bucket(index, complex);
        }
    }

    /// File rule `index` under its subject compound's most selective simple
    /// selector: an ID, else a class, else an attribute name, else a type.
    fn bucket(self: *Compiler, index: u32, complex: *const selector.ComplexSelector) Allocator.Error!void {
        const a = self.contents.allocator;
        const b = &self.contents.buckets;
        if (pseudoElementOf(&complex.compound) != null) return b.pseudo.append(a, index);
        var id: ?[]const u8 = null;
        var class: ?[]const u8 = null;
        var attribute: ?[]const u8 = null;
        var tag: ?[]const u8 = null;
        for (complex.compound.simple_selectors) |*simple| switch (simple.*) {
            .Id => |s| id = id orelse s.id,
            .Class => |s| class = class orelse s.class_name,
            .Attribute => |s| if (s.namespace == .none) {
                attribute = attribute orelse s.lower_name;
            },
            .Type => |s| tag = tag orelse s.lower_name,
            else => {},
        };
        const target: ?struct { map: *std.StringHashMapUnmanaged(std.ArrayList(u32)), key: []const u8 } =
            if (id) |k| .{ .map = &b.id, .key = k } else if (class) |k| .{ .map = &b.class, .key = k } else if (attribute) |k| .{ .map = &b.attribute, .key = k } else if (tag) |k| .{ .map = &b.tag, .key = k } else null;
        const t = target orelse return b.universal.append(a, index);
        const slot = try t.map.getOrPut(a, t.key);
        if (!slot.found_existing) slot.value_ptr.* = .empty;
        try slot.value_ptr.append(a, index);
    }
};

fn pseudoElementOf(compound: *const selector.CompoundSelector) ?[]const u8 {
    for (compound.simple_selectors) |*simple| switch (simple.*) {
        .PseudoElement => |p| return p.name,
        else => {},
    };
    return null;
}

/// supports()'s selector() function: whether `text` parses as a selector.
fn selectorSupported(allocator: Allocator, text: []const u8) bool {
    var list = selector.parse(allocator, text) catch return false;
    list.deinit();
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "compiling: rules bucketed by their subject, invalid selectors dropped, conditions kept" {
    const contents = try Contents.parse(testing.allocator,
        \\@charset "utf-8";
        \\@import url(a.css) screen;
        \\#x { color: red }
        \\.a.b { color: red }
        \\div > p { color: red }
        \\[hidden] { display: none }
        \\* { margin: 0 }
        \\p::before { color: red }
        \\!bad { color: red }
        \\@import url(late.css);
        \\@media print { span { color: blue } }
        \\@supports (display: block) { em { color: green } }
        \\@supports (bogus: nope) { strong { color: green } }
    , .{});
    defer contents.destroy();
    try testing.expectEqual(@as(usize, 1), contents.imports.items.len);
    try testing.expectEqual(@as(usize, 8), contents.rules.items.len);
    try testing.expect(contents.buckets.id.get("x") != null);
    try testing.expect(contents.buckets.class.get("a") != null);
    try testing.expect(contents.buckets.tag.get("p") != null);
    try testing.expect(contents.buckets.attribute.get("hidden") != null);
    try testing.expectEqual(@as(usize, 1), contents.buckets.universal.items.len);
    try testing.expectEqual(@as(usize, 1), contents.buckets.pseudo.items.len);
    const span = contents.rules.items[6];
    try testing.expect(span.condition != null);
    try testing.expect(!contents.conditionHolds(span.condition, &.{}));
    try testing.expect(contents.conditionHolds(span.condition, &.{ .media_type = .print }));
}

test "layers: names declared in order, nested names dotted, statements first" {
    const contents = try Contents.parse(testing.allocator,
        \\@layer reset, base;
        \\@layer base { a { color: red } }
        \\@layer reset.type { b { color: red } }
        \\@layer { c { color: red } }
        \\d { color: red }
    , .{});
    defer contents.destroy();
    try testing.expectEqualStrings("reset", contents.layers.items[0]);
    try testing.expectEqualStrings("base", contents.layers.items[1]);
    try testing.expectEqualStrings("reset.type", contents.layers.items[2]);
    try testing.expectEqual(@as(?u16, 1), contents.rules.items[0].layer);
    try testing.expectEqual(@as(?u16, 2), contents.rules.items[1].layer);
    try testing.expect(contents.rules.items[2].layer != null);
    try testing.expectEqual(@as(?u16, null), contents.rules.items[3].layer);
}

test "the HTML default namespace marks the sheet HTML-only" {
    const contents = try Contents.parse(testing.allocator, "@namespace \"http://www.w3.org/1999/xhtml\"; div { display: block }", .{});
    defer contents.destroy();
    try testing.expect(contents.html_only);
}

test "a record parses lazily, keeps its media, and owns its imports" {
    const record = try SheetRecord.create(testing.allocator, "p { color: red }", .{ .media = "print" });
    defer record.destroy();
    try testing.expect(record.contents == null);
    try testing.expect(!record.mediaMatches(&.{}));
    const contents = try record.contentsOf(null);
    try testing.expectEqual(@as(usize, 1), contents.rules.items.len);
    try testing.expect(record.text == null);
    const child = try SheetRecord.create(testing.allocator, "q { color: blue }", .{});
    try record.attachImport(1, child);
    try testing.expect(record.importAt(&.{1}) == child);
    try testing.expect(record.importAt(&.{0}) == null);
    try record.setMedia("");
    try testing.expect(record.mediaMatches(&.{}));
}
