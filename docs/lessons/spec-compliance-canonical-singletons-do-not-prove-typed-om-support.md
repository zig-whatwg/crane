# Spec Compliance: Canonical Singletons Do Not Prove Typed OM Support

**Date**: 2026-10-29
**Lesson**: Check the shipping property's Typed OM class before applying a generic singleton rule to its native value.

**Why**: A serializer can emit one number or identifier even when a browser exposes that property's value through opaque CSSStyleValue. A blank entry in the Typed OM property table does not establish the shipping behavior.

**What Happened**: After the box-property parser landed, overflow-clip-margin retained structured numeric data. Its default reference box serialized as `5px`; a nondefault box with zero offset serialized as `content-box`. Those shapes suggested CSSUnitValue and CSSKeywordValue under a generic singleton rule. The integrator's Q179 probe found that Chrome 156, the sole shipper, returned opaque CSSStyleValue for both. Three runs agreed. The same probe showed that scroll-marker-group `before` was a CSSKeywordValue when specified, but its computed `before links` value was opaque. Safari 27 shipped neither property; no browser shipped max-lines.

**Fix**:
1. Probe parse, inline-map and computed-map access independently, recording both class and text.
2. Establish which browsers ship the property before counting agreement.
3. Follow the ruled shipping class even when canonical serialization looks like a generic singleton.
4. Use the singleton principle only for the unshipped property, as the integrator ruled for max-lines.
5. Inspect retained native fields to classify values. Keep the owning parser, serializer and computation path intact; never parse their serialized output to infer a type.

Evidence: row 128 ANSWER Q179 and `tmp/probes/q179/RESULT.md`, with three Chrome and three Safari captures. Parser acceptance differences, such as Chrome rejecting calc() for overflow-clip-margin, are a separate owner follow-up.

**Takeaway**: **A simple serialization does not establish the public Typed OM class. Verify property support and each access path before generalizing.**
