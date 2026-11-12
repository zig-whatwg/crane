## 1. Introduction

*This section is non-normative*

A filter effect is a graphical operation that is applied to an element
as it is drawn into the document. It is an image-based effect, in that
it takes zero or more images as input, a number of parameters specific
to the effect, and then produces an image as output. The output image is
either rendered into the document instead of the original element, used
as an input image to another filter effect, or provided as a CSS image
value.

This is Level 2 of the Filter Effects Module. It is currently written as
a \"delta\", describing any differences from Level 1.

This specification was drafted for
discussion, and does not yet have Working Group consensus. See
[discussion in issue 53](https://github.com/w3c/fxtf-drafts/issues/53).

## 2. Backdrop filters: the [backdrop-filter property]
The description of the
[backdrop-filter](#propdef-backdrop-filter) property is as follows:

Name:

[backdrop-filter]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<filter-value-list\>](https://drafts.csswg.org/filter-effects-1/#typedef-filter-value-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements. In SVG, it applies to [container
elements](https://w3c.github.io/svgwg/svg2-draft/struct.html#container-element) without the defs element and all graphics elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see prose in [Filter Effects 1 §  14. Animation of
Filters](https://drafts.csswg.org/filter-effects-1/#animation-of-filters).

Media:

visual

If the value of the
[backdrop-filter](#propdef-backdrop-filter) property is [none] then there
is no filter effect applied. Otherwise, the list of functions are
applied in the order provided.

### 2.1. Filtering and Clipping

An element (call it B) with a backdrop-filter property other than
[none] is rendered as if the following steps are performed:

1. Copy the [Backdrop Root
 Image](#backdrop-root-image) into a temporary buffer, such as a raster image.
 Call this buffer T'.

2. Apply the backdrop-filter's filter operations to the entire contents
 of T\'.

3. If element B has any transforms (between B and the Backdrop Root),
 apply the **inverse** of those transforms to the contents of T'.

4. Apply a clip to the contents of T', using the border box of element
 B, including
 [border-radius](https://drafts.csswg.org/css-backgrounds-3/#border-radius)
 if specified. Note that the children of B are not considered for the
 sizing or location of this clip.

5. Draw all of element B, including its background, border, and any
 children elements, into T'.

6. If element B has any transforms, effects, or clips, apply those to
 T'.

7. Composite the contents of T' into element B's parent, using
 source-over compositing.

The first
[filter](https://drafts.csswg.org/filter-effects-1/#elementdef-filter) function or filter reference in the
[\<filter-value-list\>](https://drafts.csswg.org/filter-effects-1/#typedef-filter-value-list) takes the element's [Backdrop Root
Image](#backdrop-root-image) as the input image. Subsequent operations take the
output from the previous filter function or
[filter] reference as the input image. The
[filter] element reference functions can
specify an alternate input, but still uses the previous output as its
SourceGraphic.

Filter functions must operate in the sRGB color space.

If the filter functions list includes a
[blur()](https://drafts.csswg.org/filter-effects-1/#blurEquivalent)
filter, the filter will be applied with edgeMode=\"mirror\", with the
edge defined by the clipped, transformed border box of the element. See
[§ 3 Backdrop Root](#BackdropRoot).

 The effect of the backdrop-filter will not be visible
unless some portion of element B is semi-transparent. Also note that any
opacity applied to element B will be applied to the filtered backdrop
image as well. Therefore, to create a \"transparent\" element that
allows the full filtered backdrop image to be seen, you can use
\"background-color: transparent;\".

A computed value of other than [none] results in the creation of
both a [stacking context](https://www.w3.org/TR/CSS21/zindex.html)
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
and a [Containing
Block](https://developer.mozilla.org/en-US/docs/Web/CSS/Containing_block)
for absolute and fixed position descendants, unless the element it
applies to is a document root element in the current [browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context).

 This rule works in the same way as for the
[filter](https://drafts.csswg.org/filter-effects-1/#propdef-filter) property.

## 3. Backdrop Root

The [Backdrop Root Image] for an element E is the final image that
would be produced by the following steps:

1. Start at the [Backdrop Root](#backdrop-root) element that is the nearest ancestor of E.

2. Paint all content, in [painting
 order](https://www.w3.org/TR/CSS2/zindex.html#painting-order),
 between (and including) the ancestor Backdrop Root element and
 element E.

3. Flatten the painted content into a 2D screen-space buffer.

4. Transform the border box of element E to 2D screen-space, and clip
 the final painted output to this border quad.

This specification does not yet have
Working Group consensus, specifically on the definition of Backdrop
Root. See [discussion in issue
53](https://github.com/w3c/fxtf-drafts/issues/53).

 No content that is a DOM ancestor of the Backdrop Root
element should contribute to or affect the Backdrop Root Image.

A [Backdrop Root] is formed, anywhere in the document, by an element in any of
the following scenarios. See [§ 3.2 Backdrop Root
Triggers](#BackdropRootTriggers) for more details on each:

- The root element of the document (HTML).

- An element with a filter property other than \"none\".

- An element with an opacity value less than 1.

- An element with mask, mask-image, mask-border, or clip-path properties
 with values other than "none".

- An element with a backdrop-filter value other than \"none\".

- An element with a mix-blend-mode value other than \"normal\".

- An element with a will-change value specifying any property that would
 create a Backdrop Root on non-initial value.

 this definition encompases fewer element types than the
definition for a Stacking Context. In particular, a Backdrop Root is not
formed by elements with z-index applied, fixed or sticky-positioned
elements, and elements with transforms applied. This allows elements
with backdrop-filter or mix-blend-mode to apply to elements higher up
the DOM tree than would otherwise apply if they stopped at the parent
Stacking Context. For example, a container can be used to contain
elements with backdrop-filter applied, and that container can use
transforms for animation or positioning, while still allowing the
backdrop-filter to apply to the background behind the container.

### 3.1. Motivation

*This section is non-normative*

There are currently three related, but distinct, concepts in the web
platform:

- The [Stacking
 Context](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Positioning/Understanding_z_index/The_stacking_context).
 A Stacking Context is induced by many different types of element
 properties, and is primarily related to defining the painting (Z)
 order of elements.

- The [Containing
 Block](https://developer.mozilla.org/en-US/docs/Web/CSS/Containing_block).
 A Containing Block is also induced by several types of element
 properties, and is primarily related to defining how layout (X/Y) is
 performed for elements.

- The [3D Rendering
 Context](https://drafts.csswg.org/css-transforms-2/#3d-rendering-contexts).
 A 3D Rendering Context is induced by several properties, mainly
 transform-style, but also any of the grouping properties, and is
 primarily related to defining the relevant coordinate space for 3D
 transforms.

There is an important motivation for the creation of a separate web
platform concept for the Backdrop Root, rather than just re-using an
existing concept. There are essentially two other choices that might be
used as a definition of the \"backdrop\": 1) "everything that painted
before, up to the root node", or 2) "everything up to the parent
stacking context". However, there are ambiguities with definition #1,
and excessive limitations with definition #2. Therefore, the Backdrop
Root concept strikes a balance between the two.

In particular, it is important to note that including "everything that
paints before" an element is ambiguous in the case where an ancestor of
the element contains filtering and/or opacity. Because those effects are
inherited by descendant elements, including the element containing
backdrop-filter or mix-blend-mode, it is not clear "when" to apply the
effect. Filters and opacity create a stacking context, and the [css
filter-effect
specification](https://drafts.csswg.org/filter-effects/#FilterProperty)
states that "All the \[Stacking Context\] descendants are rendered
together as a group with the filter effect applied to the group as a
whole." If, somewhere inside that stacking context, an element contains
a backdrop-filter property other than "none", then it is impossible to
honor the preceding sentence. At the point of the backdrop-filtered
element, all of the (partially-painted) contents of the stacking context
need to be fully rendered, including applied filters, opacity, and
blending with the backdrop, and the resulting image needs to be used as
the input to the backdrop-filtered element. That fundamentally breaks
the atomicity of the stacking context. And the ambiguity arises from the
need, at the end of rendering the fully-completed stacking context, to
apply those filters and opacity **again** to the completed rendering.
The filters and opacity will, at this point, be applied twice to the
portion of the image that has been backdrop-filtered. This situation
grows exponentially worse if backdrop-filters are nested inside each
other. For this reason, it is necessary to prevent the backdrop-filter
from "seeing\" above nodes that have filters, opacity, and the other
conditions listed above in the definition of the Backdrop Root.

Performance would also be an issue, if backdrop-filter and
mix-blend-mode were defined to filter \"everything\" that comes before
them on the page. Each application of backdrop-filter or mix-blend-mode
would require a separate rendering pass, to temporarily finish any
partially-complete stacking contexts, and get the \"final\" output that
would appear behind each element. That would double the required
rendering time, and would potentially require twice the memory usage and
GPU bandwidth to store the intermediate graphics texture holding the
contents to be filtering. And assuming nested backdrop-filters or
mix-blend-mode elements were allowed, this doubling would become an
exponential performance breakdown. Clearly, this is not a scalable
approach.

Given the following html code:

``` highlight
<html style="background:lightgrey;">
 <div class="box">
 <b>"Box"</b><br><br>Lorem ipsum dolor sit amet, consectetur adipiscing elit,
 sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim
 ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip
 ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
 velit esse cillum
 <div class="dialog"></div>
 </div>
</html>
```

And the following style rules:

``` highlight
<style>
 div {
 position: absolute;
 width: 200px;
 height: 200px;
 top: 70px;
 left: 70px;
 }
 .box {
 background: white;
 filter: invert(1);
 }
 .dialog {
 border: 10px solid blue;
 backdrop-filter: blur(2px);
 }
</style>
```

Consider the sequence of painting operations to produce the final
result, assuming that the \"dialog\" element accesses **everything
behind it**, all the way to the root element. **Important note:** this
is **not** how the Backdrop Root is defined - this example is intended
to illustrate why a Backdrop Root is formed by elements containing
filters.

![ALT TEXT HERE](examples/step1.png){height="331" style="width:30%"
width="332"}

**Step 1.** \"Box\" is rendered, but filters are not yet applied.

![ALT TEXT HERE](examples/step2.png){height="331" style="width:30%"
width="332"}

**Step 2.** \"Dialog\" is about to be rendered, but it has
backdrop-filter applied. Since, for this example, the backdrop-filter
\"sees\" all the way to the root, the \"Box\" element needs to be
temporarily \"completed\" so that the final product can be used as input
to \"Dialog\". This means applying its \"filter: invert(1)\" style.
Note, this is where the atomicity of the Stacking Context created by
\"Box\" is broken. This is also where the performance penalty applies -
the GPU draw work that is performed here will end up being done twice.

![ALT TEXT HERE](examples/step3.png){height="331" style="width:30%"
width="332"}

**Step 3.** Start painting the \"Dialog\" element by reading back its
backdrop image, applying the \"backdrop-filter: blur(2px)\" filter, and
cropping those results to the border box of \"Dialog\". (The dotted
black border has been added here for clarity: this is the border box for
the \"Dialog\" element.)

![ALT TEXT HERE](examples/step4.png){height="331" style="width:30%"
width="332"}

**Step 4.** Now that the backdrop-filtered contents have been read back
and filtered, discard the previously \"completed\" Box element and go
back to the unfiltered version. Note that you can now see the black text
at the bottom bleeding through the white, blurred version inside
\"Dialog\".

![ALT TEXT HERE](examples/step5.png){height="331" style="width:30%"
width="332"}

**Step 5.** Draw the contents of the \"Dialog\" element - the **blue**
border.

![ALT TEXT HERE](examples/step6.png){height="331" style="width:30%"
width="332"}

**Step 6.** Complete the Stacking Context formed by the \"Box\"
element - apply the \"filter: invert(1)\" to \"Box\" and all of its
contents, including the now-completed \"Dialog\" element. Note that the
area inside the yellow \"Dialog\" element has been inverted twice - it
appears white. Also note that the text outside \"Box\" has been drawn in
blurred black text over the top of un-blurred white text, and the black
edge of \"Box\" shows through the now-white blurred edge of \"Box\".
None of these visual effects is expected or intuitive.

Opacity poses much the same problem that filter does. Using the example
above, but with the `filter: invert(1);` style replaced with
`opacity: 0.5;` the results are similarly unintuitive. **Important
note:** the left image below does **not** represent how the Backdrop
Root is defined - this example is intended to illustrate why a Backdrop
Root is formed by elements containing opacity less than 1.

![ALT TEXT HERE](examples/opacity.png){height="310" style="width:30%"
width="309"}      ![ALT TEXT
HERE](examples/opacity_correct.png){height="310" style="width:30%"
width="309"}

The left image is the final result of rendering, assuming the Backdrop
Root includes everything on the page. Note that the blurred region
inside the blue border is very faint. It is rendered at 0.25 opacity
(double-counted), instead of the 0.5 opacity inherited from the \"Box\"
element. The right image is the final result using the correct
definition of Backdrop Root. The blurred region inside the blue border
has opacity 0.5, as expected.

Because masks effectively change the opacity of parts of the elements
they are masking, the behavior for mask operations is quite similar to
that for elements with opacity applied. Using the same example as above,
but replacing the filter/opacity style line with
`-webkit-mask-image: linear-gradient(to top, transparent 25%, black 75%);`
the results are quite similar. The masked area is applied twice, meaning
the alpha channel is effectively squared. **Important note:** the left
image below does **not** represent how the Backdrop Root is defined -
this example is intended to illustrate why a Backdrop Root is formed by
elements containing masks.

![ALT TEXT HERE](examples/mask.png){height="310" style="width:30%"
width="309"}      ![ALT TEXT
HERE](examples/mask_correct.png){height="310" style="width:30%"
width="309"}

The left image is the final result of rendering, assuming the Backdrop
Root includes everything on the page. Note that the gradient applied to
the blurred region inside the blue border (but not the border itself) is
very faint at the bottom. The opacity of the mask has been applied
twice, so the gradient is no longer a linear gradient, but is instead a
quadratic gradient. The right image is the final result using the
correct definition of Backdrop Root. The mask is applied correctly as a
linear gradient for both the blue border and the blurred region inside.

### 3.2. Backdrop Root Triggers

*This section is non-normative*

(#issue-ade95eb0①) This specification does not yet have
Working Group consensus, specifically on the definition of Backdrop
Root. See [discussion in issue
53](https://github.com/w3c/fxtf-drafts/issues/53).

As described in [§ 3.1 Motivation](#BackdropRootMotivation), several
operations pose fundamental problems for operations that need to read
back content that was painted before, and then re-paint that content
(possibly filtered or blended) again. The list of element types that
trigger a [§ 3 Backdrop Root](#BackdropRoot) each pose one of these
problems. Some are obvious and some are more nuanced. This section
describes why each trigger is necessary.

Obvious triggers:

- **The root element.** There is nothing above the root element, so it
 must form a Backdrop Root.

- **Will-change values.** The will-change hint means that the element
 might take on a value that creates a Backdrop Root. For this reason,
 the Backdrop Root should be created immediately, to avoid changing it
 (and therefore changing the rendered appearance) during animation.

Less obvious triggers:

- **An element with a filter.** Filters apply to an element and all of
 its children, rendered together. Allowing the Backdrop Root to read
 back content above a filtered element necessitates breaking the
 atomicity of the filter, with undefined results. See [§ 3.1
 Motivation](#BackdropRootMotivation) for more a much more detailed
 explanation and some examples.

- **An element with opacity \< 1.** Elements with an opacity value less
 than 1.0 suffer from a very similar problem as elements with filters.
 Because the opacity applies to the element and all children, rendered
 together, the opacity value would be \"applied twice\" if the Backdrop
 Root Image were to read back content above the semi-transparent
 element. Effectively, the backdrop-filtered portion of the backdrop
 would be rendered with (Opacity)\^2. See [§ 3.1
 Motivation](#BackdropRootMotivation) for more details and an example.

- **CSS Masks.** There are two reasons why a CSS mask triggers a
 Backdrop Root element. The first is that masks are exactly analogous
 to the opacity problem described in the bullet above. Masks can
 contain regions of partial opacity (e.g.
 `style="mask-image: linear-gradient(to bottom, transparent 25%, black 75%);"`).
 If the Backdrop Root Image were to read back content above the mask,
 those partially-opaque regions would be double-applied to the final
 backdrop image, which would result in incorrect rendering. See [§ 3.1
 Motivation](#BackdropRootMotivation) for more details and an example.

- **Elements with clip-path.** These elements are effectively rendered
 as if they were a mask. While in general that mask doesn't explicitly
 contain partially-opaque regions, it is usually rendered with
 antialiasing, which introduces semi-transparent portions around the
 edges of the clip. Therefore, for the same reasons as described above
 for masks, those semi-transparent regions will be incorrectly
 rendered, producing visual artifacts near the edges of the clip.
 Disabling antialiasing for clip-paths would produce poor rendering
 quality, and relaxing the Backdrop Root restriction on these elements
 would similarly lead to observable artifacts.

- **Backdrop-filter and mix-blend-mode.** These elements themselves must
 form a Backdrop Root for two reasons. First, they cause the same
 problems that filters and opacity cause: there is an ambiguity about
 what constitutes the image to be filtered or blended, given the
 atomicity of the operations. Second, there would likely be an
 exponential performance degradation in the case of nested
 backdrop-filter or mix-blend-mode elements, due to the need to
 re-paint the content behind each element. Each nesting level will
 double the number of these required re-paint cycles, leading to
 significant performance problems.

For all of the above triggers, performance is also an important
motivation. In all of these cases, relaxing the Backdrop Root constraint
would lead to a potential doubling of the CPU/GPU memory and bandwidth.
See [§ 3.1 Motivation](#BackdropRootMotivation) for a more detailed
discussion.

### 3.3. Mix Blend Mode

*This section is non-normative*

The current definition of mix-blend-mode
[defines](https://www.w3.org/TR/compositing-1/#csscompositingrules_CSS)
the input (backdrop) image for mix-blend-mode as being all of the
underlying content of the parent stacking context. This definition could
likely be relaxed to use the Backdrop Root definition instead, allowing
more elements to be blended.

## 4. Privacy and Security Considerations

All of the same privacy and security concerns exist for backdrop-filter
as do for \"standard\" filters. See [Filter Effects 1 § 15.1 Tainted
Filter
Primitives](https://drafts.csswg.org/filter-effects-1/#tainted-filter-primitives)
for more details.

## [Acknowledgments]
The editors would like to thank Mason Freed, Marcus Stange, Matt Rakow,
Simon Fraser, Amelia Bellamy-Royds, Dirk Schulze, and Tab Atkins for
their careful reviews, comments, and corrections.
