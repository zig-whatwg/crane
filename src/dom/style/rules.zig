//! A style sheet's CSS rules, as CSSOM sees them (CSSOM 6.4 "CSS rules"):
//! the rule tree a sheet's `cssRules` reads and insertRule()/deleteRule()
//! edit, and that the cascade's index (sheet.zig `Contents`) is compiled
//! from.
//!
//! Blink's split: a StyleSheetContents holds a tree of StyleRuleBase nodes
//! (StyleRule, StyleRuleImport, StyleRuleMedia, ...), which the CSSOM
//! wrappers (CSSStyleRule, CSSImportRule, ...) are made over on demand and
//! the RuleSet indexes. Here the nodes are `Rule`, counted: held by the rule
//! list that contains them (a sheet's CSS rules, a group rule's child CSS
//! rules) and by the CSSRule object made for them, so a rule script still
//! holds after deleteRule() stays readable, with no parent.
//!
//! What a rule keeps is what CSSOM reads back and the cascade applies:
//!
//! - a style rule: its selector's text - the parsed selectors' names are
//!   slices of it (a parsed selector borrows its source text) - the parsed
//!   selector list, and its declaration block;
//! - an @import: its URL as written, its media, layer and supports(), and
//!   the style sheet the loader fetched for it (counted), once it has one;
//! - @media, @supports, @layer blocks: their child rules, and @media's
//!   media query list, @supports' condition (decided once, when parsed:
//!   CSS Conditional 3 6.1);
//! - @layer statements: their names; @namespace: its prefix and URL;
//! - @font-face and @page: their descriptors' block.
//!
//! A rule CSS drops is not here: a style rule whose selector does not
//! parse, an @import after any rule but @charset, @layer statements and
//! other @imports, an @namespace after any other rule, an unknown at-rule.
//! Stated deviations: @charset is dropped (CSSOM has no object for it);
//! @counter-style, @container, @scope,
//! @starting-style and the other at-rules Crane does not model are left out
//! of the rule lists, as the cascade left them out before; nested style
//! rules (CSS Nesting) are dropped, as css.rules drops them.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-rules
//! Spec: https://drafts.csswg.org/css-syntax-3/#parse-stylesheet-contents
//! Spec: https://drafts.csswg.org/css-cascade-5/#at-import

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const css = @import("css");
const selector = @import("selector");
const sheet_mod = @import("sheet.zig");

const SheetRecord = sheet_mod.SheetRecord;
const DeclarationBlock = css.declarations.DeclarationBlock;
const MediaQueryList = css.media_queries.MediaQueryList;

