//! The CDP `CSS` domain on page sessions (`CSS.enable`, `CSS.disable`,
//! `CSS.getStyleSheetText`, `CSS.getComputedStyleForNode`,
//! `CSS.getInlineStylesForNode`, `CSS.getMatchedStylesForNode`,
//! `CSS.getEnvironmentVariables`, `CSS.styleSheetAdded`).
//!
//! Reads directly from Crane's real `dom.style` engine (`inspectMatchedRules`,
//! `activeStyleSheets`, `computedStyle`, `inline_style`) and pairs matched
//! rules with raw stylesheet source ranges (retained behind `titlesObserved`
//! only while DevTools has adopted a Browser).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const css = dom.style.css;
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const frames = @import("../frames.zig");
const dom_domain = @import("dom.zig");

const C = protocol.CSS;
const D = protocol.DOM;
const SheetRecord = dom.style.SheetRecord;
const StyleRule = dom.style.Rule;
const NodeBase = dom.NodeBase;

/// Per-session state of the CSS domain.
pub const State = struct {
    enabled: bool = false,
    next_sheet_id: u64 = 1,
    /// Active stylesheets announced/bound in this session, keyed by
    /// `@intFromPtr(record)`. Each entry holds a `record.ref()` until cleared.
    sheets: std.AutoArrayHashMapUnmanaged(usize, BoundSheet) = .empty,

    const BoundSheet = struct {
        id: []u8,
        record: *SheetRecord,
        announced: bool = false,
    };

    fn clear(self: *State, allocator: Allocator) void {
        for (self.sheets.values()) |entry| {
            entry.record.unref();
            allocator.free(entry.id);
        }
        self.sheets.clearRetainingCapacity();
    }

    fn deinit(self: *State, allocator: Allocator) void {
        self.clear(allocator);
        self.sheets.deinit(allocator);
    }
};

pub fn sessionEnded(session: *PageSession) void {
    session.states.CSS.enabled = false;
    session.states.CSS.deinit(session.allocator);
}

pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    if (milestone.navigable_id != session.tab) return;
    switch (milestone.event) {
        .committed => {
            session.states.CSS.clear(session.allocator);
        },
        else => {},
    }
}

pub fn enable(session: *PageSession, _: C.enable.Params) !C.enable.Result {
    const st = &session.states.CSS;
    if (!st.enabled) {
        st.enabled = true;
    }
    if (dom_domain.topDocument(session)) |doc| {
        try syncStyleSheets(session, doc);
    }
    return .{};
}

pub fn disable(session: *PageSession, _: C.disable.Params) !C.disable.Result {
    const st = &session.states.CSS;
    st.enabled = false;
    st.clear(session.allocator);
    return .{};
}

pub fn getEnvironmentVariables(_: *PageSession, _: C.getEnvironmentVariables.Params) !C.getEnvironmentVariables.Result {
    return .{ .environmentVariables = .{ .object = .empty } };
}

pub fn getStyleSheetText(session: *PageSession, params: C.getStyleSheetText.Params) !C.getStyleSheetText.Result {
    const st = &session.states.CSS;
    const arena = session.arena.?;
    for (st.sheets.values()) |entry| {
        if (std.mem.eql(u8, entry.id, params.styleSheetId)) {
            const text = try rawSheetText(arena, entry.record);
            return .{ .text = text };
        }
    }
    return session.fail("No style sheet with given id found");
}

pub fn getComputedStyleForNode(session: *PageSession, params: C.getComputedStyleForNode.Params) !C.getComputedStyleForNode.Result {
    const element = try dom_domain.elementNamed(session, params.nodeId);
    const arena = session.arena.?;
    var out: std.ArrayList(C.CSSComputedStyleProperty) = .empty;

    const held = (dom.style.engine.computedStyle(element, null) catch return error.OutOfMemory) orelse {
        return .{ .computedStyle = &.{}, .extraFields = .{ .isAppearanceBase = false } };
    };
    defer held.release();

    const style = held.style;
    var buf: std.ArrayList(u8) = .empty;
    for (css.properties.lexicographic) |l| {
        buf.clearRetainingCapacity();
        style.serializeResolved(l, &buf, arena) catch continue;
        const val = try arena.dupe(u8, buf.items);
        try out.append(arena, .{ .name = l.name(), .value = val });
    }
    return .{
        .computedStyle = out.items,
        .extraFields = .{ .isAppearanceBase = false },
    };
}

pub fn getInlineStylesForNode(session: *PageSession, params: C.getInlineStylesForNode.Params) !C.getInlineStylesForNode.Result {
    const element = try dom_domain.elementNamed(session, params.nodeId);
    const arena = session.arena.?;
    const inline_style = try buildInlineStyle(arena, element);
    var insp = try dom.style.engine.inspectMatchedRules(arena, element);
    defer insp.deinit(arena);
    const attrs_style = try buildAttributesStyle(arena, insp.presentation_hints);
    return .{
        .inlineStyle = inline_style,
        .attributesStyle = attrs_style,
    };
}

