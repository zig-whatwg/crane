//! Custom-element steps with no IDL member, installed by their owners.
//! lint-impls: hook for Element, CustomElementRegistry
const runtime = @import("runtime");
const engine = @import("engine");
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
};
pub const Creation = struct {
    document: *runtime.Instance,
    local_name: []const u8,
    namespace: ?[]const u8,
    prefix: ?[]const u8 = null,
    is_value: ?[]const u8 = null,
    synchronous: bool = false,
};
pub const OwnerSteps = struct {
    has_definitions: *const fn (runtime.Context) bool,
    lookup: *const fn (?*runtime.Instance, ?[]const u8, []const u8, ?[]const u8) ?*Definition,
    create: *const fn (Creation) anyerror!*runtime.Instance,
    try_upgrade: *const fn (*runtime.Instance) void,
    enqueue_callback: *const fn (*runtime.Instance, CallbackType, CallbackArgs) void,
};
const Implementation = struct { element: ?ElementSteps = null, owner: ?OwnerSteps = null };
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
/// The registry is explicit: lookup never substitutes an entered realm.
pub fn lookup(registry: ?*runtime.Instance, namespace: ?[]const u8, local_name: []const u8, is_value: ?[]const u8) ?*Definition {
    return (implementation.owner orelse return null).lookup(registry, namespace, local_name, is_value);
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
