# Spec Compliance: Resolve a single-member shorthand before applying its spelling

**Date**: 2026-10-27
**Lesson**: A one-member shorthand uses its longhand's resolved value, then the shorthand's own serialization rules.

**Why**: Reading the stored longhand directly can bypass a property-specific resolved-value rule. Returning the canonical serialized text directly can erase a spelling that belongs to the wrapper. Both boundaries matter.

**What Happened**: Row125 found that -webkit-transform bypassed transform's own-display:none resolver. Its census also found -webkit-perspective and -webkit-text-orientation. The latter maps the resolved keyword mixed to vertical-right under the existing browser ruling, so a generic direct-text return would regress another wrapper.

**Fix**: The Q61 design resolves the sole longhand first, represents the result with the existing keyword or owned-text value, and calls the existing shorthand serializer. Keep the member-count test general and reuse the wrapper's spelling logic. Do not parse serialized matrices back as authored CSS: resolved infinity/NaN output is not necessarily accepted by the input grammar.

**Takeaway**: **Test the canonical resolver and wrapper spelling independently, through the real CSSOM caller, with a census of every single-member shorthand and allocation-failure coverage.**
