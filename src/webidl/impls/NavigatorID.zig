//! Implementation for the NavigatorID mixin (HTML 8.9.1.1):
//! appCodeName, appName, appVersion, platform, product, productSub,
//! userAgent, vendor, vendorSub, oscpu, and taintEnabled, shared by
//! Navigator and WorkerNavigator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const fetch = @import("fetch");
const platform = @import("platform");
const NavigatorID = interfaces.NavigatorID;

pub const State = NavigatorID.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// The host's overrides for the tab this navigator's Window shows, if it is a
/// Window's navigator.
fn hostOverridesOf(instance: *runtime.Instance) ?*const html.window.host_overrides.HostOverrides {
    const window = html.user_activation.windowOfRealm(instance.ctx) orelse return null;
    const bc = dom.browser_state.browsingContextOf(window) orelse return null;
    return &bc.getTop().host_overrides;
}

/// The user agent override of the worker this navigator belongs to, or null.
fn userAgentOverrideOf(instance: *runtime.Instance) ?*const html.window.host_overrides.UserAgentSnapshot {
    return html.worker_host.userAgentOverrideOfRealm(instance.ctx);
}

/// Getter for appCodeName (HTML 8.9.1.1): "Must return the string 'Mozilla'."
pub fn get_appCodeName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Mozilla");
}

/// Getter for appName (HTML 8.9.1.1): "Must return the string 'Netscape'."
pub fn get_appName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Netscape");
}

/// Getter for appVersion (HTML 8.9.1.1): from this's relevant settings
/// object's environment default `User-Agent` value (its Browser's).
pub fn get_appVersion(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const network = dom.browser_state.networkOf(instance.ctx) orelse
        return runtime.DOMString.initInterned(fetch.internal.user_agent.app_version);
    return runtime.DOMString.initDupe(instance.ctx.allocator, network.appVersion());
}

/// Getter for platform (HTML 8.9.1.1): tab/worker host override, else the
/// compile target's platform string.
pub fn get_platform(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (hostOverridesOf(instance)) |overrides| {
        if (overrides.platform) |plat| return runtime.DOMString.initDupe(instance.ctx.allocator, plat);
    }
    if (userAgentOverrideOf(instance)) |snapshot| {
        if (snapshot.platform) |plat| return runtime.DOMString.initDupe(instance.ctx.allocator, plat);
    }
    return runtime.DOMString.initInterned(platform.identity.navigator_platform.slice());
}

/// Getter for product (HTML 8.9.1.1): "Must return the string 'Gecko'."
pub fn get_product(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Gecko");
}

/// Getter for productSub (HTML 8.9.1.1): "20030107" (Chrome/WebKit compat mode).
pub fn get_productSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("20030107");
}

/// Getter for userAgent (HTML 8.9.1.1): host override (tab or worker copy),
/// else this's relevant settings object's environment default `User-Agent`
/// value (its Browser's NetworkContext).
pub fn get_userAgent(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (hostOverridesOf(instance)) |overrides| {
        if (overrides.user_agent) |ua| return runtime.DOMString.initDupe(instance.ctx.allocator, ua);
    }
    if (userAgentOverrideOf(instance)) |snapshot| {
        if (snapshot.user_agent) |ua| return runtime.DOMString.initDupe(instance.ctx.allocator, ua);
    }
    const network = dom.browser_state.networkOf(instance.ctx) orelse
        return runtime.DOMString.initInterned(fetch.internal.user_agent.default_user_agent);
    return runtime.DOMString.initDupe(instance.ctx.allocator, network.userAgent());
}

/// Getter for vendor (HTML 8.9.1.1).
/// DEVIATION, by the user's ruling of 2026-11-21 7:32 PM ET: Crane returns
/// its own name, "Crane", in place of Chrome mode's "Google Inc.".
pub fn get_vendor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("Crane");
}

/// Getter for vendorSub (HTML 8.9.1.1): empty string.
pub fn get_vendorSub(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initEmpty();
}

/// Getter for oscpu (HTML 8.9.1.1, [Exposed=Window]).
pub fn get_oscpu(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned(platform.identity.oscpu.slice());
}

/// Operation: taintEnabled (HTML 8.9.1.1, [Exposed=Window]).
pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
