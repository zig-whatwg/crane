//! HTML "create an element for a token", steps 3–12.
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ce = dom.custom_elements;
const driver = @import("driver.zig");

/// Create-for-token step 3 reads the is attribute before appending attributes.
pub fn isValue(node: *const @import("html_core").parser.TreeNode) ?[]const u8 {
    for (node.attributes.toSlice()) |attribute| {
        if (attribute.namespace == null and @import("std").mem.eql(u8, attribute.name, "is")) return attribute.value;
    }
    return null;
}

/// The caller creates the element and appends its token attributes inside
/// this scope. Full-document parsers pass fragment=false, including write().
pub const Scope = struct {
    document: *runtime.Instance,
    realm: runtime.Context,
    reactions: runtime.CEReactions.Scope = .{},
    synchronous: bool,

    pub fn begin(document: *runtime.Instance, local_name: []const u8, namespace: ?[]const u8, is_value: ?[]const u8, fragment: bool) !Scope {
        const realm = document.ctx;
        var scope = Scope{ .document = document, .realm = realm, .synchronous = false };
        // Steps 6–8. A global registry is the document's; scoped registry
        // selection from the intended parent is deferred to that batch.
        if (fragment or !driver.hasDefinitions(realm)) return scope;
        const registry = try interfaces.Document.get_customElementRegistry(document);
        if (ce.lookup(registry, namespace, local_name, is_value) == null) return scope;
        scope.synchronous = true;
        // Step 9.1–9.3. The counter also covers the checkpoint and reactions.
        dom.document_internals.incrementThrowOnDynamicMarkupInsertionCounter(document);
        errdefer if (realm.hasEngine()) dom.document_internals.decrementThrowOnDynamicMarkupInsertionCounter(document);
        if (realm.agent) |agent| {
            if (!engine.hasRunningScript(agent)) try engine.performMicrotaskCheckpoint(agent);
        }
        if (!realm.hasEngine()) return error.InvalidStateError;
        scope.reactions = driver.begin(document);
        return scope;
    }

    pub fn end(self: Scope) void {
        if (!self.synchronous) return;
        // Step 12.1–12.3: pop/invoke before decrementing the counter, also
        // when creating the element or appending its attributes failed.
        driver.end(self.reactions);
        if (self.realm.hasEngine()) dom.document_internals.decrementThrowOnDynamicMarkupInsertionCounter(self.document);
    }
};
