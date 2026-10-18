//! A CSS style sheet as the style engine holds it (CSSOM 6.1 "CSS style
//! sheet": its owner node and owner rule, title, alternate and disabled
//! flags, media, location and origin-clean flag, the constructed and
//! disallow-modification flags, its CSS rules), and its rules compiled for
//! matching.
//!
//! Blink's split: a CSSStyleSheet holds the sheet's state over a
//! StyleSheetContents, whose rule tree a RuleSet indexes. Here the state is a
//! `SheetRecord`, COUNTED: held by what the sheet is associated with - the
//! style or link element (HTML "create a CSS style sheet"), the @import rule
//! that fetched it - and by the CSSStyleSheet object made for it, so a sheet
//! script still holds after its owner let it go ("remove a CSS style sheet")
//! stays readable, with no owner. Its CSS rules are a tree of `rules.Rule`,
//! parsed the first time the cascade or CSSOM needs them: a page that never
//! reads style never parses its sheets beyond the @import scan its loads
//! already do (design section 5.4). The sheet keeps its text, base URL and
//! parser mode from its creation for that parse.
//!
//! Compiling (CSS Cascade 5 section 5 "Filtering", CSS Conditional 3) is
//! `Contents`: an index into the rule tree - each complex selector of a style
//! rule one `RuleData` with its specificity, its declarations, its layer and
//! its chain of @media conditions; @supports decided at parse time; @import
//! rules with their media and layer, and the sheets the loader attached to
//! them. It is made again whenever `contents_version` moves (every CSSOM
//! edit, every import arriving), and points into the tree only while it is
//! current.
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
const interfaces = @import("interfaces");
const css = @import("css");
const selector = @import("selector");
const rules_mod = @import("rules.zig");

const DeclarationBlock = css.declarations.DeclarationBlock;
const MediaQueryList = css.media_queries.MediaQueryList;
const MediaValues = css.media_queries.MediaValues;
pub const Rule = rules_mod.Rule;
pub const ObjectLink = rules_mod.ObjectLink;

const html_namespace = "http://www.w3.org/1999/xhtml";

/// What a sheet is parsed with, captured when it is created.
pub const ParseMode = struct {
    quirks: bool = false,
};

/// Resolves a url() in the sheet against its base URL.
pub const UrlResolver = css.properties.UrlResolver;

/// What a url() in a sheet is resolved with: the sheet's base URL, and an
/// object of the realm to run the URL parser in.
pub const UrlContext = struct {
    instance: *runtime.Instance,
    base: []const u8,

    pub fn resolver(self: *const UrlContext) UrlResolver {
        return .{ .context = self, .resolve = &resolveUrl };
    }
};

/// A url() in a sheet, parsed against the sheet's base URL (CSS Values 4
/// 4.5.1); null when it does not parse (it stays as written).
fn resolveUrl(context: *const anyopaque, allocator: Allocator, url: []const u8) ?[]u8 {
    const ctx: *const UrlContext = @ptrCast(@alignCast(context));
    const webidl = @import("webidl");
    const base_arg = if (ctx.base.len > 0) webidl.Opt(runtime.USVString).passed(ctx.base) else webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(ctx.instance, url, base_arg) catch null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    const href = interfaces.URL.get_href(parsed) catch return null;
    defer ctx.instance.ctx.allocator.free(href);
    return allocator.dupe(u8, href) catch null;
}

