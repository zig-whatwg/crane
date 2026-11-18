//! Implementation for RTCPeerConnection interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const RTCPeerConnection = interfaces.RTCPeerConnection;

pub const State = RTCPeerConnection.State;

pub const ImplError = error{
    NotImplemented,
};

/// The internal slots WebRTC 1.0 4.4.1 gives the object and this engine
/// models: those "close the connection" sets (4.4.1.6). This engine runs no
/// ICE agent and creates no transceiver, data channel or transport, so
/// nothing else moves them: an open connection stays in its initial states.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// [[IsClosed]], initially false.
    is_closed: bool = false,
    /// [[SignalingState]], initially "stable".
    signaling_state: enums.RTCSignalingState = ._stable_,
    /// [[IceConnectionState]], initially "new".
    ice_connection_state: enums.RTCIceConnectionState = ._new_,
    /// [[ConnectionState]], initially "new".
    connection_state: enums.RTCPeerConnectionState = ._new_,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // It is no longer one of its Browser's peer connections.
    forgetConnection(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.allocator.destroy(internal);
    }
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// `instance` is no longer one of its Browser's live peer connections.
fn forgetConnection(instance: *runtime.Instance) void {
    if (instance.ctx.browserScope()) |scope| {
        if (scope.existing(LiveConnections)) |live| live.remove(instance);
    }
}

/// The hooks this type owns (src/dom), installed once, at process start, by
/// crane.Process through the generated interface.
pub fn installHooks() void {
    @import("dom").bfcache.installBlocker(&blocksBfcache);
}

/// A Browser's RTCPeerConnections, each with its realm: what keeps a page
/// with one out of the back/forward cache (`blocksBfcache`). A supplement of
/// the Browser's scope (never process-wide); RTCPeerConnection is exposed to
/// Windows only, so it is read and written on the window thread.
const LiveConnections = struct {
    allocator: std.mem.Allocator,
    connections: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    pub fn init(allocator: std.mem.Allocator) LiveConnections {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LiveConnections) void {
        self.connections.deinit(self.allocator);
    }

    fn add(self: *LiveConnections, instance: *runtime.Instance) void {
        self.connections.append(self.allocator, instance) catch {};
    }

    fn remove(self: *LiveConnections, instance: *runtime.Instance) void {
        for (self.connections.items, 0..) |connection, index| {
            if (connection != instance) continue;
            _ = self.connections.swapRemove(index);
            return;
        }
    }

    fn inRealm(self: *const LiveConnections, realm: runtime.Context) bool {
        for (self.connections.items) |connection| {
            if (connection.ctx == realm) return true;
        }
        return false;
    }
};

