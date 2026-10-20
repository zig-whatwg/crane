# Chapter 12: Embedded Content

::: }}
[Overview](Overview.html) · [Previous](text.html) ·
[Next](painting.html) · [Elements](eltindex.html) ·
[Attributes](attindex.html) · [Properties](propidx.html)

## Contents

1. 1. [[12.1.] Overview](embedded.html#Overview)
 2. [[12.2.] Placement of the embedded
 content](embedded.html#Placement)
 3. [[12.3.] The ['image']
 element](embedded.html#ImageElement)
 4. [[12.4.] The ['foreignObject']
 element](embedded.html#ForeignObjectElement)
 5. [[12.5.] DOM interfaces](embedded.html#DOMInterfaces)
 1. [[12.5.1.] Interface
 SVGImageElement](embedded.html#InterfaceSVGImageElement)
 2. [[12.5.2.] Interface
 SVGForeignObjectElement](embedded.html#InterfaceSVGForeignObjectElement)

## 12.1. Overview
Embedded content is content that imports another resource into the
document, or content from another vocabulary that is inserted into the
document. This is the same definition as
[HTML\'s](https://html.spec.whatwg.org/multipage/) [embedded
content](https://html.spec.whatwg.org/multipage/embedded-content.html#embedded-content).

SVG supports embedded content with the use of
['[image](embedded.html#ImageElement)'] and
['[foreignObject](embedded.html#ForeignObjectElement)']
elements.

Content embedded with
['[image](embedded.html#ImageElement)'] is compatible
with [Resource Hints](https://www.w3.org/TR/resource-hints/) for
prioritizing downloading of external resources.

## 12.2. Placement of the embedded content
The [x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing), and
[height](geometry.html#Sizing) geometry properties specify
the rectangular region into which the embedded content is positioned
(the [positioning rectangle]). The [positioning
rectangle](embedded.html#TermPositioningRectangle) is used as the
bounding box of the element; note, however, that graphics may overflow
the positioning rectangle, depending on the value of the
[overflow](render.html#OverflowAndClipProperties) property.

When the embedded content consists of a single referenced resource
(e.g., an ['[image](embedded.html#ImageElement)']), the
dimensions of the [positioning
rectangle](embedded.html#TermPositioningRectangle), in the current
coordinate system after applying all transforms, define the [specified
size](https://www.w3.org/TR/css3-images#specified-size) for the embedded
object. A [concrete object
size](https://www.w3.org/TR/css3-images#concrete-object-size) and final
position must be determined for the object using the [Default Sizing
Algorithm](https://www.w3.org/TR/css3-images/#default-sizing-algorithm)
defined for replaced elements in CSS layout
\[[css-images-3](refs.html#ref-css-images-3)\]. The
[object-fit](https://www.w3.org/TR/css3-images/#the-object-fit)
and
[object-position](https://www.w3.org/TR/css3-images/#the-object-position)
affect the final position and size of the object, and may cause it to be
extend beyond the [positioning
rectangle](embedded.html#TermPositioningRectangle). In that case, the
[overflow](render.html#OverflowAndClipProperties) property
determines whether the rendered object should be clipped to its
[positioning rectangle](embedded.html#TermPositioningRectangle).

When the embedded content consists of a document fragment (e.g., a
['[foreignObject](embedded.html#ForeignObjectElement)']),
the [positioning rectangle](embedded.html#TermPositioningRectangle)
defines the bounds of a [containing
block](https://www.w3.org/TR/CSS21/visuren.html#containing-block) for
laying out the child content using CSS. The scale of the containing
block is defined in the current coordinate system, including all
explicit and implicit (e.g.,
['[viewBox](coords.html#ViewBoxAttribute)'])
transformations. The
['[foreignObject](embedded.html#ForeignObjectElement)'],
or other element that is positioned using SVG layout attributes, is
implicitly
[absolutely-positioned](https://www.w3.org/TR/CSS21/visuren.html#propdef-position)
for the purposes of CSS layout. As a result, any absolutely-positioned
child elements are positioned relative to this containing block. Again,
the [overflow](render.html#OverflowAndClipProperties)
property determines whether content that extends outside the
[positioning rectangle](embedded.html#TermPositioningRectangle) will be
hidden.

A value of zero for either [width](geometry.html#Sizing) or
[height](geometry.html#Sizing) disables rendering of the
element and its embedded content.

The [\'auto\'] value for
[width](geometry.html#Sizing) or
[height](geometry.html#Sizing) is used to size the
corresponding element automatically based on the [intrinsic
dimensions](https://www.w3.org/TR/css3-images#intrinsic-dimensions) or
[intrinsic aspect
ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio) of the
referenced resource. Computation of automatically-sized values follows
the [Default Sizing
Algorithm](https://www.w3.org/TR/css3-images/#default-sizing-algorithm)
defined for replaced elements in CSS layout
\[[css-images-3](refs.html#ref-css-images-3)\]. In particular, when the
referenced resource does not have an intrinsic size (such as image types
with no defined dimensions), it is assumed to have a width of 300px and
a height of 150px.

CSS positioning properties (e.g. [top] and
[margin]) have no effect when positioning the embedded
content element in the SVG coordinate system. They can, however, be used
to position child elements of a
['[foreignObject](embedded.html#ForeignObjectElement)']
or HTML embedding element.

## 12.3. The ['image'] element
:::: element-summary
::: element-summary-name
['[image]']

Categories:
: [Graphics element](struct.html#TermGraphicsElement), [graphics
 referencing element](struct.html#TermGraphicsReferencingElement),
 [renderable element](render.html#TermRenderableElement),
 [structurally external
 element](struct.html#TermStructurallyExternalElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://svgwg.org/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://svgwg.org/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://svgwg.org/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://svgwg.org/specs/animations/#AnimateTransformElement)'],
 ['[set](https://svgwg.org/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]

 [[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)],
 [[mask](https://drafts.fxtf.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [deprecated xlink attributes](linking.html#XLinkRefAttrs)[ ---
 ['[xlink:href](linking.html#XLinkHrefAttribute)'],
 ['[xlink:title](linking.html#XLinkTitleAttribute)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 - ['[href](embedded.html#ImageElementHrefAttribute)']
 - ['[crossorigin](embedded.html#ImageElementCrossoriginAttribute)']

Geometry properties:

: - [x](geometry.html#XProperty)
 - [y](geometry.html#YProperty)
 - [width](geometry.html#Sizing)
 - [height](geometry.html#Sizing)

DOM Interfaces:

: - [SVGImageElement](embedded.html#InterfaceSVGImageElement)

The ['[image](embedded.html#ImageElement)'] element
indicates that the contents of a complete file are to be rendered into a
given rectangle within the current user coordinate system. The
['[image](embedded.html#ImageElement)'] element can refer
to raster image files such as PNG or JPEG or to files with MIME type of
\"image/svg+xml\". [Conforming SVG
viewers](conform.html#ConformingSVGViewers) need to support at least
PNG, JPEG and SVG format files. SVG files must be processed in [secure
animated mode](conform.html#secure-animated-mode) if the current
document supports animation, or in [secure static
mode](conform.html#secure-static-mode) if the current document is
static.

The result of processing an
['[image](embedded.html#ImageElement)'] is always a
four-channel RGBA result. When an
['[image](embedded.html#ImageElement)'] element
references an image (such as many PNG or JPEG files) which only has
three channels (RGB), then the effect is as if the object were converted
into a 4-channel RGBA image with the alpha channel uniformly set to 1.
For a single-channel (grayscale) raster image, the effect is as if the
object were converted into a 4-channel RGBA image, where the single
channel from the referenced object is used to compute the three color
channels and the alpha channel is uniformly set to 1.

The
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute determines how the referenced image is scaled and positioned
to fit into the [concrete object
size](https://www.w3.org/TR/css3-images#concrete-object-size) determined
from the [positioning rectangle](embedded.html#TermPositioningRectangle)
and the
[object-fit](https://www.w3.org/TR/css3-images/#the-object-fit)
and
[object-position](https://www.w3.org/TR/css3-images/#the-object-position)
properties. The result of applying this attribute defines an
[image-rendering rectangle] used for actual image rendering. When the
referenced image is an SVG, the [image-rendering
rectangle](embedded.html#TermImageRenderingRectangle) defines the [SVG
viewport](coords.html#TermSVGViewport) used for rendering that SVG.

The
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
calculations are applied *after* determining the [concrete object
size](https://www.w3.org/TR/css3-images#concrete-object-size), and only
have an effect if that size does not match the [intrinsic aspect
ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio) of the
embedded image. If a value of
[object-fit](https://www.w3.org/TR/css3-images/#the-object-fit)
is used that ensures that the concrete object size matches the intrinsic
aspect ratio (i.e., any value other than the default
[fill]), then the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
value will have no effect; the [image-rendering
rectangle](embedded.html#TermImageRenderingRectangle) will be that
determined when scaling and positioning the object with CSS. The
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute can therefore be safely used as a fallback for most values of
[object-fit](https://www.w3.org/TR/css3-images/#the-object-fit)
and
[object-position](https://www.w3.org/TR/css3-images/#the-object-position);
it must be explicitly set to [none] to turn off aspect
ratio control, regardless of
[object-fit](https://www.w3.org/TR/css3-images/#the-object-fit)
value.

The aspect ratio to use when evaluating the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute is defined by the [intrinsic aspect
ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio) of the
referenced content. For an SVG file, the aspect ratio is defined in
[Intrinsic sizing properties of SVG
content\"](coords.html#SizingSVGInCSS). For most raster content (PNG,
JPEG) the pixel width and height of the image file define an intrinsic
aspect ratio. Where the embedded image does not have an [intrinsic
aspect ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio)
(e.g. an SVG file with neither
['[viewBox](coords.html#ViewBoxAttribute)'] attribute nor
explicit dimensions for the [outermost svg
element](struct.html#TermOutermostSVGElement)) the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute is ignored; the embedded image is drawn to fill the
[positioning rectangle](embedded.html#TermPositioningRectangle) defined
by the geometry properties on the
['[image](embedded.html#ImageElement)'] element.

For example, if the image element referenced a PNG or JPEG and
[preserveAspectRatio=\"xMinYMin meet\"], then the aspect
ratio of the raster would be preserved (which means that the scale
factor from image\'s coordinates to current user space coordinates would
be the same for both X and Y), the raster would be sized as large as
possible while ensuring that the entire raster fits within the viewport,
and the top/left of the raster would be aligned with the top/left of the
viewport as defined by the attributes
[x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) on the
['[image](embedded.html#ImageElement)'] element.  If the
value of
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
was [\'none\'] then aspect ratio of the image would not be
preserved. The image would be fit such that the top/left corner of the
raster exactly aligns with coordinate
([x](geometry.html#XProperty),
[y](geometry.html#YProperty)) and the bottom/right corner of
the raster exactly aligns with coordinate
([x](geometry.html#XProperty)+[width](geometry.html#Sizing),
[y](geometry.html#YProperty)+[height](geometry.html#Sizing)).

For ['[image](embedded.html#ImageElement)'] elements
embedding an SVG image, the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute on the root element in the referenced SVG image must be
ignored, and instead treated as if it had a value of
[none]. (see
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
for details). This ensures that the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute on the referencing
['[image](embedded.html#ImageElement)'] has its intended
effect, even if it is [none].

When the value of the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute on the ['[image](embedded.html#ImageElement)']
is *not* [none], the [image-rendering
rectangle](embedded.html#TermImageRenderingRectangle) determined from
the properties of the
['[image](embedded.html#ImageElement)'] element will
exactly match the embedded SVG\'s intrinsic aspect ratio. Ignoring the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute from the embedded SVG will therefore not usually have any
effect. The exception is if the aspect ratio of that image is determined
from absolute values for the [width](geometry.html#Sizing)
and [height](geometry.html#Sizing) attributes which *do not*
match its ['[viewBox](coords.html#ViewBoxAttribute)'] aspect
ratio. This is an unusual situation that authors are advised to avoid,
for many reasons.

The user agent stylesheet sets the value of the
[overflow](render.html#OverflowAndClipProperties) property on
['[image](embedded.html#ImageElement)'] element to
[hidden]. Unless over-ridden by the author, images will
therefore be clipped to the [positioning
rectangle](embedded.html#TermPositioningRectangle) defined by the
geometry properties.

For ['[image](embedded.html#ImageElement)'] elements
embedding an SVG image, two different
[overflow](render.html#OverflowAndClipProperties) values
apply. The value specified on the
['[image](embedded.html#ImageElement)'] element
determines whether the [image-rendering
rectangle](embedded.html#TermImageRenderingRectangle) is clipped to the
[positioning rectangle](embedded.html#TermPositioningRectangle). The
value on the root element of the referenced SVG determines whether the
graphics are clipped to the [image-rendering
rectangle](embedded.html#TermImageRenderingRectangle).

New in SVG 2. Previous versions of SVG required that the
[overflow](render.html#OverflowAndClipProperties) (and also
[clip](https://drafts.fxtf.org/css-masking-1/#propdef-clip))
property on the embedded SVG be ignored. The new rules ensure that an
overflowing [slice] layout can be safely used without
compromising the overflow control from the referenced image.

To link into particular view of an embedded SVG image, authors can use
media fragments as defined in [Linking into SVG
content](linking.html#LinksIntoSVG). To crop to a specific section of a
raster image, authors can use *Basic media fragments identifiers*
\[[Media Fragments URI 1.0 (basic)](refs.html#ref-media-frags)\]. Either
type of fragment may affect the [intrinsic
dimensions](https://www.w3.org/TR/css3-images#intrinsic-dimensions)
and/or [intrinsic aspect
ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio) of the
image.

The resource referenced by the
['[image](embedded.html#ImageElement)'] element
represents a separate document which generates its own parse tree and
document object model (if the resource is XML). Thus, there is no
inheritance of properties into the image.

Unlike ['[use](struct.html#UseElement)'], the
['[image](embedded.html#ImageElement)'] element cannot
reference elements within an SVG file.

 -------------------- ---------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support auto-sized images.
 Resolution: [We will allow auto-sized images in SVG 2.](http://www.w3.org/2011/10/27-svg-irc#T18-52-24)
 Purpose: To allow raster images to use their own size without the need to set width and height.
 Owner: Cameron ([ACTION-3340](http://www.w3.org/Graphics/SVG/WG/track/actions/3340))
 -------------------- ---------------------------------------------------------------------------------------------

 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support selecting part of an ['[image](embedded.html#ImageElement)'] for display.
 Resolution: [We will have a method for ['image'] to select a part of an image to display, maybe by allowing ['viewBox'] on it.](http://www.w3.org/2011/10/27-svg-irc#T18-45-13)
 Purpose: To allow selection of part of an image without requiring the author to manually slice the image.
 Owner: Nobody
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support the '[object-fit]' and '[object-position]' properties from css-images-3.
 Resolution: [SVG 2 will depend on CSS3 Image Values and CSS4 Image Values.](http://www.w3.org/2011/07/29-svg-minutes.html#item08)
 Purpose: To align with the CSS way of specifying image fitting that ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)'] provides.
 Owner: Cameron or Erik (no action)
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------

*Attribute definitions:*

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------------------- ------------------------------------- ------------------------------------ ------------
 [crossorigin] \[ anonymous \| use-credentials \]? (see HTML definition of attribute) yes

The crossorigin attribute is a [CORS settings
attribute](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attribute),
and unless otherwise specified follows the same processing rules as in
HTML \[[HTML](refs.html#ref-html)\].

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------- -------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](types.html#attribute-url) (none) yes

An [URL reference](linking.html#URLReference) identifying the image to
render. Refer to the common handling defined for [URL reference
attributes](linking.html#linkRefAttrs) and [deprecated XLink
attributes](linking.html#XLinkRefAttrs).

The URL is processed and the resource is fetched [as described in the
Linking chapter](linking.html#processingURL).

 <?xml version="1.0" standalone="no"?>
 <svg width="4in" height="3in"
 xmlns="http://www.w3.org/2000/svg">
 <desc>This graphic links to an external image
 </desc>
 <image x="200" y="200" width="100px" height="100px"
 href="myimage.png">
 <title>My image</title>
 </image>
 </svg>

Since image references always refer to a complete document, a
target-only URL is treated as a link to the same file, which is rendered
again as an independent embedded image. Since the embedded image is
processed in a secure mode, its own embedded references are not
processed, preventing infinite recursion.

``` xml
<?xml version="1.0" standalone="no"?>
<svg width="5cm" height="3cm" viewBox="0 0 50 30"
 xmlns="http://www.w3.org/2000/svg"
 xmlns:xlink="http://www.w3.org/1999/xlink">
 <title>Recursive SVG</title>
 <desc>An SVG with two recursive image reference to itself.
 One reference uses the file name as a relative URL,
 the other uses a target fragment only.
 When viewed in a processing mode that supports external file references,
 the embedded images should be rendered;
 however, the embedded image must be processed in secure mode,
 so the recursion only happens once.
 The appearance should be three nested red circles in a bulls-eye pattern;
 the innermost circle has solid fill because of target styles.
 </desc>
 <style type="text/css">
 #target:target {
 fill: red;
 }
 </style>
 <circle id="target"
 stroke="red" stroke-width="5" fill="none"
 cx="50%" cy="50%" r="12" />
 <image xlink:href="recursive-image.svg"
 x="25%" y="25%" width="50%" height="50%" />
 <image xlink:href="#target"
 x="45%" y="45%" width="10%" height="10%" />
</svg>
```

![Example recursive-image --- an SVG that embeds itself, creating a
bulls-eye pattern](images/embedded/recursive-image.png)

Example recursive-image

[View this example as SVG (SVG-enabled browsers
only)](images/embedded/recursive-image.svg)

## 12.4. The ['foreignObject'] element
:::: element-summary
::: element-summary-name
['[foreignObject]']

Categories:
: [Graphics element](struct.html#TermGraphicsElement), [renderable
 element](render.html#TermRenderableElement), [structurally external
 element](struct.html#TermStructurallyExternalElement)

Content model:
: Any elements or character data.

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]

Geometry properties:

: - [x](geometry.html#XProperty)
 - [y](geometry.html#YProperty)
 - [width](geometry.html#Sizing)
 - [height](geometry.html#Sizing)

DOM Interfaces:

: - [SVGForeignObjectElement](embedded.html#InterfaceSVGForeignObjectElement)

SVG is designed to be compatible with other XML languages for describing
and rendering other types of content. The
['[foreignObject](embedded.html#ForeignObjectElement)']
element allows for inclusion of elements in a non-SVG namespace which is
rendered within a region of the SVG graphic using other user agent
processes. The included foreign graphical content is subject to SVG
transformations, filters, clipping, masking and compositing. Examples
include inserting a
[MathML](https://www.w3.org/TR/2003/REC-MathML2-20031021/) expression
into an SVG drawing \[[MathML3](refs.html#ref-mathml3)\], or adding a
block of complex CSS-formatted HTML text or form inputs.

The HTML parser treats elements inside the
['[foreignObject](embedded.html#ForeignObjectElement)']
equivalent to elements inside an HTML document fragment. Any `svg` or
`math` element, and their descendents, will be parsed as being in the
SVG or MathML namespace, respectively; all other tags will be parsed as
being in the HTML namespace.

SVG-namespaced elements within a
['[foreignObject](embedded.html#ForeignObjectElement)']
will not be rendered, except in the situation where a properly defined
SVG fragment, including a root
['[svg](struct.html#SVGElement)'] element is defined as a
descendent of the
['[foreignObject](embedded.html#ForeignObjectElement)'].

A ['[foreignObject](embedded.html#ForeignObjectElement)']
may be used in conjunction with the
['[switch](struct.html#SwitchElement)'] element and the
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
attribute to provide proper checking for user agent support and provide
an alternate rendering in case user agent support is not available.

This specification does not define how
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
values should be mapped to support for different XML languages; a future
specification may do so.

It is not required that SVG user agents support the ability to invoke
other arbitrary user agents to handle embedded foreign object types;
however, all conforming SVG user agents would need to support the
['[switch](struct.html#SwitchElement)'] element and must
be able to render valid SVG elements when they appear as one of the
alternatives within a
['[switch](struct.html#SwitchElement)'] element.

It is expected that commercial Web browsers will support the ability for
SVG to embed CSS-formatted HTML and also MathML content, with the
rendered content subject to transformations and compositing defined in
the SVG fragment. At this time, such a capability is not a requirement.

 <?xml version="1.0" standalone="yes"?>
 <svg width="4in" height="3in"
 xmlns = 'http://www.w3.org/2000/svg'>
 <desc>This example uses the 'switch' element to provide a
 fallback graphical representation of an paragraph, if
 XMHTML is not supported.</desc>
 <!-- The 'switch' element will process the first child element
 whose testing attributes evaluate to true.-->
 <switch>
 <!-- Process the embedded XHTML if the requiredExtensions attribute
 evaluates to true (i.e., the user agent supports XHTML
 embedded within SVG). -->
 <foreignObject width="100" height="50"
 requiredExtensions="http://example.com/SVGExtensions/EmbeddedXHTML">
 <!-- XHTML content goes here -->
 <body xmlns="http://www.w3.org/1999/xhtml">
 <p>Here is a paragraph that requires word wrap</p>
 </body>
 </foreignObject>
 <!-- Else, process the following alternate SVG.
 Note that there are no testing attributes on the 'text' element.
 If no testing attributes are provided, it is as if there
 were testing attributes and they evaluated to true.-->
 <text font-size="10" font-family="Verdana">
 <tspan x="10" y="10">Here is a paragraph that</tspan>
 <tspan x="10" y="20">requires word wrap.</tspan>
 </text>
 </switch>
 </svg>

::: ready-for-wider-review
## 12.5. DOM interfaces
### 12.5.1. Interface SVGImageElement
An
[SVGImageElement](embedded.html#InterfaceSVGImageElement)
object represents an
['[image](embedded.html#ImageElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGImageElement : SVGGraphicsElement {
 [SameObject] readonly attribute SVGAnimatedLength x;
 [SameObject] readonly attribute SVGAnimatedLength y;
 [SameObject] readonly attribute SVGAnimatedLength width;
 [SameObject] readonly attribute SVGAnimatedLength height;
 [SameObject] readonly attribute SVGAnimatedPreserveAspectRatio preserveAspectRatio;
 attribute DOMString? crossOrigin;
};

SVGImageElement includes SVGURIReference;
```

The **x**, **y**, **width** and **height** IDL attributes
[reflect](types.html#TermReflect) the computed values of the
[x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties and their
corresponding presentation attributes, respectively.

The **preserveAspectRatio** IDL attribute
[reflects](types.html#TermReflect) the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
content attribute.

The **crossOrigin** IDL attribute [reflects](types.html#TermReflect) the
['[crossorigin](embedded.html#ImageElementCrossoriginAttribute)']
content attribute.

### 12.5.2. Interface SVGForeignObjectElement
An
[SVGForeignObjectElement](embedded.html#InterfaceSVGForeignObjectElement)
object represents a
['[foreignObject](embedded.html#ForeignObjectElement)']
in the DOM.

``` idl
[Exposed=Window]
interface SVGForeignObjectElement : SVGGraphicsElement {
 [SameObject] readonly attribute SVGAnimatedLength x;
 [SameObject] readonly attribute SVGAnimatedLength y;
 [SameObject] readonly attribute SVGAnimatedLength width;
 [SameObject] readonly attribute SVGAnimatedLength height;
};
```

The **x**, **y**, **width** and **height** IDL attributes
[reflect](types.html#TermReflect) the computed values of the
[x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties and their
corresponding presentation attributes, respectively.