/// A generation-checked link to a CSSOM object (a platform object the
/// collector may free without telling its model): the model's identity for
/// it - one object per model - and never a hold.
pub const ObjectLink = struct {
    instance: ?*runtime.Instance = null,
    generation: u64 = 0,

    pub fn set(self: *ObjectLink, instance: *runtime.Instance) void {
        self.* = .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The object, while it is still the one the link was taken on.
    pub fn get(self: *const ObjectLink) ?*runtime.Instance {
        const instance = self.instance orelse return null;
        if (runtime.SlabAllocator.generationOf(instance) != self.generation) return null;
        return instance;
    }

    /// The object `instance` is going: forget it, if it is this link's.
    pub fn clearIf(self: *ObjectLink, instance: *runtime.Instance) void {
        if (self.instance == instance) self.* = .{};
    }
};

pub const Kind = enum {
    style,
    import,
    media,
    supports,
    layer_block,
    layer_statement,
    namespace,
    font_face,
    font_feature_values,
    page,
    margin,
    position_try,
    property,
    keyframes,
    keyframe,

    /// CSSOM's CSSRule `type` constant for the kind ("new rule types ...
    /// return 0": the layer rules).
    pub fn typeConstant(self: Kind) u16 {
        return switch (self) {
            .style => 1,
            .import => 3,
            .media => 4,
            .font_face => 5,
            .font_feature_values => 14,
            .page => 6,
            .margin => 9,
            .keyframes => 7,
            .keyframe => 8,
            .namespace => 10,
            .supports => 12,
            .layer_block, .layer_statement => 0,
            .position_try, .property => 0,
        };
    }

    /// Whether the kind's rules have child CSS rules.
    pub fn isGroup(self: Kind) bool {
        return switch (self) {
            .media, .supports, .layer_block, .page => true,
            else => false,
        };
    }
};

pub const Import = struct {
    /// The URL as the rule wrote it (a string's or url()'s value).
    href: []u8,
    media: MediaQueryList,
    /// `layer`: the anonymous layer ("" here); `layer(name)`: its name.
    layer: ?[]u8 = null,
    /// supports(<condition>)'s text (not evaluated: stated in sheet.zig).
    supports: ?[]u8 = null,
    /// The rule's index among its sheet's @import rules as parsed: the
    /// index the loader delivers the fetched sheet by (css.import_rules
    /// counts the same rules). Null for a rule insertRule() made.
    index: ?u16 = null,
    /// The style sheet fetched for the rule (CSSOM "associated CSS style
    /// sheet"), counted; null until it arrives, or when it failed.
    child: ?*SheetRecord = null,
};

/// Q55: rare payloads do not enlarge every ordinary style rule.
pub const FontFeaturePayload = struct {
    descriptors: css.font_feature_values.Data,
    objects: [6]ObjectLink = [1]ObjectLink{.{}} ** 6,
};

pub const Data = union(Kind) {
    style: struct {
        selectors: selector.SelectorList,
        block: DeclarationBlock,
    },
    import: Import,
    media: struct {
        list: MediaQueryList,
        children: std.ArrayList(*Rule) = .empty,
    },
    supports: struct {
        holds: bool,
        children: std.ArrayList(*Rule) = .empty,
    },
    layer_block: struct {
        /// Null: an anonymous layer.
        name: ?[]u8,
        children: std.ArrayList(*Rule) = .empty,
    },
    layer_statement: struct {
        names: [][]u8,
    },
    namespace: struct {
        prefix: []u8,
        uri: []u8,
    },
    font_face: @import("font_loading.zig").FontRule,
    font_feature_values: *FontFeaturePayload,
    page: struct { descriptors: css.page_data.Data, children: std.ArrayList(*Rule) = .empty },
    margin: struct { name: []u8, block: DeclarationBlock },
    position_try: DeclarationBlock,
    property: *css.property_registry.Registration,
    keyframes: struct { children: std.ArrayList(*Rule) = .empty },
    keyframe: struct { selectors: css.keyframe_values.Selectors, block: DeclarationBlock },
};

pub const Rule = struct {
    allocator: Allocator,
    refs: u32 = 1,
    /// A style rule's selector text, or an at-rule's prelude, its component
    /// values serialized (css.rules). A style rule's parsed selectors
    /// borrow it: it lives as long as they do.
    prelude: []u8,
    data: Data,
    /// CSSOM "parent CSS rule": a raw back link (the parent holds this
    /// rule); null at a sheet's top level and once removed.
    parent_rule: ?*Rule = null,
    /// CSSOM "parent CSS style sheet": a raw back link; null once removed.
    parent_sheet: ?*SheetRecord = null,
    /// The CSSRule object made for this rule.
    object: ObjectLink = .{},

    pub fn kind(self: *const Rule) Kind {
        return std.meta.activeTag(self.data);
    }

    pub fn ref(self: *Rule) void {
        self.refs += 1;
    }

    pub fn unref(self: *Rule) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        const a = self.allocator;
        switch (self.data) {
            .style => |*s| {
                s.selectors.deinit();
                s.block.deinit();
            },
            .import => |*i| {
                a.free(i.href);
                i.media.deinit();
                if (i.layer) |l| a.free(l);
                if (i.supports) |t| a.free(t);
                if (i.child) |child| {
                    child.owner_rule = null;
                    child.unref();
                }
            },
            .font_face => |*font| font.deinit(),
            .font_feature_values => |payload| {
                payload.descriptors.deinit();
                a.destroy(payload);
            },
            .page => |*p| {
                p.descriptors.deinit();
                releaseChildren(a, &p.children);
            },
            .margin => |*m| {
                a.free(m.name);
                m.block.deinit();
            },
            .position_try => |*b| b.deinit(),
            .property => |registration| registration.unref(),
            .keyframes => |*k| releaseChildren(a, &k.children),
            .keyframe => |*k| {
                k.selectors.deinit();
                k.block.deinit();
            },
            .namespace => |n| {
                a.free(n.prefix);
                a.free(n.uri);
            },
            .layer_statement => |l| {
                for (l.names) |n| a.free(n);
                a.free(l.names);
            },
            .media => |*m| {
                m.list.deinit();
                releaseChildren(a, &m.children);
            },
            .supports => |*s| releaseChildren(a, &s.children),
            .layer_block => |*l| {
                if (l.name) |n| a.free(n);
                releaseChildren(a, &l.children);
            },
        }
        a.free(self.prelude);
        a.destroy(self);
    }

    /// A group rule's child CSS rules; null for every other kind.
    pub fn children(self: *Rule) ?*std.ArrayList(*Rule) {
        return switch (self.data) {
            .media => |*m| &m.children,
            .supports => |*s| &s.children,
            .layer_block => |*l| &l.children,
            .keyframes => |*k| &k.children,
            .page => |*p| &p.children,
            else => null,
        };
    }

    /// The declaration block of a style, @font-face or @page rule.
    pub fn block(self: *Rule) ?*DeclarationBlock {
        return switch (self.data) {
            .style => |*s| &s.block,
            .font_face => |*font| &font.block,
            .page => |*p| &p.descriptors.block,
            .margin => |*m| &m.block,
            .position_try => |*b| b,
            .keyframe => |*k| &k.block,
            else => null,
        };
    }

    /// The style sheet this rule is in, through its parents.
    pub fn sheet(self: *const Rule) ?*SheetRecord {
        var current: ?*const Rule = self;
        while (current) |r| : (current = r.parent_rule) {
            if (r.parent_sheet) |s| return s;
        }
        return null;
    }

    /// CSSOM "serialize a CSS rule". Owned by `allocator`.
    pub fn serialize(self: *Rule, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try self.serializeInto(allocator, &out);
        return out.toOwnedSlice(allocator);
    }

    fn serializeInto(self: *Rule, allocator: Allocator, out: *std.ArrayList(u8)) Allocator.Error!void {
        switch (self.data) {
            .property => |registration| try registration.serializeRule(out, allocator),
            .font_feature_values => |payload| {
                const text = try payload.descriptors.cssText(allocator);
                defer allocator.free(text);
                try out.appendSlice(allocator, text);
            },
            // "The result of performing serialize a group of selectors on
            // the rule's associated selectors, followed by the string " {"
            // ... decls ... " }"" (no nested rules here: stated).
            .style => |*s| {
                try out.appendSlice(allocator, self.prelude);
                try out.appendSlice(allocator, " {");
                const start = out.items.len;
                try out.append(allocator, ' ');
                try s.block.serialize(out);
                if (out.items.len == start + 1) {
                    out.items.len = start;
                    try out.appendSlice(allocator, " }");
                } else try out.appendSlice(allocator, " }");
            },
            // "@import" SP, serialize a URL of the rule's location, the
            // layer and supports() when given, SP and the media list when
            // not empty, ";".
            .import => |*i| {
                try out.appendSlice(allocator, "@import ");
                try serializeUrl(allocator, out, i.href);
                if (i.layer) |l| {
                    if (l.len == 0) try out.appendSlice(allocator, " layer") else {
                        try out.appendSlice(allocator, " layer(");
                        try out.appendSlice(allocator, l);
                        try out.append(allocator, ')');
                    }
                }
                if (i.supports) |t| {
                    try out.appendSlice(allocator, " supports(");
                    try out.appendSlice(allocator, t);
                    try out.append(allocator, ')');
                }
                const media = try serializeMedia(allocator, &i.media);
                defer allocator.free(media);
                if (media.len != 0) {
                    try out.append(allocator, ' ');
                    try out.appendSlice(allocator, media);
                }
                try out.append(allocator, ';');
            },
            // "@media" SP, the media query list, SP "{" LF, each child rule
            // indented by two spaces, joined with LF, LF "}".
            .media => |*m| {
                try out.appendSlice(allocator, "@media ");
                const media = try serializeMedia(allocator, &m.list);
                defer allocator.free(media);
                try out.appendSlice(allocator, media);
                try out.appendSlice(allocator, " {");
                try serializeChildren(allocator, out, m.children.items);
            },
            // CSS Conditional 3: "@supports" SP, the condition text, then
            // the block as @media's.
            .supports => |*s| {
                try out.appendSlice(allocator, "@supports ");
                try out.appendSlice(allocator, self.prelude);
                try out.appendSlice(allocator, " {");
                try serializeChildren(allocator, out, s.children.items);
            },
            // CSS Cascade 5 7.1: "@layer", the name if any, then the block.
            .layer_block => |*l| {
                try out.appendSlice(allocator, "@layer");
                if (l.name) |n| {
                    try out.append(allocator, ' ');
                    try out.appendSlice(allocator, n);
                }
                try out.appendSlice(allocator, " {");
                try serializeChildren(allocator, out, l.children.items);
            },
            .layer_statement => |l| {
                try out.appendSlice(allocator, "@layer ");
                for (l.names, 0..) |n, i| {
                    if (i > 0) try out.appendSlice(allocator, ", ");
                    try out.appendSlice(allocator, n);
                }
                try out.append(allocator, ';');
            },
            // "@namespace" SP, the prefix and SP if there is one, the URL
            // serialized as a URL, ";".
            .namespace => |n| {
                try out.appendSlice(allocator, "@namespace ");
                if (n.prefix.len != 0) {
                    const prefix = try css.serialize.serializeIdentifier(allocator, n.prefix);
                    defer allocator.free(prefix);
                    try out.appendSlice(allocator, prefix);
                    try out.append(allocator, ' ');
                }
                try serializeUrl(allocator, out, n.uri);
                try out.append(allocator, ';');
            },
            .keyframes => |k| {
                try out.appendSlice(allocator, "@keyframes ");
                try css.keyframe_values.serializeName(self.prelude, out, allocator);
                try out.appendSlice(allocator, " {");
                try serializeChildren(allocator, out, k.children.items);
            },
            .keyframe => |*k| {
                try out.appendSlice(allocator, self.prelude);
                try out.appendSlice(allocator, " { ");
                const start = out.items.len;
                try k.block.serialize(out);
                if (out.items.len != start) try out.append(allocator, ' ');
                try out.append(allocator, '}');
            },
            // Anchor Position 1 §8.1: the serialized dashed identifier
            // followed by the restricted descriptor block.
            .position_try => |*b| {
                try out.appendSlice(allocator, "@position-try ");
                try out.appendSlice(allocator, self.prelude);
                try out.appendSlice(allocator, " { ");
                const start = out.items.len;
                try b.serialize(out);
                if (out.items.len != start) try out.append(allocator, ' ');
                try out.append(allocator, '}');
            },
            .page => |*p| {
                // CSSOM serialize a CSS rule; Q53 browser probe: all
                // descriptors precede the margin children, on one line.
                try out.appendSlice(allocator, "@page");
                if (self.prelude.len != 0) {
                    try out.append(allocator, ' ');
                    try out.appendSlice(allocator, self.prelude);
                }
                try out.appendSlice(allocator, " { ");
                const start = out.items.len;
                try p.descriptors.block.serialize(out);
                if (out.items.len != start) try out.append(allocator, ' ');
                for (p.children.items) |child| {
                    try child.serializeInto(allocator, out);
                    try out.append(allocator, ' ');
                }
                try out.append(allocator, '}');
            },
            .margin => |*m| {
                try out.append(allocator, '@');
                try out.appendSlice(allocator, m.name);
                try out.appendSlice(allocator, " { ");
                const start = out.items.len;
                try m.block.serialize(out);
                if (out.items.len != start) try out.append(allocator, ' ');
                try out.append(allocator, '}');
            },
            // "@font-face {", each descriptor, " }" (CSSOM leaves the
            // descriptors' serialization undefined: the block's own).
            .font_face => |*font| {
                try out.appendSlice(allocator, "@font-face {");
                const start = out.items.len;
                try out.append(allocator, ' ');
                try font.block.serialize(out);
                if (out.items.len == start + 1) out.items.len = start;
                try out.appendSlice(allocator, " }");
            },
        }
    }
};