pub fn getMatchedStylesForNode(session: *PageSession, params: C.getMatchedStylesForNode.Params) !C.getMatchedStylesForNode.Result {
    const element = try dom_domain.elementNamed(session, params.nodeId);
    const arena = session.arena.?;
    if (interfaces.Node.get_ownerDocument(element) catch null) |doc| {
        try syncStyleSheets(session, doc);
    }

    var source_cache: SheetMapCache = .{ .arena = arena };
    var insp = try dom.style.engine.inspectMatchedRules(arena, element);
    defer insp.deinit(arena);

    const inline_style = try buildInlineStyle(arena, element);
    const attrs_style = try buildAttributesStyle(arena, insp.presentation_hints);
    const matched_rules = try buildRuleMatches(session, arena, &source_cache, insp.matched_rules);

    // Pseudo-element matches.
    var pseudo_list: std.ArrayList(C.PseudoElementMatches) = .empty;
    for (insp.pseudo_matches) |pm| {
        const pt = mapPseudoType(pm.pseudo_type) orelse continue;
        const pm_matches = try buildRuleMatches(session, arena, &source_cache, pm.matches);
        if (pm_matches.len > 0) {
            try pseudo_list.append(arena, .{
                .pseudoType = pt,
                .matches = pm_matches,
            });
        }
    }

    // Inherited chain (direct parent up to root element).
    var inherited_list: std.ArrayList(C.InheritedStyleEntry) = .empty;
    var parent_el = parentElementFlat(element);
    while (parent_el) |anc| {
        var anc_insp = try dom.style.engine.inspectMatchedRules(arena, anc);
        defer anc_insp.deinit(arena);
        const anc_inline = try buildInlineStyle(arena, anc);
        const anc_rules = try buildRuleMatches(session, arena, &source_cache, anc_insp.matched_rules);
        try inherited_list.append(arena, .{
            .inlineStyle = anc_inline,
            .matchedCSSRules = anc_rules,
        });
        parent_el = parentElementFlat(anc);
    }

    // Referenced @keyframes rules.
    var kf_list: std.ArrayList(C.CSSKeyframesRule) = .empty;
    for (insp.keyframes_rules) |kf| {
        if (try buildKeyframesRule(session, arena, &source_cache, kf.rule, kf.sheet)) |rule_val| {
            try kf_list.append(arena, rule_val);
        }
    }

    // Active @property rules.
    var prop_rules_list: std.ArrayList(C.CSSPropertyRule) = .empty;
    for (insp.property_rules) |pr| {
        if (try buildPropertyRule(session, arena, &source_cache, pr.rule, pr.sheet)) |rule_val| {
            try prop_rules_list.append(arena, rule_val);
        }
    }

    // Scripted CSS.registerProperty registrations.
    var prop_regs_list: std.ArrayList(C.CSSPropertyRegistration) = .empty;
    for (insp.registered_properties) |reg| {
        try prop_regs_list.append(arena, .{
            .propertyName = try arena.dupe(u8, reg.name),
            .initialValue = if (reg.initial_value) |iv| .{ .text = try arena.dupe(u8, iv) } else null,
            .inherits = reg.inherits,
            .syntax = try arena.dupe(u8, reg.syntax),
        });
    }

    return .{
        .inlineStyle = inline_style,
        .attributesStyle = attrs_style,
        .matchedCSSRules = matched_rules,
        .pseudoElements = if (pseudo_list.items.len > 0) pseudo_list.items else null,
        .inherited = if (inherited_list.items.len > 0) inherited_list.items else null,
        .cssKeyframesRules = if (kf_list.items.len > 0) kf_list.items else null,
        .cssPropertyRules = if (prop_rules_list.items.len > 0) prop_rules_list.items else null,
        .cssPropertyRegistrations = if (prop_regs_list.items.len > 0) prop_regs_list.items else null,
    };
}

// ============================================================================
// Stylesheet registration & CSS.styleSheetAdded
// ============================================================================

fn syncStyleSheets(session: *PageSession, document: *runtime.Instance) !void {
    const arena = session.arena.?;
    const sheets = try dom.style.engine.activeStyleSheets(arena, document);
    for (sheets) |entry| {
        _ = try ensureSheetBound(session, entry.record, document);
    }
}

fn ensureSheetBound(session: *PageSession, record: *SheetRecord, document: ?*runtime.Instance) ![]const u8 {
    const st = &session.states.CSS;
    const key = @intFromPtr(record);
    if (st.sheets.getPtr(key)) |existing| {
        if (st.enabled and !existing.announced) {
            try emitStyleSheetAdded(session, existing.id, record, document);
            existing.announced = true;
        }
        return existing.id;
    }
    const id_num = st.next_sheet_id;
    st.next_sheet_id += 1;
    const id_str = try std.fmt.allocPrint(session.allocator, "{d}", .{id_num});
    errdefer session.allocator.free(id_str);
    record.ref();
    errdefer record.unref();
    try st.sheets.put(session.allocator, key, .{
        .id = id_str,
        .record = record,
        .announced = false,
    });
    if (st.enabled) {
        try emitStyleSheetAdded(session, id_str, record, document);
        st.sheets.getPtr(key).?.announced = true;
    }
    return id_str;
}

fn emitStyleSheetAdded(session: *PageSession, style_sheet_id: []const u8, record: *SheetRecord, document: ?*runtime.Instance) !void {
    const arena = session.arena.?;
    const text = try rawSheetText(arena, record);
    var start_line: u32 = 0;
    var start_col: u32 = 0;
    var is_inline = false;
    var source_url: []const u8 = "";

    if (record.location) |loc| {
        source_url = loc;
    } else if (!record.constructed) {
        if (record.owner_node) |owner| {
            const style_start = if (session.side) |side| side.styleStartOf(owner) else null;
            if (style_start) |pos| {
                start_line = pos.start_line;
                start_col = pos.start_col;
                is_inline = true;
                if (document) |doc| {
                    source_url = try documentUrl(arena, doc);
                }
            } else if (document) |doc| {
                // Dynamically created <style> element: Blink reports empty sourceURL;
                // startLine/startColumn = 0.
                const tag = if (dom.element_data.of(owner)) |ed| ed.localName() else "";
                if (std.ascii.eqlIgnoreCase(tag, "style")) {
                    is_inline = false;
                    source_url = "";
                } else {
                    source_url = try documentUrl(arena, doc);
                }
            }
        }
    }

    const end_pos = endLineCol(text, start_line, start_col);
    const owner_backend_id: ?i64 = if (record.owner_node) |owner| dom_domain.backendNodeIdFor(session, owner) else null;

    session.emit(C.styleSheetAdded, .{
        .header = .{
            .styleSheetId = style_sheet_id,
            .frameId = session.target_id.slice(),
            .sourceURL = source_url,
            .origin = .regular,
            .title = record.title,
            .ownerNode = owner_backend_id,
            .disabled = record.disabled,
            .isInline = is_inline,
            .isMutable = record.constructed or is_inline,
            .isConstructed = record.constructed,
            .startLine = @floatFromInt(start_line),
            .startColumn = @floatFromInt(start_col),
            .length = @floatFromInt(text.len),
            .endLine = @floatFromInt(end_pos.line),
            .endColumn = @floatFromInt(end_pos.col),
        },
    });
}

fn documentUrl(arena: Allocator, document: *runtime.Instance) Allocator.Error![]const u8 {
    const url = interfaces.Document.get_URL(document) catch return "";
    defer document.ctx.allocator.free(url);
    if (url.len == 0 or std.mem.eql(u8, url, "about:blank")) return "";
    return arena.dupe(u8, url);
}

fn endLineCol(text: []const u8, start_line: u32, start_col: u32) struct { line: u32, col: u32 } {
    var line = start_line;
    var col = start_col;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == '\r') {
            if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
            line += 1;
            col = 0;
        } else if (text[i] == '\n') {
            line += 1;
            col = 0;
        } else {
            col += 1;
        }
    }
    return .{ .line = line, .col = col };
}

