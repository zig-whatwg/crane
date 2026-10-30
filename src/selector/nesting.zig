//! CSS Nesting 1 sections 3–5: resolve parent references at rule-build time.
//! Design: WebKit CSSSelectorParser::resolveNestingParent, revision
//! 3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c. The original AST stays in CSSOM;
//! an immutable counted parent view replaces & with :is(parent), or
//! :where(:scope). Matching sees the existing selector shape.
const std = @import("std");
const p = @import("parser.zig");
const Allocator = std.mem.Allocator;

/// A resolved parent is ONE immutable node with a plain, single-agent count.
/// Exactly two holders own counts: a style rule's resolved slot, and each
/// resolved nesting component (including a copied component). Construction
/// and a ResolutionPlan temporarily own the count destined for that slot.
/// Holders release only when their containing slot/list is freed. At zero,
/// this node alone frees both views; no unique-list path may claim them.
/// A selectorText mutation creates a new node and rebuilds descendants.
/// The authored selector AST, and therefore CSSOM serialization, is separate.
///
/// The resolution shape follows WebKit resolveNestingParent; this counted
/// storage is Crane's separately reviewed ownership design. WebKit's copy
/// constructor at revision 3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c deep-copies
/// rare selector data; it is not evidence for this shared-node mechanism.
/// Storage precedent: Stylo selectors/parser.rs replace_parent_selector
/// retains parent.clone() inside Is. SelectorList derives Clone over
/// ThinArcUnion; servo_arc's ArcUnion/Arc clones increment the count.
/// Examined revision: da29a2a5c1aa17a55182c52a6ee4bc2fb04214b7.
/// Crane uses its separately approved single-agent u32 contract, not Arc.
pub const SharedList = struct {
    allocator: Allocator,
    refs: u32 = 1,
    actual: p.SelectorList,
    guarded: ?p.SelectorList = null,
    frozen: bool = false,
    signature: u64 = 0,

    pub fn create(allocator: Allocator, source: *const p.SelectorList, parent: ?*SharedList) Allocator.Error!*SharedList {
        const node = try allocator.create(SharedList);
        errdefer allocator.destroy(node);
        node.* = .{ .allocator = allocator, .actual = try resolveWithParent(allocator, source, parent) };
        errdefer node.actual.deinit();
        if (hasPseudoElementBranch(&node.actual)) {
            var guarded = try clone(allocator, &node.actual);
            errdefer guarded.deinit();
            try guardPseudoElements(allocator, &guarded);
            node.guarded = guarded;
        }
        // Seal only after every allocation and AST write has succeeded.
        node.actual.shared_owner = node;
        if (node.guarded) |*guarded| guarded.shared_owner = node;
        node.signature = node.fingerprint();
        node.frozen = true;
        return node;
    }

    /// Borrow under the caller's existing slot/component count.
    pub fn actualList(self: *SharedList) *p.SelectorList {
        std.debug.assert(self.refs > 0 and self.isUnchanged());
        return &self.actual;
    }

    /// Copy a component's existing view without copying its parent tree.
    pub fn retainView(self: *SharedList, view: *const p.SelectorList) *p.SelectorList {
        std.debug.assert(self.refs > 0 and self.isUnchanged());
        std.debug.assert(view.shared_owner == self);
        std.debug.assert(view == &self.actual or (self.guarded != null and view == &self.guarded.?));
        self.refs += 1;
        return @constCast(view);
    }

    fn nestingView(self: *SharedList) *p.SelectorList {
        return self.retainView(if (self.guarded) |*guarded| guarded else &self.actual);
    }

    pub fn unref(self: *SharedList) void {
        std.debug.assert(self.refs > 0 and self.isUnchanged());
        self.refs -= 1;
        if (self.refs != 0) return;
        self.actual.deinitSharedContents(self);
        if (self.guarded) |*guarded| guarded.deinitSharedContents(self);
        self.allocator.destroy(self);
    }

    /// Debug ownership checks catch writes after sealing. Shared ancestor
    /// nodes are identified, never traversed: checking a node is linear in
    /// that node's OWN AST, even when two components share the same parent.
    pub fn isUnchanged(self: *const SharedList) bool {
        return self.frozen and self.signature == self.fingerprint();
    }

    fn fingerprint(self: *const SharedList) u64 {
        var hash = std.hash.Wyhash.init(0);
        hashList(&hash, &self.actual);
        if (self.guarded) |*guarded| hashList(&hash, guarded);
        return hash.final();
    }
};

