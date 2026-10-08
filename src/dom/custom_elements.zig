//! Custom-element steps with no IDL member, installed by their owners.
//! lint-impls: hook for Element, HTMLElement, Document, ShadowRoot, CustomElementRegistry, ElementInternals, CustomStateSet, ValidityState
const runtime = @import("runtime");
const engine = @import("engine");
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
pub const ValidityFlags = @import("dictionaries").ValidityStateFlags;
pub const ValidationState = enum { inapplicable, valid, invalid };
const core = @import("html_core");
const process_start = @import("process_start.zig");

pub const State = core.custom_element_reaction.State;
pub const Definition = core.custom_element_definition.Definition(runtime, engine);
pub const Reaction = core.custom_element_reaction.Reaction(runtime, engine);
pub const CallbackType = core.custom_element_reaction.CallbackType;
pub const CallbackArgs = Reaction.CallbackArgs;
fn realmIsLive(realm: runtime.Context) bool {
    return realm.hasEngine();
}
const Returns = core.custom_element_returns.PendingReturns(runtime.Context, engine.Owned);
pub const AgentState = core.custom_element_agent.AgentState(*runtime.Instance, runtime.Context, Reaction, engine.Owned, Returns, realmIsLive);

pub const ElementData = struct {
    state: State,
    definition: ?*Definition,
    is_value: ?[]const u8,
};
pub const ElementSteps = struct {
    get: *const fn (*runtime.Instance) ?ElementData,
    initialize: *const fn (*runtime.Instance, ?[]const u8, ?[]const u8, State) anyerror!void,
    set_state: *const fn (*runtime.Instance, State) void,
    set_definition: *const fn (*runtime.Instance, ?*Definition) void,
    shadow_root_of: *const fn (*runtime.Instance) ?*runtime.Instance,
    mark_enqueued: *const fn (*runtime.Instance) void,
    set_registry: *const fn (*runtime.Instance, ?*runtime.Instance) anyerror!void,
    attach_shadow: *const fn (*runtime.Instance, ShadowRootInit, ?*runtime.Instance) anyerror!*runtime.Instance,
};
pub const RegistrySelection = union(enum) { default, explicit: ?*runtime.Instance };
/// A platform object kept by a native pointer that an engine edge keeps
/// alive: its slab generation and its realm beside it, so that a lost edge -
/// a replaced wrapper, a teardown order - reads as gone (`get` answers null)
/// rather than as a freed or reissued object. The shape of
/// CustomElementRegistry's ScopedDocument.isLive; the docs' Instance contract
/// ("keep that realm's Context beside it and check it before every
/// dereference").
pub const KeptInstance = struct {
    instance: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,

    pub fn of(instance: *runtime.Instance) KeptInstance {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance), .realm = instance.ctx };
    }

    /// The instance while it is the one kept: not freed (its slot's
    /// generation moved on), not torn down, and its realm not ended. A
    /// context that never had an engine (native parsing, engine-free tests)
    /// has no realm to end; a retired realm keeps its agent (Node.zig's
    /// storage rule draws the same line).
    pub fn get(self: KeptInstance) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        if (runtime.instance_lifecycle.isCleanedUp(self.instance)) return null;
        if (!self.realm.hasEngine() and self.realm.agent != null) return null;
        return self.instance;
    }
};