fn rawSheetText(arena: Allocator, record: *SheetRecord) Allocator.Error![]const u8 {
    if (record.text) |t| return t;
    if (record.owner_node) |owner| {
        if (dom.element_data.of(owner)) |ed| {
            if (std.ascii.eqlIgnoreCase(ed.localName(), "style")) {
                if (dom.instance_bridge.getNodeBase(owner)) |nb| {
                    var buf: std.ArrayList(u8) = .empty;
                    var child = nb.firstChild();
                    while (child) |c| : (child = c.next_sibling) {
                        if (c.node_type == NodeBase.TEXT_NODE) {
                            if (instanceOfNode(c)) |ci| {
                                if (dom.character_data.dataOf(ci)) |td| try buf.appendSlice(arena, td);
                            }
                        }
                    }
                    if (buf.items.len > 0) return buf.items;
                }
            }
        }
    }
    // Fallback: serialize parsed rules.
    if (record.rules) |rules| {
        var out: std.ArrayList(u8) = .empty;
        for (rules.items, 0..) |r, i| {
            if (i > 0) try out.append(arena, '\n');
            if (r.serialize(arena)) |s| try out.appendSlice(arena, s) else |_| {}
        }
        return out.items;
    }
    return "";
}

// ============================================================================
// Building CDP CSSRule / CSSStyle / CSSProperty payloads
// ============================================================================

fn buildRuleMatches(
    session: *PageSession,
    arena: Allocator,
    cache: *SheetMapCache,
    matches: []const dom.style.inspect.MatchedRule,
) ![]const C.RuleMatch {
    var out: std.ArrayList(C.RuleMatch) = .empty;
    for (matches) |m| {
        const is_ua = m.origin == .user_agent;
        const sheet_id: ?[]const u8 = if (!is_ua) blk: {
            if (m.sheet) |rec| {
                const doc = if (rec.owner_node) |o| (interfaces.Node.get_ownerDocument(o) catch null) else dom_domain.topDocument(session);
                break :blk try ensureSheetBound(session, rec, doc);
            }
            break :blk null;
        } else null;

        const scanned: ?*const ScannedRule = if (!is_ua and m.sheet != null)
            try cache.findRule(m.sheet.?, m.rule)
        else
            null;

        const selector_list = try buildSelectorList(arena, m.rule, scanned);
        const css_style = if (scanned) |sc|
            try buildStyleFromScanned(arena, sheet_id, sc, m.rule.block())
        else
            try buildStyleFromBlock(arena, sheet_id, m.rule.block());

        const matching_sels = try arena.alloc(i64, m.matching_selectors.len);
        for (m.matching_selectors, 0..) |idx, i| matching_sels[i] = @intCast(idx);

        // Walk parent_rule chain (innermost to outermost) for cascade wrappers.
        var rule_types: std.ArrayList(C.CSSRuleType) = .empty;
        var medias: std.ArrayList(C.CSSMedia) = .empty;
        var containers: std.ArrayList(C.CSSContainerQuery) = .empty;
        var layers: std.ArrayList(C.CSSLayer) = .empty;
        var scopes: std.ArrayList(C.CSSScope) = .empty;
        var supports: std.ArrayList(C.CSSSupports) = .empty;
        var starting_styles: std.ArrayList(C.CSSStartingStyle) = .empty;
        var nesting_selectors: std.ArrayList([]const u8) = .empty;

        var parent = m.rule.parent_rule;
        while (parent) |p| : (parent = p.parent_rule) {
            const p_scan: ?*const ScannedRule = if (!is_ua and m.sheet != null)
                try cache.findRule(m.sheet.?, p)
            else
                null;
            switch (p.data) {
                .media => |*md| {
                    try rule_types.append(arena, .MediaRule);
                    const text = if (p_scan != null and p_scan.?.prelude.len > 0)
                        p_scan.?.prelude
                    else
                        try dom.style.rules.serializeMedia(arena, &md.list);
                    try medias.append(arena, .{
                        .text = text,
                        .source = .mediaRule,
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                    });
                },
                .container => |*ct| {
                    try rule_types.append(arena, .ContainerRule);
                    const cond_text = if (p_scan != null and p_scan.?.prelude.len > 0)
                        p_scan.?.prelude
                    else
                        try ct.conditions.serialize(arena);
                    const first_cond = if (ct.conditions.conditions.len > 0) &ct.conditions.conditions[0] else null;
                    const cname: ?[]const u8 = if (first_cond) |fc| (if (fc.name.len > 0) fc.name else null) else null;
                    const qtext: []const u8 = if (first_cond) |fc| (if (fc.query.len > 0) fc.query else cond_text) else cond_text;
                    const axes = containerAxes(qtext);
                    try containers.append(arena, .{
                        .text = qtext,
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                        .name = cname,
                        .physicalAxes = axes.physical,
                        .logicalAxes = axes.logical,
                        .queriesScrollState = axes.scroll_state,
                        .queriesAnchored = axes.anchored,
                        .conditionText = cond_text,
                    });
                },
                .layer_block => |*lb| {
                    try rule_types.append(arena, .LayerRule);
                    try layers.append(arena, .{
                        .text = lb.name orelse "",
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                    });
                },
                .scope => |*sc_rule| {
                    try rule_types.append(arena, .ScopeRule);
                    const stext = if (p_scan != null and p_scan.?.prelude.len > 0)
                        p_scan.?.prelude
                    else
                        try formatScopeText(arena, sc_rule.start, sc_rule.end);
                    try scopes.append(arena, .{
                        .text = stext,
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                    });
                },
                .supports => |*sup| {
                    try rule_types.append(arena, .SupportsRule);
                    const stext = if (p_scan != null and p_scan.?.prelude.len > 0)
                        p_scan.?.prelude
                    else
                        p.prelude;
                    try supports.append(arena, .{
                        .text = stext,
                        .active = sup.holds,
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                    });
                },
                .starting_style => {
                    try rule_types.append(arena, .StartingStyleRule);
                    try starting_styles.append(arena, .{
                        .range = if (p_scan) |ps| ps.prelude_range else null,
                        .styleSheetId = sheet_id,
                    });
                },
                .style => {
                    try rule_types.append(arena, .StyleRule);
                    const nsel = if (p_scan != null and p_scan.?.prelude.len > 0)
                        p_scan.?.prelude
                    else
                        p.prelude;
                    try nesting_selectors.append(arena, nsel);
                },
                else => {},
            }
        }

        try out.append(arena, .{
            .rule = .{
                .styleSheetId = sheet_id,
                .selectorList = selector_list,
                .nestingSelectors = if (nesting_selectors.items.len > 0) nesting_selectors.items else null,
                .origin = if (is_ua) .@"user-agent" else .regular,
                .style = css_style,
                .media = if (medias.items.len > 0) medias.items else null,
                .containerQueries = if (containers.items.len > 0) containers.items else null,
                .supports = if (supports.items.len > 0) supports.items else null,
                .layers = if (layers.items.len > 0) layers.items else null,
                .scopes = if (scopes.items.len > 0) scopes.items else null,
                .ruleTypes = if (rule_types.items.len > 0) rule_types.items else null,
                .startingStyles = if (starting_styles.items.len > 0) starting_styles.items else null,
            },
            .matchingSelectors = matching_sels,
        });
    }
    return out.items;
}

