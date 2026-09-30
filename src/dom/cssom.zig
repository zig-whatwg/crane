//! The CSSOM's model: what CSSStyleSheet, CSSRuleList and the CSSRule
//! objects wrap.
//!
//! Blink's split: a CSSStyleSheet wraps its StyleSheetContents, a
//! CSSStyleRule a StyleRule, and a CSSRuleList reads its sheet's rules. The
//! objects script sees are made on demand; the model is what they read. Here
//! the model is a `Sheet` - CSSOM's "CSS rules" of a CSSStyleSheet, and its
//! constructed / disallow-modification flags - and a `StyleRule` per CSS
//! style rule, shared by the sheet that holds it and the CSSStyleRule object
//! made for it. Each owning impl binds its object to its model here and
//! unbinds it in its deinit; the others read the model through this module,
//! never through another impl.
//!
//! A style sheet's rules come from src/css/rules.zig ("parse a stylesheet's
//! contents"); a style rule is kept only when its selector parses as a
//! selector list (src/selector/), as CSS drops a style rule whose selector is
//! invalid.
//!
//! TODO(cssom): at-rules. A constructed sheet's @import rules are dropped as
//! replaceSync() says; every other at-rule (@media - CSSMediaRule, @supports
//! - CSSSupportsRule, @font-face - CSSFontFaceRule, @keyframes -
//! CSSKeyframesRule, @page, @layer, @container, @namespace, ...) has no model
//! or CSSOM object yet, and is left out of the sheet's rules - so a sheet
//! with an @media rule reports a cssRules.length without it.
//!
//! lint-impls: hook for CSSStyleSheet, CSSRuleList, CSSRule, CSSStyleRule
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-style-sheets
//! Spec: https://drafts.csswg.org/cssom-1/#css-rules

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const selector = @import("selector");

/// The model lives as long as the objects that hold it, whichever realm
/// they are in.
const allocator = std.heap.c_allocator;

/// A link to an Instance that may be freed without telling the holder: the
/// slab reuses a freed Instance's address, and its generation says whether
/// the address still names the object the link was taken on.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The instance, while it is still the object this link was taken on.
    pub fn get(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

// ============================================================================
// Style rules
// ============================================================================

/// A CSS style rule: its selector list and its declarations - the model a
/// CSSStyleRule wraps. Held by the sheet whose rules include it and by the
/// CSSStyleRule object made for it: counted.
pub const StyleRule = struct {
    refs: u32 = 1,
    /// The selector, serialized.
    selector_text: []u8,
    /// Owned.
    declarations: []css.rules.Declaration,
    /// CSSOM "parent CSS style sheet": the sheet whose CSS rules hold this
    /// rule; null once it is removed from them.
    parent: ?Link = null,

    fn create(selector_text: []const u8, declarations: []const css.rules.Declaration) !*StyleRule {
        const self = try allocator.create(StyleRule);
        errdefer allocator.destroy(self);
        const text = try allocator.dupe(u8, selector_text);
        errdefer allocator.free(text);
        const copies = try allocator.alloc(css.rules.Declaration, declarations.len);
        var made: usize = 0;
        errdefer {
            for (copies[0..made]) |d| {
                allocator.free(d.name);
                allocator.free(d.value);
            }
            allocator.free(copies);
        }
        for (declarations, 0..) |d, i| {
            const name = try allocator.dupe(u8, d.name);
            errdefer allocator.free(name);
            copies[i] = .{ .name = name, .value = try allocator.dupe(u8, d.value), .important = d.important };
            made += 1;
        }
        self.* = .{ .selector_text = text, .declarations = copies };
        return self;
    }

    pub fn ref(self: *StyleRule) void {
        self.refs += 1;
    }

    pub fn unref(self: *StyleRule) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        for (self.declarations) |d| {
            allocator.free(d.name);
            allocator.free(d.value);
        }
        allocator.free(self.declarations);
        allocator.free(self.selector_text);
        allocator.destroy(self);
    }

    /// CSSOM "serialize a CSS declaration block" of the rule's declarations:
    /// each "name: value;" (with " !important" before the ";" when it is),
    /// joined by a space. Owned by `alloc`.
    pub fn declarationsText(self: *const StyleRule, alloc: std.mem.Allocator) ![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(alloc);
        for (self.declarations, 0..) |d, i| {
            if (i > 0) try out.append(alloc, ' ');
            try out.appendSlice(alloc, d.name);
            try out.appendSlice(alloc, ": ");
            try out.appendSlice(alloc, d.value);
            if (d.important) try out.appendSlice(alloc, " !important");
            try out.append(alloc, ';');
        }
        return out.toOwnedSlice(alloc);
    }

    /// CSSOM "serialize a CSS rule" for a CSSStyleRule: the selector, " {",
    /// the declaration block with a space either side when it has any, "}".
    /// Owned by `alloc`.
    pub fn cssText(self: *const StyleRule, alloc: std.mem.Allocator) ![]u8 {
        const block = try self.declarationsText(alloc);
        defer alloc.free(block);
        if (block.len == 0) return std.fmt.allocPrint(alloc, "{s} {{ }}", .{self.selector_text});
        return std.fmt.allocPrint(alloc, "{s} {{ {s} }}", .{ self.selector_text, block });
    }
};