fn releaseChildren(allocator: Allocator, list: *std.ArrayList(*Rule)) void {
    for (list.items) |child| {
        child.parent_rule = null;
        child.parent_sheet = null;
        child.unref();
    }
    list.deinit(allocator);
}

fn serializeChildren(allocator: Allocator, out: *std.ArrayList(u8), items: []const *Rule) Allocator.Error!void {
    try out.append(allocator, '\n');
    var wrote = false;
    for (items) |child| {
        const text = try child.serialize(allocator);
        defer allocator.free(text);
        if (text.len == 0) continue;
        if (wrote) try out.append(allocator, '\n');
        wrote = true;
        try out.appendSlice(allocator, "  ");
        try out.appendSlice(allocator, text);
    }
    try out.appendSlice(allocator, "\n}");
}

/// CSSOM "serialize a URL": `url(` the URL serialized as a string `)`.
fn serializeUrl(allocator: Allocator, out: *std.ArrayList(u8), url: []const u8) Allocator.Error!void {
    try out.appendSlice(allocator, "url(");
    try serializeString(allocator, out, url);
    try out.append(allocator, ')');
}

/// CSSOM "serialize a string".
pub fn serializeString(allocator: Allocator, out: *std.ArrayList(u8), text: []const u8) Allocator.Error!void {
    try out.append(allocator, '"');
    for (text) |c| switch (c) {
        0 => try out.appendSlice(allocator, "\u{FFFD}"),
        0x01...0x1f, 0x7f => try out.print(allocator, "\\{x} ", .{c}),
        '"', '\\' => {
            try out.append(allocator, '\\');
            try out.append(allocator, c);
        },
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');
}

/// CSSOM "serialize a media query list". Owned.
pub fn serializeMedia(allocator: Allocator, list: *const MediaQueryList) Allocator.Error![]u8 {
    var text: std.Io.Writer.Allocating = .init(allocator);
    defer text.deinit();
    list.serialize(&text.writer) catch return error.OutOfMemory;
    return text.toOwnedSlice();
}

// ============================================================================
// Building rules from the parse
// ============================================================================

/// Where a rule stands in its list, for CSS's ordering constraints.
pub const Position = enum {
    /// A sheet's top level, before any rule but @charset and @layer
    /// statements: an @import may stand here.
    imports_allowed,
    /// A sheet's top level after @imports: @namespace may stand here.
    namespaces_allowed,
    /// Anywhere else at a sheet's top level.
    top,
    /// Inside a group rule.
    nested,
};

pub const BuildOptions = struct {
    parse: css.properties.ParseOptions,
};

/// The rule `parsed` (css.rules) as a `Rule`, or null when CSS drops it
/// where it stands (`position`).
pub fn build(options: BuildOptions, parsed: *const css.rules.Rule, position: Position) Allocator.Error!?*Rule {
    const a = options.parse.allocator;
    switch (parsed.kind) {
        .qualified => {
            if (parsed.prelude.len == 0) return null;
            const prelude = try a.dupe(u8, parsed.prelude);
            var owns_prelude = true;
            errdefer if (owns_prelude) a.free(prelude);
            var selectors = selector.parse(a, prelude) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                // "A style rule whose selector is invalid is dropped."
                else => {
                    a.free(prelude);
                    return null;
                },
            };
            errdefer selectors.deinit();
            var declarations = try DeclarationBlock.fromDeclarations(options.parse, parsed.declarations);
            errdefer declarations.deinit();
            // make consumes the prelude even when its Rule allocation fails.
            owns_prelude = false;
            return make(a, prelude, .{ .style = .{ .selectors = selectors, .block = declarations } });
        },
        .at_rule => {},
    }
    const name = parsed.name;
    if (std.mem.eql(u8, name, "import")) {
        if (position != .imports_allowed or parsed.has_block) return null;
        return buildImport(a, parsed.prelude);
    }
    if (std.mem.eql(u8, name, "namespace")) {
        if (position != .imports_allowed and position != .namespaces_allowed) return null;
        if (parsed.has_block) return null;
        return buildNamespace(a, parsed.prelude);
    }
    if (std.mem.eql(u8, name, "layer")) {
        const prelude = std.mem.trim(u8, parsed.prelude, " \t\n\r\x0c");
        if (!parsed.has_block) {
            // A statement: one or more comma-separated names.
            var names: std.ArrayList([]u8) = .empty;
            errdefer {
                for (names.items) |n| a.free(n);
                names.deinit(a);
            }
            var it = std.mem.splitScalar(u8, prelude, ',');
            while (it.next()) |raw| {
                const n = std.mem.trim(u8, raw, " \t\n\r\x0c");
                if (!isLayerName(n)) {
                    for (names.items) |x| a.free(x);
                    names.deinit(a);
                    return null;
                }
                try names.append(a, try a.dupe(u8, n));
            }
            if (names.items.len == 0) return null;
            const owned = try names.toOwnedSlice(a);
            return make(a, try a.dupe(u8, prelude), .{ .layer_statement = .{ .names = owned } });
        }
        if (prelude.len != 0 and !isLayerName(prelude)) return null;
        const rule = blk: {
            const layer_name: ?[]u8 = if (prelude.len == 0) null else try a.dupe(u8, prelude);
            errdefer if (layer_name) |n| a.free(n);
            break :blk try make(a, try a.dupe(u8, prelude), .{ .layer_block = .{ .name = layer_name } });
        };
        errdefer rule.unref();
        try buildChildren(options, rule, parsed.children);
        return rule;
    }
    if (std.mem.eql(u8, name, "media")) {
        const rule = blk: {
            var list = try MediaQueryList.parse(a, parsed.prelude);
            errdefer list.deinit();
            break :blk try make(a, try a.dupe(u8, parsed.prelude), .{ .media = .{ .list = list } });
        };
        errdefer rule.unref();
        try buildChildren(options, rule, parsed.children);
        return rule;
    }
    if (std.mem.eql(u8, name, "supports")) {
        if (!parsed.has_block) return null;
        const holds = css.supports.supportsCondition(a, parsed.prelude, &selectorSupported);
        const rule = try make(a, try a.dupe(u8, std.mem.trim(u8, parsed.prelude, " \t\n\r\x0c")), .{ .supports = .{ .holds = holds } });
        errdefer rule.unref();
        try buildChildren(options, rule, parsed.children);
        return rule;
    }
    if (std.mem.eql(u8, name, "keyframes") or std.mem.eql(u8, name, "-webkit-keyframes")) {
        if (!parsed.has_block) return null;
        var stream = css.properties.Stream.init(parsed.prelude);
        const decoded = try css.keyframe_values.consumeName(a, &stream) orelse return null;
        if (!stream.atEnd()) {
            a.free(decoded);
            return null;
        }
        // make consumes decoded, including failure. The parent then owns
        // every successfully appended child; malformed blocks are discarded.
        const parent = try make(a, decoded, .{ .keyframes = .{} });
        errdefer parent.unref();
        for (parsed.children) |*child| {
            const keyframe = try buildKeyframe(options, child) orelse continue;
            parent.data.keyframes.children.append(a, keyframe) catch |err| {
                keyframe.unref();
                return err;
            };
            keyframe.parent_rule = parent;
        }
        return parent;
    }
    if (std.mem.eql(u8, name, "property")) {
        // Properties and Values §3: validate descriptors before exposing a
        // CSSPropertyRule. The immutable record also backs the registry.
        const registration = try css.property_registry.Registration.fromRule(options.parse, parsed) orelse return null;
        errdefer registration.unref();
        const prelude = try css.serialize.serializeIdentifier(a, registration.name);
        // make consumes prelude, including failure; registration moves only
        // after make succeeds, as for the other owned rule payloads.
        return make(a, prelude, .{ .property = registration });
    }
    if (std.mem.eql(u8, name, "position-try")) {
        // Anchor Position 1 §6.4: exactly one dashed identifier, with a
        // declaration block. Nested rules have no place in this model.
        if (!parsed.has_block) return null;
        var stream = css.properties.Stream.init(parsed.prelude);
        const token = stream.next();
        if (token.token_type != .ident or !stream.atEnd()) return null;
        const decoded = try css.tokenizer.decode(a, token.value);
        defer a.free(decoded);
        if (!std.mem.startsWith(u8, decoded, "--")) return null;
        var declarations = try DeclarationBlock.fromDeclarationsInContext(options.parse, parsed.declarations, .position_try);
        errdefer declarations.deinit();
        // make consumes the owned prelude, including allocation failure.
        const prelude = try css.serialize.serializeIdentifier(a, decoded);
        return make(a, prelude, .{ .position_try = declarations });
    }
    if (std.mem.eql(u8, name, "font-feature-values")) {
        var native = try css.font_feature_values.fromParsed(a, parsed) orelse return null;
        errdefer native.deinit();
        const payload = try a.create(FontFeaturePayload);
        errdefer a.destroy(payload);
        payload.* = .{ .descriptors = native };
        // The payload moves only when make succeeds. The general rule's
        // prelude is empty: the parsed family already owns its spelling.
        return make(a, try a.dupe(u8, ""), .{ .font_feature_values = payload });
    }
    if (std.mem.eql(u8, name, "font-face")) {
        if (!parsed.has_block) return null;
        // CSS Fonts 4 §4.1: descriptors have their own grammar and no
        // importance. The rule keeps source metadata after detachment.
        var font = try @import("font_loading.zig").FontRule.fromDeclarations(options.parse, parsed.declarations);
        errdefer font.deinit();
        const prelude = try a.dupe(u8, std.mem.trim(u8, parsed.prelude, " \t\n\r\x0c"));
        return make(a, prelude, .{ .font_face = font });
    }
    if (std.mem.eql(u8, name, "page")) {
        if (!parsed.has_block) return null;
        const prelude = try css.page_values.selectors(a, parsed.prelude) orelse return null;
        var owns_prelude = true;
        errdefer if (owns_prelude) a.free(prelude);
        var descriptors = try css.page_data.Data.fromDeclarations(options.parse, parsed.declarations);
        var owns_descriptors = true;
        errdefer if (owns_descriptors) descriptors.deinit();
        owns_prelude = false; // make consumes it, including failure.
        const parent = try make(a, prelude, .{ .page = .{ .descriptors = descriptors } });
        owns_descriptors = false;
        errdefer parent.unref();
        for (parsed.children) |*child| {
            const margin = try buildPageMargin(options, child) orelse continue;
            parent.data.page.children.append(a, margin) catch |err| {
                margin.unref();
                return err;
            };
            margin.parent_rule = parent;
        }
        return parent;
    }
    return null;
}

