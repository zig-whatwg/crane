//! Generated from: webrtc.idl
//! Generated at: 2025-11-23T19:47:41Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCPeerConnectionImpl = @import("impls").RTCPeerConnection;
const EventTarget = @import("interfaces").EventTarget;
const RTCRtpTransceiver = @import("interfaces").RTCRtpTransceiver;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RTCPeerConnectionErrorCallback = @import("callbacks").RTCPeerConnectionErrorCallback;
const RTCDataChannelInit = @import("dictionaries").RTCDataChannelInit;
const RTCRtpSender = @import("interfaces").RTCRtpSender;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const RTCIceGatheringState = @import("enums").RTCIceGatheringState;
const AlgorithmIdentifier = @import("typedefs").AlgorithmIdentifier;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;
const USVString = @import("interfaces").USVString;
const RTCSignalingState = @import("enums").RTCSignalingState;
const RTCPeerConnectionState = @import("enums").RTCPeerConnectionState;
const RTCDataChannel = @import("interfaces").RTCDataChannel;
const RTCCertificate = @import("interfaces").RTCCertificate;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const MediaStream = @import("interfaces").MediaStream;
const RTCIdentityProviderOptions = @import("dictionaries").RTCIdentityProviderOptions;
const RTCSctpTransport = @import("interfaces").RTCSctpTransport;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RTCIceConnectionState = @import("enums").RTCIceConnectionState;
const RTCSessionDescriptionCallback = @import("callbacks").RTCSessionDescriptionCallback;
const RTCLocalSessionDescriptionInit = @import("dictionaries").RTCLocalSessionDescriptionInit;
const EventHandler = @import("typedefs").EventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const VoidFunction = @import("callbacks").VoidFunction;
const RTCStatsReport = @import("interfaces").RTCStatsReport;
const RTCSessionDescriptionInit = @import("dictionaries").RTCSessionDescriptionInit;
const RTCSessionDescription = @import("interfaces").RTCSessionDescription;
const RTCIdentityAssertion = @import("interfaces").RTCIdentityAssertion;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RTCConfiguration = @import("dictionaries").RTCConfiguration;
const RTCOfferOptions = @import("dictionaries").RTCOfferOptions;
const RTCRtpTransceiverInit = @import("dictionaries").RTCRtpTransceiverInit;
const RTCAnswerOptions = @import("dictionaries").RTCAnswerOptions;
const DOMString = @import("typedefs").DOMString;