const ContainerAxesInfo = struct {
    physical: ?D.PhysicalAxes = null,
    logical: ?D.LogicalAxes = null,
    scroll_state: ?bool = null,
    anchored: ?bool = null,
};

fn containerAxes(query: []const u8) ContainerAxesInfo {
    var info: ContainerAxesInfo = .{};
    var has_h = false;
    var has_v = false;
    var has_inline = false;
    var has_block = false;
    if (containsAsciiIgnoreCase(query, "inline-size")) has_inline = true;
    if (containsAsciiIgnoreCase(query, "block-size")) has_block = true;
    if (containsAsciiIgnoreCase(query, "width")) has_h = true;
    if (containsAsciiIgnoreCase(query, "height")) has_v = true;
    if (containsAsciiIgnoreCase(query, "aspect-ratio") or containsAsciiIgnoreCase(query, "orientation")) {
        has_h = true;
        has_v = true;
    }
    if (has_h and has_v) {
        info.physical = .Both;
    } else if (has_h) {
        info.physical = .Horizontal;
    } else if (has_v) {
        info.physical = .Vertical;
    }
    if (has_inline and has_block) {
        info.logical = .Both;
    } else if (has_inline) {
        info.logical = .Inline;
    } else if (has_block) {
        info.logical = .Block;
    }
    if (containsAsciiIgnoreCase(query, "scroll-state(")) info.scroll_state = true;
    if (containsAsciiIgnoreCase(query, "anchored(")) info.anchored = true;
    return info;
}

fn containsAsciiIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

fn formatScopeText(arena: Allocator, start: ?[]const u8, end: ?[]const u8) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    if (start) |s| {
        try out.append(arena, '(');
        try out.appendSlice(arena, s);
        try out.append(arena, ')');
    }
    if (end) |e| {
        if (out.items.len > 0) try out.append(arena, ' ');
        try out.appendSlice(arena, "to (");
        try out.appendSlice(arena, e);
        try out.append(arena, ')');
    }
    return out.items;
}

fn buildSelectorList(arena: Allocator, rule: *const StyleRule, scanned: ?*const ScannedRule) Allocator.Error!C.SelectorList {
    var sels: std.ArrayList(C.Value) = .empty;
    const matching_sels = rule.matchingSelectors();
    if (scanned) |sc| {
        if (sc.selectors.len > 0) {
            for (sc.selectors, 0..) |sel, idx| {
                var spec: ?C.Specificity = null;
                if (matching_sels) |ms| {
                    if (idx < ms.selectors.len) {
                        const sp = ms.selectors[idx].calculateSpecificity();
                        spec = .{ .a = sp.id, .b = sp.class, .c = sp.element };
                    }
                }
                try sels.append(arena, .{
                    .text = sel.text,
                    .range = sel.range,
                    .specificity = spec,
                });
            }
            return .{
                .selectors = sels.items,
                .text = sc.prelude,
            };
        }
    }
    // Fallback: split rule.prelude on top-level commas.
    const raw_parts = try splitTopLevelCommas(arena, rule.prelude, null, 0);
    for (raw_parts, 0..) |part, idx| {
        var spec: ?C.Specificity = null;
        if (matching_sels) |ms| {
            if (idx < ms.selectors.len) {
                const sp = ms.selectors[idx].calculateSpecificity();
                spec = .{ .a = sp.id, .b = sp.class, .c = sp.element };
            }
        }
        try sels.append(arena, .{
            .text = part.text,
            .specificity = spec,
        });
    }
    return .{
        .selectors = sels.items,
        .text = rule.prelude,
    };
}

fn buildInlineStyle(arena: Allocator, element: *runtime.Instance) !?C.CSSStyle {
    const ed = dom.element_data.of(element) orelse return null;
    const attr = ed.findAttribute(null, "style") orelse return null;
    const raw = attr.value;
    var lines = try LineIndex.init(arena, raw);
    const scanned_decls = try scanDeclarations(arena, raw, 0, raw.len, &lines);
    const body_range: C.SourceRange = .{
        .startLine = 0,
        .startColumn = 0,
        .endLine = @intCast(lines.lineOf(raw.len)),
        .endColumn = @intCast(lines.colOf(raw.len)),
    };
    return try buildStyleFromDecls(arena, null, raw, body_range, scanned_decls, null);
}

fn buildAttributesStyle(arena: Allocator, hints: []const *const css.declarations.DeclarationBlock) !?C.CSSStyle {
    if (hints.len == 0) return null;
    var props: std.ArrayList(C.CSSProperty) = .empty;
    var buf: std.ArrayList(u8) = .empty;
    for (hints) |block| {
        try appendBlockProperties(arena, block, &props, &buf);
    }
    if (props.items.len == 0) return null;
    return .{
        .cssProperties = props.items,
        .shorthandEntries = &.{},
    };
}

fn buildStyleFromBlock(arena: Allocator, sheet_id: ?[]const u8, block_opt: ?*const css.declarations.DeclarationBlock) !C.CSSStyle {
    var props: std.ArrayList(C.CSSProperty) = .empty;
    var buf: std.ArrayList(u8) = .empty;
    if (block_opt) |block| {
        try appendBlockProperties(arena, block, &props, &buf);
    }
    return .{
        .styleSheetId = sheet_id,
        .cssProperties = props.items,
        .shorthandEntries = &.{},
    };
}

fn appendBlockProperties(
    arena: Allocator,
    block: *const css.declarations.DeclarationBlock,
    props: *std.ArrayList(C.CSSProperty),
    buf: *std.ArrayList(u8),
) Allocator.Error!void {
    var it = block.typed();
    while (it.next()) |d| {
        buf.clearRetainingCapacity();
        css.properties.serializeAssigned(d.longhand, d.value, buf, arena) catch continue;
        try props.append(arena, .{
            .name = d.longhand.name(),
            .value = try arena.dupe(u8, buf.items),
            .important = if (d.important) true else null,
            .parsedOk = true,
        });
    }
    var cit = block.customs();
    while (cit.next()) |c| {
        buf.clearRetainingCapacity();
        c.value.serialize(buf, arena) catch continue;
        try props.append(arena, .{
            .name = c.name.bytes,
            .value = try arena.dupe(u8, buf.items),
            .important = if (c.important) true else null,
            .parsedOk = true,
        });
    }
}

