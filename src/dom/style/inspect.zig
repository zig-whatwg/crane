//! Read-only style cascade inspection for the CDP CSS domain
//! (`CSS.getMatchedStylesForNode`, `CSS.getInlineStylesForNode`,
//! `CSS.styleSheetAdded`).
//!
//! Runs against Crane's real `StyleEngine` (`engine.zig`) via an optional
//! stack-local collector on `Resolution` — zero struct layout changes and zero
//! runtime overhead on normal style resolution.

const std = @import("std");
const Allocator = std.mem.Allocator;
const css = @import("css");
const sheet_mod = @import("sheet.zig");
const style_rules = @import("rules.zig");

const SheetRecord = sheet_mod.SheetRecord;
const Contents = sheet_mod.Contents;
const RuleData = sheet_mod.RuleData;

pub const RawMatch = struct {
    rule: *style_rules.Rule,
    sheet: ?*SheetRecord,
    origin: css.cascade.Origin,
    source: css.cascade.Source,
    selector_index: u32,
};

pub const MatchedRule = struct {
    rule: *style_rules.Rule,
    sheet: ?*SheetRecord,
    origin: css.cascade.Origin,
    source: css.cascade.Source,
    /// 0-based indices into `rule.matchingSelectors().?.selectors` (sorted ascending).
    matching_selectors: []u32,
};

pub const PseudoMatches = struct {
    pseudo_type: []const u8,
    matches: []MatchedRule,
};

pub const KeyframesEntry = struct {
    rule: *style_rules.Rule,
    sheet: ?*SheetRecord,
};

pub const PropertyRuleEntry = struct {
    rule: *style_rules.Rule,
    sheet: ?*SheetRecord,
};

pub const RegisteredPropertyEntry = struct {
    name: []const u8,
    syntax: []const u8,
    inherits: bool,
    initial_value: ?[]const u8,
};

pub const ActiveSheetEntry = struct {
    record: *SheetRecord,
    is_shadow: bool,
};

pub const Inspection = struct {
    /// Matched CSS rules for the element, ordered LOWEST to HIGHEST cascade precedence
    /// (matching Blink's `InspectorCSSAgent::getMatchedStylesForNode`).
    matched_rules: []MatchedRule = &.{},
    /// Presentational hint declaration blocks (HTML/SVG attributes).
    presentation_hints: []*const css.declarations.DeclarationBlock = &.{},
    /// Matching pseudo-element rules (`::before`, `::after`, `::marker`, etc.).
    pseudo_matches: []PseudoMatches = &.{},
    /// Active `@keyframes` rules referenced by the element's `animation-name`.
    keyframes_rules: []KeyframesEntry = &.{},
    /// Active `@property` rules in the document.
    property_rules: []PropertyRuleEntry = &.{},
    /// Script-registered custom properties (`CSS.registerProperty`).
    registered_properties: []RegisteredPropertyEntry = &.{},

    pub fn deinit(self: *Inspection, allocator: Allocator) void {
        for (self.matched_rules) |m| allocator.free(m.matching_selectors);
        if (self.matched_rules.len > 0) allocator.free(self.matched_rules);
        if (self.presentation_hints.len > 0) allocator.free(self.presentation_hints);
        for (self.pseudo_matches) |pm| {
            for (pm.matches) |m| allocator.free(m.matching_selectors);
            if (pm.matches.len > 0) allocator.free(pm.matches);
        }
        if (self.pseudo_matches.len > 0) allocator.free(self.pseudo_matches);
        if (self.keyframes_rules.len > 0) allocator.free(self.keyframes_rules);
        if (self.property_rules.len > 0) allocator.free(self.property_rules);
        if (self.registered_properties.len > 0) allocator.free(self.registered_properties);
        self.* = .{};
    }
};