pub const SheetRecord = struct {
    allocator: Allocator,
    refs: u32 = 1,
    /// CSSOM "owner node": the element the sheet is associated with, a raw
    /// back link (the element holds this record); null once removed.
    owner_node: ?*runtime.Instance = null,
    /// CSSOM "owner CSS rule": the @import rule whose sheet this is, a raw
    /// back link (the rule holds this record); its parent sheet is this
    /// sheet's "parent CSS style sheet".
    owner_rule: ?*Rule = null,
    /// CSSOM "title", "alternate flag", "disabled flag".
    title: []u8 = &.{},
    alternate: bool = false,
    disabled: bool = false,
    /// CSSOM "media", as text; parsed when first evaluated.
    media_text: []u8 = &.{},
    media: ?MediaQueryList = null,
    media_parsed: bool = false,
    /// CSSOM "location": the URL it was fetched from; null for an embedded
    /// sheet (a style element's).
    location: ?[]u8 = null,
    /// The sheet's base URL ("style sheet base URL"): its location, or the
    /// node document's base URL when it has none.
    base_url: []u8 = &.{},
    /// CSSOM "origin-clean flag".
    origin_clean: bool = true,
    /// CSSOM "constructed flag", "disallow modification flag", and
    /// "constructor document" (a raw back link with its generation).
    constructed: bool = false,
    disallow_modification: bool = false,
    constructor_document: ?*runtime.Instance = null,
    constructor_document_generation: u64 = 0,
    mode: ParseMode = .{},
    /// The text, until it is parsed.
    text: ?[]u8 = null,
    /// CSSOM "CSS rules", once parsed; each held.
    rules: ?std.ArrayList(*Rule) = null,
    /// The @import rules as parsed, by the index the loader delivers their
    /// sheets by (null where CSS dropped one the loader still fetches);
    /// each held, so an import a CSSOM edit removed still finds its rule.
    import_slots: std.ArrayList(?*Rule) = .empty,
    /// The compiled index of `rules`, and the version it was made at.
    compiled: ?*Contents = null,
    compiled_version: u64 = 0,
    /// Moves whenever what the sheet contributes changes (an import
    /// arriving, a CSSOM edit, its media or disabled flag): the engine
    /// compares it with what it built from.
    contents_version: u64 = 1,
    /// The CSSStyleSheet object made for this sheet.
    object: ObjectLink = .{},

    pub const Options = struct {
        owner_node: ?*runtime.Instance = null,
        title: []const u8 = "",
        alternate: bool = false,
        media: []const u8 = "",
        location: ?[]const u8 = null,
        base_url: []const u8 = "",
        origin_clean: bool = true,
        mode: ParseMode = .{},
    };

    /// HTML "create a CSS style sheet" with `text` as its contents. The
    /// caller holds the one reference it returns with.
    pub fn create(allocator: Allocator, text: []const u8, options: Options) Allocator.Error!*SheetRecord {
        const self = try allocator.create(SheetRecord);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .owner_node = options.owner_node, .alternate = options.alternate, .origin_clean = options.origin_clean, .mode = options.mode };
        errdefer self.freeStrings();
        self.title = try allocator.dupe(u8, options.title);
        self.media_text = try allocator.dupe(u8, options.media);
        self.base_url = try allocator.dupe(u8, options.base_url);
        if (options.location) |l| self.location = try allocator.dupe(u8, l);
        self.text = try allocator.dupe(u8, text);
        return self;
    }

    fn freeStrings(self: *SheetRecord) void {
        self.allocator.free(self.title);
        self.allocator.free(self.media_text);
        self.allocator.free(self.base_url);
        if (self.location) |l| self.allocator.free(l);
        self.location = null;
        if (self.text) |t| self.allocator.free(t);
        self.text = null;
    }

    pub fn ref(self: *SheetRecord) void {
        self.refs += 1;
    }

    /// One holder lets the sheet go; the last frees it, and its rules (an
    /// import's sheet goes with its rule, unless something else holds it).
    pub fn unref(self: *SheetRecord) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        self.dropCompiled();
        for (self.import_slots.items) |slot| if (slot) |r| r.unref();
        self.import_slots.deinit(self.allocator);
        if (self.rules) |*list| {
            for (list.items) |r| {
                r.parent_sheet = null;
                r.unref();
            }
            list.deinit(self.allocator);
        }
        if (self.media) |*m| m.deinit();
        self.freeStrings();
        self.allocator.destroy(self);
    }

    /// CSSOM "remove a CSS style sheet" step 2, for the owner letting the
    /// sheet go: "Set the CSS style sheet's parent CSS style sheet, owner
    /// node and owner CSS rule to null." The caller then drops its hold.
    pub fn detach(self: *SheetRecord) void {
        self.owner_node = null;
        self.owner_rule = null;
    }

    /// CSSOM "parent CSS style sheet": the sheet whose @import rule this
    /// sheet is.
    pub fn parentSheet(self: *const SheetRecord) ?*SheetRecord {
        const rule = self.owner_rule orelse return null;
        return rule.sheet();
    }

    /// The constructor document, while it lives.
    pub fn constructorDocument(self: *const SheetRecord) ?*runtime.Instance {
        const document = self.constructor_document orelse return null;
        if (runtime.SlabAllocator.generationOf(document) != self.constructor_document_generation) return null;
        return document;
    }

    /// What the sheet contributes changed.
    pub fn changed(self: *SheetRecord) void {
        self.contents_version +%= 1;
    }

    /// The media changed (the owner's media attribute, MediaList).
    pub fn setMedia(self: *SheetRecord, text: []const u8) Allocator.Error!void {
        const copy = try self.allocator.dupe(u8, text);
        self.allocator.free(self.media_text);
        self.media_text = copy;
        if (self.media) |*m| m.deinit();
        self.media = null;
        self.media_parsed = false;
        self.changed();
    }

    /// The parsed media list (empty when the text is).
    pub fn mediaList(self: *SheetRecord) ?*const MediaQueryList {
        if (!self.media_parsed) {
            self.media_parsed = true;
            if (std.mem.trim(u8, self.media_text, " \t\n\r\x0c").len != 0) {
                self.media = MediaQueryList.parse(self.allocator, self.media_text) catch null;
            }
        }
        return if (self.media) |*m| m else null;
    }

    /// Whether the sheet's media matches (an empty media list matches).
    pub fn mediaMatches(self: *SheetRecord, values: *const MediaValues) bool {
        const media = self.mediaList() orelse return true;
        return media.matches(values);
    }

    /// The options the sheet's text and rules are parsed with; `context`
    /// lives as long as the parse.
    pub fn parseOptions(self: *const SheetRecord, context: *const UrlContext) css.properties.ParseOptions {
        return .{ .allocator = self.allocator, .quirks = self.mode.quirks, .url_resolver = context.resolver() };
    }

    /// The URL context for this sheet's url()s, the URL parser run on
    /// `instance`.
    pub fn urlContext(self: *const SheetRecord, instance: *runtime.Instance) UrlContext {
        return .{ .instance = instance, .base = self.base_url };
    }

    /// CSSOM "CSS rules": parsed from the kept text on first use.
    /// `instance` is an object of the realm url()s are parsed in.
    pub fn rulesOf(self: *SheetRecord, instance: *runtime.Instance) Allocator.Error!*std.ArrayList(*Rule) {
        var context = self.urlContext(instance);
        return self.rulesWith(self.parseOptions(&context));
    }

    pub fn rulesWith(self: *SheetRecord, options: css.properties.ParseOptions) Allocator.Error!*std.ArrayList(*Rule) {
        if (self.rules) |*list| return list;
        var list: std.ArrayList(*Rule) = .empty;
        errdefer {
            for (list.items) |r| r.unref();
            list.deinit(self.allocator);
        }
        var slots: std.ArrayList(?*Rule) = .empty;
        errdefer {
            for (slots.items) |slot| if (slot) |r| r.unref();
            slots.deinit(self.allocator);
        }
        try rules_mod.parseSheet(.{ .parse = options }, self.text orelse "", &list, &slots);
        for (list.items) |r| r.parent_sheet = self;
        self.rules = list;
        self.import_slots = slots;
        if (self.text) |t| self.allocator.free(t);
        self.text = null;
        return &self.rules.?;
    }

    /// CSSOM "set sheet's CSS rules to rules" (replace(), replaceSync()):
    /// the old rules lose their parent sheet.
    pub fn setRules(self: *SheetRecord, new_rules: std.ArrayList(*Rule)) void {
        if (self.rules) |*list| {
            for (list.items) |r| {
                r.parent_sheet = null;
                r.unref();
            }
            list.deinit(self.allocator);
        }
        if (self.text) |t| self.allocator.free(t);
        self.text = null;
        for (new_rules.items) |r| r.parent_sheet = self;
        self.rules = new_rules;
        self.changed();
    }

    fn dropCompiled(self: *SheetRecord) void {
        if (self.compiled) |c| c.destroy();
        self.compiled = null;
    }

    /// The sheet's rules, compiled for matching (and parsed first, if they
    /// are not yet), made again when the rules have changed.
    pub fn contentsOf(self: *SheetRecord, options: css.properties.ParseOptions) Allocator.Error!*Contents {
        if (self.compiled) |c| if (self.compiled_version == self.contents_version) return c;
        self.dropCompiled();
        const list = try self.rulesWith(options);
        self.compiled = try Contents.compile(self.allocator, list.items);
        self.compiled_version = self.contents_version;
        return self.compiled.?;
    }

    /// The import at `index` was fetched: `child` is its sheet (the hold is
    /// taken). Its rule is the one parsed at that index, still in the rules
    /// or not; with none (CSS dropped it), the sheet goes.
    pub fn attachImport(self: *SheetRecord, options: css.properties.ParseOptions, index: usize, child: *SheetRecord) Allocator.Error!void {
        _ = self.rulesWith(options) catch |err| {
            child.unref();
            return err;
        };
        const rule = (if (index < self.import_slots.items.len) self.import_slots.items[index] else null) orelse return child.unref();
        const import = &rule.data.import;
        if (import.child) |old| {
            old.owner_rule = null;
            old.unref();
        }
        import.child = child;
        child.owner_rule = rule;
        self.changed();
    }

    /// The import reached by `path` (indices of @import rules, outermost
    /// first), or null.
    pub fn importAt(self: *SheetRecord, path: []const u16) ?*SheetRecord {
        var record: *SheetRecord = self;
        for (path) |index| {
            if (index >= record.import_slots.items.len) return null;
            const rule = record.import_slots.items[index] orelse return null;
            record = rule.data.import.child orelse return null;
        }
        return record;
    }
};