fn buildStyleFromScanned(
    arena: Allocator,
    sheet_id: ?[]const u8,
    sc: *const ScannedRule,
    block_opt: ?*const css.declarations.DeclarationBlock,
) !C.CSSStyle {
    return buildStyleFromDecls(arena, sheet_id, sc.body_text, sc.body_range, sc.declarations, block_opt);
}

fn buildStyleFromDecls(
    arena: Allocator,
    sheet_id: ?[]const u8,
    body_text: []const u8,
    body_range: C.SourceRange,
    decls: []const ScannedDecl,
    block_opt: ?*const css.declarations.DeclarationBlock,
) !C.CSSStyle {
    _ = block_opt;
    var props: std.ArrayList(C.CSSProperty) = .empty;
    var shorthands: std.ArrayList(C.ShorthandEntry) = .empty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    var val_buf: std.ArrayList(u8) = .empty;
    const parse_opts: css.properties.ParseOptions = .{ .allocator = arena };

    for (decls) |d| {
        const is_custom = std.mem.startsWith(u8, d.name, "--");
        if (is_custom) {
            const ok = css.rules.isDeclarationValue(d.value);
            try props.append(arena, .{
                .name = d.name,
                .value = d.value,
                .important = if (d.important) true else null,
                .text = d.text,
                .parsedOk = ok,
                .range = d.range,
            });
            continue;
        }
        const lower_name = try std.ascii.allocLowerString(arena, d.name);
        const lookup = css.properties.lookup(lower_name);
        if (lookup == null) {
            try props.append(arena, .{
                .name = lower_name,
                .value = d.value,
                .important = if (d.important) true else null,
                .text = d.text,
                .parsedOk = false,
                .range = d.range,
            });
            continue;
        }
        assignments.clearRetainingCapacity();
        const parsed_ok = css.properties.parseDeclaration(parse_opts, lookup.?, d.value, &assignments) catch false;
        defer for (assignments.items) |a| a.value.release();

        var longhands: ?[]const C.CSSProperty = null;
        if (parsed_ok and lookup.? == .shorthand) {
            var lh_list: std.ArrayList(C.CSSProperty) = .empty;
            for (assignments.items) |asgn| {
                val_buf.clearRetainingCapacity();
                css.properties.serializeAssigned(asgn.longhand, asgn.value, &val_buf, arena) catch continue;
                try lh_list.append(arena, .{
                    .name = asgn.longhand.name(),
                    .value = try arena.dupe(u8, val_buf.items),
                    .important = if (d.important) true else null,
                });
            }
            if (lh_list.items.len > 0) {
                longhands = lh_list.items;
            }
            try shorthands.append(arena, .{
                .name = lower_name,
                .value = d.value,
                .important = if (d.important) true else null,
            });
        }
        try props.append(arena, .{
            .name = lower_name,
            .value = d.value,
            .important = if (d.important) true else null,
            .text = d.text,
            .parsedOk = parsed_ok,
            .range = d.range,
            .longhandProperties = longhands,
        });
    }

    return .{
        .styleSheetId = sheet_id,
        .cssProperties = props.items,
        .shorthandEntries = shorthands.items,
        .cssText = body_text,
        .range = body_range,
    };
}

fn buildKeyframesRule(
    session: *PageSession,
    arena: Allocator,
    cache: *SheetMapCache,
    rule: *StyleRule,
    sheet: ?*SheetRecord,
) !?C.CSSKeyframesRule {
    if (rule.data != .keyframes) return null;
    const sheet_id: ?[]const u8 = if (sheet) |rec| blk: {
        const doc = if (rec.owner_node) |o| (interfaces.Node.get_ownerDocument(o) catch null) else dom_domain.topDocument(session);
        break :blk try ensureSheetBound(session, rec, doc);
    } else null;
    const kf_scan: ?*const ScannedRule = if (sheet) |rec| try cache.findRule(rec, rule) else null;

    var frames_list: std.ArrayList(C.CSSKeyframeRule) = .empty;
    for (rule.data.keyframes.children.items, 0..) |child, ci| {
        if (child.data != .keyframe) continue;
        const child_scan: ?*const ScannedRule = if (kf_scan) |ks|
            (if (ci < ks.children.len) &ks.children[ci] else null)
        else
            null;
        const key_text = child.prelude;
        const kf_style = if (child_scan) |cs|
            try buildStyleFromScanned(arena, sheet_id, cs, &child.data.keyframe.block)
        else
            try buildStyleFromBlock(arena, sheet_id, &child.data.keyframe.block);
        try frames_list.append(arena, .{
            .styleSheetId = sheet_id,
            .origin = .regular,
            .keyText = .{
                .text = key_text,
                .range = if (child_scan) |cs| cs.prelude_range else null,
            },
            .style = kf_style,
        });
    }
    if (frames_list.items.len == 0) return null;
    return .{
        .animationName = .{
            .text = rule.prelude,
            .range = if (kf_scan) |ks| ks.prelude_range else null,
        },
        .keyframes = frames_list.items,
    };
}

fn buildPropertyRule(
    session: *PageSession,
    arena: Allocator,
    cache: *SheetMapCache,
    rule: *StyleRule,
    sheet: ?*SheetRecord,
) !?C.CSSPropertyRule {
    if (rule.data != .property) return null;
    const reg = rule.data.property;
    const sheet_id: ?[]const u8 = if (sheet) |rec| blk: {
        const doc = if (rec.owner_node) |o| (interfaces.Node.get_ownerDocument(o) catch null) else dom_domain.topDocument(session);
        break :blk try ensureSheetBound(session, rec, doc);
    } else null;
    const pr_scan: ?*const ScannedRule = if (sheet) |rec| try cache.findRule(rec, rule) else null;

    var props: std.ArrayList(C.CSSProperty) = .empty;
    if (pr_scan) |ps| {
        for (ps.declarations) |d| {
            const lower = try std.ascii.allocLowerString(arena, d.name);
            try props.append(arena, .{
                .name = lower,
                .value = d.value,
                .text = d.text,
                .parsedOk = true,
                .range = d.range,
            });
        }
    } else {
        var syn_buf: std.ArrayList(u8) = .empty;
        try css.style_values.appendString(reg.syntax_text, &syn_buf, arena);
        try props.append(arena, .{ .name = "syntax", .value = syn_buf.items, .parsedOk = true });
        try props.append(arena, .{ .name = "inherits", .value = if (reg.inherits) "true" else "false", .parsedOk = true });
        if (reg.initial_text) |iv| {
            try props.append(arena, .{ .name = "initial-value", .value = iv, .parsedOk = true });
        }
    }

    return .{
        .styleSheetId = sheet_id,
        .origin = .regular,
        .propertyName = .{
            .text = reg.name,
            .range = if (pr_scan) |ps| ps.prelude_range else null,
        },
        .style = .{
            .styleSheetId = sheet_id,
            .cssProperties = props.items,
            .shorthandEntries = &.{},
            .cssText = if (pr_scan) |ps| ps.body_text else null,
            .range = if (pr_scan) |ps| ps.body_range else null,
        },
    };
}

