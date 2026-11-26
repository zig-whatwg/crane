//! Implementation for the Body mixin (Fetch §5.2):
//! body, bodyUsed, arrayBuffer(), blob(), bytes(), formData(), json(), text().
//!
//! Shared by Request and Response (codegen/inherited_mixins.zig), reaching
//! each includer's body state through dom.fetch_objects.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch_objects = dom.fetch_objects;
const Body = interfaces.Body;

pub const State = Body.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

pub const InternalState = struct {};

/// Getter for body (Fetch §5.2).
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (instance.stateAs(interfaces.Request.State) != null) {
        return fetch_objects.requestBodyStreamGet(instance);
    }
    if (instance.stateAs(interfaces.Response.State) != null) {
        return fetch_objects.responseBodyStreamGet(instance);
    }
    return null;
}

/// Getter for bodyUsed (Fetch §5.2).
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    if (instance.stateAs(interfaces.Request.State) != null) {
        return fetch_objects.requestBodyUsed(instance);
    }
    if (instance.stateAs(interfaces.Response.State) != null) {
        return fetch_objects.responseBodyUsed(instance);
    }
    return false;
}

fn consume(instance: *runtime.Instance, method: fetch_objects.BodyMethod) anyerror!runtime.JSValue {
    if (instance.stateAs(interfaces.Request.State) != null) {
        return fetch_objects.requestBodyConsume(instance, method);
    }
    if (instance.stateAs(interfaces.Response.State) != null) {
        return fetch_objects.responseBodyConsume(instance, method);
    }
    return error.InvalidState;
}

/// Operation: arrayBuffer
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .array_buffer);
}

/// Operation: blob
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .blob);
}

/// Operation: bytes
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .bytes);
}

/// Operation: formData
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .form_data);
}

/// Operation: json
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .json);
}

/// Operation: text
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consume(instance, .text);
}

/// Operation: textStream (Fetch §5.3).
pub fn call_textStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (instance.stateAs(interfaces.Request.State) != null) {
        return fetch_objects.requestBodyTextStream(instance);
    }
    if (instance.stateAs(interfaces.Response.State) != null) {
        return fetch_objects.responseBodyTextStream(instance);
    }
    return error.InvalidState;
}