/// Paged Media 3 §4.3: only named page-margin at-rules are children of
/// a page rule, with an empty prelude and an ordinary declaration block.
pub fn buildPageMargin(options: BuildOptions, parsed: *const css.rules.Rule) Allocator.Error!?*Rule {
    if (parsed.kind != .at_rule or !parsed.has_block or !css.rules.isPageMarginRule(parsed.name) or parsed.prelude.len != 0) return null;
    const a = options.parse.allocator;
    var block_value = try DeclarationBlock.fromDeclarations(options.parse, parsed.declarations);
    errdefer block_value.deinit();
    const name = try a.dupe(u8, parsed.name);
    errdefer a.free(name);
    const prelude = try a.dupe(u8, "");
    return make(a, prelude, .{ .margin = .{ .name = name, .block = block_value } });
}

/// Animations 1 §3: a qualified keyframe block, not a style selector.
/// Shared by stylesheet parsing and appendRule, with identical restrictions.
pub fn buildKeyframe(options: BuildOptions, parsed: *const css.rules.Rule) Allocator.Error!?*Rule {
    if (parsed.kind != .qualified or !parsed.has_block) return null;
    const a = options.parse.allocator;
    var selectors = try css.keyframe_values.Selectors.parse(a, parsed.prelude) orelse return null;
    errdefer selectors.deinit();
    var block = try DeclarationBlock.fromDeclarationsInContext(options.parse, parsed.declarations, .keyframe);
    errdefer block.deinit();
    const prelude = try selectors.serialize(a);
    return make(a, prelude, .{ .keyframe = .{ .selectors = selectors, .block = block } });
}

