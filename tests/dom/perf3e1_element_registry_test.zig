//! An element's custom element registry, kept where it costs nothing for
//! the common case (lane perf3, E1 item 1).
//!
//! DOM gives every element a "custom element registry" (null or a
//! CustomElementRegistry; DOM 4.9, the element's associated values). Over
//! the 3,039,618 elements of the perf pages it was the node document's own
//! global registry on 86.6%, null on the rest (documents with no browsing
//! context), and a scoped registry on none - yet every element carried a
//! 40-byte association (a kept instance with its generation and realm, and
//! a traced flag). DOM keeps a global association equal to the node
//! document's effective global registry: "create an element" takes the
//! document's (flatten element creation options 3.2.3), and adopt resets a
//! global one to the new document's (adopt 3.3.2.4). Blink infers the
//! registry from the tree scope unless its NodeRareData holds one
//! (kCustomElementRegistry; Element::SetCustomElementRegistry clears that
//! field when the registry is the tree scope's); WebKit keeps two node
//! flags (UsesNullCustomElementRegistry, UsesScopedCustomElementRegistryMap)
//! and reads the tree scope's otherwise (CustomElementRegistry::
//! registryForElement). E1: a 2-bit place in Element - none, the node
//! document's, or rare data - and any other registry (a scoped one, or a
//! global one that is not the node document's) in the element's rare data.
//!
//! The size pins are red until E1 lands; the behaviour tests hold before
//! and after it, except those that read the rare data itself.
//!
//! These name only generated interfaces, their States and src/dom types:
//! Element's InternalState is reached as its State's field type, never
//! through its impl (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
    std.debug.print("{s:<34} {s:>6} {s:>6} {s:>6}  {s}\n", .{ "field", "offset", "size", "align", "type" });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("{s:<34} {d:>6} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @alignOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

/// Element's InternalState, as its generated State keeps it by value.
const ElementState = @FieldType(interfaces.Element.State, "_embedded");
/// Whether E1's rare registry field is in this build.
const has_rare_registry = @hasField(dom.element_rare_data.Field, "custom_element_registry");

// ============================================================================
// Sizes (red until E1)
// ============================================================================

test "Element's InternalState keeps no 40-byte registry association" {
    if (comptime @hasField(ElementState, "custom_element_registry")) {
        const F = @FieldType(ElementState, "custom_element_registry");
        if (@sizeOf(F) > 1) {
            printLayout(ElementState);
            return error.AssociationStillInElement;
        }
    }
    // 240 after D2: - 40 (the association) + a one-byte place, in the
    // padding after the three one-byte fields: 200; item 2 then took the
    // slottable state out (tests/dom/perf3e1_slottable_test.zig): 136; lane nd2 N2 took the name into one record pointer (tests/dom/nd2_element_name_test.zig): 88.
    // nd2 N3: the ID and classes views (48) are indices in the list's header: 40.
    // Lane nm1: the place is two bits of the element's byte in NodeBase.
    // Its size is pinned in ONE place, tests/dom/node_block_sizes_test.zig (lane nm1).
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

test "the rare data keeps the association for a registry that is not the node document's, in a block of its own" {
    if (comptime !has_rare_registry) return error.NoRareRegistry;
    // 344 at E1 in one fixed block; since lane rare1 the rare data is one
    // sparse block whose slot names the association's own block, so the
    // block may move without moving it (tests/dom/rare1_sparse_rare_data_test.zig).
    try testing.expect(dom.element_rare_data.Value(.custom_element_registry) == *dom.custom_elements.RegistryAssociation);
}

// ============================================================================
// An engine-less page
// ============================================================================

/// An HTML document, given a global registry before any element is made
/// when `global` (HTML 7.3.2.1: step 15 sets the document's registry, step
/// 22 makes its first elements), with one div in it.
const Page = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,
    registry: ?*runtime.Instance = null,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator, global: bool) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .allocator = allocator, .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try self.newDocument(global);
        self.registry = try interfaces.Document.get_customElementRegistry(self.document);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    /// Another HTML document of the page's realm; with a global registry of
    /// its own (an engine-less document owns it: Document.ensureGlobalRegistry).
    fn newDocument(self: *Page, global: bool) !*runtime.Instance {
        const document = try interfaces.Document.init(self.allocator, &self.ctx);
        try dom.document_internals.setContentType(document, "text/html");
        try dom.document_internals.setDocumentType(document, .html);
        if (global) _ = try dom.custom_elements.ensureGlobalRegistry(document);
        return document;
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return elementIn(self.document, name);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

fn elementIn(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElement(document, str(name), .{ .was_passed = false, .value = undefined });
}

fn registryOf(element: *runtime.Instance) !?*runtime.Instance {
    return interfaces.Element.get_customElementRegistry(element);
}

/// `element`'s rare block, or null when it has none.
fn rareOf(element: *runtime.Instance) ?*dom.element_rare_data.Block {
    return dom.element_rare_data.of(element).block;
}

/// The registry `element`'s rare data keeps, if it has rare data.
fn rareRegistryOf(element: *runtime.Instance) ?*runtime.Instance {
    if (comptime !has_rare_registry) return null;
    const association = dom.element_rare_data.get(dom.element_rare_data.of(element), .custom_element_registry) orelse return null;
    return association.get();
}

// ============================================================================
// The node document's global registry: no rare data
// ============================================================================

test "an element made, parsed or cloned with its node document's global registry reads it and has no rare data" {
    var page: Page = undefined;
    try page.open(testing.allocator, true);
    defer page.close();

    const global = page.registry orelse return error.NoGlobalRegistry;
    try testing.expect(!dom.custom_elements.isScoped(global));
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(page.div));
    try testing.expect(rareOf(page.div) == null);

    // Parsed into it (the fragment parser takes the context element's registry).
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("<span><b>b</b></span><x-a></x-a>") });
    const span = (try interfaces.Node.get_firstChild(page.div)).?;
    const b = (try interfaces.Node.get_firstChild(span)).?;
    const custom = (try interfaces.Node.get_nextSibling(span)).?;
    for ([_]*runtime.Instance{ span, b, custom }) |el| {
        try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(el));
        try testing.expect(rareOf(el) == null);
    }
    // Cloned (clone a single node 2.3: the document's effective global).
    const clone = try interfaces.Node.call_cloneNode(span, .{ .was_passed = true, .value = true });
    _ = try interfaces.Node.call_appendChild(page.div, clone);
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(clone));
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf((try interfaces.Node.get_firstChild(clone)).?));
    try testing.expect(rareOf(clone) == null);
}

