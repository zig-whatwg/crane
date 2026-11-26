//! Implementation for the MessageEventTarget mixin (HTML 9.3.1 / 10.2.1):
//! onmessage and onmessageerror.
//!
//! Its includers (DedicatedWorkerGlobalScope, MessagePort, Worker) inherit
//! these members by alias (codegen/inherited_mixins.zig). get_onmessage,
//! get_onmessageerror and set_onmessageerror are handled directly by the
//! generated module through dom.event_handlers; set_onmessage also enables a
//! MessagePort's port message queue per HTML 9.3.2.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const MessageEventTarget = interfaces.MessageEventTarget;

pub const State = MessageEventTarget.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Setter for onmessage (HTML 9.3.2): sets the "message" event handler, and
/// when the receiver is a MessagePort, enables its port message queue (the
/// same step as MessagePort.start()).
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "message", value);
    if (instance.stateAs(interfaces.MessagePort.State) != null) {
        try interfaces.MessagePort.call_start(instance);
    }
}
