//! Implementation for HTMLTemplateElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const engine = @import("engine");
const HTMLTemplateElement = interfaces.HTMLTemplateElement;

pub const State = HTMLTemplateElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    content: ?*runtime.Instance = null,
    content_generation: u64 = 0,
};
const Registry = @import("webidl").utils.InstanceRegistry(InternalState);

pub fn installHooks() void {
    dom.template_contents.install(.{ .establish = &establishContents, .adopted = &adoptingSteps });
    dom.cloning_steps.install(&cloningSteps);
}

fn establishContents(instance: *runtime.Instance) !void {
    const internal = Registry.get(instance) orelse return error.InvalidStateError;
    if (internal.content != null) return;
    // HTML 4.12.3, establishing template contents, steps 1–3.
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    const owner = try dom.template_contents.ownerDocument(document);
    const content = try interfaces.Document.call_createDocumentFragment(owner);
    errdefer dom.node_creation.destroyUninserted(content);
    try dom.template_contents.setHost(content, instance);
    internal.content = content;
    internal.content_generation = runtime.SlabAllocator.generationOf(content);
    // Collector edges, as WebKit's template and TemplateContentDocumentFragment
    // keep each other; no root outlives the template's graph.
    engine.traceChild(instance, content, .{ .name = "content" });
    engine.traceChild(content, owner, .{ .name = "template owner document" });
}

fn adoptingSteps(instance: *runtime.Instance) !void {
    // HTML template adopting steps 1–2, including already exposed fragments.
    const content = try get_content(instance);
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    const owner = try dom.template_contents.ownerDocument(document);
    const content_base = dom.instance_bridge.getNodeBase(content) orelse return error.InvalidStateError;
    const owner_base = dom.instance_bridge.getNodeBase(owner) orelse return error.InvalidStateError;
    try dom.mutation.adopt(content_base, @as(*interfaces.Document, @ptrCast(@alignCast(owner_base))));
    engine.traceChild(content, owner, .{ .name = "template owner document" });
}

fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) !void {
    // HTML template cloning steps 1–2; ordinary children are cloned by Node.
    if (!subtree or Registry.get(node) == null) return;
    const source = try get_content(node);
    const target = try get_content(copy);
    const document = (try interfaces.Node.get_ownerDocument(target)) orelse return error.InvalidStateError;
    var child = try interfaces.Node.get_firstChild(source);
    while (child) |value| {
        const next = try interfaces.Node.get_nextSibling(value);
        _ = try dom.node_creation.clone(value, document, true, target);
        child = next;
    }
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);
    const internal = try Registry.createIn(instance, runtime.ArenaAllocator.get());
    internal.* = .{};
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "content" });
        // Engine-free callers own the unwrapped fragment. A wrapped fragment
        // is the collector's, and can survive a forced host teardown.
        if (internal.content) |content| {
            if (runtime.SlabAllocator.generationOf(content) == internal.content_generation and
                (!instance.ctx.hasEngine() or
                    (!runtime.cleanup_coordinator.isContextTearingDown() and !engine.hasWrapper(content))))
                dom.node_creation.destroyUninserted(content);
        }
    }
    Registry.remove(instance);
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTemplateElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for content
pub fn get_content(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = Registry.get(instance) orelse return error.InvalidStateError;
    return internal.content orelse error.InvalidStateError;
}

/// Getter for shadowRootMode
pub fn get_shadowRootMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for shadowRootMode
pub fn set_shadowRootMode(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
