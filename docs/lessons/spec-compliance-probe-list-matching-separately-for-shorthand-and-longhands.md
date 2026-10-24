# Spec Compliance: Probe list matching separately for a shorthand and its longhands

**Date**: 2026-10-23
**Lesson**: A browser's shorthand expansion does not establish how its resolved longhand lists are stored or serialized.

**Why**: Background images coordinate several lists, but the shorthand, each resolved longhand, and the stored computed values expose different decisions. A malformed string from one browser can obscure the shared mechanism.

**What Happened**: An initial probe of an excess background-position list suggested returning an empty computed background shorthand. Additional probes varied position, size, repeat, attachment, origin and clip independently. Chrome and Safari agreed on image-count matching for most shorthand cases; Safari's excess-position and excess-size strings embedded whole lists inside one layer. The integrator's mechanism comparison selected independent modulo lookup for every ancillary column, including truncation to the image count. Longhand results differed: most retained authored lists, while background-size repeated a short list and retained an excess list. The original empty-string rule was withdrawn before delivery.

**Fix**: Pin both forms and every recorded longhand before changing the serializer. Keep the immutable stored component lists, serialize the full shorthand over its image count, and apply background-size's special repetition at the resolved-value boundary with borrowed components. A reserved output buffer and a fail-on-first-allocation allocator verify that this read does not create repeated Values or mutate the source. Keep unprobed inheritance between receivers with different image counts as a follow-up; the probes do not settle it.

**Takeaway**: **Vary list lengths and properties independently, then distinguish storage from each observable serialization boundary.**