/// A native association plus, where nothing else keeps the registry, an
/// engine-traced edge - never a persistent root. A document/element can
/// outlive its browsing context; defaultView is not its registry. Blink's
/// Document/ElementRareData/ShadowRoot trace the same edge. Read it with
/// `get`: a registry whose keeper went reads null (CE2-M2). `value` is the
/// raw pointer, for readers not converted yet (Document, ShadowRoot).
pub const RegistryAssociation = struct {
    value: ?*runtime.Instance = null,
    kept: ?KeptInstance = null,
    traced: bool = false,

    /// An element's or shadow root's association (CE2-S2). DOM gives a node
    /// a global registry only as its node document's own (flatten element
    /// creation options 3.2.3, importNode 3, clone a single node 2.3, adopt
    /// 3.3.2.4, attachShadow), and the document's association keeps that
    /// registry: such a node draws no edge of its own - one per created
    /// element was a Global waiting in the wrapper cache for every unwrapped
    /// one, or a private property on every wrapped one. Only a registry the
    /// document does not keep - a scoped one, or a global one that is not
    /// `document_registry` - is traced from the node.
    ///
    /// The global case keeps the pointer with its generation rather than
    /// re-reading the node document's registry on `get`: a node can outlive
    /// a document that lost its browsing context (its wrapper is then weak
    /// and a detached node keeps no edge to it), and the node document is a
    /// bare pointer. Deviation, stated: when that document and its registry
    /// are collected while the node lives, the node's association reads null
    /// where DOM would still answer the old registry.
    pub fn setForNode(self: *RegistryAssociation, owner: *runtime.Instance, value: ?*runtime.Instance, document_registry: ?*runtime.Instance) void {
        if (value) |registry| {
            if (registry == document_registry and !isScoped(registry)) {
                self.release(owner);
                self.value = registry;
                self.kept = KeptInstance.of(registry);
                return;
            }
        }
        self.set(owner, value);
    }

    /// A document's own association, and a node's whose registry its
    /// document does not keep: traced from `owner`.
    pub fn set(self: *RegistryAssociation, owner: *runtime.Instance, value: ?*runtime.Instance) void {
        if (value) |registry| {
            if (owner.ctx.hasEngine()) {
                engine.traceChild(owner, registry, .{ .name = "customElementRegistry" });
                self.traced = true;
            }
        } else self.release(owner);
        self.value = value;
        self.kept = if (value) |registry| KeptInstance.of(registry) else null;
    }
    /// The registry, or null: none was set, or the one set is gone.
    pub fn get(self: *const RegistryAssociation) ?*runtime.Instance {
        const kept = self.kept orelse return null;
        return kept.get();
    }
    pub fn release(self: *RegistryAssociation, owner: *runtime.Instance) void {
        if (self.traced) engine.forgetTracedChild(owner, .{ .name = "customElementRegistry" });
        self.traced = false;
    }
};
pub const DocumentSteps = struct {
    set_registry: *const fn (*runtime.Instance, ?*runtime.Instance) anyerror!void,
    ensure_global_registry: *const fn (*runtime.Instance) anyerror!*runtime.Instance,
};
pub const ShadowSteps = struct {
    set_registry: *const fn (*runtime.Instance, ?*runtime.Instance) anyerror!void,
    create: *const fn (*runtime.Instance, ShadowRootInit, ?*runtime.Instance) anyerror!*runtime.Instance,
    clone_flags: *const fn (*runtime.Instance, *runtime.Instance) void,
    available_to_internals: *const fn (*runtime.Instance) bool,
    keeps_registry_null: *const fn (*runtime.Instance) bool,
};
pub const HTMLElementSteps = struct {
    internals: *const fn (*runtime.Instance) ?*runtime.Instance,
    ensure_internals: *const fn (*runtime.Instance) anyerror!*runtime.Instance,
};
pub const InternalsSteps = struct {
    set_target: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    states: *const fn (*runtime.Instance) ?*runtime.Instance,
    validity_flags: *const fn (*runtime.Instance) ValidityFlags,
    refresh_form: *const fn (*runtime.Instance) void,
    append_form_entries: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    validation_state: *const fn (*runtime.Instance) ValidationState,
    disabled_state: *const fn (*runtime.Instance) ?bool,
};
pub const ValiditySteps = struct {
    set_internals: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
};
pub const CustomStateSteps = struct {
    set_target: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    has: *const fn (*runtime.Instance, []const u8) bool,
};
pub const Creation = struct {
    document: *runtime.Instance,
    local_name: []const u8,
    namespace: ?[]const u8,
    prefix: ?[]const u8 = null,
    is_value: ?[]const u8 = null,
    synchronous: bool = false,
    registry: RegistrySelection = .default,
};
pub const OwnerSteps = struct {
    has_definitions: *const fn (runtime.Context) bool,
    lookup: *const fn (?*runtime.Instance, ?[]const u8, []const u8, ?[]const u8) ?*Definition,
    definition_for_constructor: *const fn (*runtime.Instance, runtime.Context, runtime.JSValue) ?*Definition,
    create: *const fn (Creation) anyerror!*runtime.Instance,
    try_upgrade: *const fn (*runtime.Instance) void,
    enqueue_callback: *const fn (*runtime.Instance, CallbackType, CallbackArgs) void,
    cancel_element: *const fn (*runtime.Instance) void,
    is_scoped: *const fn (*runtime.Instance) bool,
    associate_document: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    form_tree_changed: *const fn (*runtime.Instance) void,
};
const Implementation = struct { element: ?ElementSteps = null, owner: ?OwnerSteps = null, document: ?DocumentSteps = null, shadow: ?ShadowSteps = null, html_element: ?HTMLElementSteps = null, internals: ?InternalsSteps = null, custom_states: ?CustomStateSteps = null, validity: ?ValiditySteps = null };
// process-wide: immutable function pointers installed at process start; all mutable data belongs to elements or agents, so many Browsers and threads share no reaction state
var implementation: Implementation = .{};

