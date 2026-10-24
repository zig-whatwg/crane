# Spec Compliance: Synthetic components still need computed-value conversion

**Date**: 2026-10-24
**Lesson**: A component created during computation must still pass through its owner’s conversion from specified to computed values.

**Why**: A constant may represent a specified keyword even when its name describes a concrete appearance. Constructing a composite with that constant does not make its children computed.

**What Happened**: CSS Color 5 makes a selected light-dark() none equivalent to image(transparent). The image branch manufactured a solid-color image directly from Color.transparent. When the Color owner correctly preserved transparent as a specified keyword, the ordinary typed solid-color branch still converted it to transparent black, while the shortcut serialized image(transparent) at the computed boundary. Both background-image and content exposed the difference.

**Fix**: Use the same ComponentContext.color conversion as the normal solid-color branch, then release the computed temporary after the image retains it. Keep the specified background-color reset unchanged. Exercise both composite consumers through the real cascade, after declaration disposal and under every allocation failure, including inheritance under the opposite color scheme.

**Takeaway**: **Route synthetic leaves through the same owner conversion as authored leaves before calling a composite computed.**