// ============================================================================
// Style sheets
// ============================================================================

/// A CSSStyleSheet's model: its CSS rules and the flags CSSOM gives it.
pub const Sheet = struct {
    /// CSSOM "CSS rules", in order; each held (counted).
    rules: std.ArrayList(*StyleRule) = .empty,
    /// CSSOM "constructed flag".
    constructed: bool = false,
    /// CSSOM "disallow modification flag".
    disallow_modification: bool = false,

    /// Remove every rule: each one's parent CSS style sheet becomes null.
    fn clearRules(self: *Sheet) void {
        for (self.rules.items) |rule| {
            rule.parent = null;
            rule.unref();
        }
        self.rules.clearRetainingCapacity();
    }

    /// The number of CSS rules.
    pub fn length(self: *const Sheet) usize {
        return self.rules.items.len;
    }

    /// The CSS rule at `index`, or null past the end.
    pub fn ruleAt(self: *const Sheet, index: usize) ?*StyleRule {
        if (index >= self.rules.items.len) return null;
        return self.rules.items[index];
    }
};

/// Every sheet's model, by its CSSStyleSheet object: a sheet's impl binds it
/// at construction and unbinds it in its deinit, so an address is here only
/// while its object lives. Per thread: a sheet and its realm live on one.
threadlocal var sheets: std.AutoHashMapUnmanaged(*runtime.Instance, *Sheet) = .empty;

/// Bind a new CSSStyleSheet object to a new, empty model.
pub fn createSheet(instance: *runtime.Instance) !*Sheet {
    const sheet = try allocator.create(Sheet);
    errdefer allocator.destroy(sheet);
    sheet.* = .{};
    try sheets.put(allocator, instance, sheet);
    return sheet;
}

/// The model of the CSSStyleSheet object `instance`.
pub fn sheetOf(instance: *runtime.Instance) ?*Sheet {
    return sheets.get(instance);
}

/// The CSSStyleSheet object is going: its rules are removed, and its model
/// freed.
pub fn destroySheet(instance: *runtime.Instance) void {
    const entry = sheets.fetchRemove(instance) orelse return;
    const sheet = entry.value;
    sheet.clearRules();
    sheet.rules.deinit(allocator);
    allocator.destroy(sheet);
}

/// CSSOM "synchronously replace the rules of a CSSStyleSheet", from its step
/// 2 on: "Let rules be the result of running parse a stylesheet's contents
/// from text. If rules contains one or more @import rules, remove those
/// rules from rules. Set sheet's CSS rules to rules." (Steps 1 - the
/// constructed and disallow-modification checks - are the caller's.)
///
/// Spec: https://drafts.csswg.org/cssom-1/#synchronously-replace-the-rules-of-a-cssstylesheet
pub fn replaceRules(sheet_instance: *runtime.Instance, text: []const u8) !void {
    const sheet = sheetOf(sheet_instance) orelse return error.InvalidStateError;
    var parsed = try css.rules.parseStyleSheetContents(allocator, text);
    defer parsed.deinit();

    var rules: std.ArrayList(*StyleRule) = .empty;
    errdefer {
        for (rules.items) |rule| rule.unref();
        rules.deinit(allocator);
    }
    for (parsed.items) |rule| {
        switch (rule.kind) {
            .qualified => {
                // A style rule whose selector list does not parse is invalid,
                // and dropped.
                if (!isValidSelectorList(rule.prelude)) continue;
                const style_rule = try StyleRule.create(rule.prelude, rule.declarations);
                errdefer style_rule.unref();
                try rules.append(allocator, style_rule);
            },
            // @import is removed by replaceSync itself. TODO(cssom): every
            // other at-rule - see this file's header.
            .at_rule => continue,
        }
    }

    sheet.clearRules();
    sheet.rules.deinit(allocator);
    sheet.rules = rules;
    const parent = Link.to(sheet_instance);
    for (sheet.rules.items) |rule| rule.parent = parent;
}

