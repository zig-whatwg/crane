//! Implementation for the NavigatorLanguage mixin (HTML 8.9.1.4):
//! language and languages, shared by Navigator and WorkerNavigator.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const host_overrides = html.window.host_overrides;
const NavigatorLanguage = interfaces.NavigatorLanguage;

pub const State = NavigatorLanguage.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

fn hostOverridesOf(instance: *runtime.Instance) ?*const host_overrides.HostOverrides {
    const window = html.user_activation.windowOfRealm(instance.ctx) orelse return null;
    const bc = dom.browser_state.browsingContextOf(window) orelse return null;
    return &bc.getTop().host_overrides;
}

/// The languages the navigator reports now (OWNED): the tab's Accept-Language
/// override or a dedicated worker's snapshot of it, else the platform's list.
fn currentLanguages(instance: *runtime.Instance) !host_overrides.Languages {
    if (hostOverridesOf(instance)) |overrides| {
        if (try overrides.languages(instance.ctx.allocator)) |list| return list;
    }
    if (html.worker_host.userAgentOverrideOfRealm(instance.ctx)) |snapshot| {
        if (try snapshot.languages(instance.ctx.allocator)) |list| return list;
    }
    return host_overrides.platformLanguages(instance.ctx.allocator);
}

/// Getter for language (HTML 8.9.1.4): navigator.languages' first tag.
pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var list = try currentLanguages(instance);
    defer list.deinit(instance.ctx.allocator);
    return runtime.DOMString.initDupe(instance.ctx.allocator, list.first());
}

/// The member a navigator keeps its languages array in (engine.traceValue).
const languages_slot: engine.TracedSlot = .{ .name = "languages" };

/// Whether `array` holds exactly `tags`, in order.
fn holdsLanguages(instance: *runtime.Instance, array: runtime.JSValue, tags: []const []u8) bool {
    var key_buffer: [24]u8 = undefined;
    for (tags, 0..) |tag, i| {
        const key = std.fmt.bufPrint(&key_buffer, "{d}", .{i}) catch return false;
        const element = engine.getProperty(instance.ctx, array, key) catch return false;
        defer element.release();
        const text = engine.convertToDOMString(instance.ctx, element.borrow(), instance.ctx.allocator) catch return false;
        defer instance.ctx.allocator.free(text);
        if (!std.mem.eql(u8, text, tag)) return false;
    }
    const past = std.fmt.bufPrint(&key_buffer, "{d}", .{tags.len}) catch return false;
    return !(engine.hasOwnProperty(instance.ctx, array, past) catch true);
}

/// Getter for languages (HTML 8.9.1.4): a frozen array of valid BCP 47
/// language tags ordered by preference; the same object is returned until the
/// list changes (e.g. via a host Accept-Language override).
pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    var list = try currentLanguages(instance);
    defer list.deinit(allocator);
    if (engine.tracedValue(instance, languages_slot)) |kept| {
        if (holdsLanguages(instance, kept.borrow(), list.tags)) return kept.take();
        kept.release();
    }
    const values = try allocator.alloc(runtime.JSValue, list.tags.len);
    defer allocator.free(values);
    for (list.tags, values) |tag, *value| value.* = .{ .string = .{ .data = tag, .owned = false } };
    const array = try engine.createFrozenArray(instance.ctx, values);
    engine.traceValue(instance, array.value, languages_slot);
    return array.take();
}
