//! Callback functions whose return value an impl still converts by hand.
//!
//! WebIDL "invoke a callback function" (3.12) ends by converting the value
//! the function returned to the callback's declared return type - steps
//! 13-14: "Return the result of converting callResult.[[Value]] to an IDL
//! value of the same type as callable's return type", and when that type is
//! a promise type an abrupt completion becomes "a promise rejected with" its
//! value. Codegen emits no invocation for a callback yet: `callbacks/X.zig`
//! is `runtime.BorrowedCallbackFunction`, an impl calls
//! `engine.invokeCallbackFunction` and converts what comes back itself. For a
//! return type of `undefined` or `any` there is nothing to convert; every
//! other callback is listed here, with where its value is converted today.
//!
//! Lane bind1 batch B6 generates the invocation with the converted return
//! value and removes each entry as its impl moves onto it. The list only
//! shrinks, and tests/codegen/bind1_callback_returns_test.zig pins it against
//! the generated callbacks: one a new IDL adds must be listed, or generated.

/// How a listed callback's return value is converted today.
pub const Conversion = enum {
    /// An impl (or the src/dom, src/html code behind it) converts the value
    /// with the engine's conversion operations.
    hand,
    /// `engine.invokeCallbackFunctionWithReturnType`: the protocol converts
    /// for one fixed type, not from the IDL.
    protocol_typed,
    /// A promise type whose resolution value needs no conversion
    /// (`Promise<undefined>`, `Promise<any>`): the impl makes the promise
    /// from the completion by hand.
    promise_wrap,
    /// Nothing invokes the callback yet, so nothing converts.
    not_invoked,
};

/// (callback, its IDL return type, how the value is converted today).
/// Batch B6 drove this list to zero: every generated callback invokes and
/// converts its return type through `callbacks.call.<Name>.invoke`.
pub const callback_returns_converted_by_impl = [_]struct { []const u8, []const u8, Conversion }{};

/// Callback interface operations whose return value is not `undefined`/`any`
/// and is still converted by hand in an impl (WebIDL 3.11 step 14).
/// (interface, operation, Zig return type, how converted today).
/// Batch B6 drove this list to zero: NodeFilter.acceptNode and
/// XPathNSResolver.lookupNamespaceURI invoke through their generated
/// `invoke_<op>` helpers.
pub const callback_interface_returns_converted_by_impl = [_]struct { []const u8, []const u8, []const u8, Conversion }{};

/// WebIDL dictionary conversions called from spec prose (not a binding
/// argument or callback return) that are still read by hand instead of
/// `engine.convertFromJS`.
/// (dictionary, location). Batch B6 moves them onto `engine.convertFromJS`
/// and shrinks this list to zero.
pub const prose_dictionary_conversions_by_impl = [_]struct { []const u8, []const u8 }{
    // Web Animations "process a keyframes argument": converts the non-iterable
    // object form to BasePropertyIndexedKeyframe (with offset's sequence<double?>
    // typed once B6 regenerates).
    .{ "BasePropertyIndexedKeyframe", "src/dom/animations/keyframes.zig" },
    // Web Animations "process a keyframes argument": converts each element of
    // the sequence form to BaseKeyframe.
    .{ "BaseKeyframe", "src/dom/animations/keyframes.zig" },
};