fn mapPseudoType(name: []const u8) ?D.PseudoType {
    if (std.mem.eql(u8, name, "before")) return .before;
    if (std.mem.eql(u8, name, "after")) return .after;
    if (std.mem.eql(u8, name, "marker")) return .marker;
    if (std.mem.eql(u8, name, "first-line")) return .@"first-line";
    if (std.mem.eql(u8, name, "first-letter")) return .@"first-letter";
    if (std.mem.eql(u8, name, "selection")) return .selection;
    if (std.mem.eql(u8, name, "backdrop")) return .backdrop;
    if (std.mem.eql(u8, name, "highlight")) return .highlight;
    return null;
}

fn instanceOfNode(node: *NodeBase) ?*runtime.Instance {
    const ptr = dom.instance_bridge.getInstance(node) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

fn parentElementFlat(element: *runtime.Instance) ?*runtime.Instance {
    const nb = dom.instance_bridge.getNodeBase(element) orelse return null;
    if (dom.slot_helpers.slottable(nb)) |slottable| {
        if (slottable.state.assignedSlot()) |slot| {
            return instanceOfNode(slot);
        }
    }
    const p = nb.parent_node orelse return null;
    if (p.node_type == NodeBase.ELEMENT_NODE) {
        return instanceOfNode(p);
    }
    if (p.node_type == NodeBase.DOCUMENT_FRAGMENT_NODE) {
        if (instanceOfNode(p)) |frag| {
            if (frag.implements(interfaces.ShadowRoot.State)) {
                return interfaces.ShadowRoot.get_host(frag) catch null;
            }
        }
    }
    return null;
}

// ============================================================================
// On-demand CSS source scanner (using Crane's CSS Syntax 3 tokenizer)
// ============================================================================

const LineIndex = struct {
    starts: []usize,

    fn init(arena: Allocator, text: []const u8) Allocator.Error!LineIndex {
        var list: std.ArrayList(usize) = .empty;
        try list.append(arena, 0);
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            if (text[i] == '\r') {
                if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
                try list.append(arena, i + 1);
            } else if (text[i] == '\n') {
                try list.append(arena, i + 1);
            }
        }
        return .{ .starts = list.items };
    }

    fn lineOf(self: *const LineIndex, offset: usize) usize {
        var lo: usize = 0;
        var hi: usize = self.starts.len;
        while (lo + 1 < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.starts[mid] <= offset) lo = mid else hi = mid;
        }
        return lo;
    }

    fn colOf(self: *const LineIndex, offset: usize) usize {
        const line = self.lineOf(offset);
        return offset -| self.starts[line];
    }

    fn range(self: *const LineIndex, start: usize, end: usize) C.SourceRange {
        return .{
            .startLine = @intCast(self.lineOf(start)),
            .startColumn = @intCast(self.colOf(start)),
            .endLine = @intCast(self.lineOf(end)),
            .endColumn = @intCast(self.colOf(end)),
        };
    }
};

const ScannedSelector = struct {
    text: []const u8,
    range: ?C.SourceRange = null,
};

const ScannedDecl = struct {
    name: []const u8,
    value: []const u8,
    important: bool,
    text: []const u8,
    range: C.SourceRange,
};

const ScannedRule = struct {
    is_at_rule: bool = false,
    at_name: []const u8 = "",
    prelude: []const u8 = "",
    prelude_range: ?C.SourceRange = null,
    selectors: []ScannedSelector = &.{},
    body_text: []const u8 = "",
    body_range: C.SourceRange = .{ .startLine = 0, .startColumn = 0, .endLine = 0, .endColumn = 0 },
    declarations: []const ScannedDecl = &.{},
    children: []const ScannedRule = &.{},
};

const SheetMapCache = struct {
    arena: Allocator,
    entries: std.AutoArrayHashMapUnmanaged(usize, SheetScanned) = .empty,

    const SheetScanned = struct {
        map: std.AutoArrayHashMapUnmanaged(usize, *const ScannedRule) = .empty,
    };

    fn findRule(self: *SheetMapCache, record: *SheetRecord, target: *StyleRule) Allocator.Error!?*const ScannedRule {
        const key = @intFromPtr(record);
        if (self.entries.getPtr(key)) |cached| {
            return cached.map.get(@intFromPtr(target));
        }
        var scanned_entry: SheetScanned = .{};
        const text = try rawSheetText(self.arena, record);
        if (text.len > 0) {
            if (record.rules) |rules| {
                var lines = try LineIndex.init(self.arena, text);
                const top = try scanRuleList(self.arena, text, 0, text.len, &lines, false);
                try bindRuleList(self.arena, rules.items, top, &scanned_entry.map);
            }
        }
        try self.entries.put(self.arena, key, scanned_entry);
        return self.entries.getPtr(key).?.map.get(@intFromPtr(target));
    }
};

fn bindRuleList(
    arena: Allocator,
    parsed_rules: []const *StyleRule,
    scanned_rules: []const ScannedRule,
    out_map: *std.AutoArrayHashMapUnmanaged(usize, *const ScannedRule),
) Allocator.Error!void {
    var si: usize = 0;
    for (parsed_rules) |pr| {
        const want_at = pr.kind() != .style and pr.kind() != .keyframe and pr.kind() != .nested_declarations;
        if (pr.kind() == .nested_declarations) continue;
        // Find next matching scanned rule with same kind category.
        while (si < scanned_rules.len) : (si += 1) {
            const sr = &scanned_rules[si];
            if (sr.is_at_rule != want_at) continue;
            if (want_at and !atKindMatches(pr.kind(), sr.at_name)) continue;
            try out_map.put(arena, @intFromPtr(pr), sr);
            if (pr.children()) |kids| {
                try bindRuleList(arena, kids.items, sr.children, out_map);
            }
            si += 1;
            break;
        }
    }
}

