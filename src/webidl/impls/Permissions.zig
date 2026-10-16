//! Permissions 6.2: query a supported permission in this object's realm.
//! Spec: https://w3c.github.io/permissions/#query-method
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const permissions = @import("permissions");

pub const State = interfaces.Permissions.State;
pub const InternalState = struct {};
pub const ImplError = error{ NotImplemented, InvalidStateError, TypeError, OutOfMemory };

// These legacy members remain in the pinned IDL; they are not Permissions
// query algorithms and do not fabricate grants or revoke a Browser's state.
pub fn call_revoke(instance: *runtime.Instance, permissionDesc: runtime.JSValue) anyerror!runtime.JSValue {
    _ = .{ instance, permissionDesc };
    return error.NotImplemented;
}

pub fn call_request(instance: *runtime.Instance, permissionDesc: runtime.JSValue) anyerror!runtime.JSValue {
    _ = .{ instance, permissionDesc };
    return error.NotImplemented;
}

pub fn call_query(instance: *runtime.Instance, permissionDesc: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = instance.ctx;
    // Step 1. Deviation from the spec text, which checks the CURRENT settings
    // object's document: use this's RELEVANT document, as WebKit
    // Permissions::query and Gecko Permissions::Query do, including calls
    // through another window. All three browsers agree (wpt.fyi,
    // permissions/non-fully-active.https.html subtest 1: Chrome 155,
    // Firefox 157, Safari 27 pass); pinned by crane/pm-inactive.https.html.
    if (realm.isWindow()) {
        const window = relevantGlobal(realm);
        if (window == null or !dom.document_activity.fullyActive(window.?, runtime.SlabAllocator.generationOf(window.?))) {
            const reason = try engine.createDOMException(realm, "InvalidStateError", "The document is not fully active.");
            defer reason.release();
            return (try engine.createRejectedPromise(realm, reason.value)).take();
        }
    }

    // Steps 2-6: catch the whole conversion, preserving thrown values even
    // when they are undefined, null or a primitive. No descriptor survives
    // as a script object: the task owns only the converted native value.
    var conversion = Conversion{ .realm = realm, .input = permissionDesc };
    if (try engine.completionOf(realm, Conversion.run, &conversion)) |exception| {
        defer exception.release();
        return (try engine.createRejectedPromise(realm, exception.value)).take();
    }
    const descriptor = conversion.result.?;
    const state = queryState(realm, descriptor);

    // Step 7. Both this owned capability and the returned owned promise must
    // survive until the caller / the queued task takes its respective part.
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const task = try realm.allocator.create(QueryTask);
    task.* = .{
        .allocator = realm.allocator,
        .realm = realm,
        .capability = capability,
        .descriptor = descriptor,
        .state = state,
    };
    // Step 8: create the status in the task, so no native platform object is
    // held across turns. enqueue takes the record, including on queue drop.
    enqueue(realm, task);
    return promise.take();
}

const Conversion = struct {
    realm: runtime.Context,
    input: runtime.JSValue,
    result: ?permissions.PermissionDescriptor = null,

    fn run(data: ?*anyopaque) engine.Error!void {
        const self: *Conversion = @ptrCast(@alignCast(data.?));
        // The IDL argument is object; the dictionary requires a name.
        if (engine.typeOf(self.realm, self.input) != .object) return error.TypeError;
        const name = try self.readName();
        var descriptor = permissions.PermissionDescriptor.simple(name);
        // Step 5 deviation: all three engines convert plain descriptors
        // once. Gecko and WebKit also convert camera/push only once (no
        // panTiltZoom/userVisibleOnly reads). Only MIDI is converted twice
        // by both supporting engines, Blink and Gecko; WPT midi-permission
        // pins it. Sources: dom/permission/Permissions.cpp (Gecko),
        // Modules/permissions/Permissions.cpp (WebKit), and Blink's
        // modules/permissions/permission_utils.cc, ParsePermissionDescriptor.
        if (name == .midi) {
            // Both engines validate the second name but retain the kind
            // selected by the first conversion, even when that name changes.
            _ = try self.readName();
            descriptor = permissions.PermissionDescriptor.midi((try engine.getPropertyBoolean(self.realm, self.input, "sysex")) orelse false);
        }
        self.result = descriptor;
    }

    fn readName(self: *Conversion) engine.Error!permissions.PermissionName {
        const value = try engine.getProperty(self.realm, self.input, "name");
        defer value.release();
        if (engine.typeOf(self.realm, value.value) == .undefined) return error.TypeError;
        const name = try engine.convertToDOMString(self.realm, value.value, self.realm.allocator);
        defer self.realm.allocator.free(name);
        // Step 4, and the supporting engines' enum conversion for MIDI's
        // second read: exact comparison, including embedded NULs.
        return permissions.query.supportedName(name) orelse error.TypeError;
    }
};

fn relevantGlobal(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

fn queryState(realm: runtime.Context, descriptor: permissions.PermissionDescriptor) permissions.PermissionState {
    // Permission state 5.1 step 2: read the relevant settings object's
    // secure-context flag; no serialized-origin or URL approximation.
    const global = relevantGlobal(realm);
    const secure = if (global) |g| if (dom.global_settings.of(g)) |settings| settings.is_secure_context(g) else false else false;
    // Step 4. TODO(permissions-policy): documents do not yet receive their
    // header/iframe/inherited policy. Treat them as allowed, as the media
    // element implementation does, until the owning Document hook lands.
    // Steps 5-7 await the Browser's permission store (platform recipes 8).
    // Step 8. TODO(platform recipes step 8): once step 7 supplies Requester,
    // use platform.platformPermissionState(browser,
    // &html.platform_state.requester(realm, id), &descriptor) inside
    // if (platform.capabilities.os_permissions != .unsupported).
    const state = permissions.query.defaultState(secure);
    return permissions.query.resultState(descriptor.name, state);
}

/// The feature task owns only a capability, its existing runtime Context,
/// and value copies of the descriptor and state. It holds no Instance.
const QueryTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    descriptor: permissions.PermissionDescriptor,
    state: permissions.PermissionState,

    fn run(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data.?));
        defer self.finish();
        if (!self.realm.hasEngine()) return;
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data.?));
        self.finish();
    }

    fn steps(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data.?));
        // 8.1-8.3 and 6.3.1: EventTarget construction, [[query]], name and
        // the computed state, all in the Permissions object's relevant realm.
        const status = interfaces.PermissionStatus.initWith(self.allocator, self.realm, .{
            .permission_descriptor = self.descriptor,
            .permission_state = self.state,
        }) catch return;
        // 8.4. resolvePromise uses the wrapper in the promise's realm.
        engine.resolvePromise(&self.capability, .{ .instance = status }) catch {};
    }

    fn finish(self: *QueryTask) void {
        engine.releasePromiseCapability(&self.capability);
        self.allocator.destroy(self);
    }
};

fn enqueue(realm: runtime.Context, task: *QueryTask) void {
    const loop = realm.getOptionalEventLoop() orelse return QueryTask.run(task);
    // Existing task metadata makes an inactive Window's task droppable. It
    // is a borrowed document identity plus generation, never a new holder.
    const window = if (realm.isWindow()) relevantGlobal(realm) else null;
    loop.queueTask(.{
        .callback = QueryTask.run,
        .context = task,
        .drop = QueryTask.drop,
        .document = window,
        .document_generation = if (window) |w| runtime.SlabAllocator.generationOf(w) else 0,
    });
}
