//! Implementation for SVGImageElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGImageElement = interfaces.SVGImageElement;
const dom = @import("dom");
const engine = @import("engine");
const images = dom.style.engine.available_images;
const resources = dom.style.engine.resource_loading.svg_resources;

pub const State = SVGImageElement.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    loader: ?*images.Loader = null,
    /// A fetch queued for the next microtask checkpoint (`queueUpdate`) that
    /// has not run: until it runs it holds a keep of the element and a delay
    /// of its node document's load event.
    queued: ?Queued = null,

    pub fn deinit(self: *InternalState) void {
        // The element goes - its realm is ending, since a queued update keeps
        // it otherwise: the microtask will find it gone, the keep goes with the
        // realm, and the load delay ends here.
        if (self.queued) |queued| {
            self.queued = null;
            queued.endDelay();
        }
        const loader = self.loader;
        self.loader = null;
        if (loader) |value| value.destroy();
    }
};

/// What a queued update holds of the element's node document: a delay of its
/// load event, ended once the update has run (the fetch it starts delays the
/// event itself) or the element has gone.
const Queued = struct {
    document: *runtime.Instance,
    document_generation: u64,
    document_realm: runtime.Context,

    fn of(document: *runtime.Instance) Queued {
        return .{ .document = document, .document_generation = runtime.SlabAllocator.generationOf(document), .document_realm = document.ctx };
    }

    fn endDelay(self: Queued) void {
        // Realm first: its teardown may already have freed the slab ledger.
        if (!self.document_realm.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        dom.document_lifecycle.undelayLoadEvent(self.document);
    }
};
const Registry = runtime.InstanceRegistry(.svg_image_element, InternalState);

pub fn installHooks() void {
    resources.installAttributeSteps();
    dom.style.hooks.install(.{ .svg_image_resource_changed = queueUpdate });
    dom.mutation.registerInsertionStepsCallback(insertionSteps) catch {};
    dom.adopting_steps.install(adoptingSteps);
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareAbort, .abort = abortDocument });
}

/// The generated SVGGraphicsElement construction/destruction chain owns
/// the ancestors. This registry owns only this element's resource state.
pub fn initOwn(instance: *runtime.Instance, _: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| internal.deinit();
    if (instance.stateAs(State)) |state| state.own._internal = null;
    Registry.remove(instance);
}

/// SVG 2 §§12.3, 16.1.7: an href change loads the image, whether or not it
/// is displayed - and so does a crossorigin change, an insertion and an
/// adoption. SVG 2 does not say WHEN the fetch starts. Crane starts it as
/// HTML's img "update the image data" does (step 8: queue a microtask;
/// HTMLImageElement startLoad), and as Chrome and Firefox start an SVG
/// image's: in a microtask queued at the change, with the attributes and the
/// node document the element has when the microtask runs. So href,
/// crossorigin and insertion in one task make ONE request, with their final
/// values. Blink: SVGImageElement's href and crossorigin changes call
/// ImageLoader::UpdateFromElement, which queues a microtask unless
/// ShouldLoadImmediately - an image its memory cache holds, or an object,
/// embed or video element (third_party/blink/renderer/core/loader/
/// image_loader.cc, read 2026-11-20). WebKit fetches at once
/// (SVGImageElement::attributeChanged -> ImageLoader::updateFromElement).
/// wpt.fyi a3830cd8f7, fetch/metadata/generated/svg-image.https.sub.html's
/// three crossorigin subtests (href set, then crossorigin): Chrome 158 and
/// Firefox 160 pass all three, Safari 27.2 fails two - golden rule 2, the
/// majority. Crane fetched at once too and failed all three: the first,
/// no-cors request was recorded, the second got the stash's refusal (lane
/// flk2). Until the microtask runs the element is kept and its document's
/// load event delayed, as img's are from its update's start.
fn queueUpdate(instance: *runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    // One queued update reads the element as it is when it runs.
    if (internal.queued != null) return;
    // No event loop (a document no Browser runs) or no document: at once.
    const loop = instance.ctx.getOptionalEventLoop() orelse return updateNow(instance);
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return updateNow(instance);
    const allocator = instance.ctx.allocator;
    const context = allocator.create(UpdateMicrotask) catch return updateNow(instance);
    context.* = .{
        .instance = instance,
        .instance_generation = runtime.SlabAllocator.generationOf(instance),
        .realm = instance.ctx,
        .allocator = allocator,
    };
    internal.queued = Queued.of(document);
    engine.keepPlatformObjectAlive(instance);
    dom.document_lifecycle.delayLoadEvent(document);
    loop.queueMicrotask(.{ .callback = UpdateMicrotask.run, .context = context });
}