fn atKindMatches(kind: dom.style.rules.Kind, at_name: []const u8) bool {
    return switch (kind) {
        .media => std.ascii.eqlIgnoreCase(at_name, "media"),
        .supports => std.ascii.eqlIgnoreCase(at_name, "supports"),
        .layer_block, .layer_statement => std.ascii.eqlIgnoreCase(at_name, "layer"),
        .container => std.ascii.eqlIgnoreCase(at_name, "container"),
        .scope => std.ascii.eqlIgnoreCase(at_name, "scope"),
        .starting_style => std.ascii.eqlIgnoreCase(at_name, "starting-style"),
        .keyframes => std.ascii.eqlIgnoreCase(at_name, "keyframes") or std.ascii.eqlIgnoreCase(at_name, "-webkit-keyframes"),
        .property => std.ascii.eqlIgnoreCase(at_name, "property"),
        .import => std.ascii.eqlIgnoreCase(at_name, "import"),
        .namespace => std.ascii.eqlIgnoreCase(at_name, "namespace"),
        .font_face => std.ascii.eqlIgnoreCase(at_name, "font-face"),
        .page => std.ascii.eqlIgnoreCase(at_name, "page"),
        .position_try => std.ascii.eqlIgnoreCase(at_name, "position-try"),
        else => true,
    };
}

fn scanRuleList(
    arena: Allocator,
    full_text: []const u8,
    start: usize,
    end: usize,
    lines: *const LineIndex,
    inside_style_rule: bool,
) Allocator.Error![]ScannedRule {
    var list: std.ArrayList(ScannedRule) = .empty;
    var i = start;
    while (i < end) {
        i = skipWsAndComments(full_text, i, end);
        if (i >= end) break;
        if (full_text[i] == ';') {
            i += 1;
            continue;
        }

        // At-rule starting with '@'
        if (full_text[i] == '@') {
            const at_start = i;
            i += 1;
            const name_start = i;
            while (i < end and isIdentChar(full_text[i])) : (i += 1) {}
            const at_name = full_text[name_start..i];
            const prelude_raw_start = skipWsAndComments(full_text, i, end);
            const term = findRuleTerminator(full_text, prelude_raw_start, end);
            const prelude_trimmed = trimRange(full_text, prelude_raw_start, term.pos);
            if (term.kind == .brace) {
                const close = findMatchingBrace(full_text, term.pos, end);
                const body_start = term.pos + 1;
                const body_end = close;
                const is_decl_only = std.ascii.eqlIgnoreCase(at_name, "property") or
                    std.ascii.eqlIgnoreCase(at_name, "font-face") or
                    std.ascii.eqlIgnoreCase(at_name, "position-try");
                const decls = if (is_decl_only)
                    try scanDeclarations(arena, full_text, body_start, body_end, lines)
                else
                    &.{};
                const kids = if (!is_decl_only)
                    try scanRuleList(arena, full_text, body_start, body_end, lines, false)
                else
                    &.{};
                try list.append(arena, .{
                    .is_at_rule = true,
                    .at_name = at_name,
                    .prelude = prelude_trimmed.slice,
                    .prelude_range = lines.range(prelude_trimmed.start, prelude_trimmed.end),
                    .body_text = full_text[body_start..body_end],
                    .body_range = lines.range(body_start, body_end),
                    .declarations = decls,
                    .children = kids,
                });
                i = if (close < end) close + 1 else end;
            } else {
                // Statement at-rule (e.g. @import, @layer foo, bar;)
                try list.append(arena, .{
                    .is_at_rule = true,
                    .at_name = at_name,
                    .prelude = prelude_trimmed.slice,
                    .prelude_range = lines.range(at_start, term.pos),
                });
                i = if (term.pos < end) term.pos + 1 else end;
            }
            continue;
        }

        // Inside a style rule, skip ordinary declarations (`prop: val;`) and
        // only collect nested rules (which end with `{ ... }` before `;`).
        const item_start = i;
        const term = findRuleTerminator(full_text, item_start, end);
        if (term.kind == .brace) {
            const close = findMatchingBrace(full_text, term.pos, end);
            const body_start = term.pos + 1;
            const body_end = close;
            const prelude_trimmed = trimRange(full_text, item_start, term.pos);
            const sels = try splitTopLevelCommas(arena, prelude_trimmed.slice, lines, prelude_trimmed.start);
            const decls = try scanDeclarations(arena, full_text, body_start, body_end, lines);
            const kids = try scanRuleList(arena, full_text, body_start, body_end, lines, true);
            try list.append(arena, .{
                .is_at_rule = false,
                .prelude = prelude_trimmed.slice,
                .prelude_range = lines.range(prelude_trimmed.start, prelude_trimmed.end),
                .selectors = sels,
                .body_text = full_text[body_start..body_end],
                .body_range = lines.range(body_start, body_end),
                .declarations = decls,
                .children = kids,
            });
            i = if (close < end) close + 1 else end;
        } else {
            _ = inside_style_rule;
            i = if (term.pos < end) term.pos + 1 else end;
        }
    }
    return list.items;
}

fn scanDeclarations(
    arena: Allocator,
    full_text: []const u8,
    start: usize,
    end: usize,
    lines: *const LineIndex,
) Allocator.Error![]ScannedDecl {
    var list: std.ArrayList(ScannedDecl) = .empty;
    var i = start;
    while (i < end) {
        i = skipWsAndComments(full_text, i, end);
        if (i >= end) break;
        if (full_text[i] == ';') {
            i += 1;
            continue;
        }
        const decl_start = i;
        const term = findRuleTerminator(full_text, decl_start, end);
        if (term.kind == .brace) {
            // Nested rule inside style block -> skip past its closing brace.
            const close = findMatchingBrace(full_text, term.pos, end);
            i = if (close < end) close + 1 else end;
            continue;
        }
        const decl_end = term.pos;
        const next_i = if (term.kind == .semicolon and term.pos < end) term.pos + 1 else term.pos;
        const full_end = if (term.kind == .semicolon and term.pos < end) term.pos + 1 else term.pos;

        // Parse `name : value [!important]` at top level.
        if (findTopLevelColon(full_text, decl_start, decl_end)) |colon_pos| {
            const name_tr = trimRange(full_text, decl_start, colon_pos);
            if (name_tr.slice.len > 0 and name_tr.slice[0] != '@' and name_tr.slice[0] != '&') {
                var val_tr = trimRange(full_text, colon_pos + 1, decl_end);
                var important = false;
                if (stripTrailingImportant(val_tr.slice)) |stripped| {
                    important = true;
                    val_tr.slice = stripped;
                }
                const text_tr = trimRange(full_text, decl_start, full_end);
                try list.append(arena, .{
                    .name = name_tr.slice,
                    .value = val_tr.slice,
                    .important = important,
                    .text = text_tr.slice,
                    .range = lines.range(text_tr.start, text_tr.end),
                });
            }
        }
        i = next_i;
    }
    return list.items;
}

