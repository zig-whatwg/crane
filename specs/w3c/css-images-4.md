## 1. Introduction

*This section is not normative.*

This module introduces additional ways of representing 2D images, for
example as [a URL with color fallback](#image-notation), as [conic
gradients](#conic-gradients), or as the [rendering of another element in
the document](#element-notation).

### 1.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
using the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. 2D Image Values: the [\<image\> type]
The [\<image\>](#typedef-image) value type denotes a 2D image. It can be a [url
reference](#url-notation), [image notation](#image-notation), or
[gradient notation](#gradients). Its syntax is:

```
<image> = <url> | <image()> | <image-set()> | <cross-fade()> | <element()> | <gradient>
```

An [\<image\>](#typedef-image) can be used in many CSS properties, including the
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image),
[list-style-image](https://drafts.csswg.org/css-lists-3/#propdef-list-style-image),
[cursor](https://drafts.csswg.org/css-ui-4/#propdef-cursor) properties
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
(where it replaces the
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) component in the property's value).

In some cases an image is invalid, such as a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) pointing to a resource that is not a
valid image format or that has failed to load. An [invalid
image] is rendered as a solid-color
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) image with no [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions). However, [invalid
images](#invalid-image) can
trigger error-handling clauses in some contexts. For example, an
[invalid image] in
[list-style-image](https://drafts.csswg.org/css-lists-3/#propdef-list-style-image) it is treated as
[none](https://drafts.csswg.org/css-lists-3/#valdef-list-style-type-none), allowing the
[list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type) to render in its place.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

While an image is loading, is a [loading image]. [Loading
images](#loading-image) are
*not* [invalid images](#invalid-image), but have similar behavior: they are rendered as a
solid-color
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) image with no [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions), and may trigger fallback rendering in contexts that
offer it, but must not trigger loading of fallback resources.
Alternately, if a [loading image] happens to be
replacing an already-loaded image (for example due to changes in the
document or style sheet) and the UA is tracking this information, it may
continue to render the already-loaded image in place of the [loading
image].

Partially-loaded images (whose [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) are known, but whose image data is not fully loaded)
may be either treated as [loading
images](#loading-image) or as
loaded images rendered with partial data. For example, a UA may render
an interlaced GIF in place as soon as its first pass of pixel data has
loaded or even as soon as the image header (which contains sizing data)
has parsed and refresh the rendering as more data loads; or it may wait
until the entire image has loaded before using it.

A
[[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [\<image\>](#typedef-image)] value is the [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) with any
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value)s,
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)s, and
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s computed.

### 2.1. Image File Formats

At minimum, the UA must support the following image file formats when
referenced from an [\<image\>](#typedef-image) value, for all the properties in
which using [\<image\>] is valid:

- PNG, as specified in
 [\[PNG\]](#biblio-png "Portable Network Graphics (PNG) Specification (Third Edition)")
- SVG, as specified in
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 using the [secure static
 mode](https://www.w3.org/TR/svg-integration/#secure-static-mode) (See
 [\[SVG-INTEGRATION\]](#biblio-svg-integration "SVG Integration"))
- If the UA supports animated
 [\<image\>](#typedef-image)s, SVG, as specified in
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 using the [secure animated
 mode](https://www.w3.org/TR/svg-integration/#secure-animated-mode)
 (See
 [\[SVG-INTEGRATION\]](#biblio-svg-integration "SVG Integration"))

The UA may support other file formats as well.

### [2.2. ][Image References: the [url()](https://drafts.csswg.org/css-values-4/#funcdef-url) notation]
 No change from
[\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

### 2.3. Fetching External Images

To [fetch an external image for a
stylesheet], given a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) `url` and a [CSS
declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) `declaration`, [fetch a style
resource](https://drafts.csswg.org/css-values-4/#fetch-a-style-resource) given `url`, with ruleOrDeclaration being
`declaration`, destination \"image\", CORS mode \"no-cors\",
and processResponse being the following steps given
[response](https://fetch.spec.whatwg.org/#concept-response) `res` and null, failure or a byte stream
`byteStream`: If `byteStream` is a byte stream,
load the image from the byte stream.

### 2.4. Resolution/Type Negotiation: the [image-set() notation]
Delivering the most appropriate image resolution for a user's device can
be a difficult task. Ideally, images should be in the same resolution as
the device they're being viewed in, which can vary between users.
However, other factors can factor into the decision of which image to
send; for example, if the user is on a slow mobile connection, they may
prefer to receive lower-res images rather than waiting for a large
proper-res image to load. The [image-set()] function allows an author to
ignore most of these issues, simply providing multiple resolutions of an
image and letting the UA decide which is most appropriate in a given
situation.

This solution assumes that resolution is
a proxy for filesize, and therefore doesn't appropriately handle
multi-resolution sets of vector images, or mixing vector images with
raster ones (e.g. for icons). For example, use a vector for high-res,
pixel-optimized bitmap for low-res, and same vector again for
low-bandwidth (because it's much smaller, even though it's higher
resolution).

The syntax for
[image-set()](#funcdef-image-set) is:

```
<image-set()> = image-set( <image-set-option># )
<image-set-option> = [ <image> | <string> ]
 [ <resolution> || type(<string>) ]?
```

We should add \"w\" and \"h\" dimensions
as a possibility to match the functionality of HTML's
[picture](https://html.spec.whatwg.org/multipage/embedded-content.html#the-picture-element).

Each
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) inside
[image-set()](#funcdef-image-set) represents a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value).

The [image-set()](#funcdef-image-set) function can not be nested inside of itself, either
directly or indirectly (as an argument to another
[\<image\>](#typedef-image) type).

Each
[\<image-set-option\>](#typedef-image-set-option) defines a possible image for the
[image-set()](#funcdef-image-set) function to represent, composed of three parts:

- An image reference (required). This can be a URL, or a CSS generated
 image, such as a
 [linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient).

- A
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) (optional). This is used to help
 the UA decide which
 [\<image-set-option\>](#typedef-image-set-option) to choose. If the image reference
 is for a raster image, it also specifies the image's [natural
 resolution](#--natural-resolution), overriding any other source of data that might
 supply a [natural resolution].

 If not specified, it behaves as [1x] for the purpose of
 selecting which
 [\<image-set-option\>](#typedef-image-set-option) to use. It also *defaults* the
 image's [natural
 resolution](#--natural-resolution) to [1x], but if some other source of data
 supplies a [natural resolution], that
 resolution must be honored instead.

- A [type(
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) )] function (optional), specifying the image's MIME type in
 the
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value).

 If the
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value), when parsed as a [valid MIME type
 string](https://mimesniff.spec.whatwg.org/#valid-mime-type), is either not valid, or is valid but doesn't specify
 a supported image format, the
 [\<image-set-option\>](#typedef-image-set-option) does not define a valid option.
 (This has no effect on the validity of the
 [image-set()](#funcdef-image-set) function.)

 It does not have any effect on the image itself; an
 [\<image-set-option\>](#typedef-image-set-option) like
 `url("picture.png") 1x type("image/jpeg")` is valid, and
 if chosen will display the linked PNG image, even though it was
 declared to be a JPEG.

 If not specified, it has no effect on the
 [\<image-set-option\>](#typedef-image-set-option).

Tests

- [image-set-all-options-invalid.html](https://wpt.fyi/results/css/css-images/image-set/image-set-all-options-invalid.html "css/css-images/image-set/image-set-all-options-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-all-options-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-all-options-invalid.html)
- [image-set-calc-x-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-calc-x-rendering-2.html "css/css-images/image-set/image-set-calc-x-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-calc-x-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-calc-x-rendering-2.html)
- [image-set-calc-x-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-calc-x-rendering.html "css/css-images/image-set/image-set-calc-x-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-calc-x-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-calc-x-rendering.html)
- [image-set-computed.sub.html](https://wpt.fyi/results/css/css-images/image-set/image-set-computed.sub.html "css/css-images/image-set/image-set-computed.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-computed.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-computed.sub.html)
- [image-set-conic-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-conic-gradient-rendering.html "css/css-images/image-set/image-set-conic-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-conic-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-conic-gradient-rendering.html)
- [image-set-content-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-content-rendering.html "css/css-images/image-set/image-set-content-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-content-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-content-rendering.html)
- [image-set-dpcm-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-dpcm-rendering.html "css/css-images/image-set/image-set-dpcm-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-dpcm-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-dpcm-rendering.html)
- [image-set-dpi-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-dpi-rendering-2.html "css/css-images/image-set/image-set-dpi-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-dpi-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-dpi-rendering-2.html)
- [image-set-dpi-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-dpi-rendering.html "css/css-images/image-set/image-set-dpi-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-dpi-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-dpi-rendering.html)
- [image-set-dppx-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-dppx-rendering.html "css/css-images/image-set/image-set-dppx-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-dppx-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-dppx-rendering.html)
- [image-set-empty-url-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-empty-url-rendering.html "css/css-images/image-set/image-set-empty-url-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-empty-url-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-empty-url-rendering.html)
- [image-set-first-match-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-first-match-rendering.html "css/css-images/image-set/image-set-first-match-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-first-match-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-first-match-rendering.html)
- [image-set-linear-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-linear-gradient-rendering.html "css/css-images/image-set/image-set-linear-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-linear-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-linear-gradient-rendering.html)
- [image-set-negative-resolution-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-negative-resolution-rendering-2.html "css/css-images/image-set/image-set-negative-resolution-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-negative-resolution-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-negative-resolution-rendering-2.html)
- [image-set-negative-resolution-rendering-3.html](https://wpt.fyi/results/css/css-images/image-set/image-set-negative-resolution-rendering-3.html "css/css-images/image-set/image-set-negative-resolution-rendering-3.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-negative-resolution-rendering-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-negative-resolution-rendering-3.html)
- [image-set-negative-resolution-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-negative-resolution-rendering.html "css/css-images/image-set/image-set-negative-resolution-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-negative-resolution-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-negative-resolution-rendering.html)
- [image-set-no-res-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-no-res-rendering-2.html "css/css-images/image-set/image-set-no-res-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-no-res-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-no-res-rendering-2.html)
- [image-set-no-res-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-no-res-rendering.html "css/css-images/image-set/image-set-no-res-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-no-res-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-no-res-rendering.html)
- [image-set-no-url-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-no-url-rendering.html "css/css-images/image-set/image-set-no-url-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-no-url-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-no-url-rendering.html)
- [image-set-parsing.html](https://wpt.fyi/results/css/css-images/image-set/image-set-parsing.html "css/css-images/image-set/image-set-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-parsing.html)
- [image-set-radial-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-radial-gradient-rendering.html "css/css-images/image-set/image-set-radial-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-radial-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-radial-gradient-rendering.html)
- [image-set-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-rendering-2.html "css/css-images/image-set/image-set-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-rendering-2.html)
- [image-set-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-rendering.html "css/css-images/image-set/image-set-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-rendering.html)
- [image-set-repeating-conic-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-repeating-conic-gradient-rendering.html "css/css-images/image-set/image-set-repeating-conic-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-repeating-conic-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-repeating-conic-gradient-rendering.html)
- [image-set-repeating-linear-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-repeating-linear-gradient-rendering.html "css/css-images/image-set/image-set-repeating-linear-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-repeating-linear-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-repeating-linear-gradient-rendering.html)
- [image-set-repeating-radial-gradient-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-repeating-radial-gradient-rendering.html "css/css-images/image-set/image-set-repeating-radial-gradient-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-repeating-radial-gradient-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-repeating-radial-gradient-rendering.html)
- [image-set-resolution-001.html](https://wpt.fyi/results/css/css-images/image-set/image-set-resolution-001.html "css/css-images/image-set/image-set-resolution-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-resolution-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-resolution-001.html)
- [image-set-resolution-002.html](https://wpt.fyi/results/css/css-images/image-set/image-set-resolution-002.html "css/css-images/image-set/image-set-resolution-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-resolution-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-resolution-002.html)
- [image-set-resolution-003.html](https://wpt.fyi/results/css/css-images/image-set/image-set-resolution-003.html "css/css-images/image-set/image-set-resolution-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-resolution-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-resolution-003.html)
- [image-set-type-first-match-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-first-match-rendering.html "css/css-images/image-set/image-set-type-first-match-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-first-match-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-first-match-rendering.html)
- [image-set-type-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-rendering-2.html "css/css-images/image-set/image-set-type-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-rendering-2.html)
- [image-set-type-rendering-3.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-rendering-3.html "css/css-images/image-set/image-set-type-rendering-3.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-rendering-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-rendering-3.html)
- [image-set-type-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-rendering.html "css/css-images/image-set/image-set-type-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-rendering.html)
- [image-set-type-skip-unsupported-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-skip-unsupported-rendering.html "css/css-images/image-set/image-set-type-skip-unsupported-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-skip-unsupported-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-skip-unsupported-rendering.html)
- [image-set-type-unsupported-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-unsupported-rendering-2.html "css/css-images/image-set/image-set-type-unsupported-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-unsupported-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-unsupported-rendering-2.html)
- [image-set-type-unsupported-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-type-unsupported-rendering.html "css/css-images/image-set/image-set-type-unsupported-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-type-unsupported-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-type-unsupported-rendering.html)
- [image-set-unordered-res-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-unordered-res-rendering.html "css/css-images/image-set/image-set-unordered-res-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-unordered-res-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-unordered-res-rendering.html)
- [image-set-zero-resolution-rendering-2.html](https://wpt.fyi/results/css/css-images/image-set/image-set-zero-resolution-rendering-2.html "css/css-images/image-set/image-set-zero-resolution-rendering-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-zero-resolution-rendering-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-zero-resolution-rendering-2.html)
- [image-set-zero-resolution-rendering.html](https://wpt.fyi/results/css/css-images/image-set/image-set-zero-resolution-rendering.html "css/css-images/image-set/image-set-zero-resolution-rendering.html")
 [[(live
 test)]](http://wpt.live/css/css-images/image-set/image-set-zero-resolution-rendering.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/image-set/image-set-zero-resolution-rendering.html)

An [image-set()](#funcdef-image-set) function contains a list of one or more
[\<image-set-option\>](#typedef-image-set-option)s, and must select only one of them to
determine what image it will represent:

1. First, remove any
 [\<image-set-option\>](#typedef-image-set-option)s from the list that specify an
 unknown or unsupported MIME type in their
 [type()](#funcdef-image-set-type) value.

2. Second, remove any
 [\<image-set-option\>](#typedef-image-set-option)s from the list that have the same
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) as a previous option in the list.

3. If there are no
 [\<image-set-option\>](#typedef-image-set-option) left at this point, the function
 represents an [invalid
 image](#invalid-image).

4. Finally, among the remaining
 [\<image-set-option\>](#typedef-image-set-option)s, make a UA-specific choice of
 which to load, based on whatever criteria deemed relevant (such as
 the resolution of the display, connection speed, etc).

5. The [image-set()](#funcdef-image-set) function then represents the
 [\<image\>](#typedef-image) of the chosen
 [\<image-set-option\>](#typedef-image-set-option).

UAs **may** change which
[\<image-set-option\>](#typedef-image-set-option) they wish to use for a given
[image-set()](#funcdef-image-set) over the lifetime of the page, if the criteria used
to determine which option to choose change significantly enough to make
it worthwhile in the UA's estimation.

This example shows how to use
[image-set()](#funcdef-image-set) to provide an image in three versions: a \"normal\"
version, a \"high-res\" version, and an extra-high resolution version
for use in high-quality printing (as printers can have *extremely* high
resolution):

``` highlight
background-image: image-set( "foo.png" 1x,
 "foo-2x.png" 2x,
 "foo-print.png" 600dpi );
```

This example shows use of the
[type()](#funcdef-image-set-type) function to serve multiple versions of the same image
in both new, higher-quality formats, and older, more widely-supported
formats:

``` highlight
background-image: image-set( "foo.avif" type("image/avif"),
 "foo.jpg" type("image/jpeg") );
```

Note that the AVIF image is given first; since both images have the same
resolution (defaulting to [1x] since it's unspecified), the JPEG
image, coming second, is automatically dropped in UAs that support AVIF
images.

In older UAs, however, the AVIF image is ignored (because the UA knows
it doesn't support `"image/avif"` files), and so the JPEG is
chosen instead.

Raster images can be mixed
with vector images, or even CSS generated images.

For example, in this code snippet a high-resolution image with subtle
details is used on screens that can do it justice, while an ordinary CSS
[linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient) is used instead for low-resolution situations:

``` highlight
background-image: image-set( linear-gradient(cornflowerblue, white) 1x,
 url("detailed-gradient.png") 3x );
```

### 2.5. Image Fallbacks and Annotations: the [image() notation]
The [image()](#funcdef-image) function allows an author to easily generate a
solid-color image from any color. Its syntax is:

```
image() = image( <color> )
```

The [image()](#funcdef-image) function represents a solid-color image of the
specified color with no [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

For example, one can use this as a
simple way to \"tint\" a background image, by overlaying a
partially-transparent color over the top of the other image:

```
background-image: image(rgba(0, 0, 255, .5)), url("bg-image.png");
```

This is equivalent to a single color stop gradient:

```
background-image: linear-gradient(rgba(0, 0, 255, .5)), url("bg-image.png");
```

[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) does not work for this, as the
solid color it generates always lies *beneath* all the background
images.

 This function previously defined a number of additional
behaviors, but those have been shifted to
[\[css-images-5\]](#biblio-css-images-5 "CSS Images Module Level 5").

### 2.6. Combining images: the [cross-fade() notation]
When transitioning between images, CSS requires a way to explicitly
refer to the intermediate image that is a combination of the start and
end images. This is accomplished with the
[cross-fade()](#funcdef-cross-fade) function, which indicates the two images to be
combined and how far along in the transition the combination is.

 Authors can also use the
[cross-fade()](#funcdef-cross-fade) function for many simple image manipulations, such as
tinting an image with a solid color or highlighting a particular area of
the page by combining an image with a radial gradient.

The syntax for
[cross-fade()](#funcdef-cross-fade) is defined as:

```
cross-fade() = cross-fade( <cf-image># )
<cf-image> = [ <image> | <color> ] && <percentage [0,100]>?
```

The function represents an image generated by combining one or more
images.

The
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) represents how much of each image is
retained when it is blended with the other images. The
[\<percentage\>] must be between
[0%] and [100%] inclusive; any other value is invalid.

If any percentages are omitted, all the specified percentages are summed
together and subtracted from [100%], the result is floored at
[0%], then divided equally between all images with omitted
percentages at computed-value time.

While this is not reflected in the computed value, when all the
arguments' percentages sum to greater than [100%], the
sizing/painting details effectively rescale them so that they sum to
exactly [100%].

On the other hand, when the sum is less than [100%], the
sizing/painting details effectively act like there's an additional
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) argument, with its percentage set to the
remaining value necessary to make the sum equal [100%].

If a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) is provided, it represents a
solid-color image with "automatic" dimensions (it doesn't participate in
the sizing of the result image at all; see details in the sizing details
below).

Tests

- [cross-fade-basic.html](https://wpt.fyi/results/css/css-images/cross-fade-basic.html "css/css-images/cross-fade-basic.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-basic.html)
- [cross-fade-computed-value.html](https://wpt.fyi/results/css/css-images/cross-fade-computed-value.html "css/css-images/cross-fade-computed-value.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-computed-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-computed-value.html)
- [cross-fade-legacy-crash.html](https://wpt.fyi/results/css/css-images/cross-fade-legacy-crash.html "css/css-images/cross-fade-legacy-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-legacy-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-legacy-crash.html)
- [cross-fade-legacy-2-crash.html](https://wpt.fyi/results/css/css-images/cross-fade-legacy-2-crash.html "css/css-images/cross-fade-legacy-2-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-legacy-2-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-legacy-2-crash.html)
- [cross-fade-natural-size.html](https://wpt.fyi/results/css/css-images/cross-fade-natural-size.html "css/css-images/cross-fade-natural-size.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-natural-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-natural-size.html)
- [cross-fade-premultiplied-alpha.html](https://wpt.fyi/results/css/css-images/cross-fade-premultiplied-alpha.html "css/css-images/cross-fade-premultiplied-alpha.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-premultiplied-alpha.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-premultiplied-alpha.html)
- [cross-fade-target-alpha.html](https://wpt.fyi/results/css/css-images/cross-fade-target-alpha.html "css/css-images/cross-fade-target-alpha.html")
 [[(live
 test)]](http://wpt.live/css/css-images/cross-fade-target-alpha.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/cross-fade-target-alpha.html)

#### 2.6.1. [cross-fade() Sizing]
The dimensions of the image represented by a
[cross-fade()](#funcdef-cross-fade) are a weighted average of dimensions of the
[\<image\>](#typedef-image) arguments to the function; the
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) arguments have no effect. They are
calculated as follows:

To determine the [[natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) of a cross-fade()]:

1. [Normalize mix
 percentages](https://drafts.csswg.org/css-values-5/#normalize-mix-percentages) from the function's arguments, and let
 `args` and `leftover` be the result.

2. If `leftover` is 100%, return no [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

3. Let `images` be an empty list.

4. For each
 [\<cf-image\>](#typedef-cf-image) `argument` of the
 function's arguments:

 1. If `argument` is not an
 [\<image\>](#typedef-image), or is an
 [\<image\>] with no
 natural dimensions,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `item` be a
 [tuple](https://infra.spec.whatwg.org/#tuple) consisting of a width, a height, and a
 percentage.

 3. Run the [object size
 negotiation](https://drafts.csswg.org/css-images-3/#object-size-negotiation) algorithm for the
 [\<image\>](#typedef-image), as appropriate for the context in
 which the
 [cross-fade()](#funcdef-cross-fade) appears, and set `item`'s
 width and height to the width and height of the resulting
 [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size).

 4. Set `item`'s percentage to the
 `argument`'s percentage.

5. If `images` is empty, return no [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

6. Return a [natural
 width](https://drafts.csswg.org/css-images-3/#natural-width) and [natural
 height](https://drafts.csswg.org/css-images-3/#natural-height) that are weighted averages of the width and height
 of each item in `images`, according to their
 corresponding percentages.

 The percentages might sum to a value less than
 100%, so a naive weighted-averaging process might need to normalize
 them first.

#### 2.6.2. [cross-fade() Painting]
The image represented by a
[cross-fade()](#funcdef-cross-fade) is a weighted average of the input arguments to the
function, calculated as follows:

To determine the [appearance of a
cross-fade()]:

1. [Normalize mix
 percentages](https://drafts.csswg.org/css-values-5/#normalize-mix-percentages) from the function's arguments, and let
 `args` and `leftover` be the result.

2. Let `images` be an empty list.

3. Let `size` be a
 [tuple](https://infra.spec.whatwg.org/#tuple) of width and height, initialized to the result of
 finding the [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) of the
 [cross-fade()](#funcdef-cross-fade) function (using the [natural dimensions of a
 cross-fade()](#natural-dimensions-of-a-cross-fade)).

4. For each `argument` of the
 [cross-fade()](#funcdef-cross-fade) function:

 1. Let `item` be a
 [tuple](https://infra.spec.whatwg.org/#tuple) consisting of an image and a percentage.

 2. If `argument` has an
 [\<image\>](#typedef-image), rescale it to `size`'s
 width and height and set `item`'s image to the
 result. Otherwise, `argument` has a
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color); set `item`'s
 image to a solid-color image of the
 [\<color\>], with
 `size`'s dimensions.

 3. Set `item`'s percentage to the
 `argument`'s percentage.

5. If `leftover` is greater than [0%], append a
 [tuple](https://infra.spec.whatwg.org/#tuple) to `images` consisting of a solid-color
 transparent-black image with `size`'s dimensions, and a
 percentage equal to `leftover`.

6. Let `final image` be an image with `size`'s
 dimensions, and every pixel being the weighted linear average of the
 corresponding pixels of
 [each](https://infra.spec.whatwg.org/#list-iterate) `item`'s image in `images`,
 weighted according to the `item`'s percentage. (Average
 both the color channels and the alpha channel of the pixels.) For
 the purpose of this calculation, each pixel's color must be in
 pre-multiplied sRGB.

 Details on the above operation

 This is applying an N-way Porter-Duff `dissolve`
 operation to the source images. Wikipedia defines
 `dissolve` as a stochastic operation, with the result
 pixels independently randomly chosen from the source images'
 corresponding pixels according to their source images' weights, but
 as pixels shrink to infinitely small, this converges to doing
 color-averaging in pre-multiplied color space.

 In particular, this means that \`cross-fade(white 50%, transparent
 50%)\` will produce a partially-transparent solid white image.
 (Rather than a partially-transparent gray, which is what you'd get
 if you averaged the opaque white and transparent black pixels in
 non-premultiplied space.)

 As converting to pre-multiplied does entail some loss of precision,
 and graphics libraries may or may not support this operation
 natively, as per usual any method can be used so long as it achieves
 the specified effect.

 For example, one can instead rebalance the percentages according to
 the alphas of each pixel, then do the color-channel averages in
 non-premultiplied space. E.g., to render [cross-fade(rgb(255 0 0
 / 1) 40%, rgb(0 255 0 / .5) 20%, rgb(0 0 255 / 0) 40%)],
 rebalancing the percentages according to the 1 / .5 / 0 alphas would
 produce 40% / 10% / 0% (which renormalizes to 80% / 20% / 0%), at
 which point you can average the raw color channel values and end up
 with an [rgb(204 51 0 / .5)] image. (Note that the alpha
 channel is still averaged using the original percentages, not the
 rebalanced ones.)

7. Return `final image`.

#### 2.6.3. Simplifying Complex [cross-fade()]
Per WG resolution, define a notion of
\"equality\" for images, and combine \"same\" images at computed-value
time, summing their percentages.

Per WG resolution, simplify
directly-nested
[cross-fade()](#funcdef-cross-fade) at computed-value time by just distributing the
percentage and flattening; [cross-fade(A 10%, cross-fade(B 30%, C 70%)
90%)] becomes [cross-fade(A 10%, B 27%, C 63%)].

### 2.7. Using Elements as Images: the [element() notation]
The [element()](#funcdef-element) function allows an author to use an element in the
document as an image. As the referenced element changes appearance, the
image changes as well. This can be used, for example, to create live
previews of the next/previous slide in a slideshow, or to reference a
canvas element for a fancy generated gradient or even an animated
background.

 The
[element()](#funcdef-element) function only reproduces the *appearance* of the
referenced element, not the actual content and its structure. Authors
should only use this for decorative purposes, and must not use
[element()] to reproduce an element with
significant content across the page. Instead, just insert multiple
copies of the element into the document.

The syntax for [element()](#funcdef-element) is:

```
element() = element( <id-selector> )
```

where
[\<id-selector\>](https://drafts.csswg.org/selectors-4/#typedef-id-selector) is an ID selector
[\[SELECT\]](#biblio-select "Selectors Level 3").

Do we need to be able to refer to
elements in external documents (such as SVG paint servers)? Or is it
enough to just use url() for this?

This name conflicts with a somewhat
similar function in GCPM. This needs to be resolved somehow.

Want the ability to do \"reflections\"
of an element, either as a background-image on the element or in a
pseudo-element. This needs to be specially-handled to avoid triggering
the cycle-detection.

When we have overflow:paged, how can we
address a single page in the view?

The [element()](#funcdef-element) function references the element matched by its
argument. The ID is first looked up in the
[elementSources](#dom-css-elementsources) map, as described in that section. If it's not found,
it's then matched against the document. If multiple elements are
matched, the function references the first such element.

The image represented by the
[element()](#funcdef-element) function can vary based on whether the element is
visible in the document:

an [element that is rendered](#element-not-rendered), is not a descendant of a replaced element, and generates a [stacking context](https://drafts.csswg.org/css2/#stacking-context)

: The function represents an image with its [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size) equal to the [decorated bounding
 box] of the referenced element:

 - for an element rendered using a CSS rendering model, the
 [decorated bounding
 box](#decorated-bounding-box) is the smallest axis-aligned rectangle that
 contains the [border image
 areas](https://www.w3.org/TR/2011/CR-css3-background-20110215/#border-image-area)
 of all the fragments of the principal box
 - for an element rendered using the SVG rendering model, [the
 decorated bounding box is defined by
 SVG](https://www.w3.org/TR/SVGTiny12/intro.html#TermDecoratedBoundingBox)

 Because images clip anything outside their bounds
 by default, this means that decorations that extend outside the
 [decorated bounding
 box](#decorated-bounding-box), like box shadows, may be clipped.

 The image is constructed by rendering the referenced element and its
 descendants (at the same size that they would be in the document)
 over an infinite
 [transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) canvas, positioned so that the edges of the
 [decorated bounding
 box](#decorated-bounding-box) are flush with the edges of the image.

 (#issue-ed057ccb) Requiring some degree of stacking
 context on the element appears to be required for an efficient
 implementation. Do we need a full stacking context, or just a
 pseudo-stacking context? Should it need to be a stacking context
 normally, or can we just render it as a stacking context when
 rendering it to element()?

 If the referenced element has a transform applied to it or an
 ancestor, the transform must be ignored when rendering the element
 as an image.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 If the referenced element is broken across pages, the element is
 displayed as if the page content areas were joined flush in the
 pagination direction, with pages\' edges corresponding to the
 initial containing block's start edge aligned. [Elements broken
 across lines or columns are just rendered with their [decorated
 bounding
 box](#decorated-bounding-box).]

 Implementations may either re-use existing bitmap data generated for
 the referenced element or regenerate the display of the element to
 maximize quality at the image's size (for example, if the
 implementation detects that the referenced element is an SVG
 fragment); in the latter case, the layout of the referenced element
 in the image must not be changed by the regeneration process. That
 is, the image must look identical to the referenced element, modulo
 rasterization quality.

 :::
 (#ex-element-reuse)
 As a somewhat silly example, a
 [`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element can be reused as a background elsewhere
 in the document:

 ```
 <style>
 #src { color: white; background: lime; width: 300px; height: 40px; position: relative; }
 #dst { color: black; background: element(#src); padding: 20px; margin: 20px 0; }
 </style>
 <p id='src'>I'm an ordinary element!</p>
 <p id='dst'>I'm using the previous element as my background!</p>
 ```

 !(images/element-function.png){height="133" width="554"}
 :::

an [element that is not rendered](#element-not-rendered), but which provides a [paint source](#paint-source)
: The function represents an image with the [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) and appearance of the [paint
 source](#paint-source). The
 host language defines the size and appearance of paint sources.
 :::
 (#ex-element-not-rendered-ref) For example, the
 [element()](#funcdef-element) function can reference an SVG
 `<pattern>` element in an HTML document:
 ```
 <!DOCTYPE html>
 <svg>
 <defs>
 <pattern id='pattern1'>
 <path d='...'>
 </pattern>
 </defs>
 </svg>
 <p style="background: element(#pattern1)">
 I'm using the pattern as a background!
 If the pattern is changed or animated,
 my background will be updated too!
 </p>
 ```

 HTML also defines that a handful of elements, such as
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas),
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element), and
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video), provide a paint source. This means that CSS
 can, for example, reference a canvas that's being drawn into, but
 not displayed in the page:

 ```
 <!DOCTYPE html>
 <script>
 var canvas = document.querySelector('#animated-bullet');
 canvas.width = 20; canvas.height = 20;
 drawAnimation(canvas);
 </script>
 <canvas id='animated-bullet' style='display:none'></canvas>
 <ul style="list-style-image: element(#animated-bullet);">
 <li>I'm using the canvas as a bullet!</li>
 <li>So am I!</li>
 <li>As the canvas is changed over time with Javascript,
 we'll all update our bullet image with it!</li>
 </ul>
 ```
 :::

anything else

: The function represents an [invalid
 image](#invalid-image).

 :::
 (#ex-invalid-image)
 For example, all of the following
 [element()](#funcdef-element) uses will result in a transparent background:

 ```
 <!DOCTYPE html>
 <p id='one' style="display:none; position: relative;">one</p>
 <iframe src="http://example.com">
 <p id='two' style="position: relative;">I'm fallback content!</p>
 </iframe>
 <ul>
 <li style="background: element(#one);">
 A display:none element isn't rendered, and a P element
 doesn't provide a paint source.
 </li>
 <li style="background: element(#two);">
 The descendants of a replaced element like an IFRAME
 can't be used in element() either.
 </li>
 <li style="background: element(#three);">
 There's no element with an id of "three", so this also
 gets rendered as a transparent image.
 </li>
 </ul>
 ```
 :::

An element is [not rendered] if it does not have
an associated box. This can happen, for example, if the element or an
ancestor is [display:none]. Host languages may define additional
ways in which an element can be considered not rendered; for example, in
SVG, any descendant of a `<defs>` element is considered to
be not rendered.

The [element()](#funcdef-element) function can be put to many uses. For example, it can
be used to show a preview of the previous or next slide in a slideshow:

```
<!DOCTYPE html>
<script>
function navigateSlides() {
 var currentSlide = ...;
 document.querySelector('#prev-slide').id = '';
 document.querySelector('#next-slide').id = '';
 currentSlide.previousElementSibling.id = 'prev-slide';
 currentSlide.nextElementSibling.id = 'next-slide';
}
</script>
<style>
.slide {
 /* Need to be a stacking context to be element()-able. */
 position: relative;
}
#prev-preview, #next-preview {
 position: fixed;
 ...
}
#prev-preview { background: element(#prev-slide); }
#next-preview { background: element(#next-slide); }
</style>
<a id='prev-preview'>Previous Slide</a>
<a id='next-preview'>Next Slide</a>
<section class='slide'>...</section>
<section class='slide current-slide'>...</section>
...
```

In this example, the `navigateSlides` function updates the
ids of the next and previous slides, which are then displayed in small
floating boxes alongside the slides. Since you can't interact with the
slides through the
[element()](#funcdef-element) function (it's just an image), you could even use
`click` handlers on the preview boxes to help navigate
through the page.

#### 2.7.1. Paint Sources

Host languages may define that some elements provide a [paint
source]. Paint
sources have an intrinsic appearance and can obtain a [concrete object
size](https://drafts.csswg.org/css-images-3/#concrete-object-size) without having to do layout or rendering, and so may be
used as images even when they're [not
rendered](#element-not-rendered).

In HTML, the
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element),
[`video`](https://html.spec.whatwg.org/multipage/media.html#video), and
[`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) elements provide paint sources.

In SVG, any element that provides a [paint
server](https://www.w3.org/TR/SVG/pservers.html) provides a paint
source. [Note: In SVG1.1, the `<linearGradient>`,
`<radialGradient>`, and `<pattern>` elements
provide paint sources.] They are drawn as described in the spec,
with the coordinate systems defined as follows:

objectBoundingBox
: The coordinate system has its origin at the top left corner of the
 rectangle defined by the [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) that it's being drawn into, and the same width and
 height as the [concrete object
 size]. A single [user
 coordinate](https://www.w3.org/TR/SVG/coords.html#Units) is the
 width and height of the [concrete object
 size].

userSpaceOnUse
: The coordinate system has its origin at the top left corner of the
 rectangle defined by the [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) that it's being drawn into, and the same width and
 height as the [concrete object
 size]. [User
 coordinates](https://www.w3.org/TR/SVG/coords.html#Units) are sized
 equivalently to the CSS
 [px](https://drafts.csswg.org/css-values-4/#px) unit.

 It is expected that a future version of this module
will define ways to refer to paint sources in external documents, or
ones that are created solely by script and never inserted into a
document at all.

#### 2.7.2. Using Out-Of-Document Sources: the `ElementSources` interface

The [element()](#funcdef-element) function normally selects elements within a document,
but elements that provide a [paint
source](#paint-source) don't
necessarily need to be in-document. For example, an HTML
[`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element can be created, maintained, and drawn into
entirely in script, with no need for it to be inserted into the document
directly.

All that's needed is a way to refer to the element, as an ID selector
cannot select elements outside of the document. The
[elementSources](#dom-css-elementsources) Map object provides this.

```
partial namespace CSS {
 [SameObject] readonly attribute any elementSources;
};
```

Tests

- [idlharness.html](https://wpt.fyi/results/css/css-images/idlharness.html "css/css-images/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-images/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/idlharness.html)

Any entries in the
[elementSources](#dom-css-elementsources) map with a string key and a value that is an object
providing a [paint source](#paint-source) are made available to the
[element()](#funcdef-element) function.

Whenever [element()](#funcdef-element) uses an
[\<id-selector\>](https://drafts.csswg.org/selectors-4/#typedef-id-selector), the ID's value (without the leading
`#` character) is first looked up in the
[elementSources](#dom-css-elementsources) map:

- If it's found, and the object associated with it provides a [paint
 source](#paint-source), the
 [element()](#funcdef-element) function represents that paint source.
- If it's found, but the object associated with it *doesn't* provide a
 [paint source](#paint-source),
 the [element()](#funcdef-element) function represent an [invalid
 image](#invalid-image).
- If the ID isn't found in the map at all, it's then looked for in the
 document as normal.

This reuse of the ID selector matches
Moz behavior. I'm trying to avoid slapping a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) right in the beginning of the
grammar, as that eats too much syntax-space. Another possibility,
though, is to start the value with a language-defined keyword *followed
by* a [\<custom-ident\>], like
[element(external fancy)] or something. Naming suggestions
welcome.

For example, fancy animating
backgrounds can be done with an external canvas:

```
<script>
var bg = document.createElement('canvas');
bg.height = 200;
bg.width = 1000;
drawFancyBackground(bg);
CSS.elementSources.set('fancy', bg);
</script>
<style>
h1 {
 background-image: element(#fancy);
}
</style>
```

As the \"fancy\" canvas is drawn into and animated, the backgrounds of
all the H1 elements will automatically update in tandem.

Note that the
[elementSources](#dom-css-elementsources) map is consulted *before* the document to match the ID
selector, so even if there's an element in the document that would match
[#fancy], the backgrounds will still predictably come from the
[elementSources] value instead.

#### 2.7.3. Cycle Detection

The [element()](#funcdef-element) function can produce nonsensical circular
relationships, such as an element using itself as its own background.
These relationships can be easily and reliably detected and resolved,
however, by keeping track of a dependency graph and using common
cycle-detection algorithms.

The dependency graph consists of edges such that:

- every element depends on its children
- for any element A with a property using the
 [element()](#funcdef-element) function pointing to an element B, A depends on B
- if a host language defines a way for elements to refer to the
 rendering of other elements, the referencing element depends on the
 referenced element. For example, in SVG, a `<use>` element
 depends on the element it referenced.

If the graph contains a cycle, any
[element()](#funcdef-element) functions participating in the cycle are [invalid
images](#invalid-image).

## 3. Gradients

A gradient is an image that smoothly fades from one color to another.
These are commonly used for subtle shading in background images,
buttons, and many other things. The [gradient
functions] described in this section allow an author to
specify such an image in a terse syntax, so that the UA can generate the
image automatically when rendering the page. The syntax of a
[\<gradient\>](#typedef-gradient) is:

```
<gradient> = [
 <linear-gradient()> | <repeating-linear-gradient()> |
 <radial-gradient()> | <repeating-radial-gradient()> |
 <conic-gradient()> | <repeating-conic-gradient()> ]
```

As with the other [\<image\>](#typedef-image) types defined in this specification,
gradients can be used in any property that accepts images. For example:

- `background: linear-gradient(white, gray);`
- `list-style-image: radial-gradient(circle, #006, #00a 90%, #0000af 100%, white 100%)`

A gradient is drawn into a box with the dimensions of the [concrete
object
size](https://drafts.csswg.org/css-images-3/#concrete-object-size), referred to as the [gradient box]. However, the gradient itself has
no [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

Tests

- [gradients-with-border.html](https://wpt.fyi/results/css/css-images/gradients-with-border.html "css/css-images/gradients-with-border.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradients-with-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradients-with-border.html)

For example, if you use a
gradient as a background, by default the gradient will draw into a
[gradient box](#gradient-box) the
size of the element's padding box. If
[background-size](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-size) is explicitly set to a value such
as [100px 200px], then the [gradient box]
will be 100px wide and 200px tall. Similarly, for a gradient used as a
[list-style-image](https://drafts.csswg.org/css-lists-3/#propdef-list-style-image), the box would be a 1em square,
which is the [default object
size](https://drafts.csswg.org/css-images-3/#default-object-size) for that property.

Gradients are specified by defining the [starting point] and [ending
point] of a
[gradient line] (which, depending on the type of gradient, may be technically
a line, or a ray, or a spiral), and then specifying colors at points
along this line. The colors are smoothly blended to fill in the rest of
the line, and then each type of gradient defines how to use the color of
the [gradient line](#gradient-line) to produce the actual gradient.

### [3.1. ][Linear Gradients: the [linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient) notation]
This level adds a
[\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) argument to
[linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient) and
[repeating-linear-gradient()](#funcdef-repeating-linear-gradient), indicating the color space and path to use when
interpolating colors on the gradient line. See [CSS Color 4 §  13. Color
Interpolation](https://drafts.csswg.org/css-color-4/#interpolation).

```
<linear-gradient-syntax> =
 [ [ <angle> | <zero> | to <side-or-corner> ] || <color-interpolation-method> ]? ,
 <color-stop-list>
<side-or-corner> = [left | right] || [top | bottom]
```

Tests

- [color-stop-currentcolor.html](https://wpt.fyi/results/css/css-images/color-stop-currentcolor.html "css/css-images/color-stop-currentcolor.html")
 [[(live
 test)]](http://wpt.live/css/css-images/color-stop-currentcolor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/color-stop-currentcolor.html)
- [gradient-border-box.html](https://wpt.fyi/results/css/css-images/gradient-border-box.html "css/css-images/gradient-border-box.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-border-box.html)
- [gradient-button.html](https://wpt.fyi/results/css/css-images/gradient-button.html "css/css-images/gradient-button.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-button.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-button.html)
- [gradient-content-box.html](https://wpt.fyi/results/css/css-images/gradient-content-box.html "css/css-images/gradient-content-box.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-content-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-content-box.html)
- [linear-gradient-1.html](https://wpt.fyi/results/css/css-images/linear-gradient-1.html "css/css-images/linear-gradient-1.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-1.html)
- [linear-gradient-2.html](https://wpt.fyi/results/css/css-images/linear-gradient-2.html "css/css-images/linear-gradient-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-2.html)
- [linear-gradient-body-sibling-index.html](https://wpt.fyi/results/css/css-images/linear-gradient-body-sibling-index.html "css/css-images/linear-gradient-body-sibling-index.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-body-sibling-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-body-sibling-index.html)
- [linear-gradient-calc-em-units.html](https://wpt.fyi/results/css/css-images/linear-gradient-calc-em-units.html "css/css-images/linear-gradient-calc-em-units.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-calc-em-units.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-calc-em-units.html)
- [linear-gradient-non-square.html](https://wpt.fyi/results/css/css-images/linear-gradient-non-square.html "css/css-images/linear-gradient-non-square.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-non-square.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-non-square.html)
- [linear-gradient-sibling-index.html](https://wpt.fyi/results/css/css-images/linear-gradient-sibling-index.html "css/css-images/linear-gradient-sibling-index.html")
 [[(live
 test)]](http://wpt.live/css/css-images/linear-gradient-sibling-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/linear-gradient-sibling-index.html)
- [multiple-position-color-stop-linear-2.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-linear-2.html "css/css-images/multiple-position-color-stop-linear-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-linear-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-linear-2.html)
- [multiple-position-color-stop-linear.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-linear.html "css/css-images/multiple-position-color-stop-linear.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-linear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-linear.html)
- [normalization-linear-2.html](https://wpt.fyi/results/css/css-images/normalization-linear-2.html "css/css-images/normalization-linear-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-linear-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-linear-2.html)
- [normalization-linear-degenerate.html](https://wpt.fyi/results/css/css-images/normalization-linear-degenerate.html "css/css-images/normalization-linear-degenerate.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-linear-degenerate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-linear-degenerate.html)
- [normalization-linear.html](https://wpt.fyi/results/css/css-images/normalization-linear.html "css/css-images/normalization-linear.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-linear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-linear.html)
- [tiled-gradients.html](https://wpt.fyi/results/css/css-images/tiled-gradients.html "css/css-images/tiled-gradients.html")
 [[(live
 test)]](http://wpt.live/css/css-images/tiled-gradients.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/tiled-gradients.html)
- [color-stops-parsing.html](https://wpt.fyi/results/css/css-images/gradient/color-stops-parsing.html "css/css-images/gradient/color-stops-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-stops-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-stops-parsing.html)
- [display-p3-linear-gradient.html](https://wpt.fyi/results/css/css-images/gradient/display-p3-linear-gradient.html "css/css-images/gradient/display-p3-linear-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/display-p3-linear-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/display-p3-linear-gradient.html)
- [linear-gradient-relative-currentcolor-stop.html](https://wpt.fyi/results/css/css-images/gradient/linear-gradient-relative-currentcolor-stop.html "css/css-images/gradient/linear-gradient-relative-currentcolor-stop.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/linear-gradient-relative-currentcolor-stop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/linear-gradient-relative-currentcolor-stop.html)
- [gradient-single-stop-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-001.html "css/css-images/gradient/gradient-single-stop-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-001.html)
- [gradient-single-stop-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-002.html "css/css-images/gradient/gradient-single-stop-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-002.html)
- [gradient-single-stop-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-003.html "css/css-images/gradient/gradient-single-stop-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-003.html)
- [gradient-single-stop-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-004.html "css/css-images/gradient/gradient-single-stop-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-004.html)
- [gradient-single-stop-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-005.html "css/css-images/gradient/gradient-single-stop-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-005.html)
- [gradient-single-stop-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-006.html "css/css-images/gradient/gradient-single-stop-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-006.html)
- [gradient-single-stop-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-007.html "css/css-images/gradient/gradient-single-stop-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-007.html)
- [gradient-single-stop-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-008.html "css/css-images/gradient/gradient-single-stop-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-008.html)
- [gradient-single-stop-longer-hue-hsl-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html "css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html)
- [gradient-single-stop-longer-hue-hsl.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html "css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html)
- [gradient-single-stop-longer-hue-oklch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html "css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html)
- [gradient-single-stop-none-interpolation.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-none-interpolation.html "css/css-images/gradient/gradient-single-stop-none-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-none-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-none-interpolation.html)
- [gradient-interpolation-method-computed.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-computed.html "css/css-images/parsing/gradient-interpolation-method-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-computed.html)
- [gradient-interpolation-method-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-invalid.html "css/css-images/parsing/gradient-interpolation-method-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-invalid.html)
- [gradient-interpolation-method-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-valid.html "css/css-images/parsing/gradient-interpolation-method-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-valid.html)
- [gradient-position-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-invalid.html "css/css-images/parsing/gradient-position-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-invalid.html)
- [gradient-position-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-valid.html "css/css-images/parsing/gradient-position-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-valid.html)
- [gradient-position-computed.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-computed.html "css/css-images/parsing/gradient-position-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-computed.html)

#### 3.1.1. Effects of color space on interpolation: examples

*This section is non-normative.*

The effect of colorspace on interpolation can be significant.

In this example, a linear
gradient between the same pair of colors #f01 and #081 is drawn in three
different colorspaces. The middle gradient uses gamma-encoded sRGB,
which was the only choice in CSS Images 3; the result is clearly too
dark at the midpoint. The upper gradient uses CIE Lab, giving a more
perceptually uniform result; while the lower gradient uses Oklab, which
here gives almost the same result as CIE Lab.

- `linear-gradient(in lab to right, #F01, #081)`
- `linear-gradient(in srgb to right, #F01, #081)`
- `linear-gradient(in Oklab to right, #F01, #081)`

![red to green gradient in three
colorspaces](images/rectangular-f01-081.png){height="330" width="360"}

In this example, a linear
gradient between the same pair of colors white and #01E is drawn in
three different colorspaces. The middle gradient uses gamma-encoded
sRGB, the result is again too dark at the midpoint, is a little
desaturated, and has a slight purplish cast. The upper gradient uses CIE
Lab, which avoids the too-dark midpoint but has a significant purple
cast; while the lower gradient uses Oklab, giving a more perceptually
uniform result with no purple cast at all.

- `linear-gradient(in lab to right, white, #01E)`
- `linear-gradient(in srgb to right, white, #01E)`
- `linear-gradient(in Oklab to right, white, #01E)`

![white to blue gradient in three
colorspaces](images/rectangular-fff-01e.png){height="330" width="360"}

In this example, a linear gradient
between the same pair of colors #44C and #795 is drawn in three
different colorspaces. This demonstrates that the hue non-linearity of
CIE Lab affects all bulueish colors, not just the gradient from
saturated primary blue to white. The middle gradient uses gamma-encoded
sRGB, the result is again too dark at the midpoint, and has a slight
purplish cast. The upper gradient uses CIE Lab, which avoids the
too-dark midpoint but has a significant purple cast; while the lower
gradient uses Oklab, again giving a more perceptually uniform result
with no purple cast at all.

- `linear-gradient(in lab to right, #44C, #795)`
- `linear-gradient(in srgb to right, #44C, #795)`
- `linear-gradient(in Oklab to right, #44C, #795)`

![blue to green gradient in three
colorspaces](images/rectangular-44c-795.png){height="330" width="360"}

Choosing a polar, rather than rectangular, colorspace for gradient
interpolation avoids desaturation if the hues of the color stops are far
apart. Interpolating in a polar colorspaces is inherently
chroma-preserving, although it is easy for the intermediate colors to
fall out of gamut; they will then be gamut mapped to bring them back
into gamut.

In this example, a
linear gradient between the same pair of colors #A37 and #595 is drawn
in five different colorspaces, two of them polar. From top to bottom:
CIE LCH, CIE Lab, sRGB, Oklab, Oklch.

The rectangular spaces have a greyish midpoint, while the intermediate
colors in the polar spaces follow a curved, chroma-preserving path.

- `linear-gradient(in lch to right, #A37, #595)`
- `linear-gradient(in lab to right, #A37, #595)`
- `linear-gradient(in srgb to right, #A37, #595)`
- `linear-gradient(in Oklab to right, #A37, #595)`
- `linear-gradient(in oklch to right, #A37, #595)`

![blue to green gradient in three
colorspaces](images/polar-a37-595.png){height="538" width="360"}

### [3.2. ][Radial Gradients: the [radial-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-radial-gradient) notation]
#### [3.2.1. ][ Adding [\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method)]
This level adds a
[\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) argument to
[radial-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-radial-gradient) and
[repeating-radial-gradient()](#funcdef-repeating-radial-gradient), indicating the color space and path to use when
interpolating colors on the gradient line. See [CSS Color 4 §  13. Color
Interpolation](https://drafts.csswg.org/css-color-4/#interpolation).

```
<radial-gradient-syntax> =
 [ [ [ <radial-shape> || <radial-size> ]? [ at <position> ]? ] || <color-interpolation-method>]? ,
 <color-stop-list>
```

Tests

- [empty-radial-gradient-crash.html](https://wpt.fyi/results/css/css-images/empty-radial-gradient-crash.html "css/css-images/empty-radial-gradient-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/empty-radial-gradient-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/empty-radial-gradient-crash.html)
- [infinite-radial-gradient-refcrash.html](https://wpt.fyi/results/css/css-images/infinite-radial-gradient-refcrash.html "css/css-images/infinite-radial-gradient-refcrash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/infinite-radial-gradient-refcrash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/infinite-radial-gradient-refcrash.html)
- [multiple-position-color-stop-radial-2.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-radial-2.html "css/css-images/multiple-position-color-stop-radial-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-radial-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-radial-2.html)
- [multiple-position-color-stop-radial.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-radial.html "css/css-images/multiple-position-color-stop-radial.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-radial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-radial.html)
- [normalization-radial-2.html](https://wpt.fyi/results/css/css-images/normalization-radial-2.html "css/css-images/normalization-radial-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-radial-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-radial-2.html)
- [normalization-radial-3.html](https://wpt.fyi/results/css/css-images/normalization-radial-3.html "css/css-images/normalization-radial-3.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-radial-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-radial-3.html)
- [normalization-radial-4.html](https://wpt.fyi/results/css/css-images/normalization-radial-4.html "css/css-images/normalization-radial-4.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-radial-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-radial-4.html)
- [normalization-radial-degenerate.html](https://wpt.fyi/results/css/css-images/normalization-radial-degenerate.html "css/css-images/normalization-radial-degenerate.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-radial-degenerate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-radial-degenerate.html)
- [normalization-radial.html](https://wpt.fyi/results/css/css-images/normalization-radial.html "css/css-images/normalization-radial.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-radial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-radial.html)
- [radial-gradient-container-relative-units-001.html](https://wpt.fyi/results/css/css-images/radial-gradient-container-relative-units-001.html "css/css-images/radial-gradient-container-relative-units-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/radial-gradient-container-relative-units-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/radial-gradient-container-relative-units-001.html)
- [radial-gradient-container-relative-units-002.html](https://wpt.fyi/results/css/css-images/radial-gradient-container-relative-units-002.html "css/css-images/radial-gradient-container-relative-units-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/radial-gradient-container-relative-units-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/radial-gradient-container-relative-units-002.html)
- [radial-gradient-container-relative-units-003.html](https://wpt.fyi/results/css/css-images/radial-gradient-container-relative-units-003.html "css/css-images/radial-gradient-container-relative-units-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/radial-gradient-container-relative-units-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/radial-gradient-container-relative-units-003.html)
- [radial-gradient-container-relative-units-004.html](https://wpt.fyi/results/css/css-images/radial-gradient-container-relative-units-004.html "css/css-images/radial-gradient-container-relative-units-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/radial-gradient-container-relative-units-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/radial-gradient-container-relative-units-004.html)
- [radial-gradient-transition-hint-crash.html](https://wpt.fyi/results/css/css-images/radial-gradient-transition-hint-crash.html "css/css-images/radial-gradient-transition-hint-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/radial-gradient-transition-hint-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/radial-gradient-transition-hint-crash.html)
- [tiled-radial-gradients.html](https://wpt.fyi/results/css/css-images/tiled-radial-gradients.html "css/css-images/tiled-radial-gradients.html")
 [[(live
 test)]](http://wpt.live/css/css-images/tiled-radial-gradients.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/tiled-radial-gradients.html)
- [color-stops-parsing.html](https://wpt.fyi/results/css/css-images/gradient/color-stops-parsing.html "css/css-images/gradient/color-stops-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-stops-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-stops-parsing.html)
- [gradient-interpolation-method-computed.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-computed.html "css/css-images/parsing/gradient-interpolation-method-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-computed.html)
- [gradient-interpolation-method-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-invalid.html "css/css-images/parsing/gradient-interpolation-method-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-invalid.html)
- [gradient-interpolation-method-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-valid.html "css/css-images/parsing/gradient-interpolation-method-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-valid.html)
- [gradient-position-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-invalid.html "css/css-images/parsing/gradient-position-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-invalid.html)
- [gradient-position-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-valid.html "css/css-images/parsing/gradient-position-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-valid.html)

In this example, a radial
gradient between the same pair of colors color(display-p3 0.918 0.2
0.161) and #081 is drawn in three different colorspaces. Notice that the
color stops do not all need to be in the same colorspace. The middle
gradient uses gamma-encoded sRGB, the result is clearly too dark at the
midpoint. The upper gradient uses CIE Lab, giving a more perceptually
uniform result; while the lower gradient uses Oklab, which here gives
almost the same result as CIE Lab.

- `radial-gradient(in lab farthest-side at left bottom, color(display-p3 0.918 0.2 0.161), #081)`
- `radial-gradient(in srgb farthest-side at left bottom, color(display-p3 0.918 0.2 0.161), #081)`
- `radial-gradient(in Oklab farthest-side at left bottom, color(display-p3 0.918 0.2 0.161), #081)`

![red to green gradient in three
colorspaces](images/radial-rectangular-f01-081.png){height="330"
width="360"}

#### [3.2.2. ][ Expanding [\<radial-size\>](https://drafts.csswg.org/css-images-3/#typedef-radial-size)]
This level extends the
[\<radial-size\>](https://drafts.csswg.org/css-images-3/#typedef-radial-size) options to include the additions from
the
[circle()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-circle) and
[ellipse()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-ellipse)
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) values:

```
<radial-size> = <radial-extent>{1,2} | <length-percentage [0,∞]>{1,2}
```

Two-component values remain invalid when specifying [circle] as
the
[\<radial-shape\>](https://drafts.csswg.org/css-images-3/#typedef-radial-shape), and otherwise indicate the
horizontal (first) and vertical (second) radii of the ellipse.

For [circle], a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value is resolved against the "scaled
diagonal" of the [gradient box](#gradient-box)'s width and height:
`sqrt(width² + height²)/sqrt(2)`.

### 3.3. Conic Gradients: the [conic-gradient() notation]
A conic gradient starts by specifying the center of a circle, similar to
radial gradients, except that conic gradient color-stops are placed
*around* the circumference of the circle, rather than on a line emerging
from the center, causing the color to smoothly transition as you spin
around the center, rather than as you progress outward from the center.

A conic gradient is specified by indicating a rotation angle, the center
of the gradient, and then specifying a list of color-stops. Unlike
linear and radial gradients, whose color-stops are placed by specifying
a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value), the color-stops of a conic gradient
are specified with an
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value). Rays are then drawn emerging from
the center and pointing in all directions, with the color of each ray
equal to the color of the gradient-line where they intersect it.

 These gradients are called \"conic\" or \"conical\"
because, if the color stops are chosen to be significantly lighter on
one side than the other, it produces a pattern that looks like a cone
observed from above. They are also known as \"angle\" gradients in some
contexts, since they are produced by varying the rotation angle of a
ray.

::: {style="overflow: hidden"}
![\[An image showing a box with a background shading gradually clockwise
from white to black, starting from the top. A gradient circle is shown,
and the colors at 0 and 216 degrees
respectively.\]](images/conic-diagram.png){height="300"
style="float: right; margin-left: 1em;" width="400"}

This example visually illustrates how [conic-gradient(at 25% 30%, white,
black 60%)] would be drawn. Note that since color stop positions
always resolve to angles, the only effect of the [at 25% 30%] is a
2D translation of the gradient, i.e. it does not affect how the gradient
is drawn.

#### 3.3.1. [conic-gradient() Syntax]
The syntax for a conic gradient is:

```
conic-gradient() = conic-gradient( [ <conic-gradient-syntax> ] )
<conic-gradient-syntax> =
 [ [ [ from [ <angle> | <zero> ] ]? [ at <position> ]? ] || <color-interpolation-method> ]? ,
 <angular-color-stop-list>
```

The arguments are defined as follows:

[[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) \| [\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value)]
: The entire gradient is rotated by this angle. If omitted, defaults
 to [0deg]. The unit identifier may be omitted if the
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) is zero.

[[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)]
: Determines the [gradient center] of the gradient. The
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) value type (which is also used
 for
 [background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position)) is defined in
 [\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3"),
 and is resolved using the center-point as the object area and the
 [gradient box](#gradient-box) as the positioning area. If this argument is
 omitted, it defaults to
 [center](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-position-center).

Usually in conic gradients the sharp
transition at 0deg is undesirable, which is typically avoided by making
sure the first and last color stops are the same color. Perhaps it would
be useful to have a keyword for automatically achieving this.

Would a radius (inner & outer) for
clipping the gradient be useful? If so, we could also support lengths in
color stop positions, since we now have a specific radius.

Are elliptical conic gradients useful?
Do graphics libraries support them?

Tests

- [conic-gradient-001.html](https://wpt.fyi/results/css/css-images/gradient/conic-gradient-001.html "css/css-images/gradient/conic-gradient-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/conic-gradient-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/conic-gradient-001.html)
- [conic-gradient-angle-negative.html](https://wpt.fyi/results/css/css-images/conic-gradient-angle-negative.html "css/css-images/conic-gradient-angle-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-images/conic-gradient-angle-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/conic-gradient-angle-negative.html)
- [conic-gradient-angle.html](https://wpt.fyi/results/css/css-images/conic-gradient-angle.html "css/css-images/conic-gradient-angle.html")
 [[(live
 test)]](http://wpt.live/css/css-images/conic-gradient-angle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/conic-gradient-angle.html)
- [conic-gradient-center.html](https://wpt.fyi/results/css/css-images/conic-gradient-center.html "css/css-images/conic-gradient-center.html")
 [[(live
 test)]](http://wpt.live/css/css-images/conic-gradient-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/conic-gradient-center.html)
- [repeating-conic-gradient.html](https://wpt.fyi/results/css/css-images/repeating-conic-gradient.html "css/css-images/repeating-conic-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/repeating-conic-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/repeating-conic-gradient.html)
- [tiled-conic-gradients.html](https://wpt.fyi/results/css/css-images/tiled-conic-gradients.html "css/css-images/tiled-conic-gradients.html")
 [[(live
 test)]](http://wpt.live/css/css-images/tiled-conic-gradients.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/tiled-conic-gradients.html)
- [multiple-position-color-stop-conic-2.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-conic-2.html "css/css-images/multiple-position-color-stop-conic-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-conic-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-conic-2.html)
- [multiple-position-color-stop-conic.html](https://wpt.fyi/results/css/css-images/multiple-position-color-stop-conic.html "css/css-images/multiple-position-color-stop-conic.html")
 [[(live
 test)]](http://wpt.live/css/css-images/multiple-position-color-stop-conic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/multiple-position-color-stop-conic.html)
- [normalization-conic-2.html](https://wpt.fyi/results/css/css-images/normalization-conic-2.html "css/css-images/normalization-conic-2.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-conic-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-conic-2.html)
- [normalization-conic-degenerate.html](https://wpt.fyi/results/css/css-images/normalization-conic-degenerate.html "css/css-images/normalization-conic-degenerate.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-conic-degenerate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-conic-degenerate.html)
- [normalization-conic.html](https://wpt.fyi/results/css/css-images/normalization-conic.html "css/css-images/normalization-conic.html")
 [[(live
 test)]](http://wpt.live/css/css-images/normalization-conic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/normalization-conic.html)
- [out-of-range-color-stop-conic.html](https://wpt.fyi/results/css/css-images/out-of-range-color-stop-conic.html "css/css-images/out-of-range-color-stop-conic.html")
 [[(live
 test)]](http://wpt.live/css/css-images/out-of-range-color-stop-conic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/out-of-range-color-stop-conic.html)
- [tiled-conic-gradients.html](https://wpt.fyi/results/css/css-images/tiled-conic-gradients.html "css/css-images/tiled-conic-gradients.html")
 [[(live
 test)]](http://wpt.live/css/css-images/tiled-conic-gradients.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/tiled-conic-gradients.html)
- [color-stops-parsing.html](https://wpt.fyi/results/css/css-images/gradient/color-stops-parsing.html "css/css-images/gradient/color-stops-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-stops-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-stops-parsing.html)
- [gradient-interpolation-method-computed.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-computed.html "css/css-images/parsing/gradient-interpolation-method-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-computed.html)
- [gradient-interpolation-method-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-invalid.html "css/css-images/parsing/gradient-interpolation-method-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-invalid.html)
- [gradient-interpolation-method-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-valid.html "css/css-images/parsing/gradient-interpolation-method-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-valid.html)
- [gradient-position-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-invalid.html "css/css-images/parsing/gradient-position-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-invalid.html)
- [gradient-position-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-position-valid.html "css/css-images/parsing/gradient-position-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-position-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-position-valid.html)

#### 3.3.2. Placing Color Stops

Color stops are placed on a [gradient
line](#gradient-line) that
curves around the [gradient
center](#conic-gradient-gradient-center) in a circle, with both the 0% and 100% locations at
0deg. Just like linear gradients, 0deg points to the top of the page,
and increasing angles correspond to clockwise movement around the
circle.

 It may be more helpful to think of the gradient line as
forming a spiral, where only the segment from 0deg to 360deg is
rendered. This avoids any confusion about \"overlap\" when you have
angles outside of the rendered region.

A color-stop can be placed at a location before 0% or after 100%; though
these regions are never directly consulted for rendering, color stops
placed there can affect the color of color-stops within the rendered
region through interpolation or repetition (see [repeating
gradients](#repeating-gradients)). For example, [conic-gradient(red
-50%, yellow 150%)] produces a conic gradient that starts with a
reddish-orange color at 0deg (specifically, #f50), and transitions to an
orangish-yellow color at 360deg (specifically, #fa0).

The color of the gradient at any point is determined by first finding
the unique ray anchored at the center of the gradient that passes
through the given point. The point's color is then the color of the
[gradient line](#gradient-line)
at the location where this ray intersects it.

#### 3.3.3. Conic Gradient Examples

All of the following
[conic-gradient()](#funcdef-conic-gradient) examples are presumed to be applied to a box
that is 300px wide and 200px tall, unless otherwise specified.

Below are various ways of specifying
the same basic conic gradient:

```
background: conic-gradient(#f06, gold);
background: conic-gradient(at 50% 50%, #f06, gold);
background: conic-gradient(from 0deg, #f06, gold);
background: conic-gradient(from 0deg at center, #f06, gold);
background: conic-gradient(#f06 0%, gold 100%);
background: conic-gradient(#f06 0deg, gold 1turn);
```

!(images/conic1.png){height="200" width="300"}

Below are various ways of specifying
the same basic conic gradient. This demonstrates how even though color
stops with angles outside \[0deg, 360deg) are not directly painted, they
can still affect the color of the painted part of the gradient.

```
background: conic-gradient(white -50%, black 150%);
background: conic-gradient(white -180deg, black 540deg);
background: conic-gradient(hsl(0,0%,75%), hsl(0,0%,25%));
```

!(images/conic2.png){height="200" width="300"}

Below are two different ways of
specifying the same rotated conic gradient, one with a rotation angle
and one without:

```
background: conic-gradient(from 45deg, white, black, white);
background: conic-gradient(hsl(0,0%,75%), white 45deg, black 225deg, hsl(0,0%,75%));
```

!(images/conic3.png){height="200" width="300"}

Note that offsetting every color stop by the rotation angle instead
would not work and produces an entirely different gradient:

``` highlight
background: conic-gradient(white 45deg, black 225deg, white 405deg);
```

!(images/conic4.png){height="200" width="300"}

A conic gradient with a radial gradient
overlaid on it, to draw a hue & saturation wheel:

```
background: radial-gradient(closest-side, gray, transparent),
 conic-gradient(red, magenta, blue, aqua, lime, yellow, red);
border-radius: 50%;
width: 200px; height: 200px;
```

You can also achieve the same effect using \"longer\" hue interpolation.
This is more concise and makes it easy to switch to other color spaces.

```
background: radial-gradient(closest-side, gray, transparent),
 conic-gradient(in hsl longer hue, red 0 100%);
transform: scaleX(-1);
border-radius: 50%;
width: 200px; height: 200px;
```

![color wheel](images/conic5.png){height="200" width="200"}

A conic gradient used to draw a simple pie
chart. The [0deg] color stop positions will be fixed up to be
equal to the position of the color stop before them. This will produce
infinitesimal (invisible) transitions between the color stops with
different colors, effectively producing solid color segments.

```
background: conic-gradient(yellowgreen 40%, gold 0deg 75%, #f06 0deg);
border-radius: 50%;
width: 200px; height: 200px;
```

!(images/conic6.png){height="202" width="202"}

### 3.4. Repeating Gradients: the [repeating-linear-gradient(), [repeating-radial-gradient()](#funcdef-repeating-radial-gradient), and [repeating-conic-gradient()](#funcdef-repeating-conic-gradient) notations]
In addition to
[linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient),
[radial-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-radial-gradient), and
[conic-gradient()](#funcdef-conic-gradient), this specification defines
[repeating-linear-gradient()],
[repeating-radial-gradient()], and
[repeating-conic-gradient()] values. These notations take
the same values and are interpreted the same as their respective
non-repeating siblings defined previously.

```
<repeating-conic-gradient()> = repeating-conic-gradient( [ <conic-gradient-syntax> ] )
<repeating-linear-gradient()> = repeating-linear-gradient( [ <linear-gradient-syntax> ] )
<repeating-radial-gradient()> = repeating-radial-gradient( [ <radial-gradient-syntax> ] )
```

Tests

- [gradient-content-box.html](https://wpt.fyi/results/css/css-images/gradient-content-box.html "css/css-images/gradient-content-box.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-content-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-content-box.html)
- [color-stops-parsing.html](https://wpt.fyi/results/css/css-images/gradient/color-stops-parsing.html "css/css-images/gradient/color-stops-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-stops-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-stops-parsing.html)
- [repeating-gradient-hsl-and-oklch.html](https://wpt.fyi/results/css/css-images/gradient/repeating-gradient-hsl-and-oklch.html "css/css-images/gradient/repeating-gradient-hsl-and-oklch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/repeating-gradient-hsl-and-oklch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/repeating-gradient-hsl-and-oklch.html)

Basic repeating conic gradient:

``` highlight
background: repeating-conic-gradient(gold, #f06 20deg);
```

!(images/repeating-conic1.png){height="200" width="300"}

Repeating color stops with abrupt
transitions creates a starburst-type background:

```
background: repeating-conic-gradient(
 hsla(0,0%,100%,.2) 0deg 15deg,
 hsla(0,0%,100%,0) 0deg 30deg
 ) #0ac;
```

!(images/repeating-conic2.png){height="200" width="300"}

Here repeating color stops with abrupt
transitions are used to create a checkerboard:

```
background: repeating-conic-gradient(black 0deg 25%, white 0deg 50%);
background-size: 60px 60px;
```

!(images/repeating-conic3.png){height="200" width="300"}

The same checkerboard can be created via non-repeating conic gradients:

```
background: conic-gradient(black 25%, white 0deg 50%, black 0deg 75%, white 0deg);
background-size: 60px 60px;
```

### 3.5. Defining Gradient Color

The colors in gradients are specified using [color stops] (a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) and a corresponding position on the
[gradient line](#gradient-line)) and [color transition hints] (a position between two [color
stops](#color-stop) representing
the halfway point in the color transition) which are placed on the
[gradient line], defining the color at every
point of the line. (Each [gradient
function](#gradient-function) defines the shape and length of the [gradient
line], along with its [starting
point](#starting-point) and
[ending point](#ending-point);
see above.)

Colors throughout the gradient field are then determined by tying them
to specific points along the [gradient
line](#gradient-line) as
specified by the gradient function. UAs may "dither" gradient colors
slightly (randomly alternate individual pixels with nearby colors on the
gradient line) to effect a smoother gradient.

#### 3.5.1. Color Stop Lists

[Color stops](#color-stop) and
[transition
hints](#color-transition-hint) are specified in a [color stop list], which is a list of one or
more [color stops] interleaved with optional
[transition hints]:

```
<color-stop-list> =
 <linear-color-stop> , [ <linear-color-hint>? , <linear-color-stop> ]#?
<linear-color-stop> = <color> <color-stop-length>?
<linear-color-hint> = <length-percentage>
<color-stop-length> = <length-percentage>{1,2}

<angular-color-stop-list> =
 <angular-color-stop> , [ <angular-color-hint>? , <angular-color-stop> ]#?
<angular-color-stop> = <color> <color-stop-angle>?
<angular-color-hint> = <angle-percentage> | <zero>
<color-stop-angle> = [ <angle-percentage> | <zero> ]{1,2}

<color-stop> = <color-stop-length> | <color-stop-angle>
```

Tests

- [color-stops-parsing.html](https://wpt.fyi/results/css/css-images/gradient/color-stops-parsing.html "css/css-images/gradient/color-stops-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-stops-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-stops-parsing.html)
- [gradient-single-stop-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-001.html "css/css-images/gradient/gradient-single-stop-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-001.html)
- [gradient-single-stop-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-002.html "css/css-images/gradient/gradient-single-stop-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-002.html)
- [gradient-single-stop-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-003.html "css/css-images/gradient/gradient-single-stop-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-003.html)
- [gradient-single-stop-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-004.html "css/css-images/gradient/gradient-single-stop-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-004.html)
- [gradient-single-stop-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-005.html "css/css-images/gradient/gradient-single-stop-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-005.html)
- [gradient-single-stop-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-006.html "css/css-images/gradient/gradient-single-stop-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-006.html)
- [gradient-single-stop-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-007.html "css/css-images/gradient/gradient-single-stop-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-007.html)
- [gradient-single-stop-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-008.html "css/css-images/gradient/gradient-single-stop-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-008.html)
- [gradient-single-stop-longer-hue-hsl-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html "css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-hsl-002.html)
- [gradient-single-stop-longer-hue-hsl.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html "css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-hsl.html)
- [gradient-single-stop-longer-hue-oklch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html "css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-longer-hue-oklch.html)
- [gradient-single-stop-none-interpolation.html](https://wpt.fyi/results/css/css-images/gradient/gradient-single-stop-none-interpolation.html "css/css-images/gradient/gradient-single-stop-none-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-single-stop-none-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-single-stop-none-interpolation.html)

Note that
[\<color-stop-list\>](#typedef-color-stop-list) and
[\<angular-color-stop-list\>](#typedef-angular-color-stop-list) are exactly identical in structure,
they just differ on whether they accept
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s or
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)s for specifying the position of the
stops and hints.

Visualized with a railroad diagram, both of them follow this pattern:

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMTIiIHZpZXdib3g9IjAgMCA2NTMuMCAxMTIiIHdpZHRoPSI2NTMuMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKC41IC41KSI+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICA8cGF0aCBkPSJNNTAgMzFoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0xNzIuMCAzMWgwLjAiIC8+CiAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEyMiIgeD0iNTAiIHk9IjIwIiAvPgogICAgICAgIDx0ZXh0IHg9IjExMSIgeT0iMzUiPiZsdDtjb2xvci1zdG9wJmd0OzwvdGV4dD4KICAgICAgIDwvZz4KICAgICAgIDxwYXRoIGQ9Ik0xNzIuMCAzMWgxMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik0xODIuMCAzMWgxMCIgLz4KICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgPHBhdGggZD0iTTE5Mi4wIDMxaDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNMjIwLjUgMzFoMC4wIiAvPgogICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMTkyIiB5PSIyMCIgLz4KICAgICAgICA8dGV4dCB4PSIyMDYuMjUiIHk9IjM1Ij4sPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPHBhdGggZD0iTTIyMC41IDMxaDEwIiAvPgogICAgICAgPHBhdGggZD0iTTIzMC41IDMxaDEwIiAvPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTI0MC41IDMxaDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNjAzLjAgMzFoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0yNDAuNSAzMWgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTI1MC41IDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTU5My4wIDMxaDAuMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNMjUwLjUgMzFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTQ2MS4wIDMxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yNTAuNSAzMWgyMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNzAuNSAzMWgxNzAuNSIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik00NDEuMCAzMWgyMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yNTAuNSAzMWExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTI3MC41IDUxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNDQxLjAgNTFoMC4wIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNMjcwLjUgNTFoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzkyLjUgNTFoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTIyIiB4PSIyNzAuNSIgeT0iNDAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjMzMS41IiB5PSI1NSI+Jmx0O2NvbG9yLWhpbnQmZ3Q7PC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzkyLjUgNTFoMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQwMi41IDUxaDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00MTIuNSA1MWgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00NDEuMCA1MWgwLjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNDEyLjUiIHk9IjQwIiAvPgogICAgICAgICAgICA8dGV4dCB4PSI0MjYuNzUiIHk9IjU1Ij4sPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik00NDEuMCA1MWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQ2MS4wIDMxaDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik00NzEuMCAzMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNTkzLjAgMzFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEyMiIgeD0iNDcxIiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjUzMiIgeT0iMzUiPiZsdDtjb2xvci1zdG9wJmd0OzwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNTkzLjAgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI1MC41IDMxYTEwIDEwIDAgMCAwIC0xMCAxMHYzMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjUwLjUgODFoMTU3LjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MzYuMCA4MWgxNTcuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI0MDcuNSIgeT0iNzAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjQyMS43NSIgeT0iODUiPiw8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik01OTMuMCA4MWExMCAxMCAwIDAgMCAxMCAtMTB2LTMwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNjAzLjAgMzFoMTAiIC8+CiAgICAgICA8cGF0aCBkPSJNIDYxMy4wIDMxIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

A [color stop](#color-stop) with
two positions is equivalent to specifying two [color
stops] with the same color, one for each position.

 Usually, this results in a solid-color \"stripe\"
between the two positions, but using a [longer]
[\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) will instead create a \"rainbow\"
between the two positions.

Percentages are resolved against the length of the [gradient
line](#gradient-line) between
the [starting point](#starting-point) and [ending
point](#ending-point), with 0%
being at the starting point and 100% being at the ending point. Lengths
are measured along the [gradient line] from the
[starting point] in the direction of the
[ending point].

[Color stop](#color-stop) and
[transition
hint](#color-transition-hint) positions are usually placed between the [starting
point](#starting-point) and
[ending point](#ending-point),
but that's not required: the gradient line extends infinitely in both
directions, and positions can be specified anywhere on the [gradient
line](#gradient-line).

When the position of a [color stop](#color-stop) is omitted, it is automatically assigned a position.
The first or last [color stop] in the [color stop
list](#color-stop-list) is
assigned the [gradient line's](#gradient-line) [starting
point](#starting-point) or
[ending point](#ending-point)
(respectively). Otherwise, it's assigned the position halfway between
the two surrounding stops. If multiple stops in a row lack a position,
they space themselves out equally between the surrounding positioned
stops. See [§ 3.5.3 Color Stop "Fixup"](#color-stop-fixup) for details.

#### 3.5.2. Coloring the Gradient Line

At each [color stop](#color-stop)
position, the [gradient line](#gradient-line) is the color of the [color stop].
Before the first [color stop], the [gradient
line] is the color of the first [color
stop], and after the last [color
stop], the [gradient
line] is the color of the last [color
stop]. Between each pair of [color
stops], the [gradient
line's] color is interpolated between the
colors of the two [color stops], with the
interpolation taking place in the specified color space, with missing
components handled as defined in [CSS Color 4 § 13.3 Interpolating with
Missing
Components](https://drafts.csswg.org/css-color-4/#interpolation-missing),
hue interpolation as defined in [CSS Color 4 § 13.5 Hue
Interpolation](https://drafts.csswg.org/css-color-4/#hue-interpolation),
and using premultiplied alpha, as defined in [CSS Color 4 § 13.4
Interpolating with
Alpha](https://drafts.csswg.org/css-color-4/#interpolation-alpha). If no
[\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) is specified in the gradient
function, the color space used for gradient interpolation is the default
interpolation color space, Oklab, as defined in
[\[css-color-4\]](#biblio-css-color-4 "CSS Color Module Level 4").

 The
[\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) only affects the colors *between*
stops. The color before the first and after the last stop is equal to
the first/last stop, *regardless* of the interpolation method.

Tests

- [gradients-with-transparent.html](https://wpt.fyi/results/css/css-images/gradients-with-transparent.html "css/css-images/gradients-with-transparent.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradients-with-transparent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradients-with-transparent.html)
- [gradient-analogous-missing-components-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-analogous-missing-components-001.html "css/css-images/gradient/gradient-analogous-missing-components-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-analogous-missing-components-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-analogous-missing-components-001.html)
- [gradient-analogous-missing-components-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-analogous-missing-components-002.html "css/css-images/gradient/gradient-analogous-missing-components-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-analogous-missing-components-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-analogous-missing-components-002.html)
- [gradient-analogous-missing-components-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-analogous-missing-components-003.html "css/css-images/gradient/gradient-analogous-missing-components-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-analogous-missing-components-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-analogous-missing-components-003.html)
- [gradient-analogous-missing-components-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-analogous-missing-components-004.html "css/css-images/gradient/gradient-analogous-missing-components-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-analogous-missing-components-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-analogous-missing-components-004.html)
- [css-color-4-colors-default-to-oklab-gradient.html](https://wpt.fyi/results/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html "css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html)
- [gradient-decreasing-hue-hsl.html](https://wpt.fyi/results/css/css-images/gradient/gradient-decreasing-hue-hsl.html "css/css-images/gradient/gradient-decreasing-hue-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-decreasing-hue-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-decreasing-hue-hsl.html)
- [gradient-decreasing-hue-lch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-decreasing-hue-lch.html "css/css-images/gradient/gradient-decreasing-hue-lch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-decreasing-hue-lch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-decreasing-hue-lch.html)
- [gradient-eval-predefined-color-spaces.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-predefined-color-spaces.html "css/css-images/gradient/gradient-eval-predefined-color-spaces.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-predefined-color-spaces.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-predefined-color-spaces.html)
- [gradient-eval-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-001.html "css/css-images/gradient/gradient-eval-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-001.html)
- [gradient-eval-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-002.html "css/css-images/gradient/gradient-eval-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-002.html)
- [gradient-eval-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-003.html "css/css-images/gradient/gradient-eval-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-003.html)
- [gradient-eval-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-004.html "css/css-images/gradient/gradient-eval-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-004.html)
- [gradient-eval-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-005.html "css/css-images/gradient/gradient-eval-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-005.html)
- [gradient-eval-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-006.html "css/css-images/gradient/gradient-eval-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-006.html)
- [gradient-eval-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-007.html "css/css-images/gradient/gradient-eval-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-007.html)
- [gradient-eval-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-008.html "css/css-images/gradient/gradient-eval-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-008.html)
- [gradient-eval-009.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-009.html "css/css-images/gradient/gradient-eval-009.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-009.html)
- [gradient-eval-010.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-010.html)
- [gradient-none-interpolation.html](https://wpt.fyi/results/css/css-images/gradient/gradient-none-interpolation.html "css/css-images/gradient/gradient-none-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-none-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-none-interpolation.html)
- [gradient-to-transparent.html](https://wpt.fyi/results/css/css-images/gradient/gradient-to-transparent.html "css/css-images/gradient/gradient-to-transparent.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-to-transparent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-to-transparent.html)
- [legacy-color-gradient.html](https://wpt.fyi/results/css/css-images/gradient/legacy-color-gradient.html "css/css-images/gradient/legacy-color-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/legacy-color-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/legacy-color-gradient.html)
- [oklab-gradient.html](https://wpt.fyi/results/css/css-images/gradient/oklab-gradient.html "css/css-images/gradient/oklab-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/oklab-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/oklab-gradient.html)
- [srgb-gradient.html](https://wpt.fyi/results/css/css-images/gradient/srgb-gradient.html "css/css-images/gradient/srgb-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/srgb-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/srgb-gradient.html)
- [srgb-linear-gradient.html](https://wpt.fyi/results/css/css-images/gradient/srgb-linear-gradient.html "css/css-images/gradient/srgb-linear-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/srgb-linear-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/srgb-linear-gradient.html)
- [xyz-gradient.html](https://wpt.fyi/results/css/css-images/gradient/xyz-gradient.html "css/css-images/gradient/xyz-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/xyz-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/xyz-gradient.html)
- [color-scheme-dependent-color-stops.html](https://wpt.fyi/results/css/css-images/gradient/color-scheme-dependent-color-stops.html "css/css-images/gradient/color-scheme-dependent-color-stops.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/color-scheme-dependent-color-stops.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/color-scheme-dependent-color-stops.html)
- [gradient-hue-direction.html](https://wpt.fyi/results/css/css-images/gradient/gradient-hue-direction.html "css/css-images/gradient/gradient-hue-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-hue-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-hue-direction.html)
- [gradient-increasing-hue-hsl.html](https://wpt.fyi/results/css/css-images/gradient/gradient-increasing-hue-hsl.html "css/css-images/gradient/gradient-increasing-hue-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-increasing-hue-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-increasing-hue-hsl.html)
- [gradient-increasing-hue-lch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-increasing-hue-lch.html "css/css-images/gradient/gradient-increasing-hue-lch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-increasing-hue-lch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-increasing-hue-lch.html)
- [gradient-infinity-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-infinity-001.html "css/css-images/gradient/gradient-infinity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-infinity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-infinity-001.html)
- [gradient-infinity-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-infinity-002.html "css/css-images/gradient/gradient-infinity-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-infinity-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-infinity-002.html)
- [gradient-infinity-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-infinity-003.html "css/css-images/gradient/gradient-infinity-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-infinity-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-infinity-003.html)
- [gradient-longer-hue-hsl-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-001.html "css/css-images/gradient/gradient-longer-hue-hsl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-001.html)
- [gradient-longer-hue-hsl-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-002.html "css/css-images/gradient/gradient-longer-hue-hsl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-002.html)
- [gradient-longer-hue-hsl-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-003.html "css/css-images/gradient/gradient-longer-hue-hsl-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-003.html)
- [gradient-longer-hue-hsl-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-004.html "css/css-images/gradient/gradient-longer-hue-hsl-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-004.html)
- [gradient-longer-hue-hsl-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-005.html "css/css-images/gradient/gradient-longer-hue-hsl-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-005.html)
- [gradient-longer-hue-hsl-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-006.html "css/css-images/gradient/gradient-longer-hue-hsl-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-006.html)
- [gradient-longer-hue-hsl-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-007.html "css/css-images/gradient/gradient-longer-hue-hsl-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-007.html)
- [gradient-longer-hue-hsl-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-008.html "css/css-images/gradient/gradient-longer-hue-hsl-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-008.html)
- [gradient-longer-hue-hsl-009.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-009.html "css/css-images/gradient/gradient-longer-hue-hsl-009.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-009.html)
- [gradient-longer-hue-hsl-010.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-010.html "css/css-images/gradient/gradient-longer-hue-hsl-010.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-010.html)
- [gradient-longer-hue-hsl-011.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-011.html "css/css-images/gradient/gradient-longer-hue-hsl-011.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-011.html)
- [gradient-longer-hue-hsl-012.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-012.html "css/css-images/gradient/gradient-longer-hue-hsl-012.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-012.html)
- [gradient-longer-hue-hsl-013.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-hsl-013.html "css/css-images/gradient/gradient-longer-hue-hsl-013.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-hsl-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-hsl-013.html)
- [gradient-longer-hue-lch-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-001.html "css/css-images/gradient/gradient-longer-hue-lch-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-001.html)
- [gradient-longer-hue-lch-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-002.html "css/css-images/gradient/gradient-longer-hue-lch-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-002.html)
- [gradient-longer-hue-lch-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-003.html "css/css-images/gradient/gradient-longer-hue-lch-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-003.html)
- [gradient-longer-hue-lch-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-004.html "css/css-images/gradient/gradient-longer-hue-lch-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-004.html)
- [gradient-longer-hue-lch-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-005.html "css/css-images/gradient/gradient-longer-hue-lch-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-005.html)
- [gradient-longer-hue-lch-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-006.html "css/css-images/gradient/gradient-longer-hue-lch-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-006.html)
- [gradient-longer-hue-lch-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-007.html "css/css-images/gradient/gradient-longer-hue-lch-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-007.html)
- [gradient-longer-hue-lch-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-008.html "css/css-images/gradient/gradient-longer-hue-lch-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-008.html)
- [gradient-longer-hue-lch-009.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-009.html "css/css-images/gradient/gradient-longer-hue-lch-009.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-009.html)
- [gradient-longer-hue-lch-010.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-010.html "css/css-images/gradient/gradient-longer-hue-lch-010.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-010.html)
- [gradient-longer-hue-lch-011.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-011.html "css/css-images/gradient/gradient-longer-hue-lch-011.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-011.html)
- [gradient-longer-hue-lch-012.html](https://wpt.fyi/results/css/css-images/gradient/gradient-longer-hue-lch-012.html "css/css-images/gradient/gradient-longer-hue-lch-012.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-longer-hue-lch-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-longer-hue-lch-012.html)
- [gradient-powerless-hue-hsl.html](https://wpt.fyi/results/css/css-images/gradient/gradient-powerless-hue-hsl.html "css/css-images/gradient/gradient-powerless-hue-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-powerless-hue-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-powerless-hue-hsl.html)
- [gradient-powerless-hue-hwb.html](https://wpt.fyi/results/css/css-images/gradient/gradient-powerless-hue-hwb.html "css/css-images/gradient/gradient-powerless-hue-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-powerless-hue-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-powerless-hue-hwb.html)
- [gradient-powerless-hue-lch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-powerless-hue-lch.html "css/css-images/gradient/gradient-powerless-hue-lch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-powerless-hue-lch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-powerless-hue-lch.html)
- [gradient-powerless-hue-oklch.html](https://wpt.fyi/results/css/css-images/gradient/gradient-powerless-hue-oklch.html "css/css-images/gradient/gradient-powerless-hue-oklch.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-powerless-hue-oklch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-powerless-hue-oklch.html)

For example, given the following
gradient definition:

```
linear-gradient(in oklch, red, #888, green)
```

the conversion of the neutral #888 to oklch gives a missing hue
component: [oklch(0.6268 0 none)]

and thus, in the first gradient segment, the hue is taken from red,
which is [oklch(0.628 0.2577 29.234)]; while in the second
segment it is taken from green, which is [oklch(0.5198 0.1769
142.5)]

By default, this interpolation is linear---​at 25%, 50%, or 75% of the
distance between two [color stops](#color-stop), the color is a 25%, 50%, or 75% blend of the colors of
the two stops.

However, if a [transition
hint](#color-transition-hint) was provided between two [color
stops](#color-stop), the
interpolation is non-linear, and controlled by the hint:

1. Determine the location of the [transition
 hint](#color-transition-hint) as a percentage of the distance between the two
 [color stops](#color-stop),
 denoted as a number between 0 and 1, where 0 indicates the hint is
 placed right on the first [color stop], and 1
 indicates the hint is placed right on the second [color
 stop]. Let this percentage be `H`.
2. For any given point between the two color stops, determine the
 point's location as a percentage of the distance between the two
 [color stops](#color-stop),
 in the same way as the previous step. Let this percentage be
 `P`.
3. Let `C`, the color weighting at that point, be equal to
 `P`^`log`~`H`~`(.5)`^.
4. The color at that point is then a linear blend between the colors of
 the two [color stops](#color-stop), blending
 `(1 - ``C``)` of the first stop
 and `C` of the second stop.

 The [transition
hint](#color-transition-hint) specifies where the "halfway color"---​the 50% blend
between the colors of the two surrounding color stops---​should be
placed. When the hint is exactly halfway between the two surrounding
color stops, the above interpolation algorithm happens to produce the
ordinary linear interpolation. If the hint is placed anywhere else, it
produces a smooth exponential curve between the surrounding color stops,
with the "halfway color" occurring exactly where the hint specifies.

Here an example of a linear
gradient without [transition
hint](#color-transition-hint) (top) compared to one with a transition hint between
the red and blue [color stops](#color-stop) (bottom).

!(images/gradient-colors-transition-hint-comparison.png){height="200"
width="300"}

Top - Without transition hint (falling back to the default halfway
transition hint):

```
background: linear-gradient(to right, red 0%, blue 100%);
```

Bottom - With transition hint:

```
background: linear-gradient(to right, red 0%, 25%, blue 100%);
```

If multiple [color stops](#color-stop) have the same position, they produce an infinitesimal
transition from the one specified first in the list to the one specified
last. In effect, the color suddenly changes at that position rather than
smoothly transitioning.

#### 3.5.3. Color Stop "Fixup"

When resolving the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) positions of each [color
stop](#color-stop), the following
steps must be applied *in order*:

1. If the first [color stop](#color-stop) does not have a position, set its position to 0%.
2. If the last [color stop](#color-stop) does not have a position, set its position to 100%.
3. If a [color stop](#color-stop) or [transition
 hint](#color-transition-hint) has a position that is less than the specified
 position of any [color stop] or [transition
 hint] before it in the list, set
 its position to be equal to the largest specified position of any
 [color stop] or [transition
 hint] before it.
4. If any [color stop](#color-stop) still does not have a position, then, for each run
 of adjacent [color stops] without positions,
 set their positions so that they are evenly spaced between the
 preceding and following [color stops] with
 positions.

After applying these rules, all [color
stops](#color-stop) and
[transition
hints](#color-transition-hint) will have a definite position and color and they will
be in ascending order.

Tests

- [gradient-move-stops.html](https://wpt.fyi/results/css/css-images/gradient-move-stops.html "css/css-images/gradient-move-stops.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-move-stops.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-move-stops.html)
- [gradient-nan-crash.html](https://wpt.fyi/results/css/css-images/gradient-nan-crash.html "css/css-images/gradient-nan-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-nan-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-nan-crash.html)
- [gradient-refcrash.html](https://wpt.fyi/results/css/css-images/gradient-refcrash.html "css/css-images/gradient-refcrash.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient-refcrash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient-refcrash.html)

 It is recommended that authors exercise caution when
mixing different types of units, such as px, em, or %, as this can cause
a [color stop](#color-stop) to
unintentionally try to move before an earlier one. For example, the rule
[background-image: linear-gradient(yellow 100px, blue
50%)](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) wouldn't trigger any fix-up while the
background area is at least [200px] tall. If it was [150px]
tall, however, the blue [color stop's] position
would be equivalent to [75px], which precedes the yellow [color
stop], and would be corrected to a position of
[100px]. Additionally, since the relative ordering of such color
stops cannot be determined without performing layout, they will not
interpolate smoothly in
[animations](http://www.w3.org/TR/css-animations/) or
[transitions](http://www.w3.org/TR/css-transitions/).

Below are several pairs of gradients.
The latter of each pair is a manually "fixed-up" version of the former,
obtained by applying the above rules. For each pair, both gradients will
render identically. [The numbers in each arrow specify which fixup steps
are invoked in the transformation.]

``` highlight
1. linear-gradient(red, white 20%, blue)
 =1=>
 linear-gradient(red 0%, white 20%, blue 100%)

2. linear-gradient(red 40%, white, black, blue)
 =1,3=>
 linear-gradient(red 40%, white 60%, black 80%, blue 100%)

3. linear-gradient(red -50%, white, blue)
 =1,3=>
 linear-gradient(red -50%, white 25%, blue 100%)

4. linear-gradient(red -50px, white, blue)
 =1,3=>
 linear-gradient(red -50px, white calc(-25px + 50%), blue 100%)

5. linear-gradient(red 20px, white 0px, blue 40px)
 =2=>
 linear-gradient(red 20px, white 20px, blue 40px)

6. linear-gradient(red, white -50%, black 150%, blue)
 =1,2=>
 linear-gradient(red 0%, white 0%, black 150%, blue 150%)

7. linear-gradient(red 80px, white 0px, black, blue 100px)
 =2,3=>
 linear-gradient(red 80px, white 80px, black 90px, blue 100px)
```

## 4. 1D Image Values: the [\<image-1D\> type and [stripes()](#funcdef-stripes) notation]
While [\<image\>](#typedef-image) values represent a 2-dimensional (2D)
image, and
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) can be thought of as a 0-dimensional
(0D) image (unvarying in either axis), some contexts require a
[1-dimensional (1D) image],
which specifies colors along an abstract, directionless, single-axis
[paint line].
The [[\<image-1D\>](#typedef-image-1d)] type represents such [1D
images](#1d-image), including the
[stripes()](#funcdef-stripes) [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation):

```
<image-1D> = <stripes()>
<stripes()> = stripes( <color-stripe># )
<color-stripe> = <color> && [ <length-percentage> | <flex> ]?
```

The [stripes()] function defines a [1D
image](#1d-image) as a
comma-separated list of colored stripes, each placed end-to-end on the
[paint line](#paint-line) in the
order given.

Each
[[\<color-stripe\>](#typedef-color-stripe)] entry defines a solid-color
stripe with the specified
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) and thickness. If the thickness is
omitted, it defaults to [1fr]. Thickness values are interpreted as
follows:

[[\<percentage \[0,100\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: Percentage thicknesses are relative to the `total width`.
 Only values between [0%] and [100%] (inclusive) are
 valid.

[[\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Negative length values are invalid.

[[\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex)]
: A
 [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) is evaluated as a fraction of the
 `total width` relative to the total sum of
 [\<flex\>] entries in the
 function, after subtracting the thickness of any
 non-[\<flex\>] entries (flooring
 the subtraction result at zero). If the sum of
 [\<flex\>] values is less than
 [1fr], the result of the subtraction is multiplied by the
 sum's value before being distributed.

The `total width` refers to the length of the [paint
line](#paint-line). It is defined
by the context in which the
[stripes()](#funcdef-stripes) function is used. If the sum of the stripes is
smaller than the `total width`, the [paint
line] is [transparent
black](https://drafts.csswg.org/css-color-4/#transparent-black) for its remaining length, as if a final
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) argument were given. If the sum is larger, any
stripes or portions beyond the `total width` are truncated.

For example, [stripes(red 1fr,
green 2fr, blue 100px)] with a `total width` of
[400px] will result in a 100px red stripe and 200px green stripe,
giving red 1 share and green 2 shares of the 300px remaining after
subtracting blue's 100px from the 400px total.

!(images/stripes1.svg){style="height:1em; width:400px;"}

On the other hand, [stripes(red .1fr, green .2fr, blue 100px)]
with a `total width` of [400px] will instead give a
30px red stripe and 60px green stripe, followed by 100px of blue and
then 210px of transparent. The 300px of leftover space is multiplied by
.3, the value of the sum of the
[\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) values, to obtain only 90px, which is
then distributed in the 1:2 ratio dictated by the
[\<flex\>] values.

!(images/stripes2.svg){style="height:1em; width:400px;"}

(This is similar to how [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout) deals with small
[\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) sums on a line, and ensures smoothly
continuous behavior as the [\<flex\>] values approach zero.)

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of this function is an ordered list of stripes, each
given as a [computed
color](https://drafts.csswg.org/css-color-4/#computed-color) and a thickness represented either a
[\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) value or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value.

## 5. Sizing Images and Objects in CSS

### 5.1. Sizing Objects: the [object-fit property]
Name:

[object-fit]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

fill
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] \[contain
[\|] cover\]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) scale-down

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

fill

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

replaced elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The [object-fit](#propdef-object-fit) property specifies how the contents of a
replaced element should be fitted to the box established by its used
height and width.

[fill]
: The replaced content is sized to fill the element's content box: the
 object's [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) is the element's used width and height.

[none]
: The replaced content is not resized to fit inside the element's
 content box: determine the object's [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) using the [default sizing
 algorithm](https://drafts.csswg.org/css-images-3/#default-sizing-algorithm) with no specified size, and a [default object
 size](https://drafts.csswg.org/css-images-3/#default-object-size) equal to the replaced element's used width and
 height.

[contain]

: The replaced content is sized to maintain its aspect ratio while
 fitting within the element's content box: its [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) is resolved as a [contain
 constraint](https://drafts.csswg.org/css-images-3/#contain-constraint) against the element's used width and height.

 If the
 [scale-down](#valdef-object-fit-scale-down) flag is used, size the content as if
 [none](#valdef-object-fit-none) or
 [contain](#valdef-object-fit-contain) were specified, whichever would result in a
 smaller [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size).

 Both
 [none](#valdef-object-fit-none) and
 [contain](#valdef-object-fit-contain) respect the content's [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), so the concept of \"smaller\" is well-defined.

[cover]

: The replaced content is sized to maintain its aspect ratio while
 filling the element's entire content box: its [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size) is resolved as a [cover
 constraint](https://drafts.csswg.org/css-images-3/#cover-constraint) against the element's used width and height.

 If the
 [scale-down](#valdef-object-fit-scale-down) flag is used, size the content as if
 [none](#valdef-object-fit-none) or
 [cover](#valdef-object-fit-cover) were specified, whichever would result in a
 smaller [concrete object
 size](https://drafts.csswg.org/css-images-3/#concrete-object-size).

 Both
 [none](#valdef-object-fit-none) and
 [cover](#valdef-object-fit-cover) respect the content's [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), so the concept of \"smaller\" is well-defined.

[scale-down]
: Equivalent to [contain scale-down].

Tests

- [inheritance.html](https://wpt.fyi/results/css/css-images/inheritance.html "css/css-images/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-images/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/inheritance.html)
- [object-fit-contain-png-001c.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-001c.html "css/css-images/object-fit-contain-png-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-001c.html)
- [object-fit-contain-png-001e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-001e.html "css/css-images/object-fit-contain-png-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-001e.html)
- [object-fit-contain-png-001i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-001i.html "css/css-images/object-fit-contain-png-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-001i.html)
- [object-fit-contain-png-001o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-001o.html "css/css-images/object-fit-contain-png-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-001o.html)
- [object-fit-contain-png-001p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-001p.html "css/css-images/object-fit-contain-png-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-001p.html)
- [object-fit-contain-png-002c.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-002c.html "css/css-images/object-fit-contain-png-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-002c.html)
- [object-fit-contain-png-002e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-002e.html "css/css-images/object-fit-contain-png-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-002e.html)
- [object-fit-contain-png-002i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-002i.html "css/css-images/object-fit-contain-png-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-002i.html)
- [object-fit-contain-png-002o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-002o.html "css/css-images/object-fit-contain-png-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-002o.html)
- [object-fit-contain-png-002p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-png-002p.html "css/css-images/object-fit-contain-png-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-png-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-png-002p.html)
- [object-fit-contain-svg-001e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-001e.html "css/css-images/object-fit-contain-svg-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-001e.html)
- [object-fit-contain-svg-001i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-001i.html "css/css-images/object-fit-contain-svg-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-001i.html)
- [object-fit-contain-svg-001o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-001o.html "css/css-images/object-fit-contain-svg-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-001o.html)
- [object-fit-contain-svg-001p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-001p.html "css/css-images/object-fit-contain-svg-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-001p.html)
- [object-fit-contain-svg-002e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-002e.html "css/css-images/object-fit-contain-svg-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-002e.html)
- [object-fit-contain-svg-002i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-002i.html "css/css-images/object-fit-contain-svg-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-002i.html)
- [object-fit-contain-svg-002o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-002o.html "css/css-images/object-fit-contain-svg-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-002o.html)
- [object-fit-contain-svg-002p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-002p.html "css/css-images/object-fit-contain-svg-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-002p.html)
- [object-fit-contain-svg-003e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-003e.html "css/css-images/object-fit-contain-svg-003e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-003e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-003e.html)
- [object-fit-contain-svg-003i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-003i.html "css/css-images/object-fit-contain-svg-003i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-003i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-003i.html)
- [object-fit-contain-svg-003o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-003o.html "css/css-images/object-fit-contain-svg-003o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-003o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-003o.html)
- [object-fit-contain-svg-003p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-003p.html "css/css-images/object-fit-contain-svg-003p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-003p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-003p.html)
- [object-fit-contain-svg-004e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-004e.html "css/css-images/object-fit-contain-svg-004e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-004e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-004e.html)
- [object-fit-contain-svg-004i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-004i.html "css/css-images/object-fit-contain-svg-004i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-004i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-004i.html)
- [object-fit-contain-svg-004o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-004o.html "css/css-images/object-fit-contain-svg-004o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-004o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-004o.html)
- [object-fit-contain-svg-004p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-004p.html "css/css-images/object-fit-contain-svg-004p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-004p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-004p.html)
- [object-fit-contain-svg-005e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-005e.html "css/css-images/object-fit-contain-svg-005e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-005e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-005e.html)
- [object-fit-contain-svg-005i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-005i.html "css/css-images/object-fit-contain-svg-005i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-005i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-005i.html)
- [object-fit-contain-svg-005o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-005o.html "css/css-images/object-fit-contain-svg-005o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-005o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-005o.html)
- [object-fit-contain-svg-005p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-005p.html "css/css-images/object-fit-contain-svg-005p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-005p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-005p.html)
- [object-fit-contain-svg-006e.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-006e.html "css/css-images/object-fit-contain-svg-006e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-006e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-006e.html)
- [object-fit-contain-svg-006i.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-006i.html "css/css-images/object-fit-contain-svg-006i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-006i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-006i.html)
- [object-fit-contain-svg-006o.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-006o.html "css/css-images/object-fit-contain-svg-006o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-006o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-006o.html)
- [object-fit-contain-svg-006p.html](https://wpt.fyi/results/css/css-images/object-fit-contain-svg-006p.html "css/css-images/object-fit-contain-svg-006p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-contain-svg-006p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-contain-svg-006p.html)
- [object-fit-cover-png-001c.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-001c.html "css/css-images/object-fit-cover-png-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-001c.html)
- [object-fit-cover-png-001e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-001e.html "css/css-images/object-fit-cover-png-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-001e.html)
- [object-fit-cover-png-001i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-001i.html "css/css-images/object-fit-cover-png-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-001i.html)
- [object-fit-cover-png-001o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-001o.html "css/css-images/object-fit-cover-png-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-001o.html)
- [object-fit-cover-png-001p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-001p.html "css/css-images/object-fit-cover-png-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-001p.html)
- [object-fit-cover-png-002c.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-002c.html "css/css-images/object-fit-cover-png-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-002c.html)
- [object-fit-cover-png-002e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-002e.html "css/css-images/object-fit-cover-png-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-002e.html)
- [object-fit-cover-png-002i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-002i.html "css/css-images/object-fit-cover-png-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-002i.html)
- [object-fit-cover-png-002o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-002o.html "css/css-images/object-fit-cover-png-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-002o.html)
- [object-fit-cover-png-002p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-png-002p.html "css/css-images/object-fit-cover-png-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-png-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-png-002p.html)
- [object-fit-cover-svg-001e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-001e.html "css/css-images/object-fit-cover-svg-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-001e.html)
- [object-fit-cover-svg-001i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-001i.html "css/css-images/object-fit-cover-svg-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-001i.html)
- [object-fit-cover-svg-001o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-001o.html "css/css-images/object-fit-cover-svg-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-001o.html)
- [object-fit-cover-svg-001p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-001p.html "css/css-images/object-fit-cover-svg-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-001p.html)
- [object-fit-cover-svg-002e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-002e.html "css/css-images/object-fit-cover-svg-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-002e.html)
- [object-fit-cover-svg-002i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-002i.html "css/css-images/object-fit-cover-svg-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-002i.html)
- [object-fit-cover-svg-002o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-002o.html "css/css-images/object-fit-cover-svg-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-002o.html)
- [object-fit-cover-svg-002p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-002p.html "css/css-images/object-fit-cover-svg-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-002p.html)
- [object-fit-cover-svg-003e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-003e.html "css/css-images/object-fit-cover-svg-003e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-003e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-003e.html)
- [object-fit-cover-svg-003i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-003i.html "css/css-images/object-fit-cover-svg-003i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-003i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-003i.html)
- [object-fit-cover-svg-003o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-003o.html "css/css-images/object-fit-cover-svg-003o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-003o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-003o.html)
- [object-fit-cover-svg-003p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-003p.html "css/css-images/object-fit-cover-svg-003p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-003p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-003p.html)
- [object-fit-cover-svg-004e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-004e.html "css/css-images/object-fit-cover-svg-004e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-004e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-004e.html)
- [object-fit-cover-svg-004i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-004i.html "css/css-images/object-fit-cover-svg-004i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-004i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-004i.html)
- [object-fit-cover-svg-004o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-004o.html "css/css-images/object-fit-cover-svg-004o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-004o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-004o.html)
- [object-fit-cover-svg-004p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-004p.html "css/css-images/object-fit-cover-svg-004p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-004p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-004p.html)
- [object-fit-cover-svg-005e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-005e.html "css/css-images/object-fit-cover-svg-005e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-005e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-005e.html)
- [object-fit-cover-svg-005i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-005i.html "css/css-images/object-fit-cover-svg-005i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-005i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-005i.html)
- [object-fit-cover-svg-005o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-005o.html "css/css-images/object-fit-cover-svg-005o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-005o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-005o.html)
- [object-fit-cover-svg-005p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-005p.html "css/css-images/object-fit-cover-svg-005p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-005p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-005p.html)
- [object-fit-cover-svg-006e.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-006e.html "css/css-images/object-fit-cover-svg-006e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-006e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-006e.html)
- [object-fit-cover-svg-006i.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-006i.html "css/css-images/object-fit-cover-svg-006i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-006i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-006i.html)
- [object-fit-cover-svg-006o.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-006o.html "css/css-images/object-fit-cover-svg-006o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-006o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-006o.html)
- [object-fit-cover-svg-006p.html](https://wpt.fyi/results/css/css-images/object-fit-cover-svg-006p.html "css/css-images/object-fit-cover-svg-006p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-cover-svg-006p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-cover-svg-006p.html)
- [object-fit-dyn-aspect-ratio-001.html](https://wpt.fyi/results/css/css-images/object-fit-dyn-aspect-ratio-001.html "css/css-images/object-fit-dyn-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-dyn-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-dyn-aspect-ratio-001.html)
- [object-fit-dyn-aspect-ratio-002.html](https://wpt.fyi/results/css/css-images/object-fit-dyn-aspect-ratio-002.html "css/css-images/object-fit-dyn-aspect-ratio-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-dyn-aspect-ratio-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-dyn-aspect-ratio-002.html)
- [object-fit-fill-png-001c.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-001c.html "css/css-images/object-fit-fill-png-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-001c.html)
- [object-fit-fill-png-001e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-001e.html "css/css-images/object-fit-fill-png-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-001e.html)
- [object-fit-fill-png-001i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-001i.html "css/css-images/object-fit-fill-png-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-001i.html)
- [object-fit-fill-png-001o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-001o.html "css/css-images/object-fit-fill-png-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-001o.html)
- [object-fit-fill-png-001p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-001p.html "css/css-images/object-fit-fill-png-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-001p.html)
- [object-fit-fill-png-002c.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-002c.html "css/css-images/object-fit-fill-png-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-002c.html)
- [object-fit-fill-png-002e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-002e.html "css/css-images/object-fit-fill-png-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-002e.html)
- [object-fit-fill-png-002i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-002i.html "css/css-images/object-fit-fill-png-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-002i.html)
- [object-fit-fill-png-002o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-002o.html "css/css-images/object-fit-fill-png-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-002o.html)
- [object-fit-fill-png-002p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-png-002p.html "css/css-images/object-fit-fill-png-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-png-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-png-002p.html)
- [object-fit-fill-svg-001e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-001e.html "css/css-images/object-fit-fill-svg-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-001e.html)
- [object-fit-fill-svg-001i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-001i.html "css/css-images/object-fit-fill-svg-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-001i.html)
- [object-fit-fill-svg-001o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-001o.html "css/css-images/object-fit-fill-svg-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-001o.html)
- [object-fit-fill-svg-001p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-001p.html "css/css-images/object-fit-fill-svg-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-001p.html)
- [object-fit-fill-svg-002e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-002e.html "css/css-images/object-fit-fill-svg-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-002e.html)
- [object-fit-fill-svg-002i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-002i.html "css/css-images/object-fit-fill-svg-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-002i.html)
- [object-fit-fill-svg-002o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-002o.html "css/css-images/object-fit-fill-svg-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-002o.html)
- [object-fit-fill-svg-002p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-002p.html "css/css-images/object-fit-fill-svg-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-002p.html)
- [object-fit-fill-svg-003e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-003e.html "css/css-images/object-fit-fill-svg-003e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-003e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-003e.html)
- [object-fit-fill-svg-003i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-003i.html "css/css-images/object-fit-fill-svg-003i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-003i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-003i.html)
- [object-fit-fill-svg-003o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-003o.html "css/css-images/object-fit-fill-svg-003o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-003o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-003o.html)
- [object-fit-fill-svg-003p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-003p.html "css/css-images/object-fit-fill-svg-003p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-003p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-003p.html)
- [object-fit-fill-svg-004e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-004e.html "css/css-images/object-fit-fill-svg-004e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-004e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-004e.html)
- [object-fit-fill-svg-004i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-004i.html "css/css-images/object-fit-fill-svg-004i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-004i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-004i.html)
- [object-fit-fill-svg-004o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-004o.html "css/css-images/object-fit-fill-svg-004o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-004o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-004o.html)
- [object-fit-fill-svg-004p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-004p.html "css/css-images/object-fit-fill-svg-004p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-004p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-004p.html)
- [object-fit-fill-svg-005e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-005e.html "css/css-images/object-fit-fill-svg-005e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-005e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-005e.html)
- [object-fit-fill-svg-005i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-005i.html "css/css-images/object-fit-fill-svg-005i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-005i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-005i.html)
- [object-fit-fill-svg-005o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-005o.html "css/css-images/object-fit-fill-svg-005o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-005o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-005o.html)
- [object-fit-fill-svg-005p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-005p.html "css/css-images/object-fit-fill-svg-005p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-005p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-005p.html)
- [object-fit-fill-svg-006e.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-006e.html "css/css-images/object-fit-fill-svg-006e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-006e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-006e.html)
- [object-fit-fill-svg-006i.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-006i.html "css/css-images/object-fit-fill-svg-006i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-006i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-006i.html)
- [object-fit-fill-svg-006o.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-006o.html "css/css-images/object-fit-fill-svg-006o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-006o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-006o.html)
- [object-fit-fill-svg-006p.html](https://wpt.fyi/results/css/css-images/object-fit-fill-svg-006p.html "css/css-images/object-fit-fill-svg-006p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-fill-svg-006p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-fill-svg-006p.html)
- [object-fit-none-png-001c.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-001c.html "css/css-images/object-fit-none-png-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-001c.html)
- [object-fit-none-png-001e.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-001e.html "css/css-images/object-fit-none-png-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-001e.html)
- [object-fit-none-png-001i.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-001i.html "css/css-images/object-fit-none-png-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-001i.html)
- [object-fit-none-png-001o.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-001o.html "css/css-images/object-fit-none-png-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-001o.html)
- [object-fit-none-png-001p.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-001p.html "css/css-images/object-fit-none-png-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-001p.html)
- [object-fit-none-png-002c.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-002c.html "css/css-images/object-fit-none-png-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-002c.html)
- [object-fit-none-png-002e.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-002e.html "css/css-images/object-fit-none-png-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-002e.html)
- [object-fit-none-png-002i.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-002i.html "css/css-images/object-fit-none-png-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-002i.html)
- [object-fit-none-png-002o.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-002o.html "css/css-images/object-fit-none-png-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-002o.html)
- [object-fit-none-png-002p.html](https://wpt.fyi/results/css/css-images/object-fit-none-png-002p.html "css/css-images/object-fit-none-png-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-png-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-png-002p.html)
- [object-fit-none-svg-001e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-001e.html "css/css-images/object-fit-none-svg-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-001e.html)
- [object-fit-none-svg-001i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-001i.html "css/css-images/object-fit-none-svg-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-001i.html)
- [object-fit-none-svg-001o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-001o.html "css/css-images/object-fit-none-svg-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-001o.html)
- [object-fit-none-svg-001p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-001p.html "css/css-images/object-fit-none-svg-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-001p.html)
- [object-fit-none-svg-002e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-002e.html "css/css-images/object-fit-none-svg-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-002e.html)
- [object-fit-none-svg-002i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-002i.html "css/css-images/object-fit-none-svg-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-002i.html)
- [object-fit-none-svg-002o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-002o.html "css/css-images/object-fit-none-svg-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-002o.html)
- [object-fit-none-svg-002p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-002p.html "css/css-images/object-fit-none-svg-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-002p.html)
- [object-fit-none-svg-003e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-003e.html "css/css-images/object-fit-none-svg-003e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-003e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-003e.html)
- [object-fit-none-svg-003i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-003i.html "css/css-images/object-fit-none-svg-003i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-003i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-003i.html)
- [object-fit-none-svg-003o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-003o.html "css/css-images/object-fit-none-svg-003o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-003o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-003o.html)
- [object-fit-none-svg-003p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-003p.html "css/css-images/object-fit-none-svg-003p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-003p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-003p.html)
- [object-fit-none-svg-004e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-004e.html "css/css-images/object-fit-none-svg-004e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-004e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-004e.html)
- [object-fit-none-svg-004i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-004i.html "css/css-images/object-fit-none-svg-004i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-004i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-004i.html)
- [object-fit-none-svg-004o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-004o.html "css/css-images/object-fit-none-svg-004o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-004o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-004o.html)
- [object-fit-none-svg-004p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-004p.html "css/css-images/object-fit-none-svg-004p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-004p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-004p.html)
- [object-fit-none-svg-005e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-005e.html "css/css-images/object-fit-none-svg-005e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-005e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-005e.html)
- [object-fit-none-svg-005i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-005i.html "css/css-images/object-fit-none-svg-005i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-005i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-005i.html)
- [object-fit-none-svg-005o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-005o.html "css/css-images/object-fit-none-svg-005o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-005o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-005o.html)
- [object-fit-none-svg-005p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-005p.html "css/css-images/object-fit-none-svg-005p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-005p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-005p.html)
- [object-fit-none-svg-006e.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-006e.html "css/css-images/object-fit-none-svg-006e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-006e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-006e.html)
- [object-fit-none-svg-006i.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-006i.html "css/css-images/object-fit-none-svg-006i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-006i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-006i.html)
- [object-fit-none-svg-006o.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-006o.html "css/css-images/object-fit-none-svg-006o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-006o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-006o.html)
- [object-fit-none-svg-006p.html](https://wpt.fyi/results/css/css-images/object-fit-none-svg-006p.html "css/css-images/object-fit-none-svg-006p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-none-svg-006p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-none-svg-006p.html)
- [object-fit-scale-down-png-001c.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-001c.html "css/css-images/object-fit-scale-down-png-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-001c.html)
- [object-fit-scale-down-png-001e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-001e.html "css/css-images/object-fit-scale-down-png-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-001e.html)
- [object-fit-scale-down-png-001i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-001i.html "css/css-images/object-fit-scale-down-png-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-001i.html)
- [object-fit-scale-down-png-001o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-001o.html "css/css-images/object-fit-scale-down-png-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-001o.html)
- [object-fit-scale-down-png-001p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-001p.html "css/css-images/object-fit-scale-down-png-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-001p.html)
- [object-fit-scale-down-png-002c.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-002c.html "css/css-images/object-fit-scale-down-png-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-002c.html)
- [object-fit-scale-down-png-002e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-002e.html "css/css-images/object-fit-scale-down-png-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-002e.html)
- [object-fit-scale-down-png-002i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-002i.html "css/css-images/object-fit-scale-down-png-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-002i.html)
- [object-fit-scale-down-png-002o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-002o.html "css/css-images/object-fit-scale-down-png-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-002o.html)
- [object-fit-scale-down-png-002p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-png-002p.html "css/css-images/object-fit-scale-down-png-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-png-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-png-002p.html)
- [object-fit-scale-down-svg-001e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-001e.html "css/css-images/object-fit-scale-down-svg-001e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-001e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-001e.html)
- [object-fit-scale-down-svg-001i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-001i.html "css/css-images/object-fit-scale-down-svg-001i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-001i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-001i.html)
- [object-fit-scale-down-svg-001o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-001o.html "css/css-images/object-fit-scale-down-svg-001o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-001o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-001o.html)
- [object-fit-scale-down-svg-001p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-001p.html "css/css-images/object-fit-scale-down-svg-001p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-001p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-001p.html)
- [object-fit-scale-down-svg-002e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-002e.html "css/css-images/object-fit-scale-down-svg-002e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-002e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-002e.html)
- [object-fit-scale-down-svg-002i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-002i.html "css/css-images/object-fit-scale-down-svg-002i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-002i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-002i.html)
- [object-fit-scale-down-svg-002o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-002o.html "css/css-images/object-fit-scale-down-svg-002o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-002o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-002o.html)
- [object-fit-scale-down-svg-002p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-002p.html "css/css-images/object-fit-scale-down-svg-002p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-002p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-002p.html)
- [object-fit-scale-down-svg-003e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-003e.html "css/css-images/object-fit-scale-down-svg-003e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-003e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-003e.html)
- [object-fit-scale-down-svg-003i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-003i.html "css/css-images/object-fit-scale-down-svg-003i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-003i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-003i.html)
- [object-fit-scale-down-svg-003o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-003o.html "css/css-images/object-fit-scale-down-svg-003o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-003o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-003o.html)
- [object-fit-scale-down-svg-003p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-003p.html "css/css-images/object-fit-scale-down-svg-003p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-003p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-003p.html)
- [object-fit-scale-down-svg-004e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-004e.html "css/css-images/object-fit-scale-down-svg-004e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-004e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-004e.html)
- [object-fit-scale-down-svg-004i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-004i.html "css/css-images/object-fit-scale-down-svg-004i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-004i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-004i.html)
- [object-fit-scale-down-svg-004o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-004o.html "css/css-images/object-fit-scale-down-svg-004o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-004o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-004o.html)
- [object-fit-scale-down-svg-004p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-004p.html "css/css-images/object-fit-scale-down-svg-004p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-004p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-004p.html)
- [object-fit-scale-down-svg-005e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-005e.html "css/css-images/object-fit-scale-down-svg-005e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-005e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-005e.html)
- [object-fit-scale-down-svg-005i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-005i.html "css/css-images/object-fit-scale-down-svg-005i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-005i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-005i.html)
- [object-fit-scale-down-svg-005o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-005o.html "css/css-images/object-fit-scale-down-svg-005o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-005o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-005o.html)
- [object-fit-scale-down-svg-005p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-005p.html "css/css-images/object-fit-scale-down-svg-005p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-005p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-005p.html)
- [object-fit-scale-down-svg-006e.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-006e.html "css/css-images/object-fit-scale-down-svg-006e.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-006e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-006e.html)
- [object-fit-scale-down-svg-006i.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-006i.html "css/css-images/object-fit-scale-down-svg-006i.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-006i.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-006i.html)
- [object-fit-scale-down-svg-006o.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-006o.html "css/css-images/object-fit-scale-down-svg-006o.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-006o.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-006o.html)
- [object-fit-scale-down-svg-006p.html](https://wpt.fyi/results/css/css-images/object-fit-scale-down-svg-006p.html "css/css-images/object-fit-scale-down-svg-006p.html")
 [[(live
 test)]](http://wpt.live/css/css-images/object-fit-scale-down-svg-006p.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/object-fit-scale-down-svg-006p.html)
- [object-fit-computed.html](https://wpt.fyi/results/css/css-images/parsing/object-fit-computed.html "css/css-images/parsing/object-fit-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/object-fit-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/object-fit-computed.html)
- [object-fit-invalid.html](https://wpt.fyi/results/css/css-images/parsing/object-fit-invalid.html "css/css-images/parsing/object-fit-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/object-fit-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/object-fit-invalid.html)
- [object-fit-valid.html](https://wpt.fyi/results/css/css-images/parsing/object-fit-valid.html "css/css-images/parsing/object-fit-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/object-fit-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/object-fit-valid.html)

If the content does not completely fill the replaced element's content
box, the unfilled space shows the replaced element's background. Since
replaced elements always clip their contents to the content box, the
content will never overflow. See the
[object-position](https://drafts.csswg.org/css-images-3/#propdef-object-position) property for positioning the object
with respect to the content box.

![An example showing how four of the values of
[object-fit](#propdef-object-fit) cause the replaced element (blue figure)
to be scaled to fit its height/width box (shown with a green
background), using the initial value for
[object-position](https://drafts.csswg.org/css-images-3/#propdef-object-position). In this case,
[scale-down](#valdef-object-fit-scale-down) and [scale-down contain] would look
identical to
[contain](#valdef-object-fit-contain), and [scale-down cover] would look
identical to
[none](#valdef-object-fit-none).](images/img_scale.png){height="116"
style="border: thin solid black;" width="488"}

 The
[object-fit](#propdef-object-fit) property has similar semantics to the
`fit` attribute in
[\[SMIL10\]](#biblio-smil10 "Synchronized Multimedia Integration Language (SMIL) 1.0 Specification")
and the [\<meetOrSlice\>] parameter
on the [`preserveAspectRatio`
attribute](https://www.w3.org/TR/SVG11/coords.html#PreserveAspectRatioAttribute)
in
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)").

 Per the [object size
negotiation](https://drafts.csswg.org/css-images-3/#object-size-negotiation) algorithm, the [concrete object
size](https://drafts.csswg.org/css-images-3/#concrete-object-size) (or, in this case, the size of the content) does not
directly scale the object itself - it is merely passed to the object as
information about the size of the visible canvas. How to then draw into
that size is up to the image format. In particular, raster images always
scale to the given size, while SVG uses the given size as the size of
the \"SVG Viewport\" (a term defined by SVG) and then uses the values of
several attributes on the root `<svg>` element to determine
how to draw itself.

## 6. Image Processing

### 6.1. Overriding Image Resolutions: the [image-resolution property]
The [image resolution] is defined as the number of image pixels per
unit length, e.g., pixels per inch. Some image formats can record
information about the resolution of images. This information can be
helpful when determining the actual size of the image in the formatting
process. However, the information can also be wrong, in which case it
should be ignored. By default, CSS assumes a resolution of one image
pixel per CSS
[px](https://drafts.csswg.org/css-values-4/#px) unit; however, the
[image-resolution](#propdef-image-resolution) property allows using some other
resolution.

Name:

[image-resolution]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ from-image
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) \]
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
snap[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1dppx

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s) and/or
[\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) (possibly adjusted for
[snap](#valdef-image-resolution-snap), see below)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[image-set()](#funcdef-image-set) notation can alter the [natural
resolution](#--natural-resolution) of an image, which ideally would be automatically
honored without having to set this property. How should we best address
this? Change the initial value to [auto], meaning \"1dppx, unless
CSS says otherwise\"? Say that image-resolution has no effect on images
whose resolution was set by something else in CSS? Or somehow
wordsmithing [image-set()] in some
way such that it always produces [1dppx] images somehow?

The
[image-resolution](#propdef-image-resolution) property specifies the [preferred
resolution](#preferred-resolution) of all raster images used in or on the element. It
affects both content images (e.g. replaced elements and generated
content) and decorative images (such as
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image)). The [preferred
resolution] of an image is used to determine the image's [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions). Values have the following meanings:

[[\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value)]
: Specifies the [preferred
 resolution](#preferred-resolution) explicitly. A \"dot\" in this case corresponds to a
 single image pixel.

[from-image]

: The image's [preferred
 resolution](#preferred-resolution) is taken as that specified by the image format (the
 [natural resolution]). If the image does not
 specify its own resolution, the explicitly specified resolution is
 used (if given), else it defaults to [1dppx].

 [CSS Images 3 § 2.1.2 Image
 Metadata](https://drafts.csswg.org/css-images-3/#url-metadata)
 imposes some restrictions on what metadata can be used.

[snap]
: If the \"snap\" keyword is provided, the computed
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) (if any) is the specified
 resolution rounded to the nearest value that would map one image
 pixel to an integer number of device pixels. If the resolution is
 taken from the image, then the used [natural
 resolution](#--natural-resolution) is the image's native resolution similarly
 adjusted.

As vector formats such as SVG do not have a [natural
resolution](#--natural-resolution), this property has no effect on vector images.

Printers tend to have substantially
higher resolution than computer monitors; due to this, an image that
looks fine on the screen may look pixelated when printed out. The
[image-resolution](#propdef-image-resolution) property can be used to embed a
high-resolution image into the document and maintain an appropriate
size, ensuring attractive display both on screen and on paper:

```
img.high-res {
 image-resolution: 300dpi;
}
```

With this set, an image meant to be 5 inches wide at 300dpi will
actually display as 5in wide; without this set, the image would display
as approximately 15.6in wide since the image is 15000 image pixels
across, and by default CSS displays 96 image pixels per inch.

Some image formats can encode
the image resolution into the image data. This rule specifies that the
UA should use the image resolution found in the image itself, falling
back to 1 image pixel per CSS
[px](https://drafts.csswg.org/css-values-4/#px) unit.

```
img { image-resolution: from-image }
```

These rules both specify that the UA should use the image resolution
found in the image itself, but if the image has no resolution, the
resolution is set to [300dpi] instead of the default
[1dppx].

```
img { image-resolution: from-image 300dpi }
img { image-resolution: 300dpi from-image }
```

Using this rule, the image resolution
is set to 300dpi. (The resolution in the image, if any, is ignored.)

```
img { image-resolution: 300dpi }
```

This rule, on the other hand, if used when the screen's resolution is
96dpi, would instead render the image at 288dpi (so that 3 image pixels
map to 1 device pixel):

```
img { image-resolution: 300dpi snap; }
```

The
[snap](#valdef-image-resolution-snap) keyword can also be used when the resolution is
taken from the image:

```
img { image-resolution: snap from-image; }
```

An image declaring itself as 300dpi will, in the situation above,
display at 288dpi (3 image pixels per device pixel) whereas an image
declaring 72dpi will render at 96dpi (1 image pixel per device pixel).

## 7. Interpolation

This section describes how to interpolate between new value types
defined in this specification, for use with modules such as CSS
Transitions and CSS Animations.

If an algorithm below simply states that two values should be
\"interpolated\" or \"transitioned\" without further details, then the
value should be interpolated as described by the Transitions spec.
Otherwise, the algorithm may reference a variable `t` in its
detailed description of the interpolation. This is a number which starts
at 0% and goes to 100%, and is set to a value that represents the
progress through the transition, based on the duration of the
transition, the elapsed time, and the timing function in use. For
example, with a linear timing function and a 1s duration, after .3s
`t` is equal to 30%.

### 7.1. Interpolating [\<image\>]
All images can be interpolated, though some special types of images
(like some gradients) have their own special interpolation rules. In
general terms, images are interpolated by scaling them to the size of
the `start image` and cross-fading the two while they
transition to the size of the `end image`.

In specific terms, at each point in the interpolation the image is equal
to
`cross-fade( (100% - ``t``) ``start image``, ``end image``)`.

Special-case interpolating to/from no
image, like \"background-image: url(foo);\" to \"background-image:
none;\".

### 7.2. Interpolating [image()]
If two [image()](#funcdef-image) functions are to be interpolated, and they both have
a single
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) argument, their interpolated value is
an [image()] function with an interpolated
[\<color\>], using the standard
rules for [\<color\>]
interpolation.

### 7.3. Interpolating [cross-fade()]
The three components of
[cross-fade()](#funcdef-cross-fade) are interpolated independently. Note this may result
in nested [cross-fade()] notations.

### 7.4. Interpolating [\<gradient\>]
This section needs review and
improvement. In particular, I believe the handling of linear-gradient()
is incomplete - I think we want to specifically interpolate the
\"length\" of the gradient line (the distance between 0% and 100%)
between the starting and ending positions explicitly, so it doesn't grow
and then shrink over a single animation.

Gradient images can be interpolated directly in CSS transitions and
animations, smoothly animating from one gradient to another. There are
only a few restrictions on what gradients are allowed to be
interpolated:

1. Both the starting and ending gradient must be expressed with the
 same function. (For example, you can transition from a
 [linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient) to a
 [linear-gradient()], but not
 from a [linear-gradient()]
 to a
 [radial-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-radial-gradient) or a
 [repeating-linear-gradient()](#funcdef-repeating-linear-gradient).)

2. Both the starting and ending gradient must have the same number of
 [\<color-stop\>](#typedef-color-stop)s. For this purpose, all repeating
 gradients are considered to have infinite color stops, and thus all
 repeating gradients match in this respect.

3. Neither gradient uses a combination of
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) and
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) color stops.

If the two gradients satisfy all of those constraints, they must be
interpolated as described below. If they fail the third one only, they
must be abruptly transitioned at 50% (unless otherwise specified by a
future specification). If they fail either of the first two constraints,
they must be interpolated using
[cross-fade()](#funcdef-cross-fade) as for generic images.

 The abrupt transition at 50% is so that content will
not rely on cross-fading, and smarter interpolation rules can be added
for this case in the future.

1. Convert both the start and end gradients to their explicit forms:

 For linear gradients:

 : - If the direction is specified as an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value), it is already in its
 explicit form.

 - Otherwise, change its direction to an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) in
 \[[0deg],[360deg]) that would produce an
 equivalent rendering.

 If both the start and end gradients had their direction
 specified with keywords, and the absolute difference between
 the angles their directions mapped to is greater than 180deg,
 add 360deg to the direction of the gradient with the smaller
 angle. [This ensures that a transition from, for example, \"to
 left\" (270deg) to \"to top\" (0deg) rotates the gradient a
 quarter-turn clockwise, as expected, rather than rotating
 three-quarters of a turn counter-clockwise.]

 For radial gradients:

 : - If the size is specified as two
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s, it is already in its
 explicit form.

 - Otherwise, the size must be changed to a pair of
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s that would produce an
 equivalent ending-shape. If the
 [\<radial-shape\>](https://drafts.csswg.org/css-images-3/#typedef-radial-shape) was specified as
 [circle](https://drafts.csswg.org/css-images-3/#valdef-radial-shape-circle), change it to
 [ellipse](https://drafts.csswg.org/css-images-3/#valdef-radial-shape-ellipse).

2. Interpolate each component and color-stop of the gradients
 independently. For linear gradients, the only component is the
 angle. For radial gradients, the components are the horizontal and
 vertical position of the center and the horizontal and vertical axis
 lengths.

3. To interpolate a color-stop, first match each color-stop in the
 start gradient to the corresponding color-stop at the same index in
 the end gradient. For repeating gradients, the first specified
 color-stop in the start and end gradients are considered to be at
 the same index, and all other color-stops following and preceding
 are indexed appropriately, repeating and shifting each gradient's
 list of color-stops as needed. Then, for each pair of color-stops,
 interpolate the position and color independently.

### 7.5. Interpolating [stripes()]
Similar to gradients, two
[stripes()](#funcdef-stripes) can be interpolated, allowing for smooth animations
from one image to another. There is only one restriction on what
[stripes()] are allowed to be
interpolated. Both the starting and ending image must have the same
number of
[\<color-stripe\>](#typedef-color-stripe)s. If the two images satisfy this
constraint, they must be interpolated as described below. If they fail
the constraint, they must be interpolated using
[cross-fade()](#funcdef-cross-fade) as for generic images.

1. Interpolate each component and stripe of the images independently.

2. To interpolate a stripe, first match each stripe in the start image
 to the corresponding stripe at the same index in the end image.
 Then, for each pair of stripes, interpolate the thickness and color
 independently.
 [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) values are interpolated as
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s using the following formula:

 ``` highlight
 max(0, 100% - sum-of-percents - sum-of-fixed) * flex value / max(1, sum-of-flexes)
 ```

 where [sum-of-percents] is the sum of all
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s in the
 [stripes()](#funcdef-stripes) function, [sum-of-fixed] is the sum of all
 fixed
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s in the function, and
 [sum-of-flexes] is the sum of all
 [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) values.

## 8. Serialization

This section describes the serialization of all new properties and value
types introduced in this specification, for the purpose of interfacing
with the CSS Object Model
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)").

To serialize any function defined in this module, serialize it per its
individual grammar, in the order its grammar is written in, omitting
components when possible without changing the meaning, joining
space-separated tokens with a single space, and following each
serialized comma with a single space.

For [cross-fade()](#funcdef-cross-fade), always serialize the
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value).

For example, a gradient specified
as:

``` highlight
Linear-Gradient( to bottom, red 0%,yellow,black 100px)
```

must serialize as:

``` highlight
linear-gradient(rgb(255, 0, 0), rgb(255, 255, 0), rgb(0, 0, 0) 100px)
```

## [ Appendix A: Deprecated Features and Aliases]
Implementations must accept
[-webkit-image-set()] as a parse-time alias of
[image-set()](#funcdef-image-set). (It's a valid value, with identical arguments to
[image-set()], and is turned into
[image-set()] during parsing.)

## 9. Privacy Considerations

 No change from
[\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

## 10. Security Considerations

 No change from
[\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

## 11. Changes

### [ Changes Since the [30 September 2025](https://www.w3.org/TR/2025/WD-css-images-4-20250930/) Working Draft]
- (none)

### [ Changes Since the [17 February 2023](https://www.w3.org/TR/2023/WD-css-images-4-20230217/) Working Draft]
- Cleaned up the use of fetching external URLs for style resources
 ([Issue 12065](https://github.com/w3c/csswg-drafts/issues/12065),
 [Issue 12068](https://github.com/w3c/csswg-drafts/issues/12068),
 [Issue 12086](https://github.com/w3c/csswg-drafts/issues/12086),
 [Issue 12147](https://github.com/w3c/csswg-drafts/issues/12147))

- Made cross-fade() accept 1+ arguments ([Issue
 11530](https://github.com/w3c/csswg-drafts/issues/11530))

- Allowed \<zero\> for angular color stop/hint

- Explicitly allowed \<zero\> for gradient rotation

- Fixed note about double positions making a stripe. Added note about
 color before/after the stop lists. ([Issue
 11381](https://github.com/w3c/csswg-drafts/issues/11381))

- Separated the first and last stop fixing into separate steps, so it's
 clearer what happens with a single stop ([Issue
 10092](https://github.com/w3c/csswg-drafts/issues/10092))

- Allow just one color stop ([Issue
 10092](https://github.com/w3c/csswg-drafts/issues/10092))

- Made cross-fade() have same order as color-mix() ([Issue
 9405](https://github.com/w3c/csswg-drafts/issues/9405))

- Added example images for the stripes() function ([PR
 9749](https://github.com/w3c/csswg-drafts/pull/9749))

- Added
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values to
 [radial-gradient(circle)], and dual
 [\<radial-extent\>](https://drafts.csswg.org/css-images-3/#typedef-radial-extent) values to
 [radial-gradient(ellipse)] to make
 [radial-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-radial-gradient) consistent with the
 [circle()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-circle) and
 [ellipse()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-ellipse)
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)s. ([Issue
 824](https://github.com/w3c/csswg-drafts/issues/824))

- Added example of missing hues when interpolating with neutrals ([Issue
 4928](https://github.com/w3c/csswg-drafts/issues/4928))

- Explicitly linked to CSS Color 4 hue interpolation, and handling of
 missing components ([Issue
 4928](https://github.com/w3c/csswg-drafts/issues/4928))

- Allowed omitting resolution/type in image-set()

- Applied fix from [PR
 #8021](https://github.com/w3c/csswg-drafts/pull/8021) to gradient
 definitions in CSS Images 4 ([Issue
 9147](https://github.com/w3c/csswg-drafts/pull/9147))

- Made explicit what the default interpolation color space is. ([Issue
 7947](https://github.com/w3c/csswg-drafts/issues/7948))

- Fixed duplicate repeating gradient definitions ([Issue
 8797](https://github.com/w3c/csswg-drafts/pull/8797))

- Added basic syntax of repeating gradient types ([Issue
 8775](https://github.com/w3c/csswg-drafts/pull/8775))

- Fixed interpolation of stripes() with different types ([Issue
 8614](https://github.com/w3c/csswg-drafts/pull/8614))

- Added url request modifiers to enable request parameters ([PR
 8222](https://github.com/w3c/csswg-drafts/pull/8222))

- Specified that image-set() is an invalid image if you remove all the
 options. ([Issue
 8266](https://github.com/w3c/csswg-drafts/issues/8266))

### [ Changes Since the [13 April 2017](https://www.w3.org/TR/2017/WD-css-images-4-20170413/) Working Draft]
- Major editorial rewrite of [§ 3.5 Defining Gradient
 Color](#gradient-colors).

- Added new [\<image-1D\>](#typedef-image-1d) data type and
 [stripes()](#funcdef-stripes) function. ([Issue
 2532](https://github.com/w3c/csswg-drafts/issues/2532))

- Added
 [\<color-interpolation-method\>](https://drafts.csswg.org/css-color-4/#color-interpolation-method) to all gradient functions. (Issues
 [6094](https://github.com/w3c/csswg-drafts/issues/6094),
 [6667](https://github.com/w3c/csswg-drafts/issues/6667))

- Added new
 [object-view-box](https://drafts.csswg.org/css-images-5/#propdef-object-view-box) property. ([Issue
 7058](https://github.com/w3c/csswg-drafts/issues/7058))

- Pulled definition of
 [image-set()](#funcdef-image-set) from
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3")
 and:

 - Added
 [type()](#funcdef-image-set-type) to
 [image-set()](#funcdef-image-set). ([Issue
 656](https://github.com/w3c/csswg-drafts/issues/656))

 - Added the
 [-webkit-image-set()](#funcdef--webkit-image-set) compatibility alias. ([Issue
 6285](https://github.com/w3c/csswg-drafts/issues/6285))

- Pulled definition of
 [cross-fade()](#funcdef-cross-fade) from
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3")
 and:

 - Clarified that
 [cross-fade()](#funcdef-cross-fade) takes 1+ arguments.

 - Updated to allow mixing colors as well as images.

 - Defined sizing and painting of the new function arguments in detail.

 - Fixed incorrect definition of
 [cross-fade()](#funcdef-cross-fade) image blending.

 - Add issue about computation planned simplification and comparison.
 ([Issue 2852](https://github.com/w3c/csswg-drafts/issues/2852))

 ([Minutes](https://lists.w3.org/Archives/Public/www-style/2018Jul/0024.html),
 [Changeset](https://github.com/w3c/csswg-drafts/commit/ab20b4cbccf41db8e61850f58b2f1c1afc6ec66a))

- Pulled [interpolation](#interpolation) and
 [serialization](#serialization) of images from
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

- Defined that image metadata placed after the image data should be
 ignored, see [CSS Images 3 § 2.1.2 Image
 Metadata](https://drafts.csswg.org/css-images-3/#url-metadata).
 ([Issue 4929](https://github.com/w3c/csswg-drafts/issues/4929))

- Defined image loading. ([Issue
 1984](https://github.com/w3c/csswg-drafts/issues/1984))

 - Copied definition of [loading
 image](#loading-image) from
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

 - Integrated loading and error handling into
 [image()](#funcdef-image) behavior.

 - Explicitly allow UA to render the old image while a new image loads
 in to replace another.

 - Properly defined [§ 2.3 Fetching External Images](#fetching-images).
 ([Issue 562](https://github.com/w3c/csswg-drafts/issues/562), [Pull
 Request 6715](https://github.com/w3c/csswg-drafts/pull/6715))

- Updated
 [`CSS`](https://drafts.csswg.org/cssom-1/#namespacedef-css) interface to a namespace. ([Issue
 437](https://github.com/w3c/csswg-drafts/pull/437))

- Allowed unitless zero to represent
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) values in
 [conic-gradient()](#funcdef-conic-gradient). ([Issue
 1162](https://github.com/w3c/csswg-drafts/issues/1162),
 [Changes](https://github.com/w3c/csswg-drafts/commit/edb0b3090bdd73abb765023475e58afe52c701b9))

- Allowed
 [scale-down](#valdef-object-fit-scale-down) to be combined with other values in
 [object-fit](#propdef-object-fit). ([Issue
 1578](https://github.com/w3c/csswg-drafts/issues/1578))

- Added missing
 [\<element()\>](#funcdef-element) to
 [\<image\>](#typedef-image) data type. ([issue
 5170](https://github.com/w3c/csswg-drafts/issues/5170))

- Fixed `elementSources` IDL definition.

- Fixed grammar error requiring color stop positions to be mandatory.
 ([Issue 1334](https://github.com/w3c/csswg-drafts/issues/1334))

- Updated property definition tables to:

 - Align "Computed Value" and "Animation Type" lines across modules,
 tighten wording, and correct errors.

 - Use the new [CSS bracketed range
 notation](https://drafts.csswg.org/css-values-4/#css-bracketed-range-notation) where appropriate.

 - Drop "Media" lines.

- Renamed "intrinsic dimensions" to [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) to avoid confusion with [intrinsic
 sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-size). ([Issue
 4961](https://github.com/w3c/csswg-drafts/issues/4961))

- Copied over definition of computed
 [\<image\>](#typedef-image) from
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").
 ([Issue 4042](https://github.com/w3c/csswg-drafts/issues/4042))

- Explicitly allowed dithering in gradients. ([Issue
 4793](https://github.com/w3c/csswg-drafts/issues/4793))

- Assorted markup fixes, corrections to property syntaxes, inline
 issues, spelling corrections, example fixes and improvements, and
 minor editorial refinements.

- Shortened module title.

### [ Changes Since the [11 September 2012 Working Draft](https://www.w3.org/TR/2012/WD-css4-images-20120911/)]
- Added [color interpolation hints](#color-stop-syntax)

- Added the [two location syntax](#color-stop-syntax) for gradient color
 stops

- Added start angles to [conic gradients](#conic-gradients)

- The position(s) of a color stop can now come before the color

- Text that is identical to
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3")
 has been replaced with a reference to
 [\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

- Added the
 [-webkit-image-set()](#funcdef--webkit-image-set) alias.

### [ Changes Since Level 3]
- Added the [image()](#funcdef-image) notation (deferred from Level 3)

- Added the
 [image-resolution](#propdef-image-resolution) property (deferred from Level 3)

- Added the [element()](#funcdef-element) notation (deferred from Level 3)

- Added [conic gradients](#conic-gradients)

- Added \<color-interpolation-method\> to all gradient functions
