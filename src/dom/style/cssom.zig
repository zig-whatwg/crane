//! CSSOM's edits of a style sheet's rules (CSSOM 6.4 "insert a CSS rule",
//! "remove a CSS rule"; 6.1.2 replace() and replaceSync()), over the rule
//! tree (rules.zig) - for CSSStyleSheet and CSSGroupingRule, which own the
//! objects these are called on. Every edit moves the containing sheet's
//! version, so the cascade compiles the sheet again on its next read.
//!
//! Stated: an @import rule insertRule() adds to a sheet that is not
//! constructed is not fetched (its styleSheet stays null). Nested rules
//! use the nearest style/scope selector context; every selector replacement
//! needed by a deletion is prepared before the live list changes.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#insert-a-css-rule
//! Spec: https://drafts.csswg.org/cssom-1/#remove-a-css-rule

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const css = @import("css");
const sheet_mod = @import("sheet.zig");
const rules_mod = @import("rules.zig");
const objects = @import("objects.zig");

const SheetRecord = sheet_mod.SheetRecord;
const Rule = rules_mod.Rule;
const RulesOf = sheet_mod.RulesOf;

pub const InsertOptions = struct {
    /// CSSStyleSheet.insertRule() step 5: a constructed sheet takes no
    /// @import.
    forbid_import: bool = false,
};

/// The rule list `of` names, parsed first if it is a sheet's; `object` is
/// the object the edit was called on (its realm parses url()s).
fn listOf(of: RulesOf, object: *runtime.Instance) !*std.ArrayList(*Rule) {
    return switch (of) {
        .sheet => |record| record.rulesOf(object),
        .rule => |rule| rule.children() orelse error.InvalidStateError,
    };
}

/// The sheet whose rules `of` are in.
fn sheetOf(of: RulesOf) ?*SheetRecord {
    return switch (of) {
        .sheet => |record| record,
        .rule => |rule| rule.sheet(),
    };
}