fn stripTrailingImportant(value: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimEnd(u8, value, " \t\r\n\x0c");
    if (trimmed.len < 10) return null;
    const suffix_start = trimmed.len - 9;
    if (!std.ascii.eqlIgnoreCase(trimmed[suffix_start..], "important")) return null;
    const before_imp = std.mem.trimEnd(u8, trimmed[0..suffix_start], " \t\r\n\x0c");
    if (before_imp.len == 0 or before_imp[before_imp.len - 1] != '!') return null;
    return std.mem.trimEnd(u8, before_imp[0 .. before_imp.len - 1], " \t\r\n\x0c");
}

const Term = struct {
    kind: enum { brace, semicolon, eof },
    pos: usize,
};

fn findRuleTerminator(text: []const u8, start: usize, end: usize) Term {
    var i = start;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    while (i < end) {
        const c = text[i];
        if (c == '/' and i + 1 < end and text[i + 1] == '*') {
            i = skipComment(text, i, end);
            continue;
        }
        if (c == '"' or c == '\'') {
            i = skipString(text, i, end);
            continue;
        }
        if (c == '\\' and i + 1 < end) {
            i += 2;
            continue;
        }
        if (c == '(') {
            paren_depth += 1;
        } else if (c == ')' and paren_depth > 0) {
            paren_depth -= 1;
        } else if (c == '[') {
            bracket_depth += 1;
        } else if (c == ']' and bracket_depth > 0) {
            bracket_depth -= 1;
        } else if (paren_depth == 0 and bracket_depth == 0) {
            if (c == '{') return .{ .kind = .brace, .pos = i };
            if (c == ';') return .{ .kind = .semicolon, .pos = i };
        }
        i += 1;
    }
    return .{ .kind = .eof, .pos = end };
}

fn findMatchingBrace(text: []const u8, open_pos: usize, end: usize) usize {
    var i = open_pos + 1;
    var depth: usize = 1;
    while (i < end) {
        const c = text[i];
        if (c == '/' and i + 1 < end and text[i + 1] == '*') {
            i = skipComment(text, i, end);
            continue;
        }
        if (c == '"' or c == '\'') {
            i = skipString(text, i, end);
            continue;
        }
        if (c == '\\' and i + 1 < end) {
            i += 2;
            continue;
        }
        if (c == '{') {
            depth += 1;
        } else if (c == '}') {
            depth -= 1;
            if (depth == 0) return i;
        }
        i += 1;
    }
    return end;
}

fn findTopLevelColon(text: []const u8, start: usize, end: usize) ?usize {
    var i = start;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    while (i < end) {
        const c = text[i];
        if (c == '/' and i + 1 < end and text[i + 1] == '*') {
            i = skipComment(text, i, end);
            continue;
        }
        if (c == '"' or c == '\'') {
            i = skipString(text, i, end);
            continue;
        }
        if (c == '\\' and i + 1 < end) {
            i += 2;
            continue;
        }
        if (c == '(') paren_depth += 1 else if (c == ')' and paren_depth > 0) paren_depth -= 1 else if (c == '[') bracket_depth += 1 else if (c == ']' and bracket_depth > 0) bracket_depth -= 1 else if (c == ':' and paren_depth == 0 and bracket_depth == 0) return i;
        i += 1;
    }
    return null;
}

fn splitTopLevelCommas(
    arena: Allocator,
    text: []const u8,
    lines: ?*const LineIndex,
    base_offset: usize,
) Allocator.Error![]ScannedSelector {
    var out: std.ArrayList(ScannedSelector) = .empty;
    var seg_start: usize = 0;
    var i: usize = 0;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    while (i <= text.len) {
        const at_end = i == text.len;
        if (!at_end) {
            const c = text[i];
            if (c == '/' and i + 1 < text.len and text[i + 1] == '*') {
                i = skipComment(text, i, text.len);
                continue;
            }
            if (c == '"' or c == '\'') {
                i = skipString(text, i, text.len);
                continue;
            }
            if (c == '\\' and i + 1 < text.len) {
                i += 2;
                continue;
            }
            if (c == '(') {
                paren_depth += 1;
                i += 1;
                continue;
            }
            if (c == ')' and paren_depth > 0) {
                paren_depth -= 1;
                i += 1;
                continue;
            }
            if (c == '[') {
                bracket_depth += 1;
                i += 1;
                continue;
            }
            if (c == ']' and bracket_depth > 0) {
                bracket_depth -= 1;
                i += 1;
                continue;
            }
            if (c != ',' or paren_depth != 0 or bracket_depth != 0) {
                i += 1;
                continue;
            }
        }
        const tr = trimRange(text, seg_start, i);
        if (tr.slice.len > 0) {
            try out.append(arena, .{
                .text = tr.slice,
                .range = if (lines) |li| li.range(base_offset + tr.start, base_offset + tr.end) else null,
            });
        }
        seg_start = i + 1;
        i += 1;
    }
    return out.items;
}

const Trimmed = struct {
    slice: []const u8,
    start: usize,
    end: usize,
};

fn trimRange(text: []const u8, start: usize, end: usize) Trimmed {
    var s = start;
    var e = end;
    while (s < e and isWs(text[s])) : (s += 1) {}
    while (e > s and isWs(text[e - 1])) : (e -= 1) {}
    return .{ .slice = text[s..e], .start = s, .end = e };
}

fn isWs(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0c';
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '_';
}

fn skipWsAndComments(text: []const u8, start: usize, end: usize) usize {
    var i = start;
    while (i < end) {
        if (isWs(text[i])) {
            i += 1;
        } else if (text[i] == '/' and i + 1 < end and text[i + 1] == '*') {
            i = skipComment(text, i, end);
        } else {
            break;
        }
    }
    return i;
}

fn skipComment(text: []const u8, start: usize, end: usize) usize {
    var i = start + 2;
    while (i + 1 < end) : (i += 1) {
        if (text[i] == '*' and text[i + 1] == '/') return i + 2;
    }
    return end;
}

fn skipString(text: []const u8, start: usize, end: usize) usize {
    const quote = text[start];
    var i = start + 1;
    while (i < end) : (i += 1) {
        if (text[i] == '\\' and i + 1 < end) {
            i += 1;
        } else if (text[i] == quote) {
            return i + 1;
        }
    }
    return end;
}
