# Spec Compliance: An Alias Must Express the Longhand's Initial Value

**Date**: 2026-10-23
**Lesson**: Choose a coherent parser and serializer for a legacy alias; intersecting competing browser grammars can make a valid longhand impossible to read back through its alias.

**Why**: CSSOM exposes an alias alongside its target. A supported alias must serialize the target's initial value into a value accepted by the alias's own grammar.

**What Happened**: Chrome represents the standard `text-orientation: mixed` through `-webkit-text-orientation: vertical-right`; Safari accepts `mixed` directly. Firefox does not ship the alias. Crane initially rejected both disputed spellings while exposing the alias, so two existing CSSOM enumeration tests lost their passes.

**Fix**: Use Blink's complete mechanism: parse `vertical-right` into the longhand's `mixed`, and serialize `mixed` back to `vertical-right` through the prefixed name at both specified and computed stages. Keep the standard name unchanged. Pin initial-value round-tripping, inheritance, CSS-wide values, and the remaining legacy spellings.

**Takeaway**: **Compare complete browser mechanisms. A conservative-looking intersection can fail an invariant that each shipping implementation preserves.**
