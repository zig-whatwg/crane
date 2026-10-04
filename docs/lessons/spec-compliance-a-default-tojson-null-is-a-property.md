# Spec Compliance: A [Default] toJSON null is a property; a dictionary's is not

**Date**: 2026-10-04
**Lesson**: The generated ToJSON struct typed every attribute from its type name alone, so a nullable attribute was non-optional, and the struct went through the dictionary conversion, which leaves a null member out.

**Why**: WebIDL 3.7.4.1's default toJSON steps put every JSON-typed attribute's value in the map - null included - and CreateDataProperty each entry. A dictionary converted to JavaScript (3.2.18) defines only members that are present. Both are Zig structs with optional fields; the conversion cannot tell them apart unless the struct says which it is.

**What Happened**: PerformanceNavigationTiming's ToJSON had `notRestoredReasons: *runtime.Instance` for `NotRestoredReasons?`: the impl could not leave it null, and had it been optional, toJSON() would have omitted it. GeolocationCoordinates, PaymentResponse, VideoColorSpace and the report bodies had the same shape.

**Fix**: writer.writeToJSONStruct keeps the `?` for a nullable attribute and adds `pub const default_to_json = true;`; toV8Value's struct branch defines a null member as null when the struct has it. tests/codegen/default_tojson_nullable_test.zig, tests/v8/webidl_value_conversion_test.zig.

**Takeaway**: **Two Zig structs with optional fields can need different JavaScript conversions; mark the one whose null is a value.**
