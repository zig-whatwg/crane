# Spec Compliance: Recheck Representation Workarounds

**Date**: 2026-10-20
**Lesson**: Revalidate a workaround's representation assumption when returning to an old conformance failure.

**Why**: A workaround can outlive the representation limitation that justified it and keep rejecting valid data after the underlying subsystem is fixed.

**What Happened**: Option text collection excluded a null-namespace element named script because an old comment said null also represented HTML's namespace. Element had since gained explicit namespace storage. The workaround still excluded real null-namespace script content, and a case-insensitive name check also excluded an HTML-namespace element whose local name was uppercase SCRIPT.

**Fix**: Read Element's current namespace storage and the full HTML-aware-text algorithm. Exclude only exact lowercase script elements in the HTML or SVG namespaces, matching Blink's element-kind test. Cover HTML, SVG, MathML, null namespaces, and uppercase local names through generated interfaces and script tests.

**Takeaway**: **An old limitation comment is a hypothesis to check against today's code.**