/// A queued update's microtask: the element, checked by slab generation.
const UpdateMicrotask = struct {
    instance: *runtime.Instance,
    instance_generation: u64,
    realm: runtime.Context,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *UpdateMicrotask = @ptrCast(@alignCast(data.?));
        const instance = self.instance;
        const instance_generation = self.instance_generation;
        const realm = self.realm;
        self.allocator.destroy(self);
        // Realm first: its teardown may already have freed the slab ledger.
        if (!realm.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(instance) != instance_generation) return;
        const internal = Registry.get(instance) orelse return;
        const queued = internal.queued orelse return;
        internal.queued = null;
        updateNow(instance);
        // The fetch, if any, took its own keep and delay first.
        queued.endDelay();
        engine.releasePlatformObject(instance);
    }
};

/// The update itself, against the element's attributes now: the image's
/// fetch, superseding the one in flight, or its cancellation.
fn updateNow(instance: *runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    const source = resources.href(instance) orelse {
        if (internal.loader) |loader| loader.cancel();
        return;
    };
    if (internal.loader == null) internal.loader = images.Loader.create(instance) catch return;
    const data = dom.element_data.of(instance) orelse return;
    const cors = if (data.findAttribute(null, "crossorigin")) |attribute| attribute.value else null;
    internal.loader.?.start(source, .{
        .initiator = .image,
        .cors = images.CorsSetting.fromAttribute(cors),
        .invalid_source = .queue_error,
    }) catch {};
}

fn insertionSteps(node: *dom.NodeBase) void {
    if (node.node_type != dom.NodeBase.ELEMENT_NODE or !node.is_connected) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const internal = Registry.get(instance) orelse return;
    // An href set while detached may already have started, or be queued.
    // Insertion must not duplicate it; an inert document's attempt has no
    // document owner.
    if (internal.loader) |loader| if (loader.document != null) return;
    queueUpdate(instance);
}

fn adoptingSteps(instance: *runtime.Instance, _: ?*runtime.Instance) void {
    const internal = Registry.get(instance) orelse return;
    if (internal.loader) |loader| loader.cancel();
    // A queued update fetches for the new document: its load event is the
    // one delayed now.
    if (internal.queued) |queued| {
        const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
        queued.endDelay();
        internal.queued = Queued.of(document);
        dom.document_lifecycle.delayLoadEvent(document);
        return;
    }
    queueUpdate(instance);
}

fn discardRealm(realm: runtime.Context) void {
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| {
        if (loader.realm == realm) loader.cancel();
    };
}

fn prepareAbort(document: *runtime.Instance) bool {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var marked = false;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| {
        marked = loader.markAbort(document) or marked;
    };
    return marked;
}

fn abortDocument(document: *runtime.Instance) void {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iterator.next()) |entry| if (entry.internal.loader) |loader| loader.abortMarked(document);
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for preserveAspectRatio
pub fn get_preserveAspectRatio(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const data = dom.element_data.of(instance) orelse return null;
    const attribute = data.findAttribute(null, "crossorigin") orelse return null;
    return runtime.DOMString.initInterned(if (images.CorsSetting.fromAttribute(attribute.value) == .use_credentials) "use-credentials" else "anonymous");
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |text| try dom.element_attributes.set(instance, "crossorigin", text.asSlice(), .{}) else dom.element_attributes.remove(instance, null, "crossorigin");
}
