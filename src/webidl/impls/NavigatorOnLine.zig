//! Implementation for the NavigatorOnLine mixin (HTML 8.9.1.5):
//! onLine, shared by Navigator and WorkerNavigator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const NavigatorOnLine = interfaces.NavigatorOnLine;

pub const State = NavigatorOnLine.State;

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

/// Getter for onLine (HTML 8.9.1.5): reflects CDP Network.overrideNetworkState
/// / emulateNetworkConditions for Window navigators, true otherwise.
pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
    if (hostOverridesOf(instance)) |overrides| return !overrides.network_state_offline;
    return true;
}