fn make(a: Allocator, prelude: []u8, data: Data) Allocator.Error!*Rule {
    errdefer a.free(prelude);
    const rule = try a.create(Rule);
    rule.* = .{ .allocator = a, .prelude = prelude, .data = data };
    return rule;
}

fn buildChildren(options: BuildOptions, parent: *Rule, items: []const css.rules.Rule) Allocator.Error!void {
    const list = parent.children().?;
    for (items) |*item| {
        const child = (try build(options, item, .nested)) orelse continue;
        child.parent_rule = parent;
        list.append(options.parse.allocator, child) catch |err| {
            child.unref();
            return err;
        };
    }
}

/// `<layer-name>`: one or more identifiers joined by ".".
fn isLayerName(text: []const u8) bool {
    if (text.len == 0) return false;
    var it = std.mem.splitScalar(u8, text, '.');
    while (it.next()) |part| {
        if (part.len == 0) return false;
        for (part) |c| if (c == ' ' or c == '\t' or c == '\n' or c == '(' or c == ')' or c == ',' or c == ';' or c == '{') return false;
    }
    return true;
}

/// `@import [ <url> | <string> ] [ layer | layer(<layer-name>) ]?
/// [ supports( <condition> ) ]? <media-query-list>?`, its prelude
/// serialized (a url() is `url("...")`, its string escaped).
fn buildImport(a: Allocator, prelude_text: []const u8) Allocator.Error!?*Rule {
    var rest = std.mem.trim(u8, prelude_text, " \t\n\r\x0c");
    if (rest.len == 0) return null;
    var href: std.ArrayList(u8) = .empty;
    defer href.deinit(a);
    if (rest[0] == '"' or rest[0] == '\'') {
        const end = try readString(a, rest, 0, &href) orelse return null;
        rest = rest[end..];
    } else if (std.ascii.startsWithIgnoreCase(rest, "url(")) {
        var i: usize = "url(".len;
        while (i < rest.len and rest[i] == ' ') i += 1;
        if (i < rest.len and (rest[i] == '"' or rest[i] == '\'')) {
            i = try readString(a, rest, i, &href) orelse return null;
            while (i < rest.len and rest[i] == ' ') i += 1;
            if (i >= rest.len or rest[i] != ')') return null;
            rest = rest[i + 1 ..];
        } else {
            const close = std.mem.indexOfScalarPos(u8, rest, i, ')') orelse return null;
            try href.appendSlice(a, std.mem.trim(u8, rest[i..close], " "));
            rest = rest[close + 1 ..];
        }
    } else return null;
    rest = std.mem.trim(u8, rest, " \t\n\r\x0c");
    var layer: ?[]u8 = null;
    errdefer if (layer) |l| a.free(l);
    if (std.ascii.startsWithIgnoreCase(rest, "layer(")) {
        const end = std.mem.indexOfScalar(u8, rest, ')') orelse return null;
        const n = std.mem.trim(u8, rest["layer(".len..end], " ");
        if (!isLayerName(n)) return null;
        layer = try a.dupe(u8, n);
        rest = std.mem.trim(u8, rest[end + 1 ..], " \t\n\r\x0c");
    } else if (rest.len >= 5 and std.ascii.eqlIgnoreCase(rest[0..5], "layer") and (rest.len == 5 or rest[5] == ' ')) {
        layer = try a.dupe(u8, "");
        rest = std.mem.trim(u8, rest[5..], " \t\n\r\x0c");
    }
    var supports: ?[]u8 = null;
    errdefer if (supports) |t| a.free(t);
    if (std.ascii.startsWithIgnoreCase(rest, "supports(")) {
        const end = matchingParen(rest, "supports".len) orelse return null;
        supports = try a.dupe(u8, std.mem.trim(u8, rest["supports(".len..end], " "));
        rest = std.mem.trim(u8, rest[end + 1 ..], " \t\n\r\x0c");
    }
    var media = try MediaQueryList.parse(a, rest);
    errdefer media.deinit();
    const owned_href = try href.toOwnedSlice(a);
    errdefer a.free(owned_href);
    return try make(a, try a.dupe(u8, prelude_text), .{ .import = .{ .href = owned_href, .media = media, .layer = layer, .supports = supports } });
}