fn hashList(hash: *std.hash.Wyhash, list: *const p.SelectorList) void {
    std.hash.autoHashStrat(hash, list.*, .Shallow);
    for (list.strings) |text| hash.update(text);
    for (list.selectors) |*complex| {
        std.hash.autoHashStrat(hash, complex.*, .Shallow);
        hashCompound(hash, &complex.compound);
        for (complex.combinators) |*pair| {
            std.hash.autoHashStrat(hash, pair.*, .Shallow);
            hashCompound(hash, &pair.compound);
        }
    }
}

fn hashChild(hash: *std.hash.Wyhash, list: *const p.SelectorList) void {
    if (list.shared_owner != null) {
        std.hash.autoHashStrat(hash, list, .Shallow);
    } else hashList(hash, list);
}

fn hashCompound(hash: *std.hash.Wyhash, compound: *const p.CompoundSelector) void {
    std.hash.autoHashStrat(hash, compound.*, .Shallow);
    for (compound.simple_selectors) |simple| {
        std.hash.autoHashStrat(hash, simple, .Shallow);
        switch (simple) {
            .NamespacedAttribute => |attribute| std.hash.autoHashStrat(hash, attribute.*, .Shallow),
            .PseudoClass => |pseudo| switch (pseudo.kind) {
                .Is, .Where, .Not, .Has => |list| hashChild(hash, list),
                .Host => |maybe| if (maybe) |list| hashChild(hash, list),
                .NthChild, .NthLastChild => |pattern| if (pattern.of) |list| hashChild(hash, list),
                .Lang => |ranges| for (ranges) |text| hash.update(text),
                else => {},
            },
            .PseudoElement => |pseudo| {
                if (pseudo.argument) |list| hashChild(hash, list);
                for (pseudo.part_names) |text| hash.update(text);
            },
            else => {},
        }
    }
}

fn pseudoElementBranch(complex: *const p.ComplexSelector) bool {
    if (complex.compound.hasPseudoElement()) return true;
    for (complex.combinators) |*pair| if (pair.compound.hasPseudoElement()) return true;
    return false;
}

fn hasPseudoElementBranch(list: *const p.SelectorList) bool {
    for (list.selectors) |*complex| if (pseudoElementBranch(complex)) return true;
    return false;
}

fn guardPseudoElements(allocator: Allocator, list: *p.SelectorList) Allocator.Error!void {
    std.debug.assert(list.shared_owner == null);
    for (list.selectors) |*complex| {
        if (!pseudoElementBranch(complex)) continue;
        // Nesting 1 section 4: pseudo-element branches contribute their
        // specificity, but & cannot represent their pseudo-elements.
        // :not(*) rejects only that branch with zero added specificity.
        const guard = try falseGuard(allocator);
        errdefer guard.releaseBoxed();
        const length = complex.compound.simple_selectors.len;
        complex.compound.simple_selectors = try allocator.realloc(complex.compound.simple_selectors, length + 1);
        complex.compound.simple_selectors[length] = .{ .PseudoClass = .{ .kind = .{ .Not = guard } } };
    }
}

fn falseGuard(allocator: Allocator) Allocator.Error!*p.SelectorList {
    const guard = try allocator.create(p.SelectorList);
    errdefer allocator.destroy(guard); // Uninitialized until the final assignment.
    const selectors = try allocator.alloc(p.ComplexSelector, 1);
    errdefer allocator.free(selectors);
    const simples = try allocator.alloc(p.SimpleSelector, 1);
    errdefer allocator.free(simples);
    simples[0] = .{ .Universal = .{} };
    selectors[0] = .{ .allocator = allocator, .compound = .{ .allocator = allocator, .simple_selectors = simples }, .combinators = &.{} };
    guard.* = .{ .allocator = allocator, .selectors = selectors };
    return guard;
}

pub fn contains(list: *const p.SelectorList) bool {
    return containsKind(list, .nesting);
}

const Search = enum { nesting, scope };

fn containsKind(list: *const p.SelectorList, kind: Search) bool {
    for (list.selectors) |*complex| if (complexContains(complex, kind)) return true;
    return false;
}

pub fn containsScope(complex: *const p.ComplexSelector) bool {
    return complexContains(complex, .scope);
}

fn complexContains(complex: *const p.ComplexSelector, kind: Search) bool {
    if (compoundContains(&complex.compound, kind)) return true;
    for (complex.combinators) |*pair| if (compoundContains(&pair.compound, kind)) return true;
    return false;
}