/// CSSOM "insert a CSS rule" `text` in the rule list `of` at `index`, the
/// parse first (CSSStyleSheet.insertRule() steps 3-5 parse before "insert a
/// CSS rule" checks the index; CSSGroupingRule.insertRule() goes to "insert
/// a CSS rule" directly, `of` a rule).
pub fn insertRule(object: *runtime.Instance, of: RulesOf, text: []const u8, index: u32, options: InsertOptions) !u32 {
    const allocator = object.ctx.allocator;
    const list = try listOf(of, object);
    const record = sheetOf(of);
    const nested = of == .rule;
    // CSSGroupingRule: "insert a CSS rule" step 2 before its parse.
    if (nested and index > list.items.len) return error.IndexSizeError;
    // "Parse a CSS rule": parse a rule, then by the CSS specifications -
    // where it would stand, so that its own validity is all that decides
    // (its position is step 6's).
    const in_page = of == .rule and of.rule.kind() == .page;
    var context = if (record) |r|
        try @import("resource_loading.zig").ParseContext.forSheet(r, object, text)
    else
        @import("resource_loading.zig").ParseContext{ .parse = .{ .allocator = allocator }, .url_context = .{ .instance = object, .base = "" } };
    defer context.deinit();
    const parent: ?*Rule = if (of == .rule) of.rule else null;
    const in_style = if (parent) |p| rules_mod.hasStyleAncestor(p) else false;
    var promotion = rules_mod.ResolutionPlan{ .allocator = allocator };
    defer promotion.deinit();
    const build_options = rules_mod.BuildOptions{
        .parse = context.options(),
        .nesting = if (parent) |p| try rules_mod.nestingInside(p, &promotion) else null,
        .in_style = in_style,
    };
    const new_rule = rule: {
        if (in_page) {
            // Q53: valid non-margin rules reach the placement check below.
            var parsed = (try css.rules.parsePageMarginRule(allocator, text)) orelse
                (try css.rules.parseRule(allocator, text)) orelse return error.SyntaxError;
            defer parsed.deinitOwned(allocator);
            break :rule (if (css.rules.isPageMarginRule(parsed.name))
                try rules_mod.buildPageMargin(build_options, &parsed)
            else
                try rules_mod.build(build_options, &parsed, .imports_allowed)) orelse return error.SyntaxError;
        }
        if (try css.rules.parseRule(allocator, text)) |value| {
            var parsed = value;
            defer parsed.deinitOwned(allocator);
            if (try rules_mod.build(build_options, &parsed, .imports_allowed)) |built| break :rule built;
        }
        // CSSOM section 6.4, step 4. Browser-backed deviation: the nested
        // flag does NOT enable declaration fallback in a top-level media,
        // supports or layer group. A style OR scope context passes through
        // every conditional group (all three insert; Firefox/Safari parse,
        // Chrome drops parsed declarations under scope: 2026-10-27 probes
        // Q36/Q38, Chrome 156, Firefox 158, Safari 27).
        const declarations_allowed = build_options.nesting != null;
        if (!declarations_allowed) return error.SyntaxError;
        const declarations = try css.rules.parseDeclarationList(allocator, text);
        defer css.rules.freeDeclarationList(allocator, declarations);
        break :rule (try rules_mod.buildNestedDeclarations(build_options, declarations)) orelse return error.SyntaxError;
    };
    var inserted = false;
    defer if (!inserted) new_rule.unref();
    const kind = new_rule.kind();
    // CSSStyleSheet.insertRule() step 5.
    if (kind == .import and options.forbid_import) return error.SyntaxError;
    // 1-2. "If index is greater than length, then throw an IndexSizeError."
    if (index > list.items.len) return error.IndexSizeError;
    // 6. "If new rule cannot be inserted into list at the zero-indexed
    // position index due to constraints specified by CSS, then throw a
    // HierarchyRequestError": an @import or @namespace only at a sheet's
    // top level, @imports (and @layer statements) before everything else,
    // @namespace after them and before every other rule.
    if (in_page and kind != .margin) return error.HierarchyRequestError;
    try checkPosition(list.items, index, kind, nested);
    // Nesting 1 section 3.3. This restriction persists through @scope;
    // its nearest-selector context does not erase a style ancestor.
    if (in_style and !rules_mod.allowedNestedKind(kind)) return error.HierarchyRequestError;
    // 7. "If new rule is an @namespace at-rule, and list contains anything
    // other than @import at-rules, and @namespace at-rules, throw an
    // InvalidStateError exception."
    if (kind == .namespace) {
        for (list.items) |r| switch (r.kind()) {
            .import, .namespace => {},
            else => return error.InvalidStateError,
        };
    }
    // 8. "Insert new rule into list at the zero-indexed position index."
    try list.insert(allocator, index, new_rule);
    switch (of) {
        .sheet => |r| new_rule.parent_sheet = r,
        .rule => |owner| new_rule.parent_rule = owner,
    }
    inserted = true;
    promotion.apply();
    if (record) |r| r.changed();
    // 9. "Return index."
    return index;
}

fn checkPosition(items: []const *Rule, index: usize, kind: rules_mod.Kind, nested: bool) !void {
    if (nested) {
        if (kind == .import or kind == .namespace) return error.HierarchyRequestError;
        return;
    }
    switch (kind) {
        // Only @imports and @layer statements before it, and no @import or
        // @namespace... after it but imports.
        .import => {
            for (items[0..index]) |r| switch (r.kind()) {
                .import, .layer_statement => {},
                else => return error.HierarchyRequestError,
            };
        },
        .namespace => {
            for (items[0..index]) |r| switch (r.kind()) {
                .import, .namespace, .layer_statement => {},
                else => return error.HierarchyRequestError,
            };
            for (items[index..]) |r| if (r.kind() == .import) return error.HierarchyRequestError;
        },
        // A @layer statement may stand among the imports.
        .layer_statement => {
            for (items[index..]) |r| if (r.kind() == .namespace) return error.HierarchyRequestError;
        },
        else => {
            for (items[index..]) |r| switch (r.kind()) {
                .import, .namespace => return error.HierarchyRequestError,
                else => {},
            };
        },
    }
}

