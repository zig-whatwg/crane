//! DOM create-an-element and flatten-element-creation-options algorithms.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const core = @import("html_core");
const driver = @import("driver.zig");
const ce = dom.custom_elements;
pub const Creation = ce.Creation;
pub const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

pub const FlattenedOptions = struct {
    registry: ?*runtime.Instance,
    is_value: ?[]u8 = null,
    registry_root: ?engine.Owned = null,

    pub fn deinit(self: FlattenedOptions, allocator: std.mem.Allocator) void {
        if (self.is_value) |value| allocator.free(value);
        if (self.registry_root) |root| root.release();
    }
};

/// WebIDL dictionary conversion precedes DOM flatten-element-creation-options.
/// Keep the registry's wrapper alive while the subsequent `is` getter runs.
pub fn flatten(document: *runtime.Instance, options: webidl.Opt(runtime.JSValue)) !FlattenedOptions {
    var result: FlattenedOptions = .{ .registry = try interfaces.Document.get_customElementRegistry(document) };
    errdefer result.deinit(document.ctx.allocator);
    if (!options.was_passed) return result;
    const realm = document.ctx;
    const value = options.value;
    switch (engine.typeOf(realm, value)) {
        .null, .undefined => return result,
        .object => {},
        else => {
            // The legacy string form is converted but never used as an is
            // value. Conversion still throws for a Symbol.
            const ignored = try engine.convertToDOMString(realm, value, realm.allocator);
            realm.allocator.free(ignored);
            return result;
        },
    }
    // WebIDL dictionary members are read in lexicographic order.
    const registry_value = try engine.getProperty(realm, value, "customElementRegistry");
    const explicit = engine.typeOf(realm, registry_value.value) != .undefined;
    result.registry_root = registry_value;
    if (explicit) {
        if (engine.typeOf(realm, registry_value.value) == .null) {
            result.registry = null;
        } else {
            const registry = engine.convertToPlatformObject(realm, registry_value.value) orelse return error.TypeError;
            if (registry.stateAs(interfaces.CustomElementRegistry.State) == null) return error.TypeError;
            result.registry = registry;
        }
    }
    const is_value = try engine.getProperty(realm, value, "is");
    defer is_value.release();
    if (engine.typeOf(realm, is_value.value) != .undefined) result.is_value = try engine.convertToDOMString(realm, is_value.value, realm.allocator);
    // DOM flatten steps 3.2.1–3.2.3.
    if (explicit) {
        if (result.is_value != null) return error.NotSupportedError;
        if (result.registry) |registry| {
            if (!ce.isScoped(registry) and registry != try interfaces.Document.get_customElementRegistry(document)) return error.NotSupportedError;
        }
    }
    return result;
}

pub fn create(requested: Creation) !*runtime.Instance {
    var options = requested;
    const realm = options.document.ctx;
    // Steps 2–3: null is an explicit association, distinct from "default".
    const registry = switch (options.registry) {
        .default => try interfaces.Document.get_customElementRegistry(options.document),
        .explicit => |value| value,
    };
    options.registry = .{ .explicit = registry };
    const definition = ce.lookup(registry, options.namespace, options.local_name, options.is_value);
    if (definition) |found| {
        const held = found.retain();
        defer held.deinit();
        if (!std.mem.eql(u8, found.name, found.local_name)) {
            // Step 4: customized built-ins start as their built-in interface.
            const element = try createInternal(options, .undefined, .appropriate);
            if (options.synchronous) {
                const root = engine.retainValue(realm, .{ .instance = element }) catch |err| {
                    dom.node_creation.destroyUninserted(element);
                    return err;
                };
                var transferred = false;
                defer if (!transferred) root.release();
                if (try @import("../upgrade.zig").upgradeElement(element, found)) |exception| {
                    defer exception.release();
                    reportConstructionError(realm, found, exception.value);
                }
                if (!realm.hasEngine()) return error.InvalidStateError;
                transferred = true;
                try driver.takeReturnedValue(realm, root);
            } else {
                driver.enqueueUpgrade(element, found) catch |err| {
                    dom.node_creation.destroyUninserted(element);
                    return err;
                };
            }
            return element;
        }
        if (options.synchronous) {
            // Step 5.1: constructor overrides on the agent implement the
            // save/set/restore of its active custom element constructor map.
            const state = try driver.pushConstructor(realm, found);
            defer state.popConstructor();
            const completion = try engine.constructCallbackFunction(realm, &found.constructor, &.{});
            if (state.active_constructors.get(state.active_constructors.len - 1).?.registry == null) {
                switch (completion) {
                    inline else => |value| value.release(),
                }
                return error.InvalidStateError;
            }
            switch (completion) {
                .throw => |exception| {
                    defer exception.release();
                    reportConstructionError(realm, found, exception.value);
                },
                .normal => |result| {
                    var transferred = false;
                    defer if (!transferred) result.release();
                    if (try validateConstructed(options, result.value)) |exception| {
                        defer exception.release();
                        reportConstructionError(realm, found, exception.value);
                    } else {
                        const element = engine.convertToPlatformObject(realm, result.value).?;
                        const data = ce.get(element) orelse return error.InvalidStateError;
                        // Steps 5.1.4.9–5.1.4.11.
                        try ce.initialize(element, options.prefix, null, data.state);
                        try ce.setElementRegistry(element, registry);
                        // Owned keeps the custom wrapper alive across the
                        // generated CEReactions.end and return conversion.
                        transferred = true;
                        try driver.takeReturnedValue(realm, result);
                        return element;
                    }
                },
            }
            // Step 5.1.4, exception substep 2: a fresh failed unknown element.
            if (!realm.hasEngine()) return error.InvalidStateError;
            var fallback = options;
            fallback.is_value = null;
            return createInternal(fallback, .failed, .unknown);
        }
        // Step 5.2: autonomous elements have HTMLElement, then enqueue upgrade.
        var autonomous = options;
        autonomous.is_value = null;
        const element = try createInternal(autonomous, .undefined, .autonomous);
        errdefer dom.node_creation.destroyUninserted(element);
        try driver.enqueueUpgrade(element, found);
        return element;
    }
    // Step 6: absent a definition, valid HTML custom names and is values can
    // be upgraded later; all other elements are already defined (uncustomized).
    const is_html = if (options.namespace) |namespace| std.mem.eql(u8, namespace, html_namespace) else false;
    const state: ce.State = if (is_html and (dom.names.isValidCustomElementName(options.local_name) or options.is_value != null)) .undefined else .uncustomized;
    return createInternal(options, state, .appropriate);
}