test "an element of a document with no registry reads null and has no rare data" {
    var page: Page = undefined;
    try page.open(testing.allocator, false);
    defer page.close();

    try testing.expect(page.registry == null);
    try testing.expectEqual(@as(?*runtime.Instance, null), try registryOf(page.div));
    try testing.expect(rareOf(page.div) == null);
}

test "adopt moves a global association to each new document's effective global registry, with no rare data" {
    var page: Page = undefined;
    try page.open(testing.allocator, true);
    defer page.close();
    const other = try page.newDocument(true);
    defer interfaces.Document.deinit(other);
    const bare = try page.newDocument(false);
    defer interfaces.Document.deinit(bare);
    const other_registry = (try interfaces.Document.get_customElementRegistry(other)) orelse return error.NoGlobalRegistry;
    try testing.expect(other_registry != page.registry.?);

    const el = try page.element("p");
    try testing.expectEqual(page.registry, try registryOf(el));
    // Adopt 3.3.2.4: a global registry becomes the new document's effective
    // global registry.
    _ = try interfaces.Document.call_adoptNode(other, el);
    try testing.expectEqual(@as(?*runtime.Instance, other_registry), try registryOf(el));
    try testing.expect(rareOf(el) == null);
    // A document with none: null.
    _ = try interfaces.Document.call_adoptNode(bare, el);
    try testing.expectEqual(@as(?*runtime.Instance, null), try registryOf(el));
    try testing.expect(rareOf(el) == null);
    // Back, parentless: adopt 3.3.2.2 takes the document's registry.
    _ = try interfaces.Document.call_adoptNode(page.document, el);
    try testing.expectEqual(page.registry, try registryOf(el));
    try testing.expect(rareOf(el) == null);
    // A subtree moves together.
    try interfaces.Element.set_innerHTML(el, .{ .domstring = str("<i>i</i>") });
    _ = try interfaces.Document.call_adoptNode(other, el);
    try testing.expectEqual(@as(?*runtime.Instance, other_registry), try registryOf((try interfaces.Node.get_firstChild(el)).?));
    _ = try interfaces.Document.call_adoptNode(page.document, el);
    try testing.expectEqual(page.registry, try registryOf((try interfaces.Node.get_firstChild(el)).?));
}

