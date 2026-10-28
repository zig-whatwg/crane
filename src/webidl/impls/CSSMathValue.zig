//! CSS Typed OM 1 §4.3.4: the operator of each concrete math value.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dom = @import("dom");

pub const State = interfaces.CSSMathValue.State;
pub const ImplError = error{TypeError};
pub const InternalState = struct {};

pub fn get_operator(instance: *runtime.Instance) anyerror!enums.CSSMathOperator {
    return switch (try dom.style.typed_om.numericKind(instance)) {
        .unit => error.TypeError,
        .sum => ._sum_,
        .product => ._product_,
        .negate => ._negate_,
        .invert => ._invert_,
        .min => ._min_,
        .max => ._max_,
        .clamp => ._clamp_,
    };
}
