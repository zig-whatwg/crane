//! Implementation for the NavigatorCookies mixin (HTML 8.9.1.6):
//! cookieEnabled, included by Navigator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NavigatorCookies = interfaces.NavigatorCookies;

pub const State = NavigatorCookies.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for cookieEnabled (HTML 8.9.1.6).
pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return true;
}