fn compoundContains(compound: *const p.CompoundSelector, kind: Search) bool {
    for (compound.simple_selectors) |simple| switch (simple) {
        .Nesting => if (kind == .nesting) return true,
        .PseudoClass => |pseudo| switch (pseudo.kind) {
            .Scope => if (kind == .scope) return true,
            .Is, .Where, .Not, .Has => |list| if (containsKind(list, kind)) return true,
            .Host => |maybe| if (maybe) |list| if (containsKind(list, kind)) return true,
            .NthChild, .NthLastChild => |pattern| if (pattern.of) |list| if (containsKind(list, kind)) return true,
            else => {},
        },
        .PseudoElement => |pseudo| if (pseudo.argument) |list| if (containsKind(list, kind)) return true,
        else => {},
    };
    return false;
}

/// The returned unique root owns its names and holds shared references to
/// parent nodes. Standalone callers can provide an unshared parent list;
/// production rule models provide their counted resolved slot.
pub fn resolve(allocator: Allocator, source: *const p.SelectorList, parent: ?*const p.SelectorList) Allocator.Error!p.SelectorList {
    const list = parent orelse return resolveWithParent(allocator, source, null);
    if (list.shared_owner) |owner| return resolveWithParent(allocator, source, owner);
    const owner = try SharedList.create(allocator, list, null);
    defer owner.unref();
    return resolveWithParent(allocator, source, owner);
}

fn resolveWithParent(allocator: Allocator, source: *const p.SelectorList, parent: ?*SharedList) Allocator.Error!p.SelectorList {
    var copier = Copier{ .allocator = allocator, .parent = parent };
    defer copier.deinit();
    var result = try copier.copyList(source);
    errdefer result.deinit();
    result.strings = try copier.strings.toOwnedSlice(allocator);
    return result;
}

/// CSSNestedDeclarations takes the parent's actual selector list, without
/// wrapping it in :is(): individual specificity and pseudo-elements remain.
pub fn clone(allocator: Allocator, source: *const p.SelectorList) Allocator.Error!p.SelectorList {
    return resolve(allocator, source, null);
}

/// A zero-specificity scope reference, also used for DOM's top-level &.
pub fn scopeReference(allocator: Allocator) Allocator.Error!p.SimpleSelector {
    const simples = try allocator.alloc(p.SimpleSelector, 1);
    errdefer allocator.free(simples);
    simples[0] = .{ .PseudoClass = .{ .kind = .Scope } };
    const selectors = try allocator.alloc(p.ComplexSelector, 1);
    errdefer allocator.free(selectors);
    selectors[0] = .{ .allocator = allocator, .compound = .{ .allocator = allocator, .simple_selectors = simples }, .combinators = &.{} };
    const list = try allocator.create(p.SelectorList);
    list.* = .{ .allocator = allocator, .selectors = selectors };
    return .{ .PseudoClass = .{ .kind = .{ .Where = list } } };
}

