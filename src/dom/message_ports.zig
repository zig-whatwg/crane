//! HTML's MessagePort transfer steps and transfer-receiving steps (§ 9.4.3),
//! for code that transfers ports without being MessagePort: a Worker's
//! postMessage, a worker's implicit port, the one shared transfer step
//! (dom.transferables). And the ports a stream's cross-realm transform
//! listens and posts on (Streams 8.2): made, posted to and disentangled
//! here (`hidden`, `post`, `disentangle`). No IDL member runs any of these,
//! so MessagePort installs them here, the shape of `abort_algorithms.zig`.
//!
//! A port's END is its channel end (dom.port_channels.End) - the port
//! message queue and the entanglement - opaque at this seam. Shipping a port
//! hands its end over as the data holder; receiving it makes a new
//! MessagePort on it in the receiving realm, which may be another thread's.
//!
//! lint-impls: hook for MessagePort
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");

pub const Steps = struct {
    /// Whether `instance` can be transferred: not a MessagePort, a
    /// MessagePort, or a detached one (HTML 2.7.5 steps 2.1 and 5.2).
    transferable_state: *const fn (instance: *runtime.Instance) runtime.TransferableState,
    /// The transfer steps for the MessagePort `instance`: it is shipped and
    /// detached, and its end - which the caller now holds, to hand to
    /// `receive` - is returned.
    ship: *const fn (instance: *runtime.Instance) ?*anyopaque,
    /// The transfer-receiving steps: a new MessagePort of `realm` on `end`,
    /// which it takes.
    receive: *const fn (realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance,
    /// A new MessagePort of `realm` on `end`, an end of a fresh channel
    /// (dom.port_channels.Channel) - not a transferred one: MessageChannel's
    /// ports, a SharedWorker's outside port. Takes `end`, also on failure.
    adopt: *const fn (realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance,
    /// Free `end`, which no port will take: its queue goes, and its
    /// entangled port is disentangled.
    discard: *const fn (end: *anyopaque) void,
    /// A new MessagePort of `realm` on `end` (taken, also on failure) whose
    /// `message` and `messageerror` are `receiver`'s native steps, its port
    /// message queue enabled (`hidden`).
    hidden: *const fn (realm: runtime.Context, end: *anyopaque, receiver: NativeReceiver) anyerror!*runtime.Instance,
    /// The message port post message steps from `port` with an empty
    /// transfer list (`post`).
    post: *const fn (port: *runtime.Instance, message: runtime.JSValue) anyerror!void,
    /// HTML "disentangle", initiated by `port` (`disentangle`).
    disentangle: *const fn (port: *runtime.Instance) void,
};

/// The steps a port made for a cross-realm transform (Streams 8.2) runs for
/// what reaches it: "Add a handler for port's message event" and "... for
/// port's messageerror event", as native steps run by the port's own port
/// message queue task in its realm, in place of events - script never holds
/// the port, so nothing else could hear one. WebKit gives such a port a
/// native message handler (MessagePort::setMessageHandler, used by
/// Modules/streams/StreamTransferUtilities.cpp's CrossRealmReadableStreamSource
/// and CrossRealmWritableStreamSink); Blink a native listener
/// (core/streams/transferable_streams.cc: CrossRealmTransformMessageListener,
/// CrossRealmTransformErrorListener).
pub const NativeReceiver = struct {
    ctx: *anyopaque,
    /// A message deserialized in the port's realm: its data, BORROWED for
    /// the call. Run inside the realm, as the port's task.
    message: *const fn (ctx: *anyopaque, data: runtime.JSValue) void,
    /// A message that did not deserialize: the port's messageerror.
    message_error: *const fn (ctx: *anyopaque) void,
    /// The port is gone - its realm ended, or the collector took it: the
    /// receiver lets go of it and of `ctx`'s reference. Called exactly once,
    /// unless `hidden` failed.
    released: *const fn (ctx: *anyopaque) void,
};

/// Process-wide, written once at start-up (process_start.zig).
var steps: Hook(?Steps) = .init(null);

/// Called by MessagePort's installHooks, once, at process start (process_start.zig).
pub fn install(installed: Steps) void {
    steps.install(installed);
}

/// Whether `instance` can be transferred. Nothing is a transferable port
/// before MessagePort has installed its steps - no port exists yet.
pub fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const installed = steps.get() orelse return .not_transferable;
    return installed.transferable_state(instance);
}

/// Ship the MessagePort `instance`: its end, or null when it is not one.
pub fn ship(instance: *runtime.Instance) ?*anyopaque {
    const installed = steps.get() orelse return null;
    return installed.ship(instance);
}

/// A new MessagePort of `realm` on the shipped `end`.
pub fn receive(realm: runtime.Context, end: *anyopaque) !*runtime.Instance {
    const installed = steps.get() orelse return error.NotSupported;
    return installed.receive(realm, end);
}

/// A new MessagePort of `realm` on `end`, an end of a fresh channel. Takes
/// `end`.
pub fn adopt(realm: runtime.Context, end: *anyopaque) !*runtime.Instance {
    const installed = steps.get() orelse return error.NotSupported;
    return installed.adopt(realm, end);
}

/// Free the channel end `end`, which no MessagePort took - a shared worker's
/// inside end when its worker never started. Nothing to do before MessagePort
/// has installed its steps: no end exists yet.
pub fn discard(end: *anyopaque) void {
    const installed = steps.get() orelse return;
    installed.discard(end);
}

/// A port for a cross-realm transform (Streams 8.2): a new MessagePort of
/// `realm` on `end` (taken, also on failure), which script never sees. What
/// reaches it runs `receiver`'s steps; its port message queue is enabled at
/// once (SetUpCrossRealmTransformReadable step 5, ...Writable step 6), so,
/// like any started port, it is kept while it is entangled (HTML 9.4.6).
/// `receiver.released` runs once the port is gone.
pub fn hidden(realm: runtime.Context, end: *anyopaque, receiver: NativeReceiver) !*runtime.Instance {
    const installed = steps.get() orelse return error.NotSupported;
    return installed.hidden(realm, end, receiver);
}

/// The message port post message steps from `port`, with `message` and an
/// empty transfer list (Streams PackAndPostMessage steps 4-6): `message` is
/// serialized in `port`'s realm - a throw is the caller's, pending, or
/// error.DataCloneError - and joins the entangled port's queue, if there is
/// one.
pub fn post(port: *runtime.Instance, message: runtime.JSValue) !void {
    const installed = steps.get() orelse return error.NotSupported;
    return installed.post(port, message);
}

/// HTML "disentangle" (9.4.4), initiated by `port`: the entangled port hears
/// `close`, and neither is entangled any longer.
pub fn disentangle(port: *runtime.Instance) void {
    const installed = steps.get() orelse return;
    installed.disentangle(port);
}
