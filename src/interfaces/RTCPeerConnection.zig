//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCPeerConnectionImpl = @import("../impls/RTCPeerConnection.zig");
const EventTarget = @import("EventTarget.zig");

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
            peerIdentity: Promise<RTCIdentityAssertion> = undefined,
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
        .call_addIceCandidate = &call_addIceCandidate,
        .call_addTrack = &call_addTrack,
        .call_addTransceiver = &call_addTransceiver,
        .call_close = &call_close,
        .call_createAnswer = &call_createAnswer,
        .call_createAnswer = &call_createAnswer,
        .call_createDataChannel = &call_createDataChannel,
        .call_createOffer = &call_createOffer,
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
        .call_setLocalDescription = &call_setLocalDescription,
        .call_setRemoteDescription = &call_setRemoteDescription,
        .call_setRemoteDescription = &call_setRemoteDescription,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCPeerConnectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, configuration: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RTCPeerConnectionImpl.constructor(state, configuration);
        
        return instance;
    }

    pub fn get_localDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_localDescription(state);
    }

    pub fn get_currentLocalDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_currentLocalDescription(state);
    }

    pub fn get_pendingLocalDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_pendingLocalDescription(state);
    }

    pub fn get_remoteDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_remoteDescription(state);
    }

    pub fn get_currentRemoteDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_currentRemoteDescription(state);
    }

    pub fn get_pendingRemoteDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_pendingRemoteDescription(state);
    }

    pub fn get_signalingState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_signalingState(state);
    }

    pub fn get_iceGatheringState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_iceGatheringState(state);
    }

    pub fn get_iceConnectionState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_iceConnectionState(state);
    }

    pub fn get_connectionState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_connectionState(state);
    }

    pub fn get_canTrickleIceCandidates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_canTrickleIceCandidates(state);
    }

    pub fn get_onnegotiationneeded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onnegotiationneeded(state);
    }

    pub fn set_onnegotiationneeded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onnegotiationneeded(state, value);
    }

    pub fn get_onicecandidate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onicecandidate(state);
    }

    pub fn set_onicecandidate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onicecandidate(state, value);
    }

    pub fn get_onicecandidateerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onicecandidateerror(state);
    }

    pub fn set_onicecandidateerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onicecandidateerror(state, value);
    }

    pub fn get_onsignalingstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onsignalingstatechange(state);
    }

    pub fn set_onsignalingstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onsignalingstatechange(state, value);
    }

    pub fn get_oniceconnectionstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_oniceconnectionstatechange(state);
    }

    pub fn set_oniceconnectionstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_oniceconnectionstatechange(state, value);
    }

    pub fn get_onicegatheringstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onicegatheringstatechange(state);
    }

    pub fn set_onicegatheringstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onicegatheringstatechange(state, value);
    }

    pub fn get_onconnectionstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_onconnectionstatechange(state);
    }

    pub fn set_onconnectionstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_onconnectionstatechange(state, value);
    }

    pub fn get_ontrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_ontrack(state);
    }

    pub fn set_ontrack(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_ontrack(state, value);
    }

    pub fn get_sctp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_sctp(state);
    }

    pub fn get_ondatachannel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_ondatachannel(state);
    }

    pub fn set_ondatachannel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCPeerConnectionImpl.set_ondatachannel(state, value);
    }

    pub fn get_peerIdentity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_peerIdentity(state);
    }

    pub fn get_idpLoginUrl(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_idpLoginUrl(state);
    }

    pub fn get_idpErrorInfo(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.get_idpErrorInfo(state);
    }

    pub fn call_addTransceiver(instance: *runtime.Instance, trackOrKind: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_addTransceiver(state, trackOrKind, init);
    }

    pub fn call_setIdentityProvider(instance: *runtime.Instance, provider: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_setIdentityProvider(state, provider, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_when(state, type_, options);
    }

    pub fn call_setConfiguration(instance: *runtime.Instance, configuration: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_setConfiguration(state, configuration);
    }

    /// Arguments for setRemoteDescription (WebIDL overloading)
    pub const SetRemoteDescriptionArgs = union(enum) {
        /// setRemoteDescription(description)
        RTCSessionDescriptionInit: anyopaque,
        /// setRemoteDescription(description, successCallback, failureCallback)
        RTCSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback: struct {
            description: anyopaque,
            successCallback: anyopaque,
            failureCallback: anyopaque,
        },
    };

    pub fn call_setRemoteDescription(instance: *runtime.Instance, args: SetRemoteDescriptionArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .RTCSessionDescriptionInit => |arg| return RTCPeerConnectionImpl.RTCSessionDescriptionInit(state, arg),
            .RTCSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback => |a| return RTCPeerConnectionImpl.RTCSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback(state, a.description, a.successCallback, a.failureCallback),
        }
    }

    /// Arguments for addIceCandidate (WebIDL overloading)
    pub const AddIceCandidateArgs = union(enum) {
        /// addIceCandidate(candidate)
        RTCIceCandidateInit: anyopaque,
        /// addIceCandidate(candidate, successCallback, failureCallback)
        RTCIceCandidateInit_VoidFunction_RTCPeerConnectionErrorCallback: struct {
            candidate: anyopaque,
            successCallback: anyopaque,
            failureCallback: anyopaque,
        },
    };

    pub fn call_addIceCandidate(instance: *runtime.Instance, args: AddIceCandidateArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .RTCIceCandidateInit => |arg| return RTCPeerConnectionImpl.RTCIceCandidateInit(state, arg),
            .RTCIceCandidateInit_VoidFunction_RTCPeerConnectionErrorCallback => |a| return RTCPeerConnectionImpl.RTCIceCandidateInit_VoidFunction_RTCPeerConnectionErrorCallback(state, a.candidate, a.successCallback, a.failureCallback),
        }
    }

    /// Arguments for setLocalDescription (WebIDL overloading)
    pub const SetLocalDescriptionArgs = union(enum) {
        /// setLocalDescription(description)
        RTCLocalSessionDescriptionInit: anyopaque,
        /// setLocalDescription(description, successCallback, failureCallback)
        RTCLocalSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback: struct {
            description: anyopaque,
            successCallback: anyopaque,
            failureCallback: anyopaque,
        },
    };

    pub fn call_setLocalDescription(instance: *runtime.Instance, args: SetLocalDescriptionArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .RTCLocalSessionDescriptionInit => |arg| return RTCPeerConnectionImpl.RTCLocalSessionDescriptionInit(state, arg),
            .RTCLocalSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback => |a| return RTCPeerConnectionImpl.RTCLocalSessionDescriptionInit_VoidFunction_RTCPeerConnectionErrorCallback(state, a.description, a.successCallback, a.failureCallback),
        }
    }

    pub fn call_getSenders(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_getSenders(state);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: anyopaque, streams: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_addTrack(state, track, streams);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, sender: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_removeTrack(state, sender);
    }

    pub fn call_restartIce(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_restartIce(state);
    }

    pub fn call_getIdentityAssertion(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_getIdentityAssertion(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_generateCertificate(instance: *runtime.Instance, keygenAlgorithm: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_generateCertificate(state, keygenAlgorithm);
    }

    pub fn call_getReceivers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_getReceivers(state);
    }

    pub fn call_createDataChannel(instance: *runtime.Instance, label: runtime.USVString, dataChannelDict: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_createDataChannel(state, label, dataChannelDict);
    }

    pub fn call_getStats(instance: *runtime.Instance, selector: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_getStats(state, selector);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_getConfiguration(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCPeerConnectionImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for createOffer (WebIDL overloading)
    pub const CreateOfferArgs = union(enum) {
        /// createOffer(options)
        RTCOfferOptions: anyopaque,
        /// createOffer(successCallback, failureCallback, options)
        RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback_RTCOfferOptions: struct {
            successCallback: anyopaque,
            failureCallback: anyopaque,
            options: anyopaque,
        },
    };

    pub fn call_createOffer(instance: *runtime.Instance, args: CreateOfferArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .RTCOfferOptions => |arg| return RTCPeerConnectionImpl.RTCOfferOptions(state, arg),
            .RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback_RTCOfferOptions => |a| return RTCPeerConnectionImpl.RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback_RTCOfferOptions(state, a.successCallback, a.failureCallback, a.options),
        }
    }

    /// Arguments for createAnswer (WebIDL overloading)
    pub const CreateAnswerArgs = union(enum) {
        /// createAnswer(options)
        RTCAnswerOptions: anyopaque,
        /// createAnswer(successCallback, failureCallback)
        RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback: struct {
            successCallback: anyopaque,
            failureCallback: anyopaque,
        },
    };

    pub fn call_createAnswer(instance: *runtime.Instance, args: CreateAnswerArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .RTCAnswerOptions => |arg| return RTCPeerConnectionImpl.RTCAnswerOptions(state, arg),
            .RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback => |a| return RTCPeerConnectionImpl.RTCSessionDescriptionCallback_RTCPeerConnectionErrorCallback(state, a.successCallback, a.failureCallback),
        }
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_close(state);
    }

    pub fn call_getTransceivers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCPeerConnectionImpl.call_getTransceivers(state);
    }

};