pub const RTCPeerConnection = struct {
    pub const Meta = struct {
        pub const name = "RTCPeerConnection";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "localDescription", "get_localDescription", null },
            .{ "currentLocalDescription", "get_currentLocalDescription", null },
            .{ "pendingLocalDescription", "get_pendingLocalDescription", null },
            .{ "remoteDescription", "get_remoteDescription", null },
            .{ "currentRemoteDescription", "get_currentRemoteDescription", null },
            .{ "pendingRemoteDescription", "get_pendingRemoteDescription", null },
            .{ "signalingState", "get_signalingState", null },
            .{ "iceGatheringState", "get_iceGatheringState", null },
            .{ "iceConnectionState", "get_iceConnectionState", null },
            .{ "connectionState", "get_connectionState", null },
            .{ "canTrickleIceCandidates", "get_canTrickleIceCandidates", null },
            .{ "onnegotiationneeded", "get_onnegotiationneeded", "set_onnegotiationneeded" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
            .{ "onicecandidateerror", "get_onicecandidateerror", "set_onicecandidateerror" },
            .{ "onsignalingstatechange", "get_onsignalingstatechange", "set_onsignalingstatechange" },
            .{ "oniceconnectionstatechange", "get_oniceconnectionstatechange", "set_oniceconnectionstatechange" },
            .{ "onicegatheringstatechange", "get_onicegatheringstatechange", "set_onicegatheringstatechange" },
            .{ "onconnectionstatechange", "get_onconnectionstatechange", "set_onconnectionstatechange" },
            .{ "ontrack", "get_ontrack", "set_ontrack" },
            .{ "sctp", "get_sctp", null },
            .{ "ondatachannel", "get_ondatachannel", "set_ondatachannel" },
            .{ "peerIdentity", "get_peerIdentity", null },
            .{ "idpLoginUrl", "get_idpLoginUrl", null },
            .{ "idpErrorInfo", "get_idpErrorInfo", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createOffer", "call_createOffer", 0 },
            .{ "createAnswer", "call_createAnswer", 0 },
            .{ "setLocalDescription", "call_setLocalDescription", 0 },
            .{ "setRemoteDescription", "call_setRemoteDescription", 1 },
            .{ "addIceCandidate", "call_addIceCandidate", 0 },
            .{ "restartIce", "call_restartIce", 0 },
            .{ "getConfiguration", "call_getConfiguration", 0 },
            .{ "setConfiguration", "call_setConfiguration", 0 },
            .{ "close", "call_close", 0 },
            .{ "createOffer", "call_createOffer", 2 },
            .{ "setLocalDescription", "call_setLocalDescription", 3 },
            .{ "createAnswer", "call_createAnswer", 2 },
            .{ "setRemoteDescription", "call_setRemoteDescription", 3 },
            .{ "addIceCandidate", "call_addIceCandidate", 3 },
            .{ "generateCertificate", "call_generateCertificate", 1 },
            .{ "getSenders", "call_getSenders", 0 },
            .{ "getReceivers", "call_getReceivers", 0 },
            .{ "getTransceivers", "call_getTransceivers", 0 },
            .{ "addTrack", "call_addTrack", 2 },
            .{ "removeTrack", "call_removeTrack", 1 },
            .{ "addTransceiver", "call_addTransceiver", 1 },
            .{ "createDataChannel", "call_createDataChannel", 1 },
            .{ "getStats", "call_getStats", 0 },
            .{ "setIdentityProvider", "call_setIdentityProvider", 1 },
            .{ "getIdentityAssertion", "call_getIdentityAssertion", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createOffer",
            "createAnswer",
            "setLocalDescription",
            "setRemoteDescription",
            "addIceCandidate",
            "restartIce",
            "getConfiguration",
            "setConfiguration",
            "close",
            "createOffer",
            "setLocalDescription",
            "createAnswer",
            "setRemoteDescription",
            "addIceCandidate",
            "generateCertificate",
            "getSenders",
            "getReceivers",
            "getTransceivers",
            "addTrack",
            "removeTrack",
            "addTransceiver",
            "createDataChannel",
            "getStats",
            "setIdentityProvider",
            "getIdentityAssertion",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "localDescription", "get_localDescription", null },
            .{ "currentLocalDescription", "get_currentLocalDescription", null },
            .{ "pendingLocalDescription", "get_pendingLocalDescription", null },
            .{ "remoteDescription", "get_remoteDescription", null },
            .{ "currentRemoteDescription", "get_currentRemoteDescription", null },
            .{ "pendingRemoteDescription", "get_pendingRemoteDescription", null },
            .{ "signalingState", "get_signalingState", null },
            .{ "iceGatheringState", "get_iceGatheringState", null },
            .{ "iceConnectionState", "get_iceConnectionState", null },
            .{ "connectionState", "get_connectionState", null },
            .{ "canTrickleIceCandidates", "get_canTrickleIceCandidates", null },
            .{ "onnegotiationneeded", "get_onnegotiationneeded", "set_onnegotiationneeded" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
            .{ "onicecandidateerror", "get_onicecandidateerror", "set_onicecandidateerror" },
            .{ "onsignalingstatechange", "get_onsignalingstatechange", "set_onsignalingstatechange" },
            .{ "oniceconnectionstatechange", "get_oniceconnectionstatechange", "set_oniceconnectionstatechange" },
            .{ "onicegatheringstatechange", "get_onicegatheringstatechange", "set_onicegatheringstatechange" },
            .{ "onconnectionstatechange", "get_onconnectionstatechange", "set_onconnectionstatechange" },
            .{ "ontrack", "get_ontrack", "set_ontrack" },
            .{ "sctp", "get_sctp", null },
            .{ "ondatachannel", "get_ondatachannel", "set_ondatachannel" },
            .{ "peerIdentity", "get_peerIdentity", null },
            .{ "idpLoginUrl", "get_idpLoginUrl", null },
            .{ "idpErrorInfo", "get_idpErrorInfo", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            localDescription: ?*runtime.Instance = null,
            currentLocalDescription: ?*runtime.Instance = null,
            pendingLocalDescription: ?*runtime.Instance = null,
            remoteDescription: ?*runtime.Instance = null,
            currentRemoteDescription: ?*runtime.Instance = null,
            pendingRemoteDescription: ?*runtime.Instance = null,
            signalingState: RTCSignalingState = undefined,
            iceGatheringState: RTCIceGatheringState = undefined,
            iceConnectionState: RTCIceConnectionState = undefined,
            connectionState: RTCPeerConnectionState = undefined,
            canTrickleIceCandidates: ?bool = null,
            onnegotiationneeded: EventHandler = undefined,
            onicecandidate: EventHandler = undefined,
            onicecandidateerror: EventHandler = undefined,
            onsignalingstatechange: EventHandler = undefined,
            oniceconnectionstatechange: EventHandler = undefined,
            onicegatheringstatechange: EventHandler = undefined,
            onconnectionstatechange: EventHandler = undefined,
            ontrack: EventHandler = undefined,
            sctp: ?*runtime.Instance = null,
            ondatachannel: EventHandler = undefined,
            peerIdentity: runtime.Promise(RTCIdentityAssertion) = undefined,
            idpLoginUrl: ?runtime.DOMString = null,
            idpErrorInfo: ?runtime.DOMString = null,
            _internal: ?*RTCPeerConnectionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canTrickleIceCandidates = &get_canTrickleIceCandidates,
        .get_connectionState = &get_connectionState,
        .get_currentLocalDescription = &get_currentLocalDescription,
        .get_currentRemoteDescription = &get_currentRemoteDescription,
        .get_iceConnectionState = &get_iceConnectionState,
        .get_iceGatheringState = &get_iceGatheringState,
        .get_idpErrorInfo = &get_idpErrorInfo,
        .get_idpLoginUrl = &get_idpLoginUrl,
        .get_localDescription = &get_localDescription,
        .get_onconnectionstatechange = &get_onconnectionstatechange,
        .get_ondatachannel = &get_ondatachannel,
        .get_onicecandidate = &get_onicecandidate,
        .get_onicecandidateerror = &get_onicecandidateerror,
        .get_oniceconnectionstatechange = &get_oniceconnectionstatechange,
        .get_onicegatheringstatechange = &get_onicegatheringstatechange,
        .get_onnegotiationneeded = &get_onnegotiationneeded,
        .get_onsignalingstatechange = &get_onsignalingstatechange,
        .get_ontrack = &get_ontrack,
        .get_peerIdentity = &get_peerIdentity,
        .get_pendingLocalDescription = &get_pendingLocalDescription,
        .get_pendingRemoteDescription = &get_pendingRemoteDescription,
        .get_remoteDescription = &get_remoteDescription,
        .get_sctp = &get_sctp,
        .get_signalingState = &get_signalingState,

        .set_onconnectionstatechange = &set_onconnectionstatechange,
        .set_ondatachannel = &set_ondatachannel,
        .set_onicecandidate = &set_onicecandidate,
        .set_onicecandidateerror = &set_onicecandidateerror,
        .set_oniceconnectionstatechange = &set_oniceconnectionstatechange,
        .set_onicegatheringstatechange = &set_onicegatheringstatechange,
        .set_onnegotiationneeded = &set_onnegotiationneeded,
        .set_onsignalingstatechange = &set_onsignalingstatechange,
        .set_ontrack = &set_ontrack,

        .call_addIceCandidate = &call_addIceCandidate,
        .call_addTrack = &call_addTrack,
        .call_addTransceiver = &call_addTransceiver,
        .call_close = &call_close,
        .call_createAnswer = &call_createAnswer,
        .call_createDataChannel = &call_createDataChannel,
        .call_createOffer = &call_createOffer,
        .call_generateCertificate = &call_generateCertificate,
        .call_getConfiguration = &call_getConfiguration,
        .call_getIdentityAssertion = &call_getIdentityAssertion,
        .call_getReceivers = &call_getReceivers,
        .call_getSenders = &call_getSenders,
        .call_getStats = &call_getStats,
        .call_getTransceivers = &call_getTransceivers,
        .call_removeTrack = &call_removeTrack,
        .call_restartIce = &call_restartIce,
        .call_setConfiguration = &call_setConfiguration,
        .call_setIdentityProvider = &call_setIdentityProvider,
        .call_setLocalDescription = &call_setLocalDescription,
        .call_setRemoteDescription = &call_setRemoteDescription,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCPeerConnectionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCPeerConnectionImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, configuration: RTCConfiguration) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCPeerConnectionImpl.call_constructor(allocator, ctx, configuration);
    }

    pub fn get_localDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_localDescription(instance);
    }

    pub fn get_currentLocalDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_currentLocalDescription(instance);
    }

    pub fn get_pendingLocalDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_pendingLocalDescription(instance);
    }

    pub fn get_remoteDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_remoteDescription(instance);
    }

    pub fn get_currentRemoteDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_currentRemoteDescription(instance);
    }

    pub fn get_pendingRemoteDescription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_pendingRemoteDescription(instance);
    }

    pub fn get_signalingState(instance: *runtime.Instance) anyerror!RTCSignalingState {
        return try RTCPeerConnectionImpl.get_signalingState(instance);
    }

    pub fn get_iceGatheringState(instance: *runtime.Instance) anyerror!RTCIceGatheringState {
        return try RTCPeerConnectionImpl.get_iceGatheringState(instance);
    }

    pub fn get_iceConnectionState(instance: *runtime.Instance) anyerror!RTCIceConnectionState {
        return try RTCPeerConnectionImpl.get_iceConnectionState(instance);
    }

    pub fn get_connectionState(instance: *runtime.Instance) anyerror!RTCPeerConnectionState {
        return try RTCPeerConnectionImpl.get_connectionState(instance);
    }

    pub fn get_canTrickleIceCandidates(instance: *runtime.Instance) anyerror!bool {
        return try RTCPeerConnectionImpl.get_canTrickleIceCandidates(instance);
    }

    pub fn get_onnegotiationneeded(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onnegotiationneeded(instance);
    }

    pub fn set_onnegotiationneeded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onnegotiationneeded(instance, value);
    }

    pub fn get_onicecandidate(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onicecandidate(instance);
    }

    pub fn set_onicecandidate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onicecandidate(instance, value);
    }

    pub fn get_onicecandidateerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onicecandidateerror(instance);
    }

    pub fn set_onicecandidateerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onicecandidateerror(instance, value);
    }

    pub fn get_onsignalingstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onsignalingstatechange(instance);
    }

    pub fn set_onsignalingstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onsignalingstatechange(instance, value);
    }

    pub fn get_oniceconnectionstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_oniceconnectionstatechange(instance);
    }

    pub fn set_oniceconnectionstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_oniceconnectionstatechange(instance, value);
    }

    pub fn get_onicegatheringstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onicegatheringstatechange(instance);
    }

    pub fn set_onicegatheringstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onicegatheringstatechange(instance, value);
    }

    pub fn get_onconnectionstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_onconnectionstatechange(instance);
    }

    pub fn set_onconnectionstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_onconnectionstatechange(instance, value);
    }

    pub fn get_ontrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_ontrack(instance);
    }

    pub fn set_ontrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_ontrack(instance, value);
    }

    pub fn get_sctp(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCPeerConnectionImpl.get_sctp(instance);
    }

    pub fn get_ondatachannel(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_ondatachannel(instance);
    }

    pub fn set_ondatachannel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_ondatachannel(instance, value);
    }

    pub fn get_peerIdentity(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCPeerConnectionImpl.get_peerIdentity(instance);
    }

    pub fn get_idpLoginUrl(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCPeerConnectionImpl.get_idpLoginUrl(instance);
    }

    pub fn get_idpErrorInfo(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCPeerConnectionImpl.get_idpErrorInfo(instance);
    }

    pub fn call_addTransceiver(instance: *runtime.Instance, trackOrKind: *const anyopaque, init_data: RTCRtpTransceiverInit) anyerror!*runtime.Instance {
        
        return try RTCPeerConnectionImpl.call_addTransceiver(instance, trackOrKind, init_data);
    }

    pub fn call_setIdentityProvider(instance: *runtime.Instance, provider: DOMString, options: RTCIdentityProviderOptions) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_setIdentityProvider(instance, provider, options);
    }

    pub fn call_setConfiguration(instance: *runtime.Instance, configuration: RTCConfiguration) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_setConfiguration(instance, configuration);
    }

    pub fn call_getSenders(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCPeerConnectionImpl.call_getSenders(instance);
    }

    pub fn call_setRemoteDescription(instance: *runtime.Instance, description: RTCSessionDescriptionInit) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_setRemoteDescription(instance, description);
    }

    pub fn call_addIceCandidate(instance: *runtime.Instance, candidate: RTCIceCandidateInit) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_addIceCandidate(instance, candidate);
    }

    pub fn call_setLocalDescription(instance: *runtime.Instance, description: RTCLocalSessionDescriptionInit) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_setLocalDescription(instance, description);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: *runtime.Instance, streams: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try RTCPeerConnectionImpl.call_addTrack(instance, track, streams);
    }

    pub fn call_getIdentityAssertion(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCPeerConnectionImpl.call_getIdentityAssertion(instance);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, sender: *runtime.Instance) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_removeTrack(instance, sender);
    }

    pub fn call_restartIce(instance: *runtime.Instance) anyerror!void {
        return try RTCPeerConnectionImpl.call_restartIce(instance);
    }

    pub fn call_getReceivers(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCPeerConnectionImpl.call_getReceivers(instance);
    }

    pub fn call_generateCertificate(instance: *runtime.Instance, keygenAlgorithm: AlgorithmIdentifier) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_generateCertificate(instance, keygenAlgorithm);
    }

    pub fn call_createDataChannel(instance: *runtime.Instance, label: runtime.USVString, dataChannelDict: RTCDataChannelInit) anyerror!*runtime.Instance {
        
        return try RTCPeerConnectionImpl.call_createDataChannel(instance, label, dataChannelDict);
    }

    pub fn call_getStats(instance: *runtime.Instance, selector: *runtime.Instance) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_getStats(instance, selector);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!RTCConfiguration {
        return try RTCPeerConnectionImpl.call_getConfiguration(instance);
    }

    pub fn call_createOffer(instance: *runtime.Instance, options: RTCOfferOptions) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_createOffer(instance, options);
    }

    pub fn call_createAnswer(instance: *runtime.Instance, options: RTCAnswerOptions) anyerror!*const anyopaque {
        
        return try RTCPeerConnectionImpl.call_createAnswer(instance, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try RTCPeerConnectionImpl.call_close(instance);
    }

    pub fn call_getTransceivers(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCPeerConnectionImpl.call_getTransceivers(instance);
    }

};