const Copier = struct {
    allocator: Allocator,
    parent: ?*SharedList,
    strings: std.ArrayList([]u8) = .empty,

    fn deinit(self: *Copier) void {
        for (self.strings.items) |text| self.allocator.free(text);
        self.strings.deinit(self.allocator);
    }

    fn string(self: *Copier, text: []const u8) Allocator.Error![]const u8 {
        const owned = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(owned);
        try self.strings.append(self.allocator, owned);
        return owned;
    }

    fn copyList(self: *Copier, source: *const p.SelectorList) Allocator.Error!p.SelectorList {
        const selectors = try self.allocator.alloc(p.ComplexSelector, source.selectors.len);
        errdefer self.allocator.free(selectors);
        var initialized: usize = 0;
        errdefer for (selectors[0..initialized]) |*complex| complex.deinit();
        for (source.selectors, 0..) |*complex, i| {
            selectors[i] = try self.copyComplex(complex);
            initialized += 1;
        }
        return .{ .allocator = self.allocator, .selectors = selectors };
    }

    fn boxed(self: *Copier, source: *const p.SelectorList) Allocator.Error!*p.SelectorList {
        if (source.shared_owner) |owner| return owner.retainView(source);
        const owned = try self.allocator.create(p.SelectorList);
        errdefer self.allocator.destroy(owned);
        owned.* = try self.copyList(source);
        return owned;
    }

    fn copyComplex(self: *Copier, source: *const p.ComplexSelector) Allocator.Error!p.ComplexSelector {
        var result = source.*;
        result.allocator = self.allocator;
        result.compound = try self.copyCompound(&source.compound);
        errdefer result.compound.deinit();
        result.combinators = try self.allocator.alloc(p.CombinatorPair, source.combinators.len);
        errdefer self.allocator.free(result.combinators);
        var initialized: usize = 0;
        errdefer for (result.combinators[0..initialized]) |*pair| pair.compound.deinit();
        for (source.combinators, 0..) |*pair, i| {
            result.combinators[i] = .{ .combinator = pair.combinator, .compound = try self.copyCompound(&pair.compound) };
            initialized += 1;
        }
        result.computeAncestorHashes();
        result.computeBacktrackingInfo();
        return result;
    }

    fn copyCompound(self: *Copier, source: *const p.CompoundSelector) Allocator.Error!p.CompoundSelector {
        const simples = try self.allocator.alloc(p.SimpleSelector, source.simple_selectors.len);
        errdefer self.allocator.free(simples);
        var initialized: usize = 0;
        errdefer for (simples[0..initialized]) |*simple| simple.deinit(self.allocator);
        for (source.simple_selectors, 0..) |simple, i| {
            simples[i] = try self.copySimple(simple);
            initialized += 1;
        }
        return .{ .allocator = self.allocator, .simple_selectors = simples, .active_hover_quirk = source.active_hover_quirk };
    }

    fn copySimple(self: *Copier, source: p.SimpleSelector) Allocator.Error!p.SimpleSelector {
        return switch (source) {
            .Nesting => if (self.parent) |parent| .{ .PseudoClass = .{ .kind = .{ .Is = parent.nestingView() } } } else try scopeReference(self.allocator),
            .Universal => source,
            .Type => |t| .{ .Type = .{ .tag_name = try self.string(t.tag_name), .lower_name = try self.string(t.lower_name), .namespace = t.namespace } },
            .Class => |c| .{ .Class = .{ .class_name = try self.string(c.class_name) } },
            .Id => |id| .{ .Id = .{ .id = try self.string(id.id) } },
            .NamespaceURI => |ns| .{ .NamespaceURI = .{ .uri = try self.string(ns.uri) } },
            .Attribute => |attribute| .{ .Attribute = try self.copyAttribute(attribute) },
            .NamespacedAttribute => |source_box| blk: {
                const box = try self.allocator.create(@typeInfo(@FieldType(p.SimpleSelector, "NamespacedAttribute")).pointer.child);
                errdefer self.allocator.destroy(box);
                box.* = .{ .uri = try self.string(source_box.uri), .attribute = try self.copyAttribute(source_box.attribute) };
                break :blk .{ .NamespacedAttribute = box };
            },
            .PseudoClass => |pseudo| .{ .PseudoClass = .{ .kind = try self.pseudoClass(pseudo.kind) } },
            .PseudoElement => |pseudo| blk: {
                var result = p.PseudoElementSelector{ .name = try self.string(pseudo.name) };
                errdefer result.deinit(self.allocator);
                if (pseudo.argument) |argument| result.argument = try self.boxed(argument);
                const names = try self.allocator.alloc([]const u8, pseudo.part_names.len);
                result.part_names = names;
                for (pseudo.part_names, 0..) |name, i| names[i] = try self.string(name);
                break :blk .{ .PseudoElement = result };
            },
        };
    }

    fn copyAttribute(self: *Copier, source: p.AttributeSelector) Allocator.Error!p.AttributeSelector {
        var result = source;
        result.name = try self.string(source.name);
        result.lower_name = try self.string(source.lower_name);
        result.matcher = switch (source.matcher) {
            .Presence => .Presence,
            inline else => |m, tag| @unionInit(p.AttributeMatcher, @tagName(tag), .{ .value = try self.string(m.value) }),
        };
        return result;
    }

    fn pseudoClass(self: *Copier, source: p.PseudoClassKind) Allocator.Error!p.PseudoClassKind {
        return switch (source) {
            inline .Is, .Where, .Not, .Has => |list, tag| @unionInit(p.PseudoClassKind, @tagName(tag), try self.boxed(list)),
            .Host => |maybe| .{ .Host = if (maybe) |list| try self.boxed(list) else null },
            inline .NthChild, .NthLastChild => |pattern, tag| blk: {
                var result = pattern;
                if (pattern.of) |list| result.of = try self.boxed(list);
                break :blk @unionInit(p.PseudoClassKind, @tagName(tag), result);
            },
            .Lang => |ranges| blk: {
                const owned = try self.allocator.alloc([]const u8, ranges.len);
                errdefer self.allocator.free(owned);
                for (ranges, 0..) |text, i| owned[i] = try self.string(text);
                break :blk .{ .Lang = owned };
            },
            .State => |name| .{ .State = try self.string(name) },
            else => source,
        };
    }
};