/// Stack-local collector passed through `Resolution.inspect_collector` during
/// `engine.inspectMatchedRules`.
pub const Collector = struct {
    allocator: Allocator,
    raw: std.ArrayList(RawMatch) = .empty,
    presentation_hints: std.ArrayList(*const css.declarations.DeclarationBlock) = .empty,

    pub fn deinit(self: *Collector) void {
        self.raw.deinit(self.allocator);
        self.presentation_hints.deinit(self.allocator);
    }

    pub fn reset(self: *Collector) void {
        self.raw.clearRetainingCapacity();
        self.presentation_hints.clearRetainingCapacity();
    }

    pub fn recordRule(
        self: *Collector,
        contents: *const Contents,
        rule_data: *const RuleData,
        source: css.cascade.Source,
        sheet: ?*SheetRecord,
    ) Allocator.Error!void {
        if (source.origin == .presentational_hint) {
            try self.presentation_hints.append(self.allocator, rule_data.block);
            return;
        }
        if (rule_data.position >= contents.style_rules.items.len) return;
        const rule_obj = contents.style_rules.items[rule_data.position];
        const sel_idx = selectorIndexOf(rule_obj, rule_data.complex);
        try self.raw.append(self.allocator, .{
            .rule = rule_obj,
            .sheet = sheet,
            .origin = source.origin,
            .source = source,
            .selector_index = sel_idx,
        });
    }

    pub fn recordHint(self: *Collector, block: *const css.declarations.DeclarationBlock) Allocator.Error!void {
        try self.presentation_hints.append(self.allocator, block);
    }

    /// Deduplicates by `(sheet, rule)`, keeps the highest-precedence `Source`
    /// among matching selectors of each rule, and sorts all rules from LOWEST
    /// to HIGHEST cascade precedence.
    pub fn buildMatchedRules(self: *const Collector, allocator: Allocator) Allocator.Error![]MatchedRule {
        if (self.raw.items.len == 0) return &.{};

        const Group = struct {
            rule: *style_rules.Rule,
            sheet: ?*SheetRecord,
            origin: css.cascade.Origin,
            source: css.cascade.Source,
            selectors: std.ArrayList(u32) = .empty,
        };
        var groups: std.ArrayList(Group) = .empty;
        defer {
            for (groups.items) |*g| g.selectors.deinit(allocator);
            groups.deinit(allocator);
        }

        for (self.raw.items) |item| {
            var found: ?*Group = null;
            for (groups.items) |*g| {
                if (g.rule == item.rule and g.sheet == item.sheet and g.origin == item.origin) {
                    found = g;
                    break;
                }
            }
            if (found) |g| {
                if (sourceLessThan(g.source, item.source)) {
                    g.source = item.source;
                }
                var has = false;
                for (g.selectors.items) |s| {
                    if (s == item.selector_index) {
                        has = true;
                        break;
                    }
                }
                if (!has) try g.selectors.append(allocator, item.selector_index);
            } else {
                var g: Group = .{
                    .rule = item.rule,
                    .sheet = item.sheet,
                    .origin = item.origin,
                    .source = item.source,
                };
                try g.selectors.append(allocator, item.selector_index);
                try groups.append(allocator, g);
            }
        }

        std.mem.sort(Group, groups.items, {}, struct {
            fn lessThan(_: void, a: Group, b: Group) bool {
                return sourceLessThan(a.source, b.source);
            }
        }.lessThan);

        const out = try allocator.alloc(MatchedRule, groups.items.len);
        var built: usize = 0;
        errdefer {
            for (out[0..built]) |m| allocator.free(m.matching_selectors);
            allocator.free(out);
        }
        for (groups.items) |*g| {
            std.mem.sort(u32, g.selectors.items, {}, std.sort.asc(u32));
            const sels = try allocator.dupe(u32, g.selectors.items);
            out[built] = .{
                .rule = g.rule,
                .sheet = g.sheet,
                .origin = g.origin,
                .source = g.source,
                .matching_selectors = sels,
            };
            built += 1;
        }
        return out;
    }
};

fn selectorIndexOf(rule: *const style_rules.Rule, complex: @FieldType(RuleData, "complex")) u32 {
    const list = rule.matchingSelectors() orelse return 0;
    const base = @intFromPtr(list.selectors.ptr);
    const ptr = @intFromPtr(complex);
    const stride = @sizeOf(@TypeOf(list.selectors[0]));
    if (ptr < base or stride == 0) return 0;
    const idx = (ptr - base) / stride;
    if (idx >= list.selectors.len) return 0;
    return @intCast(idx);
}

/// Normal-declaration CSS Cascade 5 + 6 precedence: returns true if `a` has
/// LOWER precedence than `b` (so sorting ascending yields lowest-to-highest).
pub fn sourceLessThan(a: css.cascade.Source, b: css.cascade.Source) bool {
    const a_orig = originRank(a.origin);
    const b_orig = originRank(b.origin);
    if (a_orig != b_orig) return a_orig < b_orig;

    // Context (outer tree wins over inner shadow tree for normal declarations;
    // lower tree_depth = outer = higher precedence, so deeper comes earlier).
    if (a.tree_depth != b.tree_depth) return a.tree_depth > b.tree_depth;

    // Cascade layers: earlier declared layer loses to later; unlayered wins all.
    if (a.layer != b.layer) return a.layer < b.layer;

    // Element-attached (inline style) beats non-element-attached.
    if (a.element_attached != b.element_attached) return !a.element_attached;

    // Specificity (a, b, c).
    if (a.specificity.a != b.specificity.a) return a.specificity.a < b.specificity.a;
    if (a.specificity.b != b.specificity.b) return a.specificity.b < b.specificity.b;
    if (a.specificity.c != b.specificity.c) return a.specificity.c < b.specificity.c;

    // Scope proximity: larger hops loses to fewer hops (no_scope = maxInt loses).
    if (a.scope_proximity != b.scope_proximity) return a.scope_proximity > b.scope_proximity;

    // Order of appearance: earlier loses to later.
    return a.order < b.order;
}

fn originRank(o: css.cascade.Origin) u8 {
    return switch (o) {
        .user_agent => 0,
        .user => 1,
        .presentational_hint => 2,
        .author => 3,
        .animation => 4,
        .transition => 5,
    };
}