/// CSSStyleRule's selectorText setter: replace the rule's selectors with
/// `text` when it parses as a group of selectors; false, and nothing
/// changed, when it does not.
pub fn setSelectorText(model: *StyleRule, text: []const u8) !bool {
    const trimmed = std.mem.trim(u8, text, " \t\n\r\x0c");
    if (!isValidSelectorList(trimmed)) return false;
    const copy = try allocator.dupe(u8, trimmed);
    allocator.free(model.selector_text);
    model.selector_text = copy;
    return true;
}

/// Whether `text` parses as a <selector-list>, all of it.
fn isValidSelectorList(text: []const u8) bool {
    if (text.len == 0) return false;
    var tokens = selector.Tokenizer.init(allocator, text);
    var parser = selector.Parser.init(allocator, &tokens) catch return false;
    defer parser.deinit();
    var list = parser.parse() catch return false;
    list.deinit();
    // The parser stops at a token that continues no selector; the list is
    // valid only if that is the end of the input.
    while (parser.current_token) |token| {
        switch (token.tag) {
            .whitespace => parser.current_token = tokens.nextToken() catch return false,
            .eof => return true,
            else => return false,
        }
    }
    return true;
}

// ============================================================================
// Rule lists and rule objects
// ============================================================================

/// Each CSSRuleList object's sheet, while the list lives.
threadlocal var rule_lists: std.AutoHashMapUnmanaged(*runtime.Instance, Link) = .empty;

/// The CSSRuleList object `list` is the CSS rules of the CSSStyleSheet
/// object `sheet_instance`.
pub fn bindRuleList(list: *runtime.Instance, sheet_instance: *runtime.Instance) !void {
    try rule_lists.put(allocator, list, Link.to(sheet_instance));
}

pub fn unbindRuleList(list: *runtime.Instance) void {
    _ = rule_lists.remove(list);
}

/// The sheet model whose rules the CSSRuleList object `list` reads - null
/// once that sheet has gone.
pub fn ruleListSheet(list: *runtime.Instance) ?*Sheet {
    const link = rule_lists.get(list) orelse return null;
    const sheet_instance = link.get() orelse return null;
    return sheetOf(sheet_instance);
}

/// Each CSSRule object's model, held (counted) while the object lives.
threadlocal var rule_objects: std.AutoHashMapUnmanaged(*runtime.Instance, *StyleRule) = .empty;

/// The CSSStyleRule object `rule_instance` wraps `model`, which it holds.
pub fn bindRule(rule_instance: *runtime.Instance, model: *StyleRule) !void {
    try rule_objects.put(allocator, rule_instance, model);
    model.ref();
}

pub fn unbindRule(rule_instance: *runtime.Instance) void {
    const entry = rule_objects.fetchRemove(rule_instance) orelse return;
    entry.value.unref();
}

/// The model the CSSRule object `rule_instance` wraps.
pub fn ruleOf(rule_instance: *runtime.Instance) ?*StyleRule {
    return rule_objects.get(rule_instance);
}

/// The CSSStyleSheet object a rule's parent CSS style sheet is, while it
/// lives.
pub fn parentSheetOf(model: *const StyleRule) ?*runtime.Instance {
    const link = model.parent orelse return null;
    return link.get();
}

// ============================================================================
// Tests
// ============================================================================

test "StyleRule serializes its declaration block and its rule" {
    const declarations = [_]css.rules.Declaration{
        .{ .name = @constCast("color"), .value = @constCast("red"), .important = false },
        .{ .name = @constCast("content"), .value = @constCast("\"x\""), .important = true },
    };
    const rule = try StyleRule.create("div > p", &declarations);
    defer rule.unref();
    const block = try rule.declarationsText(std.testing.allocator);
    defer std.testing.allocator.free(block);
    try std.testing.expectEqualStrings("color: red; content: \"x\" !important;", block);
    const text = try rule.cssText(std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("div > p { color: red; content: \"x\" !important; }", text);

    const empty = try StyleRule.create("p", &.{});
    defer empty.unref();
    const empty_text = try empty.cssText(std.testing.allocator);
    defer std.testing.allocator.free(empty_text);
    try std.testing.expectEqualStrings("p { }", empty_text);
}

test "isValidSelectorList: the whole prelude must be a selector list" {
    try std.testing.expect(isValidSelectorList("div"));
    try std.testing.expect(isValidSelectorList("#test4b"));
    try std.testing.expect(isValidSelectorList("div > p.x, #id"));
    try std.testing.expect(!isValidSelectorList("#test4 }"));
    try std.testing.expect(!isValidSelectorList(""));
}