/// The index just past the string starting at `start`, its value decoded
/// into `out`; null when it is not closed.
fn readString(a: Allocator, text: []const u8, start: usize, out: *std.ArrayList(u8)) Allocator.Error!?usize {
    const quote = text[start];
    var i = start + 1;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == quote) return i + 1;
        if (c == '\\' and i + 1 < text.len) {
            i += 1;
            // An escaped code point the serializer wrote as hex digits and
            // a space.
            if (std.ascii.isHex(text[i])) {
                var end = i;
                while (end < text.len and end - i < 6 and std.ascii.isHex(text[end])) end += 1;
                const value = std.fmt.parseInt(u21, text[i..end], 16) catch 0xFFFD;
                var buffer: [4]u8 = undefined;
                const n = std.unicode.utf8Encode(if (value == 0 or value > 0x10FFFF) 0xFFFD else value, &buffer) catch 0;
                try out.appendSlice(a, buffer[0..n]);
                i = end;
                if (i < text.len and text[i] == ' ') {} else i -= 1;
                continue;
            }
        }
        try out.append(a, text[i]);
    }
    return null;
}

/// The index of the `)` closing the `(` at `open`.
fn matchingParen(text: []const u8, open: usize) ?usize {
    var depth: usize = 0;
    var i = open;
    while (i < text.len) : (i += 1) switch (text[i]) {
        '(' => depth += 1,
        ')' => {
            depth -= 1;
            if (depth == 0) return i;
        },
        else => {},
    };
    return null;
}

/// CSS Namespaces 3 §2: `@namespace <namespace-prefix>? [ <string> | <url> ]`.
/// Consume tokens, as Blink's CSSParserImpl::ConsumeNamespaceRule does;
/// comments and an escape's terminating space are not prefix separators.
fn buildNamespace(a: Allocator, prelude_text: []const u8) Allocator.Error!?*Rule {
    const prelude = std.mem.trim(u8, prelude_text, " \t\n\r\x0c");
    var stream = css.tokenizer.Tokenizer.init(prelude);
    stream.skipWhitespace();
    var token = stream.next();
    var prefix: []const u8 = "";
    if (token.token_type == .ident) {
        prefix = token.value;
        stream.skipWhitespace();
        token = stream.next();
    }
    const uri = switch (token.token_type) {
        .string => token.stringContents(),
        .url => token.value,
        .function => blk: {
            if (!css.tokenizer.nameEql(token.value, "url")) return null;
            if (stream.next().token_type != .left_paren) return null;
            stream.skipWhitespace();
            const argument = stream.next();
            if (argument.token_type != .string) return null;
            stream.skipWhitespace();
            const close = stream.next();
            // CSS Syntax closes a function at EOF, as it does a URL token.
            if (close.token_type != .right_paren and close.token_type != .eof) return null;
            break :blk argument.stringContents();
        },
        else => return null,
    };
    stream.skipWhitespace();
    if (stream.next().token_type != .eof) return null;
    const owned_prefix = try css.tokenizer.decode(a, prefix);
    errdefer a.free(owned_prefix);
    // §2.1: a namespace URI is an exact string; never resolve it as a URL.
    const owned_uri = try css.tokenizer.decode(a, uri);
    errdefer a.free(owned_uri);
    return try make(a, try a.dupe(u8, prelude), .{ .namespace = .{ .prefix = owned_prefix, .uri = owned_uri } });
}

/// supports()'s selector() function: whether `text` parses as a selector.
pub fn selectorSupported(allocator: Allocator, text: []const u8) bool {
    var list = selector.parse(allocator, text) catch return false;
    list.deinit();
    return true;
}