/// CSSOM "remove a CSS rule" from the rule list `of` at `index`.
pub fn removeRule(object: *runtime.Instance, of: RulesOf, index: u32) !void {
    const list = try listOf(of, object);
    // 1-2. "If index is greater than or equal to length, then throw an
    // IndexSizeError exception."
    if (index >= list.items.len) return error.IndexSizeError;
    // 3. "Set old rule to the indexth item in list."
    const old = list.items[index];
    // 4. "If old rule is an @namespace at-rule, and list contains anything
    // other than @import at-rules, and @namespace at-rules, throw an
    // InvalidStateError exception."
    if (old.kind() == .namespace) {
        for (list.items) |r| switch (r.kind()) {
            .import, .namespace => {},
            else => return error.InvalidStateError,
        };
    }
    // 5. "Remove rule old rule from list at the zero-indexed position
    // index." 6. "Set old rule's parent CSS rule and parent CSS style sheet
    // to null."
    // CSS Nesting 1 section 4: without this parent, & refers to scope.
    // Resolve the entire prospective detached subtree before changing
    // anything. OOM preserves the old list, selectors and compiled index.
    var plan = rules_mod.ResolutionPlan{ .allocator = old.allocator };
    defer plan.deinit();
    try plan.prepare(old, null, null);
    _ = list.orderedRemove(index);
    objects.ruleRemoved(old);
    plan.apply();
    if (sheetOf(of)) |r| r.changed();
    old.unref();
}

/// CSSOM "synchronously replace the rules of a CSSStyleSheet", steps 2-4
/// (step 1's checks are the caller's): "Let rules be the result of running
/// parse a stylesheet's contents from text. If rules contains one or more
/// @import rules, remove those rules from rules. Set sheet's CSS rules to
/// rules."
pub fn replaceRules(object: *runtime.Instance, record: *SheetRecord, text: []const u8) !void {
    var context = try @import("resource_loading.zig").ParseContext.forSheet(record, object, text);
    defer context.deinit();
    var new_rules: std.ArrayList(*Rule) = .empty;
    errdefer {
        for (new_rules.items) |r| r.unref();
        new_rules.deinit(record.allocator);
    }
    try rules_mod.parseSheet(.{ .parse = context.options() }, text, &new_rules, null);
    var i: usize = 0;
    while (i < new_rules.items.len) {
        if (new_rules.items[i].kind() == .import) {
            new_rules.orderedRemove(i).unref();
            continue;
        }
        i += 1;
    }
    // The old rules leave the sheet (a rule script still holds keeps its
    // data, with no parent).
    const old = try record.rulesOf(object);
    for (old.items) |r| objects.ruleRemoved(r);
    record.setRules(new_rules);
}

/// replace(text), its promise settled from a task (CSSStyleSheet.zig
/// states why). The sheet is kept alive until it runs.
pub fn replace(object: *runtime.Instance, record: *SheetRecord, text: []const u8) !runtime.JSValue {
    const realm = object.ctx;
    var capability = try engine.createPromise(realm);
    const promise = engine.retainValue(realm, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    errdefer promise.release();
    // 2. "If the constructed flag is not set, or the disallow modification
    // flag is set, reject promise with a NotAllowedError DOMException and
    // return promise."
    if (!record.constructed or record.disallow_modification) {
        defer engine.releasePromiseCapability(&capability);
        const exception = try engine.createDOMException(realm, "NotAllowedError", "replace() needs a constructed sheet that is not being replaced");
        defer exception.release();
        try engine.rejectPromise(&capability, exception.value);
        return promise.take();
    }
    // 3. "Set the disallow modification flag."
    record.disallow_modification = true;
    const task = realm.allocator.create(ReplaceTask) catch {
        record.disallow_modification = false;
        engine.releasePromiseCapability(&capability);
        return error.OutOfMemory;
    };
    const copy = realm.allocator.dupe(u8, text) catch {
        realm.allocator.destroy(task);
        record.disallow_modification = false;
        engine.releasePromiseCapability(&capability);
        return error.OutOfMemory;
    };
    task.* = .{ .object = object, .record = record, .text = copy, .capability = capability };
    record.ref();
    engine.keepPlatformObjectAlive(object);
    if (realm.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = ReplaceTask.run, .context = task, .drop = ReplaceTask.drop });
    } else ReplaceTask.run(task);
    return promise.take();
}