pub const Interface = enum { appropriate, autonomous, unknown };

/// DOM create-an-element-internal steps 1–4. No script-visible setters run.
pub fn createInternal(options: Creation, state: ce.State, interface: Interface) !*runtime.Instance {
    const realm = options.document.ctx;
    const is_html = if (options.namespace) |namespace| std.mem.eql(u8, namespace, html_namespace) else false;
    const is_svg = if (options.namespace) |namespace| std.mem.eql(u8, namespace, svg_namespace) else false;
    const element = if (interface == .autonomous)
        try interfaces.HTMLElement.init(realm.allocator, realm)
    else if (interface == .unknown)
        try interfaces.HTMLUnknownElement.init(realm.allocator, realm)
    else if (is_html)
        try @import("../parser_script_execution.zig").createHTMLElement(realm.allocator, realm, options.local_name)
    else if (is_svg and std.mem.eql(u8, options.local_name, "script"))
        try interfaces.SVGScriptElement.init(realm.allocator, realm)
    else if (is_svg and std.mem.eql(u8, options.local_name, "a"))
        try interfaces.SVGAElement.init(realm.allocator, realm)
    else
        try interfaces.Element.init(realm.allocator, realm);
    errdefer dom.node_creation.destroyUninserted(element);
    try dom.node_creation.setElementNames(element, options.namespace, options.local_name);
    try dom.node_document.set(element, options.document);
    try ce.initialize(element, options.prefix, options.is_value, state);
    try ce.setElementRegistry(element, switch (options.registry) {
        .default => try interfaces.Document.get_customElementRegistry(options.document),
        .explicit => |value| value,
    });
    return element;
}

fn validateConstructed(options: Creation, value: runtime.JSValue) !?engine.Owned {
    const realm = options.document.ctx;
    const element = engine.convertToPlatformObject(realm, value) orelse
        return try engine.createSimpleException(realm, .TypeError, "Custom element constructor did not return an HTMLElement");
    if (element.stateAs(interfaces.HTMLElement.State) == null)
        return try engine.createSimpleException(realm, .TypeError, "Custom element constructor did not return an HTMLElement");
    // Steps 5.1.4.4–5.1.4.8: validate only after constructing C.
    if (dom.element_attributes.count(element) != 0 or
        (try interfaces.Node.get_firstChild(element)) != null or
        (try interfaces.Node.get_parentNode(element)) != null or
        (try interfaces.Node.get_ownerDocument(element)) != options.document)
        return try engine.createDOMException(realm, "NotSupportedError", "Custom element constructor changed the element's attributes, children, parent, or document");
    var local_name = try interfaces.Element.get_localName(element);
    defer local_name.deinit(element.ctx.allocator);
    if (!std.mem.eql(u8, local_name.asSlice(), options.local_name))
        return try engine.createDOMException(realm, "NotSupportedError", "Custom element constructor returned the wrong local name");
    return null;
}

fn reportConstructionError(fallback: runtime.Context, definition: *ce.Definition, value: runtime.JSValue) void {
    const realm = if (engine.capabilities.exact_function_realm != .unsupported)
        engine.functionRealm(definition.constructor.function.value) orelse fallback
    else
        fallback;
    if (!realm.hasEngine()) return;
    driver.reportThrown(realm, value);
}