/// What a MediaList is a view of: a sheet's media, or an @media or
/// @import rule's media query list. Held by the MediaList.
pub const MediaOf = union(enum) {
    sheet: *SheetRecord,
    rule: *Rule,
};

/// What a CSSRuleList lists: a sheet's CSS rules, or a group rule's child
/// CSS rules. Held by the list.
pub const RulesOf = union(enum) {
    sheet: *SheetRecord,
    rule: *Rule,
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
    /// The @media rule's list, in the rule tree.
    media: *const MediaQueryList,
    parent: ?u32,
};

/// An @import rule, as the cascade substitutes its sheet.
pub const ImportRule = struct {
    media: *const MediaQueryList,
    /// The rule's layer (`layer` / `layer(name)`), an index into `layers`.
    layer: ?u16,
    /// The sheet the loader fetched for it.
    child: ?*SheetRecord,
};

pub const Contents = struct {
    allocator: Allocator,
    /// The style rules indexed, in order (the tree holds them).
    style_rules: std.ArrayList(*Rule) = .empty,
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
    /// A sheet parsed on its own (`parse`: the UA sheet) owns its tree.
    owned_tree: ?std.ArrayList(*Rule) = null,

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

    /// A sheet of its own: `text` parsed into a tree this owns, compiled.
    pub fn parse(allocator: Allocator, text: []const u8, options: struct { quirks: bool = false, url_resolver: ?UrlResolver = null }) Allocator.Error!*Contents {
        var tree: std.ArrayList(*Rule) = .empty;
        var tree_owned = true;
        defer if (tree_owned) {
            for (tree.items) |r| r.unref();
            tree.deinit(allocator);
        };
        try rules_mod.parseSheet(.{ .parse = .{ .allocator = allocator, .quirks = options.quirks, .url_resolver = options.url_resolver } }, text, &tree, null);
        const self = try compile(allocator, tree.items);
        self.owned_tree = tree;
        tree_owned = false;
        return self;
    }

    /// The index of the rule tree `items` (a sheet's top-level rules).
    pub fn compile(allocator: Allocator, items: []const *Rule) Allocator.Error!*Contents {
        const self = try allocator.create(Contents);
        self.* = .{ .allocator = allocator, .buckets = .{} };
        errdefer self.destroy();
        var compiler: Compiler = .{ .contents = self };
        try compiler.ruleList(items, null, null);
        return self;
    }

    pub fn destroy(self: *Contents) void {
        const a = self.allocator;
        self.style_rules.deinit(a);
        self.rules.deinit(a);
        self.conditions.deinit(a);
        for (self.layers.items) |name| a.free(name);
        self.layers.deinit(a);
        self.imports.deinit(a);
        self.buckets.deinit(a);
        if (self.owned_tree) |*tree| {
            for (tree.items) |r| r.unref();
            tree.deinit(a);
        }
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
    position: u32 = 0,
    anonymous_layers: u32 = 0,

    /// Index a list of rules of the tree (CSS's ordering constraints were
    /// applied when the tree was built: an @import or @namespace here
    /// stands where one may).
    fn ruleList(self: *Compiler, items: []const *Rule, condition: ?u32, layer: ?u16) Allocator.Error!void {
        for (items) |rule| switch (rule.data) {
            .style => try self.styleRule(rule, condition, layer),
            .import => |*import| {
                // Cascade 5 2: `layer` puts the imported sheet in a new
                // anonymous layer, `layer(name)` in that layer.
                const import_layer: ?u16 = if (import.layer) |name| try self.declareLayer(null, name) else null;
                try self.contents.imports.append(self.contents.allocator, .{ .media = &import.media, .layer = import_layer, .child = import.child });
            },
            .namespace => |n| self.namespaceRule(n.prefix, n.uri),
            // A statement declares its layers' order.
            .layer_statement => |l| for (l.names) |name| {
                _ = try self.declareLayer(layer, name);
            },
            .media => |*m| {
                const index: u32 = @intCast(self.contents.conditions.items.len);
                try self.contents.conditions.append(self.contents.allocator, .{ .media = &m.list, .parent = condition });
                try self.ruleList(m.children.items, index, layer);
            },
            // CSS Conditional 3 6.1: decided once, when parsed.
            .supports => |*s| if (s.holds) try self.ruleList(s.children.items, condition, layer),
            .layer_block => |*l| {
                const sub = try self.declareLayer(layer, l.name orelse "");
                try self.ruleList(l.children.items, condition, sub);
            },
            // Descriptors, not style rules.
            .font_face, .page => {},
        };
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

    /// CSS Namespaces 3: the default namespace (no prefix) declared as
    /// HTML's.
    fn namespaceRule(self: *Compiler, prefix: []const u8, uri: []const u8) void {
        if (prefix.len == 0 and std.mem.eql(u8, uri, html_namespace)) self.contents.html_only = true;
    }

    fn styleRule(self: *Compiler, rule: *Rule, condition: ?u32, layer: ?u16) Allocator.Error!void {
        const a = self.contents.allocator;
        const style = &rule.data.style;
        try self.contents.style_rules.append(a, rule);
        const position = self.position;
        self.position += 1;
        for (style.selectors.selectors) |*complex| {
            const spec = complex.calculateSpecificity();
            const index: u32 = @intCast(self.contents.rules.items.len);
            try self.contents.rules.append(a, .{
                .complex = complex,
                .specificity = .{ .a = spec.id, .b = spec.class, .c = spec.element },
                .block = &style.block,
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

test "an @import whose URL holds a parenthesis keeps its media" {
    const contents = try Contents.parse(testing.allocator, "@import url('a.css?pipe=trickle(d1)'); @import url(b.css) print; p { color: red }", .{});
    defer contents.destroy();
    try testing.expectEqual(@as(usize, 2), contents.imports.items.len);
    try testing.expectEqual(@as(usize, 0), contents.imports.items[0].media.queries.len);
    try testing.expectEqual(@as(usize, 1), contents.imports.items[1].media.queries.len);
}

test "the HTML default namespace marks the sheet HTML-only" {
    const contents = try Contents.parse(testing.allocator, "@namespace \"http://www.w3.org/1999/xhtml\"; div { display: block }", .{});
    defer contents.destroy();
    try testing.expect(contents.html_only);
}

test "a record parses lazily, keeps its media, and owns its imports" {
    const record = try SheetRecord.create(testing.allocator, "@import url(a.css); @import url(b.css); p { color: red }", .{ .media = "print" });
    defer record.unref();
    try testing.expect(record.rules == null);
    try testing.expect(!record.mediaMatches(&.{}));
    const options: css.properties.ParseOptions = .{ .allocator = testing.allocator };
    const contents = try record.contentsOf(options);
    try testing.expectEqual(@as(usize, 1), contents.rules.items.len);
    try testing.expect(record.text == null);
    const child = try SheetRecord.create(testing.allocator, "q { color: blue }", .{});
    try record.attachImport(options, 1, child);
    try testing.expect(record.importAt(&.{1}) == child);
    try testing.expect(record.importAt(&.{0}) == null);
    try testing.expect(child.owner_rule != null);
    try testing.expect(child.parentSheet() == record);
    // The import's arrival moved the version: the index is made again, and
    // sees the child.
    const again = try record.contentsOf(options);
    try testing.expect(again.imports.items[1].child == child);
    try record.setMedia("");
    try testing.expect(record.mediaMatches(&.{}));
}

test "a record a second holder keeps outlives its owner's hold, its rules readable" {
    const record = try SheetRecord.create(testing.allocator, "@media print { a { color: red } }", .{});
    const rules = try record.rulesWith(.{ .allocator = testing.allocator });
    try testing.expectEqual(@as(usize, 1), rules.items.len);
    record.ref(); // the CSSStyleSheet object's hold
    record.detach();
    record.unref(); // the owner lets it go
    try testing.expectEqual(@as(usize, 1), record.rules.?.items.len);
    try testing.expect(record.rules.?.items[0].parent_sheet == record);
    record.unref();
}
