//! Generated from: webrtc.idl
//! Generated at: 2025-11-19T20:02:00Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            localDescription: ?RTCSessionDescription = null,
            currentLocalDescription: ?RTCSessionDescription = null,
            pendingLocalDescription: ?RTCSessionDescription = null,
            remoteDescription: ?RTCSessionDescription = null,
            currentRemoteDescription: ?RTCSessionDescription = null,
            pendingRemoteDescription: ?RTCSessionDescription = null,
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
            sctp: ?RTCSctpTransport = null,
            ondatachannel: EventHandler = undefined,
            peerIdentity: runtime.Promise(RTCIdentityAssertion) = undefined,
            idpLoginUrl: ?runtime.DOMString = null,
            idpErrorInfo: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCPeerConnection, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_addIceCandidate = &call_addIceCandidate,
        .call_addTrack = &call_addTrack,
        .call_addTransceiver = &call_addTransceiver,
        .call_close = &call_close,
        .call_createAnswer = &call_createAnswer,
        .call_createDataChannel = &call_createDataChannel,
        .call_createOffer = &call_createOffer,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_generateCertificate = &call_generateCertificate,
        .call_getConfiguration = &call_getConfiguration,
        .call_getIdentityAssertion = &call_getIdentityAssertion,
        .call_getReceivers = &call_getReceivers,
        .call_getSenders = &call_getSenders,
        .call_getStats = &call_getStats,
        .call_getTransceivers = &call_getTransceivers,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeTrack = &call_removeTrack,
        .call_restartIce = &call_restartIce,
        .call_setConfiguration = &call_setConfiguration,
        .call_setIdentityProvider = &call_setIdentityProvider,
        .call_setLocalDescription = &call_setLocalDescription,
        .call_setRemoteDescription = &call_setRemoteDescription,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return RTCPeerConnectionImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCPeerConnectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, configuration: RTCConfiguration) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCPeerConnectionImpl.constructor(instance, configuration);
        
        return instance;
    }

    pub fn get_localDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
        return try RTCPeerConnectionImpl.get_localDescription(instance);
    }

    pub fn get_currentLocalDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
        return try RTCPeerConnectionImpl.get_currentLocalDescription(instance);
    }

    pub fn get_pendingLocalDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
        return try RTCPeerConnectionImpl.get_pendingLocalDescription(instance);
    }

    pub fn get_remoteDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
        return try RTCPeerConnectionImpl.get_remoteDescription(instance);
    }

    pub fn get_currentRemoteDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
        return try RTCPeerConnectionImpl.get_currentRemoteDescription(instance);
    }

    pub fn get_pendingRemoteDescription(instance: *runtime.Instance) anyerror!RTCSessionDescription {
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

    pub fn get_sctp(instance: *runtime.Instance) anyerror!RTCSctpTransport {
        return try RTCPeerConnectionImpl.get_sctp(instance);
    }

    pub fn get_ondatachannel(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCPeerConnectionImpl.get_ondatachannel(instance);
    }

    pub fn set_ondatachannel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCPeerConnectionImpl.set_ondatachannel(instance, value);
    }

    pub fn get_peerIdentity(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCPeerConnectionImpl.get_peerIdentity(instance);
    }

    pub fn get_idpLoginUrl(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCPeerConnectionImpl.get_idpLoginUrl(instance);
    }

    pub fn get_idpErrorInfo(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCPeerConnectionImpl.get_idpErrorInfo(instance);
    }

    pub fn call_addTransceiver(instance: *runtime.Instance, trackOrKind: anyopaque, init_data: RTCRtpTransceiverInit) anyerror!RTCRtpTransceiver {
        
        return try RTCPeerConnectionImpl.call_addTransceiver(instance, trackOrKind, init_data);
    }

    pub fn call_setIdentityProvider(instance: *runtime.Instance, provider: DOMString, options: RTCIdentityProviderOptions) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_setIdentityProvider(instance, provider, options);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCPeerConnectionImpl.call_when(instance, @"type", options);
    }

    pub fn call_setConfiguration(instance: *runtime.Instance, configuration: RTCConfiguration) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_setConfiguration(instance, configuration);
    }

    pub fn call_setRemoteDescription(instance: *runtime.Instance, description: RTCSessionDescriptionInit) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_setRemoteDescription(instance, description);
    }

    pub fn call_addIceCandidate(instance: *runtime.Instance, candidate: RTCIceCandidateInit) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_addIceCandidate(instance, candidate);
    }

    pub fn call_setLocalDescription(instance: *runtime.Instance, description: RTCLocalSessionDescriptionInit) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_setLocalDescription(instance, description);
    }

    pub fn call_getSenders(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCPeerConnectionImpl.call_getSenders(instance);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: MediaStreamTrack, streams: MediaStream) anyerror!RTCRtpSender {
        
        return try RTCPeerConnectionImpl.call_addTrack(instance, track, streams);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, sender: RTCRtpSender) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_removeTrack(instance, sender);
    }

    pub fn call_restartIce(instance: *runtime.Instance) anyerror!void {
        return try RTCPeerConnectionImpl.call_restartIce(instance);
    }

    pub fn call_getIdentityAssertion(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCPeerConnectionImpl.call_getIdentityAssertion(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RTCPeerConnectionImpl.call_removeEventListener(instance, @"type", callback, options);
    }

    pub fn call_generateCertificate(instance: *runtime.Instance, keygenAlgorithm: AlgorithmIdentifier) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_generateCertificate(instance, keygenAlgorithm);
    }

    pub fn call_getReceivers(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCPeerConnectionImpl.call_getReceivers(instance);
    }

    pub fn call_createDataChannel(instance: *runtime.Instance, label: runtime.USVString, dataChannelDict: RTCDataChannelInit) anyerror!RTCDataChannel {
        
        return try RTCPeerConnectionImpl.call_createDataChannel(instance, label, dataChannelDict);
    }

    pub fn call_getStats(instance: *runtime.Instance, selector: MediaStreamTrack) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_getStats(instance, selector);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!RTCConfiguration {
        return try RTCPeerConnectionImpl.call_getConfiguration(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCPeerConnectionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_createOffer(instance: *runtime.Instance, options: RTCOfferOptions) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_createOffer(instance, options);
    }

    pub fn call_createAnswer(instance: *runtime.Instance, options: RTCAnswerOptions) anyerror!anyopaque {
        
        return try RTCPeerConnectionImpl.call_createAnswer(instance, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try RTCPeerConnectionImpl.call_close(instance);
    }

    pub fn call_getTransceivers(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCPeerConnectionImpl.call_getTransceivers(instance);
    }

};