// ============================================================================
// A scoped registry: rare data
// ============================================================================

test "a scoped registry is kept in rare data, survives adopt, and the place follows every set" {
    var page: Page = undefined;
    try page.open(testing.allocator, true);
    defer page.close();
    const scoped = try interfaces.CustomElementRegistry.call_constructor(&page.ctx);
    defer runtime.Instance.deinit(scoped);
    const bare = try page.newDocument(false);
    defer interfaces.Document.deinit(bare);
    const global = page.registry.?;

    // An element of the registry-less document, initialized by the scoped
    // registry (initialize step 4 sets a null association).
    const el = try elementIn(bare, "div");
    try testing.expectEqual(@as(?*runtime.Instance, null), try registryOf(el));
    try interfaces.CustomElementRegistry.call_initialize(scoped, el);
    try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(el));
    if (comptime !has_rare_registry) return error.NoRareRegistry;
    try testing.expect(rareOf(el) != null);
    try testing.expectEqual(@as(?*runtime.Instance, scoped), rareRegistryOf(el));

    // Adopt 3.3.2: a scoped association stays.
    _ = try interfaces.Document.call_adoptNode(page.document, el);
    try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(el));
    // A shallow clone keeps it (clone a single node: not global).
    const clone = try interfaces.Node.call_cloneNode(el, .{ .was_passed = true, .value = false });
    defer dom.node_creation.destroyUninserted(clone);
    try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(clone));

    // Set to the node document's own global registry, the rare association
    // is let go (the block stays: it never moves or shrinks).
    try dom.custom_elements.setElementRegistry(el, global);
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(el));
    try testing.expectEqual(@as(?*runtime.Instance, null), rareRegistryOf(el));
    // To null, and back to scoped, and to null again.
    try dom.custom_elements.setElementRegistry(el, null);
    try testing.expectEqual(@as(?*runtime.Instance, null), try registryOf(el));
    try dom.custom_elements.setElementRegistry(el, scoped);
    try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(el));
    try dom.custom_elements.setElementRegistry(el, null);
    try testing.expectEqual(@as(?*runtime.Instance, null), try registryOf(el));
    try testing.expectEqual(@as(?*runtime.Instance, null), rareRegistryOf(el));

    // A global registry that is not the node document's is kept in rare
    // data too, and read back as itself.
    const bare_el = try elementIn(bare, "span");
    try dom.custom_elements.setElementRegistry(bare_el, global);
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(bare_el));
    try testing.expectEqual(@as(?*runtime.Instance, global), rareRegistryOf(bare_el));
    // Adopted into the document whose registry it is: the node document's,
    // the rare association let go.
    _ = try interfaces.Document.call_adoptNode(page.document, bare_el);
    try testing.expectEqual(@as(?*runtime.Instance, global), try registryOf(bare_el));
    try testing.expectEqual(@as(?*runtime.Instance, null), rareRegistryOf(bare_el));
    dom.node_creation.destroyUninserted(bare_el);
    dom.node_creation.destroyUninserted(el);
}

test "elements with a registry in rare data are freed at both exits (poisoning DebugAllocator)" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator(), true);
    defer page.close();
    const scoped = try interfaces.CustomElementRegistry.call_constructor(&page.ctx);
    defer runtime.Instance.deinit(scoped);

    // One in the tree, one orphan only the Browser's sweep reaches, and a
    // parsed subtree that innerHTML drops.
    const kept = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.div, kept);
    try dom.custom_elements.setElementRegistry(kept, scoped);
    const orphan = try page.element("div");
    try dom.custom_elements.setElementRegistry(orphan, scoped);
    try interfaces.Element.set_innerHTML(kept, .{ .domstring = str("<p>a</p><p>b</p>") });
    var child = try interfaces.Node.get_firstChild(kept);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) {
        try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(c));
    }
    try interfaces.Element.set_innerHTML(kept, .{ .domstring = str("") });
    try testing.expectEqual(@as(?*runtime.Instance, scoped), try registryOf(orphan));
}