const ReplaceTask = struct {
    object: *runtime.Instance,
    record: *SheetRecord,
    text: []u8,
    capability: engine.PromiseCapability,

    fn run(data: ?*anyopaque) void {
        const self: *ReplaceTask = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        // 4.1-4.3.
        replaceRules(self.object, self.record, self.text) catch |err| {
            std.log.scoped(.css).warn("replace(): rules not replaced: {}", .{err});
        };
        // 4.4. "Unset sheet's disallow modification flag."
        self.record.disallow_modification = false;
        // 4.5. "Resolve promise with sheet."
        engine.resolvePromise(&self.capability, .{ .instance = self.object }) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ReplaceTask = @ptrCast(@alignCast(data orelse return));
        self.record.disallow_modification = false;
        self.finish();
    }

    fn finish(self: *ReplaceTask) void {
        const allocator = self.object.ctx.allocator;
        engine.releasePromiseCapability(&self.capability);
        self.record.unref();
        engine.releasePlatformObject(self.object);
        allocator.free(self.text);
        allocator.destroy(self);
    }
};

/// CSS Animations 1 §6.3.4: parse exactly one qualified keyframe rule,
/// then append it even if an identical selector already exists. Invalid
/// syntax is an atomic no-op. No declaration is applied as an author rule.
pub fn appendKeyframe(object: *runtime.Instance, parent: *Rule, text: []const u8) !void {
    if (parent.kind() != .keyframes) return;
    const a = parent.allocator;
    var parsed = try css.rules.parseRule(a, text) orelse return;
    defer parsed.deinitOwned(a);
    const record = parent.sheet();
    var url_context: sheet_mod.UrlContext = .{ .instance = object, .base = if (record) |r| r.base_url else "" };
    const parse_options: css.properties.ParseOptions = .{
        .allocator = a,
        .quirks = if (record) |r| r.mode.quirks else false,
        .url_resolver = url_context.resolver(),
    };
    const child = try rules_mod.buildKeyframe(.{ .parse = parse_options }, &parsed) orelse return;
    errdefer child.unref();
    try parent.data.keyframes.children.append(a, child);
    child.parent_rule = parent;
    if (record) |r| r.changed();
}

/// §§6.3.5–6.3.6: the final exact ordered selector list wins. Comparing
/// parsed numeric lists preserves distinctions hidden by CSSOM rounding.
pub fn keyframeIndex(parent: *Rule, text: []const u8) !?usize {
    if (parent.kind() != .keyframes) return null;
    var selectors = try css.keyframe_values.Selectors.parse(parent.allocator, text) orelse return null;
    defer selectors.deinit();
    const children = parent.data.keyframes.children.items;
    var i = children.len;
    while (i > 0) {
        i -= 1;
        if (selectors.eql(children[i].data.keyframe.selectors)) return i;
    }
    return null;
}

/// §6.3.5 uses the same detachment and bidirectional traced slots as every
/// CSSOM removal. A removed object continues to own its native rule model.
pub fn deleteKeyframe(parent: *Rule, text: []const u8) !void {
    const index = try keyframeIndex(parent, text) orelse return;
    const old = parent.data.keyframes.children.orderedRemove(index);
    objects.ruleRemoved(old);
    if (parent.sheet()) |record| record.changed();
    old.unref();
}