/// A sheet's top-level rules from `text` ("parse a stylesheet's contents"),
/// each CSS keeps where it stands. `imports` gets, at each index the loader
/// delivers by, the @import rule there (a hold of its own), or null where
/// CSS dropped the rule the loader still fetches.
pub fn parseSheet(options: BuildOptions, text: []const u8, out: *std.ArrayList(*Rule), imports: ?*std.ArrayList(?*Rule)) Allocator.Error!void {
    const a = options.parse.allocator;
    var parsed = try css.rules.parseStyleSheetContents(a, text);
    defer parsed.deinit();
    var position: Position = .imports_allowed;
    // A complete sheet supplies its OWN bindings, including on replaceSync.
    // A single-rule CSSOM edit instead receives the current map in build().
    var scoped = options;
    scoped.parse.namespaces = null;
    var map: ?*css.namespace_map.NamespaceMap = null;
    defer if (map) |m| m.release();
    var namespaces_done = false;
    var import_count: u16 = 0;
    for (parsed.items) |*item| {
        if (item.kind == .at_rule and std.mem.eql(u8, item.name, "charset")) continue;
        const is_import = item.kind == .at_rule and std.mem.eql(u8, item.name, "import");
        // The loader (css.import_rules) fetches every @import standing where
        // one may, with no block - even one CSS then drops for its layer() or
        // supports() - and delivers it by that count: the indices agree.
        const index: ?u16 = if (is_import and position == .imports_allowed and !item.has_block) import_count else null;
        if (index != null) import_count +|= 1;
        if (!namespaces_done and advance(position, item) == .top) {
            map = try namespaceMap(a, out.items);
            scoped.parse.namespaces = map;
            namespaces_done = true;
        }
        const built = try build(scoped, item, position);
        position = advance(position, item);
        if (index != null) if (imports) |list| {
            const held: ?*Rule = if (built) |r| (if (r.data == .import) r else null) else null;
            if (held) |r| r.ref();
            list.append(a, held) catch |err| {
                if (held) |r| r.unref();
                if (built) |r| r.unref();
                return err;
            };
        };
        const rule = built orelse continue;
        if (rule.data == .import) rule.data.import.index = index;
        out.append(a, rule) catch |err| {
            rule.unref();
            return err;
        };
    }
}

/// CSS Namespaces 3 §2: a snapshot of the accepted namespace preamble.
/// No allocation for the usual sheet with no namespace declarations. Only
/// its preamble is inspected, never its style-rule body on a CSSOM edit.
pub fn namespaceMap(allocator: Allocator, rules: []const *Rule) Allocator.Error!?*css.namespace_map.NamespaceMap {
    var entries: std.ArrayList(css.namespace_map.Entry) = .empty;
    defer entries.deinit(allocator);
    var default: ?[]const u8 = null;
    for (rules) |rule| switch (rule.data) {
        .namespace => |ns| {
            if (ns.prefix.len == 0) default = ns.uri else try entries.append(allocator, .{ .prefix = ns.prefix, .namespace = ns.uri });
        },
        .import, .layer_statement => {},
        else => break,
    };
    if (entries.items.len == 0 and default == null) return null;
    return try css.namespace_map.NamespaceMap.create(allocator, entries.items, default);
}

/// The position after `item` stands at `position`.
fn advance(position: Position, item: *const css.rules.Rule) Position {
    if (item.kind == .at_rule) {
        if (std.mem.eql(u8, item.name, "import") and position == .imports_allowed) return .imports_allowed;
        if (std.mem.eql(u8, item.name, "layer") and !item.has_block and position == .imports_allowed) return .imports_allowed;
        if (std.mem.eql(u8, item.name, "namespace") and (position == .imports_allowed or position == .namespaces_allowed)) return .namespaces_allowed;
    }
    return .top;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn parseForTest(text: []const u8, out: *std.ArrayList(*Rule)) !void {
    try parseSheet(.{ .parse = .{ .allocator = testing.allocator } }, text, out, null);
}

fn freeForTest(list: *std.ArrayList(*Rule)) void {
    for (list.items) |r| r.unref();
    list.deinit(testing.allocator);
}

test "a sheet's rules: kinds, CSS's ordering constraints, dropped rules" {
    var rules: std.ArrayList(*Rule) = .empty;
    defer freeForTest(&rules);
    try parseForTest(
        \\@charset "utf-8";
        \\@layer a, b;
        \\@import url(x.css) screen;
        \\@namespace svg url(http://www.w3.org/2000/svg);
        \\p { color: red }
        \\@import "late.css";
        \\@namespace late "x";
        \\!bad { color: red }
        \\@media print { a { color: blue } @bogus; }
        \\@supports (display: block) { b { color: green } }
        \\@layer c { i { color: red } }
        \\@font-face { font-family: x }
        \\@unknown { }
    , &rules);
    const kinds = [_]Kind{ .layer_statement, .import, .namespace, .style, .media, .supports, .layer_block, .font_face };
    try testing.expectEqual(kinds.len, rules.items.len);
    for (kinds, rules.items) |k, r| try testing.expectEqual(k, r.kind());
    try testing.expectEqualStrings("x.css", rules.items[1].data.import.href);
    try testing.expectEqual(@as(?u16, 0), rules.items[1].data.import.index);
    try testing.expectEqualStrings("svg", rules.items[2].data.namespace.prefix);
    try testing.expectEqual(@as(usize, 1), rules.items[4].children().?.items.len);
    try testing.expect(rules.items[4].children().?.items[0].parent_rule == rules.items[4]);
    try testing.expect(rules.items[5].data.supports.holds);
}

test "serialize a CSS rule" {
    var rules: std.ArrayList(*Rule) = .empty;
    defer freeForTest(&rules);
    try parseForTest(
        \\@import url("a b.css") layer(x) print;
        \\@namespace "http://www.w3.org/1999/xhtml";
        \\div > p { color: red; margin-left: 2px !important }
        \\q { }
        \\@media screen and (min-width: 1px) { a { color: blue } b { } }
        \\@layer outer { c { color: green } }
        \\@layer a.b, c;
    , &rules);
    const expected = [_][]const u8{
        "@import url(\"a b.css\") layer(x) print;",
        "@namespace url(\"http://www.w3.org/1999/xhtml\");",
        "div > p { color: red; margin-left: 2px !important; }",
        "q { }",
        "@media screen and (min-width: 1px) {\n  a { color: blue; }\n  b { }\n}",
        "@layer outer {\n  c { color: green; }\n}",
        "@layer a.b, c;",
    };
    try testing.expectEqual(expected.len, rules.items.len);
    for (expected, rules.items) |e, r| {
        const text = try r.serialize(testing.allocator);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings(e, text);
    }
}

test "namespace rules decode CSS tokens without resolving their URI" {
    const cases = [_]struct { input: []const u8, prefix: []const u8, uri: []const u8 }{
        .{ .input = "n\\73 \"urn:x\"", .prefix = "ns", .uri = "urn:x" },
        .{ .input = "n/**/\"urn:x\"", .prefix = "n", .uri = "urn:x" },
        .{ .input = "n\"urn:x\"", .prefix = "n", .uri = "urn:x" },
        .{ .input = " /*before*/ n \"urn:x\" /*after*/ ", .prefix = "n", .uri = "urn:x" },
        .{ .input = "n url(relative/path)", .prefix = "n", .uri = "relative/path" },
        .{ .input = "n URL( \"a\\62 c\" )", .prefix = "n", .uri = "abc" },
        .{ .input = "n url(a\\20 b)", .prefix = "n", .uri = "a b" },
        .{ .input = "Ns u\\72 l(urn:x)", .prefix = "Ns", .uri = "urn:x" },
        .{ .input = "inherit \"urn:x\"", .prefix = "inherit", .uri = "urn:x" },
        .{ .input = "n \"\"", .prefix = "n", .uri = "" },
        .{ .input = "url(urn:x)", .prefix = "", .uri = "urn:x" },
        .{ .input = "\"urn:x\"", .prefix = "", .uri = "urn:x" },
        .{ .input = "n \"urn:x", .prefix = "n", .uri = "urn:x" },
        .{ .input = "n url(urn:x", .prefix = "n", .uri = "urn:x" },
        .{ .input = "n url(\"urn:x\"", .prefix = "n", .uri = "urn:x" },
    };
    for (cases) |case| {
        const rule = (try buildNamespace(testing.allocator, case.input)) orelse return error.ExpectedNamespaceRule;
        defer rule.unref();
        try testing.expectEqualStrings(case.prefix, rule.data.namespace.prefix);
        try testing.expectEqualStrings(case.uri, rule.data.namespace.uri);
    }
}

test "namespace rules reject malformed tokens and unconsumed URL tails" {
    for ([_][]const u8{
        "1n \"x\"",              "* \"x\"",              "n n \"x\"",  "n",             "n url(x) trailing",
        "n url(\"x\") trailing", "n url(\"x\" invalid)", "n url(x y)", "n \"x\" \"y\"", "n \"bad\nstring\"",
        "n url(x))",             "n 123",
    }) |input| {
        const rule = try buildNamespace(testing.allocator, input);
        defer if (rule) |r| r.unref();
        try testing.expect(rule == null);
    }
}

test "namespace serialization escapes decoded identifiers and string contents" {
    var parsed: std.ArrayList(*Rule) = .empty;
    defer freeForTest(&parsed);
    try parseForTest("@namespace \\31 prefix \"a\\22 b\";", &parsed);
    try testing.expectEqual(@as(usize, 1), parsed.items.len);
    try testing.expectEqualStrings("1prefix", parsed.items[0].data.namespace.prefix);
    const text = try parsed.items[0].serialize(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("@namespace \\31 prefix url(\"a\\\"b\");", text);
    var round_trip: std.ArrayList(*Rule) = .empty;
    defer freeForTest(&round_trip);
    try parseForTest(text, &round_trip);
    try testing.expectEqual(@as(usize, 1), round_trip.items.len);
    try testing.expectEqualStrings(parsed.items[0].data.namespace.prefix, round_trip.items[0].data.namespace.prefix);
    try testing.expectEqualStrings(parsed.items[0].data.namespace.uri, round_trip.items[0].data.namespace.uri);
}

test "namespace parsing and serialization clean up each allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: Allocator) !void {
            const rule = (try buildNamespace(allocator, "n\\73 \"a\\22 b\"")) orelse return error.ExpectedNamespaceRule;
            defer rule.unref();
            const text = try rule.serialize(allocator);
            defer allocator.free(text);
            try testing.expectEqualStrings("ns", rule.data.namespace.prefix);
            try testing.expectEqualStrings("@namespace ns url(\"a\\\"b\");", text);
        }
    }.exercise, .{});
}