pub fn installElement(steps: ElementSteps) void {
    process_start.assertInstalling();
    implementation.element = steps;
}
pub fn installOwner(steps: OwnerSteps) void {
    process_start.assertInstalling();
    implementation.owner = steps;
}
pub fn installDocument(steps: DocumentSteps) void {
    process_start.assertInstalling();
    implementation.document = steps;
}
pub fn installShadow(steps: ShadowSteps) void {
    process_start.assertInstalling();
    implementation.shadow = steps;
}
pub fn installHTMLElement(steps: HTMLElementSteps) void {
    process_start.assertInstalling();
    implementation.html_element = steps;
}
pub fn installInternals(steps: InternalsSteps) void {
    process_start.assertInstalling();
    implementation.internals = steps;
}
pub fn installCustomStates(steps: CustomStateSteps) void {
    process_start.assertInstalling();
    implementation.custom_states = steps;
}
pub fn installValidity(steps: ValiditySteps) void {
    process_start.assertInstalling();
    implementation.validity = steps;
}
pub fn setValidityInternals(validity: *runtime.Instance, internals: *runtime.Instance) !void {
    return (implementation.validity orelse return error.InvalidStateError).set_internals(validity, internals);
}
pub fn validityFlags(internals: *runtime.Instance) ValidityFlags {
    return (implementation.internals orelse return .{}).validity_flags(internals);
}
pub fn validationState(element: *runtime.Instance) ValidationState {
    return (implementation.internals orelse return .inapplicable).validation_state(element);
}
pub fn disabledState(element: *runtime.Instance) ?bool {
    return (implementation.internals orelse return null).disabled_state(element);
}
pub fn setCustomStatesTarget(states: *runtime.Instance, target: *runtime.Instance) !void {
    return (implementation.custom_states orelse return error.InvalidStateError).set_target(states, target);
}
/// DOM's defined-element definition and HTML 4.16.3: registry association
/// does not affect whether an uncustomized or custom element is defined.
pub fn isDefined(element: *runtime.Instance) bool {
    const data = get(element) orelse return false;
    return data.state == .uncustomized or data.state == .custom;
}
/// HTML :state() reads the target's states without materializing internals.
pub fn matchesState(element: *runtime.Instance, name: []const u8) bool {
    const internals = attachedInternals(element) orelse return false;
    const states = (implementation.internals orelse return false).states(internals) orelse return false;
    return (implementation.custom_states orelse return false).has(states, name);
}
pub fn attachedInternals(element: *runtime.Instance) ?*runtime.Instance {
    return (implementation.html_element orelse return null).internals(element);
}
pub fn ensureInternals(element: *runtime.Instance) !*runtime.Instance {
    return (implementation.html_element orelse return error.InvalidStateError).ensure_internals(element);
}
pub fn isFormAssociated(element: *runtime.Instance) bool {
    const data = get(element) orelse return false;
    const definition = data.definition orelse return false;
    return definition.form_associated and data.state == .custom;
}
pub fn refreshForm(element: *runtime.Instance) void {
    if (!isFormAssociated(element)) return;
    refreshFormAfterUpgrade(element);
}
/// HTML upgrade step 11 runs just before step 12 makes the element custom.
/// Ordinary mutations must not expose precustomized elements as form controls.
pub fn refreshFormAfterUpgrade(element: *runtime.Instance) void {
    const internals = ensureInternals(element) catch return;
    (implementation.internals orelse return).refresh_form(internals);
}
pub fn appendFormEntries(element: *runtime.Instance, form_data: *runtime.Instance) !void {
    const internals = attachedInternals(element) orelse return;
    return (implementation.internals orelse return error.InvalidStateError).append_form_entries(internals, form_data);
}
pub fn setInternalsTarget(internals: *runtime.Instance, target: *runtime.Instance) !void {
    return (implementation.internals orelse return error.InvalidStateError).set_target(internals, target);
}
pub fn setElementRegistry(element: *runtime.Instance, registry: ?*runtime.Instance) !void {
    return (implementation.element orelse return error.InvalidStateError).set_registry(element, registry);
}
pub fn setDocumentRegistry(document: *runtime.Instance, registry: ?*runtime.Instance) !void {
    return (implementation.document orelse return error.InvalidStateError).set_registry(document, registry);
}
pub fn ensureGlobalRegistry(document: *runtime.Instance) !*runtime.Instance {
    return (implementation.document orelse return error.InvalidStateError).ensure_global_registry(document);
}
pub fn setShadowRegistry(shadow: *runtime.Instance, registry: ?*runtime.Instance) !void {
    return (implementation.shadow orelse return error.InvalidStateError).set_registry(shadow, registry);
}
pub fn attachShadow(host: *runtime.Instance, options: ShadowRootInit, registry: ?*runtime.Instance) !*runtime.Instance {
    return (implementation.element orelse return error.InvalidStateError).attach_shadow(host, options, registry);
}
pub fn createShadow(host: *runtime.Instance, options: ShadowRootInit, registry: ?*runtime.Instance) !*runtime.Instance {
    return (implementation.shadow orelse return error.InvalidStateError).create(host, options, registry);
}
pub fn cloneShadowFlags(source: *runtime.Instance, copy: *runtime.Instance) void {
    (implementation.shadow orelse return).clone_flags(source, copy);
}
pub fn shadowAvailableToInternals(shadow: *runtime.Instance) bool {
    return (implementation.shadow orelse return false).available_to_internals(shadow);
}
pub fn shadowKeepsRegistryNull(shadow: *runtime.Instance) bool {
    return (implementation.shadow orelse return false).keeps_registry_null(shadow);
}
pub fn formTreeChanged(root: *runtime.Instance) void {
    (implementation.owner orelse return).form_tree_changed(root);
}
/// DOM's effective global custom element registry: a scoped registry yields null.
pub fn effectiveGlobal(registry: ?*runtime.Instance) ?*runtime.Instance {
    const value = registry orelse return null;
    return if (isScoped(value)) null else value;
}
pub fn isScoped(registry: *runtime.Instance) bool {
    return (implementation.owner orelse return false).is_scoped(registry);
}
pub fn associateDocument(registry: *runtime.Instance, document: *runtime.Instance) !void {
    return (implementation.owner orelse return error.InvalidStateError).associate_document(registry, document);
}
pub fn get(element: *runtime.Instance) ?ElementData {
    return (implementation.element orelse return null).get(element);
}
/// DOM create-an-element's prefix, is value and custom-element state.
pub fn initialize(element: *runtime.Instance, prefix: ?[]const u8, is_value: ?[]const u8, state: State) !void {
    return (implementation.element orelse return error.InvalidStateError).initialize(element, prefix, is_value, state);
}
pub fn setState(element: *runtime.Instance, state: State) void {
    (implementation.element orelse return).set_state(element, state);
}
pub fn setDefinition(element: *runtime.Instance, definition: ?*Definition) void {
    (implementation.element orelse return).set_definition(element, definition);
}
/// DOM's shadow root concept, including closed roots. The IDL shadowRoot
/// getter deliberately hides closed roots and cannot serve tree algorithms.
pub fn shadowRootOf(element: *runtime.Instance) ?*runtime.Instance {
    return (implementation.element orelse return null).shadow_root_of(element);
}
pub fn markEnqueued(element: *runtime.Instance) void {
    (implementation.element orelse return).mark_enqueued(element);
}
pub fn cancelElement(element: *runtime.Instance) void {
    (implementation.owner orelse return).cancel_element(element);
}
/// The registry is explicit: lookup never substitutes an entered realm.
pub fn lookup(registry: ?*runtime.Instance, namespace: ?[]const u8, local_name: []const u8, is_value: ?[]const u8) ?*Definition {
    return (implementation.owner orelse return null).lookup(registry, namespace, local_name, is_value);
}
/// HTMLConstructor's registry lookup uses SameValue on the constructor.
pub fn definitionForConstructor(registry: *runtime.Instance, realm: runtime.Context, constructor: runtime.JSValue) ?*Definition {
    return (implementation.owner orelse return null).definition_for_constructor(registry, realm, constructor);
}
pub fn create(options: Creation) !*runtime.Instance {
    return (implementation.owner orelse return error.InvalidStateError).create(options);
}
pub fn tryUpgrade(element: *runtime.Instance) void {
    (implementation.owner orelse return).try_upgrade(element);
}
pub fn hasDefinitions(realm: runtime.Context) bool {
    return (implementation.owner orelse return false).has_definitions(realm);
}
pub fn enqueueCallback(element: *runtime.Instance, kind: CallbackType, args: CallbackArgs) void {
    (implementation.owner orelse return).enqueue_callback(element, kind, args);
}