/// dom.bfcache: a page with an RTCPeerConnection is not kept in the
/// back/forward cache, with Chromium's reason "rtc" (kWebRTC). Chrome 155 and
/// Firefox 158 keep such a page out and Safari 27 caches it
/// (webrtc/back-forward-cache-with-open-webrtc-connection.https.window.js:
/// PASS, PASS, FAIL on wpt.fyi 23b0b89b1a) - the majority. A closed one
/// (close()) is no longer counted: it leaves the page cacheable, as
/// back-forward-cache-with-closed-webrtc-connection expects in all three.
fn blocksBfcache(realm: runtime.Context) ?@import("dom").bfcache.Blocked {
    const scope = realm.browserScope() orelse return null;
    const live = scope.existing(LiveConnections) orelse return null;
    return if (live.inRealm(realm)) .{ .reason = .rtc } else null;
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context, configuration: webidl.Opt(dictionaries.RTCConfiguration)) !*runtime.Instance {
    // Create instance through init(): the internal slots in their initial
    // states (WebRTC 4.4.1.1 constructor steps).
    const instance = try init(ctx.allocator, State, &RTCPeerConnection.vtable, ctx);
    errdefer deinit(instance);

    _ = configuration;
    // One of its Browser's peer connections, until its deinit.
    if (ctx.browserScope()) |scope| {
        if (scope.of(LiveConnections) catch null) |live| live.add(instance);
    }
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for localDescription
pub fn get_localDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for currentLocalDescription
pub fn get_currentLocalDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for pendingLocalDescription
pub fn get_pendingLocalDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for remoteDescription
pub fn get_remoteDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for currentRemoteDescription
pub fn get_currentRemoteDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for pendingRemoteDescription
pub fn get_pendingRemoteDescription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for signalingState: "return the value of [[SignalingState]]".
pub fn get_signalingState(instance: *runtime.Instance) anyerror!enums.RTCSignalingState {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.signaling_state;
}

/// Getter for iceGatheringState: the aggregate of the connection's
/// RTCIceTransports' gathering states - "new" with none (4.4.4), and this
/// engine creates none.
pub fn get_iceGatheringState(instance: *runtime.Instance) anyerror!enums.RTCIceGatheringState {
    _ = instance;
    return ._new_;
}

/// Getter for iceConnectionState: "return the value of
/// [[IceConnectionState]]".
pub fn get_iceConnectionState(instance: *runtime.Instance) anyerror!enums.RTCIceConnectionState {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.ice_connection_state;
}

/// Getter for connectionState: "return the value of [[ConnectionState]]".
pub fn get_connectionState(instance: *runtime.Instance) anyerror!enums.RTCPeerConnectionState {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.connection_state;
}

/// Getter for canTrickleIceCandidates
pub fn get_canTrickleIceCandidates(instance: *runtime.Instance) anyerror!?bool {
    _ = instance;
    return null;
}

/// Getter for onnegotiationneeded
pub fn get_onnegotiationneeded(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onicecandidate
pub fn get_onicecandidate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onicecandidateerror
pub fn get_onicecandidateerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsignalingstatechange
pub fn get_onsignalingstatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oniceconnectionstatechange
pub fn get_oniceconnectionstatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onicegatheringstatechange
pub fn get_onicegatheringstatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onconnectionstatechange
pub fn get_onconnectionstatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontrack
pub fn get_ontrack(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sctp
pub fn get_sctp(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for ondatachannel
pub fn get_ondatachannel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for peerIdentity
pub fn get_peerIdentity(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for idpLoginUrl
pub fn get_idpLoginUrl(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for idpErrorInfo
pub fn get_idpErrorInfo(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Setter for onnegotiationneeded
pub fn set_onnegotiationneeded(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onicecandidate
pub fn set_onicecandidate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onicecandidateerror
pub fn set_onicecandidateerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsignalingstatechange
pub fn set_onsignalingstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oniceconnectionstatechange
pub fn set_oniceconnectionstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onicegatheringstatechange
pub fn set_onicegatheringstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onconnectionstatechange
pub fn set_onconnectionstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontrack
pub fn set_ontrack(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondatachannel
pub fn set_ondatachannel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: addTransceiver
pub fn call_addTransceiver(instance: *runtime.Instance, trackOrKind: typedefs.MediaStreamTrackOrDOMString, init_data: webidl.Opt(dictionaries.RTCRtpTransceiverInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = trackOrKind;
    _ = init_data;
    return error.NotImplemented;
}

/// Operation: setIdentityProvider
pub fn call_setIdentityProvider(instance: *runtime.Instance, provider: runtime.DOMString, options: webidl.Opt(dictionaries.RTCIdentityProviderOptions)) anyerror!void {
    _ = instance;
    _ = provider;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setConfiguration
pub fn call_setConfiguration(instance: *runtime.Instance, configuration: webidl.Opt(dictionaries.RTCConfiguration)) anyerror!void {
    _ = instance;
    _ = configuration;
    return error.NotImplemented;
}

/// Operation: getSenders
pub fn call_getSenders(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setRemoteDescription
pub fn call_setRemoteDescription(instance: *runtime.Instance, description: dictionaries.RTCSessionDescriptionInit) anyerror!runtime.JSValue {
    _ = instance;
    _ = description;
    return error.NotImplemented;
}

/// Operation: addIceCandidate
pub fn call_addIceCandidate(instance: *runtime.Instance, candidate: webidl.Opt(dictionaries.RTCIceCandidateInit)) anyerror!runtime.JSValue {
    _ = instance;
    _ = candidate;
    return error.NotImplemented;
}

/// Operation: setLocalDescription
pub fn call_setLocalDescription(instance: *runtime.Instance, description: webidl.Opt(dictionaries.RTCLocalSessionDescriptionInit)) anyerror!runtime.JSValue {
    _ = instance;
    _ = description;
    return error.NotImplemented;
}

/// Operation: addTrack
pub fn call_addTrack(instance: *runtime.Instance, track: *runtime.Instance, streams: []const *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = track;
    _ = streams;
    return error.NotImplemented;
}

/// Operation: getIdentityAssertion
pub fn call_getIdentityAssertion(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: removeTrack
pub fn call_removeTrack(instance: *runtime.Instance, sender: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = sender;
    return error.NotImplemented;
}

/// Operation: restartIce
pub fn call_restartIce(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getReceivers
pub fn call_getReceivers(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: generateCertificate
pub fn call_static_generateCertificate(instance: *runtime.Instance, keygenAlgorithm: typedefs.AlgorithmIdentifier) anyerror!runtime.JSValue {
    _ = instance;
    _ = keygenAlgorithm;
    return error.NotImplemented;
}

/// Operation: createDataChannel
pub fn call_createDataChannel(instance: *runtime.Instance, label: runtime.USVString, dataChannelDict: webidl.Opt(dictionaries.RTCDataChannelInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = label;
    _ = dataChannelDict;
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance, selector: webidl.Opt(?*runtime.Instance)) anyerror!runtime.JSValue {
    _ = instance;
    _ = selector;
    return error.NotImplemented;
}

/// Operation: getConfiguration
pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!dictionaries.RTCConfiguration {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createOffer
pub fn call_createOffer(instance: *runtime.Instance, options: webidl.Opt(dictionaries.RTCOfferOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createAnswer
pub fn call_createAnswer(instance: *runtime.Instance, options: webidl.Opt(dictionaries.RTCAnswerOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: close (WebRTC 1.0 4.4.2): "close the connection" with this
/// and false.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    closeTheConnection(instance);
}

/// WebRTC 1.0 4.4.1.6 "close the connection" given `connection` (its
/// `disappear` argument reaches only step 4's transceivers, of which this
/// engine creates none).
fn closeTheConnection(connection: *runtime.Instance) void {
    const internal = getInternal(connection) orelse return;
    // 1. "If connection.[[IsClosed]] is true, abort these steps."
    if (internal.is_closed) return;
    // 2. "Set connection.[[IsClosed]] to true."
    internal.is_closed = true;
    // 3. "Set connection.[[SignalingState]] to "closed". This does not fire
    // any event."
    internal.signaling_state = ._closed_;
    // 4-9. The transceivers to stop, the data channels to close, the SCTP
    // association, the DTLS transports, the ICE agent and its transports:
    // this engine creates none of them (InternalState says so), so each step
    // has nothing to act on.
    // 10. "Set connection.[[IceConnectionState]] to "closed". This does not
    // fire any event."
    internal.ice_connection_state = ._closed_;
    // 11. "Set connection.[[ConnectionState]] to "closed". This does not fire
    // any event."
    internal.connection_state = ._closed_;
    // A closed connection no longer keeps its page out of the back/forward
    // cache (blocksBfcache).
    forgetConnection(connection);
}

/// Operation: getTransceivers
pub fn call_getTransceivers(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: finishDiagnosticLogging
pub fn call_static_finishDiagnosticLogging(instance: *runtime.Instance, options: webidl.Opt(dictionaries.RTCDiagnosticLoggingOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: startDiagnosticLogging
pub fn call_static_startDiagnosticLogging(instance: *runtime.Instance, options: webidl.Opt(dictionaries.RTCDiagnosticLoggingOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: discardDiagnosticLogging
pub fn call_static_discardDiagnosticLogging(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