test "a rule held after its list lets go keeps its data and loses its parents" {
    var rules: std.ArrayList(*Rule) = .empty;
    try parseForTest("@media print { a { color: red } }", &rules);
    const child = rules.items[0].children().?.items[0];
    child.ref();
    freeForTest(&rules);
    defer child.unref();
    try testing.expect(child.parent_rule == null);
    const text = try child.serialize(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("a { color: red; }", text);
}

test "pending declarations retain the last namespace bindings from their sheet" {
    var tree: std.ArrayList(*Rule) = .empty;
    defer freeForTest(&tree);
    try parseForTest("@namespace p 'urn:first'; @namespace p 'urn:last'; @namespace 'urn:default'; div { --value: var(--x) }", &tree);
    const pending = tree.items[3].block().?.getCustom("--value").?.value.pending;
    const map = pending.namespaces orelse return error.ExpectedNamespaceMap;
    try testing.expectEqualStrings("urn:last", map.lookup("p").?);
    try testing.expectEqualStrings("urn:default", map.default.?);
    pending.ref();
    defer pending.unref();
    freeForTest(&tree);
    tree = .empty;
    try testing.expectEqualStrings("urn:last", pending.namespaces.?.lookup("p").?);
}

test "parsing replacement sheet contents never reuses the supplied old namespace map" {
    const old = try css.namespace_map.NamespaceMap.create(testing.allocator, &.{.{ .prefix = "p", .namespace = "urn:old" }}, null);
    defer old.release();
    for ([_][]const u8{ "div { --value: var(--x) }", "@namespace p 'urn:new'; div { --value: var(--x) }" }, 0..) |text, i| {
        var tree: std.ArrayList(*Rule) = .empty;
        defer freeForTest(&tree);
        try parseSheet(.{ .parse = .{ .allocator = testing.allocator, .namespaces = old } }, text, &tree, null);
        const map = tree.items[tree.items.len - 1].block().?.getCustom("--value").?.value.pending.namespaces;
        if (i == 0) try testing.expect(map == null) else try testing.expectEqualStrings("urn:new", map.?.lookup("p").?);
    }
}

test "namespace snapshots and pending declarations release partial parse allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: Allocator) !void {
            var tree: std.ArrayList(*Rule) = .empty;
            defer {
                for (tree.items) |rule| rule.unref();
                tree.deinit(allocator);
            }
            try parseSheet(.{ .parse = .{ .allocator = allocator } }, "@namespace p 'urn:p'; @media all { div { --value: var(--x) } }", &tree, null);
            const map = try namespaceMap(allocator, tree.items) orelse return error.ExpectedNamespaceMap;
            defer map.release();
            try testing.expectEqualStrings("urn:p", map.lookup("p").?);
        }
    }.exercise, .{});
}
