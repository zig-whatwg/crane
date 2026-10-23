## 1. Introduction

*This section is not normative.*

Grid Layout is a layout model for CSS that has powerful abilities to
control the sizing and positioning of boxes and their contents. Grid
Layout is optimized for 2-dimensional layouts: those in which alignment
of content is desired in both dimensions.

![Representative Grid layout
example](images/grid-layout.png){a
height="70" width="486"}

Although many layouts can be expressed with regular Grid Layout,
restricting items into a grid in both axes also makes it impossible to
express some common layouts on the Web.

This module defines a variant of [Grid
Layout](https://drafts.csswg.org/css-grid-2/#grid-layout) that removes that restriction so that items can be
placed into Grid-like tracks in one axis while stacking one after
another in the other. Items not explicitly placed into specific tracks
are placed into the column (or row) with the most remaining space based
on the layout size of the items placed so far.

### 1.1. Background and Motivation

#### 1.1.1. Waterfall Layout with Auto-placed Items

[Grid lanes layout](#grid-lanes-layout), sometimes also called "masonry layout" or "waterfall
layout", is a common Web design pattern where a number of
items---​commonly images or short article summaries---​are placed one by
one into columns in a way that loosely resembles masonry construction.
Unlike [multi-column
layout](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1")
and [multi-line column flex
layout](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1"),
where content is placed vertically in the first column until it must
spills over to the second column, [automatic
placement](https://drafts.csswg.org/css-grid-2/#auto-placement) in [grid lanes layout]
selects a column for each new item such that it is generally closer to
the top of the layout than items placed later.

The traditional Pinterest search
results page exemplifies this layout:

![Representative grid lanes layout
example](images/pinterest.png){a
height="608" width="775"}

Here, each item has a different height (depending on the content and the
width of the column), and inspecting the DOM reveals (as the visual
content itself gives no indication of ordering) that each item has been
placed into the column with the smallest height so far.

This layout superficially looks similar to multi-column layout; but it
has the advantage that scrolling down will naturally lead to "later"
items in the layout (such as those less relevant in the search results).

It's not possible to achieve this layout using earlier CSS layout
models, unless you know up-front how tall each item will be, or use
JavaScript for content measurement or placement.

Using [display:
grid-lanes](https://drafts.csswg.org/css-display-4/#propdef-display) together with
[grid-template-columns](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-columns) yields this type of [grid lanes
layout](#grid-lanes-layout)

#### 1.1.2. One-dimensional Grid Layout

[Grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) allows for powerful track sizing and explicit placement
in two axes, but sometimes a layout only needs alignment of its items in
one dimension.

Using [grid lanes
layout](#grid-lanes-layout)
together with explicitly-positioned items allows for this type of
one-dimensional grid layout.

This example [by Douglas
Graham](https://github.com/w3c/csswg-drafts/issues/10233#issuecomment-2071279204)
uses explicit positioning to place each item into its assigned column;
but there are no rows. Instead, items in each column stack one after the
other. This layout can't be duplicated in [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) because the "spanning" relationships among the items in
adjacent columns is not fixed: it depends on their relative heights and
whether the optional banner or advertisement items are included. It also
can't be duplicated in [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout) because the source order of the items (which is used
for reading, sequential navigation, and one-column mobile phone layout)
goes back and forth between the two columns.

![Comparison of one-column and two-column variants of a one-dimensional
grid
layout.](images/masonry-page-layout.png){a
height="492" width="731"}

### 1.2. Value Definitions

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

## 2. Grid Lanes Layout Model

[Grid lanes layout] lays out items into pre-defined tracks similar to [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) in one axis (called the [grid axis]), but
flows them freely similar to [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout) in the other (called the [stacking axis]).
Similar to [grid layout] and unlike [flex
layout], [grid lanes
layout](#grid-lanes-layout)'s auto-placement distributes items across the tracks to
keep the lengths of those tracks as similar as possible.

[Grid
items](https://drafts.csswg.org/css-grid-2/#grid-item) are formed and
[blockified](https://drafts.csswg.org/css-display-4/#blockify) exactly the same as in a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container).

All CSS properties work the same as in a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) unless otherwise specified by this specification. For
example,
[order](https://drafts.csswg.org/css-display-4/#propdef-order) can be used to specify a different
layout order for the items.

 Subgrid items are supported, but subgridding only
occurs in the [grid axis](#grid-axis); see [§ 3.2 Subgrids](#subgrids) for details.

A [grid lanes container] is a [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) whose contents participate in [grid lanes
layout](#grid-lanes-layout). A [grid lanes
container](#grid-lanes-container) creates column
[tracks](https://drafts.csswg.org/css-grid-2/#grid-track) if its [stacking
axis](#stacking-axis) is the
[block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis), or row [tracks] if its [stacking
axis] is the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis).

Comparing Grid Lanes Containers

Column Lanes

 grid-template-columns: 1fr 2fr 3fr;

![Column grid lanes layout lays out items in columns, but ordered across
the columns, placing each item in the then-shortest
column.](images/masonry-columns.png){height="146" width="216"}

Row Lanes

 grid-template-rows: 1fr 2fr 3fr;

![Row grid lanes layout lays out items in rows, but ordered down across
the rows, placing each item in the then-shortest
row.](images/masonry-rows.png){height="214" width="143"}

### 2.1. Reordering and Accessibility

Although [grid lanes
layout](#grid-lanes-layout)
generally progresses in a forwards fashion (placing the next item
endward of the current item in at least one axis, matching the natural
"reading order"), it can switch between endward in the inline or block
axis in a seemingly arbitrary manner. In simple cases, the
[fit-tolerance](#propdef-fit-tolerance) property can help reduce the
feeling of backtracking due to small sizing differences in the [stacking
axis](#stacking-axis) when
laying out auto-placed items. But when
[auto-placement](#grid-lanes-layout-algorithm) is mixed with [explicit
placement](https://drafts.csswg.org/css-grid-2/#definite-grid-position) or spanning items, some amount of backtracking may
occur.

For example, in the following markup
sample, the fourth item is a spanner that doesn't fit in the remaining
empty column on the first line. It ends up positioned into the into the
first column, which is the highest available space into which it will
fit. The next few items, which have a span of 1, end up laying out
"above" it in the empty column, violating the natural reading order.

``` highlight
<section class=masonry>
 <div class=item>1</div>
 <div class=item>2</div>
 <div class="item tall">3</div>
 <div class="item wide">4</div>
 <div class=item>5</div>
 <div class=item>6</div>
 <div class=item>7</div>
</section>
<style>
.masonry {
 display: grid-lanes;
 grid-template-columns: repeat(5, auto);
}
.item { height: 50px; }
.item.wide { grid-column: span 3; }
.item.tall { height: 90px; }
</style>
```

![Auto-placed grid lanes layout with mixed-height items and mixed span
sizes](images/masonry-reorder-span.png){a
height="214" width="514"}

Similarly, items explicitly placed into specific tracks can leave gaps
behind them, into which subsequent auto-placed items can be placed
visually out-of-order.

Authors should be aware of these possibilities and design layouts where
such backtracking is minimized so that focus and reading order can be
more easily followed. Alternatively, if the items do not have an
inherent order, use the
[reading-flow](https://drafts.csswg.org/css-display-4/#propdef-reading-flow) property to allow the UA to
re-order the items for reading and linear navigation.

Or should reordering be the default
behavior for auto-placed items here?

Techniques for reducing backtracking include:

- Using appropriate values for
 [fit-tolerance](#propdef-fit-tolerance), i.e. values large enough to
 avoid gratuitous differentiation among similarly-sized tracks, but not
 so large that meaningful differences get ignored.

- Using explicit placement in ways that help group related items
 together, rather than ways that disrupt the natural order of items

- Avoiding the combination of mixed span sizes in the [grid
 axis](#grid-axis) and disparate
 item sizes in the [stacking
 axis](#stacking-axis), which
 can cause items to get pulled out of order (see example above).

As with [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) and [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout) authors can use the
[order](https://drafts.csswg.org/css-display-4/#propdef-order) property to re-order items; the
same caveats apply. See [CSS Grid Layout 2 § 4 Reordering and
Accessibility](https://drafts.csswg.org/css-grid-2/#order-accessibility)
and [CSS Display 4 § 3.1 Reordering and
Accessibility](https://drafts.csswg.org/css-display-4/#order-accessibility).

### 2.2. Establishing Grid Lanes Layout

Name:

[display](https://drafts.csswg.org/css-display-4/#propdef-display)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

grid-lanes
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline-grid-lanes

[grid-lanes]
: This value causes an element to generate a
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) [grid lanes
 container](#grid-lanes-container) box.

[inline-grid-lanes]
: This value causes an element to generate an
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) [grid lanes
 container](#grid-lanes-container) box.

A [grid lanes
container](#grid-lanes-container) that is not
[subgridded](https://drafts.csswg.org/css-grid-2/#subgrid) in its [grid axis](#grid-axis) establishes an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context) for its contents.

ISSUE(12820): Write up how grid/masonry
formatting contexts work more formally?

### 2.3. Orienting Grid Lanes Layout

The orientation of a [grid lanes
container](#grid-lanes-container), i.e. whether its [grid
axis](#grid-axis) is the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) (establishing columns) or the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) (establishing rows) is determined by the
[(#issue-d4908b1e)TBD] property.

The [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value) of this property is
[normal], which determines
the orientation from the [grid-template-\*] properties:

- If
 [grid-template-columns](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-columns) is
 [none](https://drafts.csswg.org/css-grid-2/#valdef-grid-template-rows-none) and
 [grid-template-rows](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-rows) is not
 [none], the [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container)'s [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) is the [grid axis](#grid-axis) (establishing rows).

- Otherwise (thus by default), the [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container)'s [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) is the [grid axis](#grid-axis) (establishing columns).

The following code will create a
2-column ("waterfall style") [grid lanes
container](#grid-lanes-container) that grows downward:

``` css
.container {
 display: grid-lanes;
 grid-template-columns: 100px 200px;
}
```

while the following code will create a 2-row ("brick wall style") [grid
lanes container](#grid-lanes-container) that grows horizontally:

``` css
.container {
 display: grid-lanes;
 grid-template-rows: 100px 200px;
}
```

Figure out whether we are re-using
[grid-auto-flow](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-flow) here (and what it's values mean) or
defining a new property like [grid-lanes-direction]. [\[Issue
#12803\]](https://github.com/w3c/csswg-drafts/issues/12803)

## 3. Grid Lanes Track Specification

In the [grid axis](#grid-axis), the
full power of [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) is available for track specification:

- Track sizes, line names, and areas can be specified on the [grid lanes
 container](#grid-lanes-container)'s [grid axis](#grid-axis), just like in [grid
 layout](https://drafts.csswg.org/css-grid-2/#grid-layout).

- The [explicit
 grid](https://drafts.csswg.org/css-grid-2/#explicit-grid) and [implicit
 grid](https://drafts.csswg.org/css-grid-2/#implicit-grid) are formed in the same way as for a regular [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container).

- Items can be [placed](#grid-lanes-track-placement) against these grid
 templates just as in [grid
 layout](https://drafts.csswg.org/css-grid-2/#grid-layout).

However, auto-placed items contribute sizing to all tracks, not just the
track into which they are ultimately placed; see [§ 3.4 Grid Axis Track
Sizing](#track-sizing).

 This is because auto-placed items must be laid out *as*
they are placed, so that each track knows how "full" it is (and
therefore which track should receive the next auto-placed item); thus,
the tracks themselves must already have a definite size so that the
items know their [available
space](https://drafts.csswg.org/css-sizing-3/#available) during layout.

### [3.1. ][ Declaring Grid Lanes Track Templates: the [grid-template-\*] properties]
The [grid-template-\*] and
[grid-auto-rows](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-rows)/[grid-auto-columns](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-columns) properties (and their shorthands)
apply in the [grid axis](#grid-axis) of the [grid lanes
container](#grid-lanes-container) and establish tracks just as on regular [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container). (They are ignored in the [stacking
axis](#stacking-axis).)

#### 3.1.1. Intrinsic Tracks and repeat()

Level 3 extends the
[repeat()](https://drafts.csswg.org/css-gaps-1/#funcdef-repeat-line-color-repeat) notation to allow repetitions where neither the
[min track sizing
function](https://drafts.csswg.org/css-grid-2/#min-track-sizing-function) nor the [max track sizing
function](https://drafts.csswg.org/css-grid-2/#max-track-sizing-function) is
[definite](https://drafts.csswg.org/css-sizing-3/#definite); in other words, the syntax for
[\<auto-repeat\>](#typedef-auto-repeat) is relaxed to the following:

``` prod
<auto-repeat> = repeat( [ auto-fill | auto-fit ] , [ <line-names>? <track-size> ]+ <line-names>? )
```

In order to resolve the number of repetitions, a hypothetical size is
calculated for such tracks by initializing the track sizes (per [CSS
Grid Layout 2 § 12.4 Initialize Track
Sizes](https://drafts.csswg.org/css-grid-2/#algo-init)) and resolving
intrinsic track sizes (per [CSS Grid Layout 2 § 12.5 Resolve Intrinsic
Track Sizes](https://drafts.csswg.org/css-grid-2/#algo-content)) in
accordance with [§ 3.4 Grid Axis Track Sizing](#track-sizing) with the
following assumptions:

- Ignore explicit item placement. (That is, assume all items have an
 [automatic
 position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position).)

- Do not
 [collapse](https://drafts.csswg.org/css-grid-2/#collapsed-grid-track) any tracks.

- Expand the repeated track listing to capture all possible [automatic
 placements](https://drafts.csswg.org/css-grid-2/#auto-placement) of each item, i.e. repeat the track listing
 `2 + (``largest span`` - 2)/(``number of tracks in repeat()``)`
 times, rounded *down* to a whole number.

The hypothetical size of each track in the
[repeat()](https://drafts.csswg.org/css-gaps-1/#funcdef-repeat-line-color-repeat) listing is given by the largest track
corresponding to that entry (by index) in the listing.

For example, given a template of
[repeat(auto-fill, 50px auto auto)] and a largest spanner of 2,
you need to repeat the track listing twice, giving [50px auto auto 50px
auto auto]. After doing the hypothetical layout, the 2nd and 5th
tracks are maxed together to provide a hypothetical size for the first
[auto] and the 3rd and 6th tracks are maxed together to provide a
hypothetical size for the second [auto]. Those concrete sizes are
then used to determine how many repetitions will fill the container.

Should this work also in Grid Layout
somehow, or fall back to a single repetition? If so, how? [\[Issue
#10915\]](https://github.com/w3c/csswg-drafts/issues/10915)

 This simplified layout heuristic is defined to be
\"good enough\", while remaining fast and consistent. Ignoring placement
is required just to make the concept coherent; before you know how many
repetitions you need, you can't tell what track an item (even one with a
definite placement) will end up in.

Technically, if your explicit placement
does not enter or cross over the repetition, we can know its placement
prior to resolving the reptition. Do we want to adjust the algorithm
above to account for this? That is, given [auto repeat(auto-fill, \...)
auto], if you explicitly place an item against line 1 or -1, we
could let it only affect that track (rather than pretending it'll go in
every track).

### 3.2. Subgrids

[Subgridding](https://drafts.csswg.org/css-grid-2/#subgrid) allows nested [grid lanes
containers](#grid-lanes-container) (and [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container)) to share track sizes. If the parent's corresponding
axis is a [grid axis](#grid-axis),
the subgridded axis is taken from the parent container [as specified for
grid containers](https://drafts.csswg.org/css-grid-2/#subgrids); if the
parent's corresponding axis is a [stacking
axis](#stacking-axis), the
subgridded axis also acts as a [stacking axis].

What if this conflicts with the lanes
orientation, or results in both axes stacking?

In [grid lanes layout](#grid-lanes-layout), auto-placed
[subgrids](https://drafts.csswg.org/css-grid-2/#subgrid) don't inherit any line names from their parent grid,
because that would make the placement of the item dependent on layout
results; but the subgrid's tracks are still aligned to the parent's
tracks as usual.

Here's a subgrid
[example](examples/subgrid-example-1.html):

```
<style>
.grid {
 display: inline-grid-lanes;
 grid-template-rows: auto auto 100px;
 align-content: center;
 height: 300px;
 border: 1px solid;
}

.grid > * {
 margin: 5px;
 background: silver;
}
.grid > :nth-child(2n) {
 background: pink;
}

.grid subgrid {
 display: grid;
 grid: subgrid / subgrid;
 grid-row: 2 / span 2;
 grid-gap: 30px;
}
.grid subgrid > * { background: cyan; }
</style>
```

```
<div class="grid">
 <item>1</item>
 <item>2</item>
 <item>3</item>
 <subgrid>
 <item style="height:100px">subgrid.1</item>
 <item>sub.2</item>
 <item>s.3</item>
 </subgrid>
 <item>4</item>
 <item>5</item>
 <item style="width: 80px">6</item>
 <item>7</item>
</div>
```

![The rendering of the subgrid example
above.](images/subgrid-example-1.png){height="315" width="162"}

Note how the subgrid's first item (\"subgrid.1\") contributes to the
intrinsic size of the 2nd row in the parent grid. This is possible since
the subgrid specified a definite position so we know which tracks it
will occupy. Note also that trying to subgrid the parent's [stacking
axis](#stacking-axis) results
in the subgrid converting to a [grid lanes
container](#grid-lanes-container) with its [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) as the [stacking axis].

[subgrid](https://drafts.csswg.org/css-grid-2/#subgrid) that is a [grid lanes
container](#grid-lanes-container) can be referred to as a [grid lanes
subgrid]. To distinguish, a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) [subgrid] can be referred to as a
[regular grid subgrid].

### [3.3. ][ Track Repetition: the [repeat()](https://drafts.csswg.org/css-gaps-1/#funcdef-repeat-line-color-repeat) notation]
This specification introduces new keywords and grid-lanes--specific
behavior for the
[repeat()](https://drafts.csswg.org/css-gaps-1/#funcdef-repeat-line-color-repeat) notation.

#### 3.3.1. repeat(auto-fit)

In [grid lanes
containers](#grid-lanes-container) (as in regular [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container))
[auto-fit](https://drafts.csswg.org/css-grid-2/#valdef-repeat-auto-fit) acts like
[auto-fill](https://drafts.csswg.org/css-grid-2/#valdef-repeat-auto-fill), but with empty tracks
[collapsed](https://drafts.csswg.org/css-grid-2/#collapsed-grid-track). However, because placement occurs after track sizing,
[grid lanes containers] use a heuristic
to determine if a track will be occupied:

- All tracks occupied by explicitly placed items are considered
 occupied.

- With the sum of the spans of all auto-placed items as `N`,
 all unoccupied tracks up to the `N`th such track are
 considered occupied.

All tracks produced by the
[auto-fit](https://drafts.csswg.org/css-grid-2/#valdef-repeat-auto-fit) repetition and considered unoccupied by this
heuristic are assumed "empty" and are
[collapsed](https://drafts.csswg.org/css-grid-2/#collapsed-grid-track). A [collapsed grid
track] cannot accept placement of
auto-placed items.

 It is possible for an auto-placed item to be placed in
a track when
[auto-fill](https://drafts.csswg.org/css-grid-2/#valdef-repeat-auto-fill) is used that would be collapsed if
[auto-fit](https://drafts.csswg.org/css-grid-2/#valdef-repeat-auto-fit) is used if there are auto-placed items with a
span greater than 1 mixed with explicitly-placed items that leave gaps
too small for the auto-placed items.

### 3.4. Grid Axis Track Sizing

Track sizing works the same as in [CSS
Grid](https://drafts.csswg.org/css-grid-2/#algo-track-sizing), except
that when considering which items contribute to intrinsic sizes:

- All items explicitly placed in that track contribute, and

- All items with an [automatic grid
 position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position) contribute (regardless of whether they are ultimately
 placed in that track).

For example, suppose there are two
columns in the [grid axis](#grid-axis) and that

- Items A, B, and C have no explicit position.

- Item D is explicitly placed into the first column.

In this case, items A, B, C, and D all contribute to sizing the first
column, while only A, B, and C (and not D) contribute to the second
column.

In the case of spanning items with an [automatic grid
position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position), they are assumed to be placed at every possible start
position, and contribute accordingly.

For example, suppose there are 5
columns in the [grid axis](#grid-axis), with the middle having a fixed size of [100px]
and the other two being [auto]-sized. For the purpose of track
sizing, an item that spans 2 tracks and has an intrinsic contribution of
220px is essentially copied and assumed to exist:

- At grid line 1, contributing 110px to each of the first two tracks.

- At grid line 2, contributing 120px to the second track.

- At grid line 3, contributing 120px to the fourth track.

- At grid line 4, contributing 110px to the fourth and fifth tracks.

 This algorithm ensures that each track is at least big
enough to accommodate every item that is ultimately placed in it, and
does not create dependency cycles between placement and track sizing.
However, depending on the variation in sizes, tracks could be larger
than necessary: an exact fit is only guaranteed if all items are
explicitly placed in the [grid axis](#grid-axis) or all items are the same size (or matching multiples
of that size, in the case of spanning items).

#### 3.4.1. Subgrid Item Contributions

When sizing the tracks of either a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) or a [grid lanes
container](#grid-lanes-container), a [grid lanes
subgrid](#grid-lanes-subgrid) has special handling of items that have an [automatic
grid
position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position):

- Any such item is placed into every possible [parent
 grid](https://drafts.csswg.org/css-grid-2/#parent-grid) track that could be spanned by the [grid lanes
 subgrid](#grid-lanes-subgrid). (If the subgrid has a [definite grid
 position](https://drafts.csswg.org/css-grid-2/#definite-grid-position), thus only the spanned tracks; if it has an
 [automatic grid
 position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position), then all tracks in the parent grid.)

- Any such item receives the largest margin/border/padding contribution
 of each edge at which it could hypothetically be placed. If the item
 spans the entire subgrid, it receives both. (See [CSS Grid Layout
 §9](https://www.w3.org/TR/css-grid-2/#subgrid-item-contribution).)

When sizing the tracks of a [grid lanes
container](#grid-lanes-container), a
[subgrid](https://drafts.csswg.org/css-grid-2/#subgrid) with an [automatic grid
position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position) (whether a [regular grid
subgrid](#regular-grid-subgrid) or [grid lanes
subgrid](#grid-lanes-subgrid)) also has special handling of its items:

- *Every* item is placed into every possible [parent
 grid](https://drafts.csswg.org/css-grid-2/#parent-grid) track that could be spanned by the
 [subgrid](https://drafts.csswg.org/css-grid-2/#subgrid), (ignoring any explicit placement of the item).

- Explicitly-placed sub-items only receive the subgrid's
 margin/border/padding contribution when their explicit placement is at
 an edge of the subgrid (as usual).

 Explicitly placed items inside an explicitly placed
[subgrid](https://drafts.csswg.org/css-grid-2/#subgrid) only ever contribute to their actual [parent
grid](https://drafts.csswg.org/css-grid-2/#parent-grid) tracks. This is because in this case, just like in
regular [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout), the item's placement is known prior to track sizing.

#### 3.4.2. Optimized Track Sizing

Track sizing can be optimized by aggregating items that have the same
span size and placement into a single virtual item as follows:

1. Separate all the [grid
 items](https://drafts.csswg.org/css-grid-2/#grid-item) into [item groups], according to the following properties:

 - the span of the item

 - the placement of the item, i.e. which tracks it is allowed to be
 placed in

 - the item's [baseline-sharing
 group](https://drafts.csswg.org/css-align-3/#baseline-sharing-group)

 For example, an item with span 2 placed in the
 second track will be in a different group than an item with span 2
 that has an [automatic grid
 position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position).

2. For each [item group](#item-groups), synthesize a [virtual grid
 item] that has the maximum of every intrinsic size
 contribution among the items in that group.

 If the items apply [baseline
 alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment), determine the baselines of the [virtual grid
 item](#virtual-grid-item) by placing all of its items into a single
 hypothetical grid track and finding their shared baseline(s) and
 shims. Increase the group's intrinsic size contributions
 accordingly.

3. Place hypothetical copies of each [virtual grid
 item](#virtual-grid-item) into the [grid
 axis](#grid-axis) tracks in
 every position that the item could potentially occupy, and run the
 [track sizing
 algorithm](https://drafts.csswg.org/css-grid-2/#algo-track-sizing)
 with those items. The resulting track sizes are the [grid lanes
 container's](#grid-lanes-container) track sizes.

 This optimization should give the same results as the
track sizing description [above](#track-sizing); if not this is an
error, please [report it to the
CSSWG](https://github.com/w3c/csswg-drafts/issues).

## 4. Grid Lanes Item Placement

In the [grid axis](#grid-axis),
items can be *explicitly placed* into tracks and span them using the
familiar [grid-placement
properties](https://drafts.csswg.org/css-grid-2/#grid-placement-property)' syntax. Auto-placement, however, uses the [§ 4.4 Grid
Lanes Layout and Placement Algorithm](#grid-lanes-layout-algorithm),
placing each item with an [automatic grid
position](https://drafts.csswg.org/css-grid-2/#automatic-grid-position) into the "shortest" track available.

Here's a grid lanes layout
demonstrating explicitly placed and spanning items:

``` highlight
.container {
 grid-template-columns: repeat(3, auto);
}
.container > :nth-child(2) {
 /* auto-placed, but spanning. */
 grid-column: span 2;
}
.container > :nth-child(3) {
 /* manually placed */
 grid-column: 3;
}
/* all other children are auto-placed */
```

![Rendering of the example
above.](images/example-span-and-manual.png){height="445" width="770"}

### [4.1. ][ Specifying Grid Axis Item Placement: the [grid-column-\*] and [grid-row-\*] properties]
The [grid-column-\*] and [grid-row-\*] properties (and their
shorthands) apply in the [grid axis](#grid-axis) of the items and establish placement just as in regular
[grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout).

### 4.2. Placement Precision: the [fit-tolerance property]
Name:

[fit-tolerance]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [\|] infinite

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid lanes
containers](#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [grid-axis](#grid-axis) [content
box](https://drafts.csswg.org/css-box-4/#content-box) size of the [grid lanes
container](#grid-lanes-container)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

as length

[Grid lanes
containers](#grid-lanes-container) are filled by placing each [grid
item](https://drafts.csswg.org/css-grid-2/#grid-item) in whichever [grid
track](https://drafts.csswg.org/css-grid-2/#grid-track) is currently the least filled. When multiple tracks are
tied for least-filled, placing the items in order looks good. But if
tracks are only *very slightly* different heights, it can look strange
to have them not fill in order, as the height differences aren't
perceived as *meaningfully* different.

The
[fit-tolerance](#propdef-fit-tolerance) property specifies what the
threshold is for considering tracks to be "the same height", causing
them to fill in order.

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: Specifies the [tie threshold] for
 the [grid lanes
 container](#grid-lanes-container). Placement positions are considered to be equally
 good ("tied") if they are within the specified distance from the
 shortest position.

 The initial value is a "small" distance
 ([1em]) that is probably appropriate to represent "close
 enough".

[normal]

: Resolves to a [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of [1em] in [grid lanes
 layout](#grid-lanes-layout) and a [used value] of
 [0] in all other layout modes.

[infinite]

: Specifies an infinite [tie
 threshold](#grid-lanes-tie-threshold). This makes items distribute themselves strictly in
 order, without considering the length of the tracks at all.

 This value can result in consecutive items being
 placed in dramatically different positions in the [stacking
 axis](#stacking-axis),
 which can be confusing to readers. If the initial value (\`1em\`) is
 too small, consider a larger value (such as \`10em\` or \`50vh\`)
 instead of \`infinite\`.

In the following example, when placing
the 5th item, the fourth column is the shortest, but the first column is
*almost* as short.

!(images/tolerance.png){a
height="341" width="720"}

With the default tolerance of [1em], both the first and fourth
columns are considered to be \"tied\", and so the first is chosen.

If, instead, the tolerance is set to [0px], then there is no tie;
only the fourth column is a possible placement.

 We expect to apply this property to [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout) in the future also, see
[discussions](https://github.com/w3c/csswg-drafts/issues/3071) on how
that might work.

### [4.3. ][ Dense Placement: the [dense](https://drafts.csswg.org/css-grid-2/#valdef-grid-auto-flow-dense) keyword]
In [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout), [grid-auto-flow:
dense](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-flow) allows backtracking during the [grid item
placement
algorithm](https://drafts.csswg.org/css-grid-2/#auto-placement-algo).
The
[dense](https://drafts.csswg.org/css-grid-2/#valdef-grid-auto-flow-dense) keyword similarly allows backtracking during the
[grid lanes placement algorithm](#grid-lanes-layout-algorithm). However,
because item placement and sizing are intertwined in [grid lanes
layout](#grid-lanes-layout), an item can only backtrack into a compatible empty
slot if the total used size of that slot's tracks matches the used size
of the item's normal-placement tracks.

 This restriction avoids laying out the item more than
once.

### 4.4. Grid Lanes Layout and Placement Algorithm

For each of the tracks in the [grid
axis](#grid-axis), keep a [running
position] initialized to zero. Maintain also a [auto-placement
cursor], initially pointing to the first line.

For each item in [order-modified document
order](https://drafts.csswg.org/css-display-4/#order-modified-document-order):

1. If the item has a [definite grid
 position](https://drafts.csswg.org/css-grid-2/#definite-grid-position) in the [grid axis](#grid-axis), use that placement.

 (#issue-9c647ef6) Should this also update the
 placement cursor?

 Otherwise, resolve its [grid axis](#grid-axis) placement using these substeps:

 1. Starting at the first [grid
 axis](#grid-axis) line in
 the [implicit
 grid](https://drafts.csswg.org/css-grid-2/#implicit-grid), find the largest [running
 position](#running-position) of the [grid axis] tracks
 that the item would span if it were placed at this line, and
 call this position `max_pos`.
 2. Repeat the previous step for each successive line number until
 the item would no longer fit inside the grid.
 3. Let `possible lines` be the line that resulted in the
 smallest `max_pos`, and all lines that result in a
 `max_pos` within the [tie
 threshold](#grid-lanes-tie-threshold) of this `max_pos`.
 4. Choose the first line in `possible lines` greater
 than or equal to the [auto-placement
 cursor](#auto-placement-cursor) as the item's position in the [grid
 axis](#grid-axis); or if
 there are none such, choose the first one.
 5. Update the [auto-placement
 cursor](#auto-placement-cursor) to point to item's last line.

2. Place the item in its [grid axis](#grid-axis) tracks at the maximum of the [running
 position](#running-position)s of the tracks it spans.

3. Calculate the size of the item's [containing
 block](#containing-block) and then layout the item. Set the [running
 position](#running-position) of the spanned [grid
 axis](#grid-axis) tracks to
 `max_pos`` + `[`outer size`](https://drafts.csswg.org/css-sizing-3/#outer-size)` + `[`grid-gap`](https://drafts.csswg.org/css-gaps-1/#propdef-grid-gap).

 For this purpose, the [outer
 sizes](https://drafts.csswg.org/css-sizing-3/#outer-size) of the box are floored at zero.

 That is, if the box has sufficiently large negative
 margins, it won't somehow count as a negative *size* here. The
 [running position](#running-position) of a track never decreases, so a negative-sized box
 won't cause future normally-sized items placed in the track to
 overlap previous items.

4. If the [grid lanes
 container](#grid-lanes-container) uses
 [dense](https://drafts.csswg.org/css-grid-2/#valdef-grid-auto-flow-dense) packing, and there exists skipped spaces in
 the layout (e.g. due to spanning items) into which the item, as it
 is sized now, could have fit if it were placed earlier, and where
 the spanned tracks have the same total used size as the tracks into
 which it is currently placed, then instead place it into the highest
 such space. If there are multiple valid spaces within the [tie
 threshold](#grid-lanes-tie-threshold) of the highest space, place it in the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start)-most of them. Rewind the [auto-placement
 cursor](#auto-placement-cursor) and the [running
 position](#running-position) to their values before this item's placement.

 Items that *visually* intrude into preceding empty
 spaces (via negative margins, [position:
 relative](https://drafts.csswg.org/css-position-3/#propdef-position), transforms, etc.), do not affect the
 size of those empty spaces. Later items can get placed in those
 spaces and visually overlap these previous items.

 Dense packing both ignores the [auto-placement
 cursor](#auto-placement-cursor) when backfilling, and does not update it after
 placement. If there aren't any acceptable placement gaps to
 backfill, though, it places items exactly as when
 [dense](https://drafts.csswg.org/css-grid-2/#valdef-grid-auto-flow-dense) were not specified.

 This algorithm chooses the track that would result in
the item being placed as highly as possible. If there are ties, it
chooses the earliest such track, *after* the most recently placed item
if possible (ensuring that it always "moves forward" even in the
presence of ties).

#### 4.4.1. Containing Block

The [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) for a [grid
item](https://drafts.csswg.org/css-grid-2/#grid-item) participating in [grid lanes
layout](#grid-lanes-layout) is formed by its [grid
area](https://drafts.csswg.org/css-grid-2/#grid-area) in the [grid axis](#grid-axis) and the [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container)'s [content
box](https://drafts.csswg.org/css-box-4/#content-box) in the [stacking
axis](#stacking-axis).

#### 4.4.2. Placement and Writing Modes

 Like all of [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout), grid lanes layout and placement is sensitive to the
[writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode). For example, for [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), items are placed right-to-left rather than
left-to-right, whether the inline axis is a [grid
axis](#grid-axis) or a [stacking
axis](#stacking-axis).

Here's a simple
[example](examples/rtl-grid-axis.html) using [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) in the [grid
axis](#grid-axis):

```
<style>
 .grid {
 display: inline-grid-lanes;
 direction: rtl;
 grid-template-columns: repeat(4, 2ch);
 border: 1px solid;
 }

 item { background: silver }
 item:nth-child(2n+1) {
 background: pink;
 height: 4em;
 }
 </style>
```

```
<div class="grid">
 <item>1</item>
 <item style="grid-column:span 2">2</item>
 <item>3</item>
 <item>4</item>
</div>
```

![Rendering of the [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) example
above.](images/rtl-grid-axis.png){height="107" width="128"}

Here's a simple
[example](examples/rtl-masonry-axis.html) using [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) in the [stacking
axis](#stacking-axis):

```
<style>
.grid {
 display: inline-grid-lanes;
 direction: rtl;
 width: 10ch;
 column-gap: 1ch;
 grid-template-rows: repeat(4, 2em);
 border: 1px solid;
}

item { background: silver }
item:nth-child(2n+1) {
 background: pink;
 width: 4ch;
}
</style>
```

```
<div class="grid">
 <item>1</item>
 <item style="grid-row:span 2">2</item>
 <item>3</item>
 <item>4</item>
</div>
```

![Rendering of the [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) example
above.](images/rtl-masonry-axis.png){height="107" width="128"}

## 5. Sizing Grid Containers

[Sizing Grid
Containers](https://drafts.csswg.org/css-grid-2/#intrinsic-sizes) works
the same as for regular [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container) but with the following replacement for the [stacking
axis](#stacking-axis): The
[max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content) ([min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content)) of a [grid container] in
the [stacking axis] is the size of the
[stacking range](#stacking-range) when the [grid lanes
container](#grid-lanes-container) is sized under a [max-content
constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint) ([min-content
constraint](https://drafts.csswg.org/css-sizing-3/#min-content-constraint)) in that axis. The [stacking range] is the range between the
startmost [outer
edge](https://drafts.csswg.org/css-box-4/#outer-edge) among the first items of each track and the endmost
[outer edge] among the last items of each track.

Here's a simple
[example](examples/grid-intrinsic-sizing-example-1.html):

```
<style>
.grid {
 display: inline-grid-lanes;
 grid-template-columns: 50px 100px auto;
 grid-gap: 10px;
 border: 1px solid;
}
item { background: silver; margin: 5px; }
</style>
```

```
<div class="grid">
 <item style="border:10px solid">1</item>
 <item>2</item>
 <item>3</item>
 <item style="height:50px">4</item>
 <item>5</item>
 <item>6</item>
</div>
```

![Rendering of the [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) intrinsic sizing example
above.](images/grid-intrinsic-sizing-example-1.png){height="158"
width="294"}

## 6. Alignment and Spacing

### [6.1. ][ Gutters: the [row-gap](https://drafts.csswg.org/css-gaps-1/#propdef-row-gap), [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap), and [gap](https://drafts.csswg.org/css-gaps-1/#propdef-gap) properties]
[Gutters](https://drafts.csswg.org/css-grid-2/#gutters) are supported in
both axes using the
[row-gap](https://drafts.csswg.org/css-gaps-1/#propdef-row-gap) and
[column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) properties (and their
[gap](https://drafts.csswg.org/css-gaps-1/#propdef-gap)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property)). Margins do not collapse in either axis.

In the [grid axis](#grid-axis),
gutters are the spacing between adjacent [grid
tracks](https://drafts.csswg.org/css-grid-2/#grid-track), as in a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container).

In the [stacking axis](#stacking-axis), a gutter is placed before each [grid
item](https://drafts.csswg.org/css-grid-2/#grid-item) except the first in a [grid
track](https://drafts.csswg.org/css-grid-2/#grid-track), and extends across that track in the [grid
axis](#grid-axis). The gutter is
placed before item self alignment is applied, thus the self alignment of
an item does not affect the gutter's position. Each gutter has the
specified gap size, any additional space left by item placement is not
part of the gutter. For an item that spans multiple tracks, there is a
separate gutter in each track it spans; these gutters do not join across
tracks.

![Gutters in a four-column grid lanes container with spanning items;
[grid axis](#grid-axis) gutters in
orange and [stacking axis](#stacking-axis) gutters in blue. The orange gutters continue behind
spanning items, while each blue gutter remains within a single
track.](images/grid-lanes-gutters-span.png){height="402" width="466"}

### [6.2. ][ Grid-axis Alignment: the [align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content)/[justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content), [align-self](https://drafts.csswg.org/css-align-3/#propdef-align-self)/[justify-self](https://drafts.csswg.org/css-align-3/#propdef-justify-self), and [align-items](https://drafts.csswg.org/css-align-3/#propdef-align-items)/[justify-items](https://drafts.csswg.org/css-align-3/#propdef-justify-items) properties]
In the [grid axis](#grid-axis),
the [box alignment
properties](https://drafts.csswg.org/css-align-3/#box-alignment-properties) work the same as in a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container), except that
[flow-start](https://drafts.csswg.org/css-align-3/#valdef-self-position-flow-start) and
[flow-end](https://drafts.csswg.org/css-align-3/#valdef-self-position-flow-end) follow the [grid lanes
layout](#grid-lanes-layout) placement direction, as defined in [CSS Box Alignment 3
§ 4.1 Positional Alignment: the center, start, end, self-start,
self-end, flow-start, flow-end, flex-start, flex-end, left, and right
keywords](https://drafts.csswg.org/css-align-3/#positional-values). See
[CSS Grid Layout 2 §  11. Alignment and
Spacing](https://drafts.csswg.org/css-grid-2/#alignment).

### [6.3. ][ Stacking-axis Content Distribution: the [align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content)/[justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content) properties]
In the [stacking axis](#stacking-axis),
[content-distribution](https://drafts.csswg.org/css-align-3/#content-distribution)
is applied to the content as a whole, similarly to how it behaves in
block containers. More specifically, the [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) is the [stacking
range](#stacking-range).

![The extent of the alignment subject is indicated by the dashed border,
while the alignment container is the whole container (indicated by the
height of the column dividers). It defaults to start-aligning, but
depending on (in this case)
[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content), the items can move down, as a
block, to center- or end-align
vertically.](images/masonry-box.png){height="364" width="370"}

 There is only ever one [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) for these properties in the [stacking
axis](#stacking-axis), so the
unique
[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content) /
[justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content) values boil down to
[start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start),
[center](https://drafts.csswg.org/css-align-3/#valdef-self-position-center),
[end](https://drafts.csswg.org/css-align-3/#valdef-self-position-end), and [baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment). (The behavior of
[normal](https://drafts.csswg.org/css-align-3/#valdef-justify-content-normal) and
[stretch](https://drafts.csswg.org/css-align-3/#valdef-align-content-stretch) is identical to
[flow-start](https://drafts.csswg.org/css-align-3/#valdef-self-position-flow-start), and the [distributed
alignment](https://drafts.csswg.org/css-align-3/#distributed-alignment) values behave as their [fallback
alignments](https://drafts.csswg.org/css-align-3/#fallback-alignment).) If the [grid
items](https://drafts.csswg.org/css-grid-2/#grid-item) overflow the [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container)'s [content
box](https://drafts.csswg.org/css-box-4/#content-box) in the [stacking axis], then
the [stacking range](#stacking-range) will be larger than the [grid
container]'s [content
box].

### [6.4. ][ Stacking-axis Self Alignment: the [align-self](https://drafts.csswg.org/css-align-3/#propdef-align-self)/[justify-self](https://drafts.csswg.org/css-align-3/#propdef-justify-self) and [align-items](https://drafts.csswg.org/css-align-3/#propdef-align-items)/[justify-items](https://drafts.csswg.org/css-align-3/#propdef-justify-items) properties]
In the [stacking axis](#stacking-axis), the [self-alignment
properties](https://drafts.csswg.org/css-align-3/#self-alignment-properties) only apply to items that are adjacent to a "gap" in the
layout, i.e. placed in their [grid
track](https://drafts.csswg.org/css-grid-2/#grid-track)(s) either immediately before a spanning item or as the
last item. The [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) is the item's [margin
box](https://drafts.csswg.org/css-box-4/#margin-box), and the [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container) is that box plus the adjacent "gap". For the last item
in a track, the [alignment container]
extends to the lowest bottom outer edge among all the last items in all
tracks.

![The three highlighted items are the only ones with \"gaps\" following
them, so they're the only ones that will respond to
[align-items](https://drafts.csswg.org/css-align-3/#propdef-align-items). Their [alignment
containers](https://drafts.csswg.org/css-align-3/#alignment-container) are indicated by the cross-hatched
areas.](images/align-self.png){a
height="302" width="724"}

<figure>
<a href="https://drafts.csswg.org/css-align-3/#propdef-align-self"
id="ref-for-propdef-align-self②" class="css"
data->align-self: start</a>
<a href="https://drafts.csswg.org/css-align-3/#propdef-align-self"
id="ref-for-propdef-align-self③" class="css"
data->align-self: end</a>
<img src="images/self-align-stack-start.png" width="448" height="440"
a />
<img src="images/self-align-stack-end.png" width="448" height="440"
a />
<figcaption>Alignment of an item does not affect the size or position of
other items' <a
href="https://drafts.csswg.org/css-align-3/#alignment-container"
id="ref-for-alignment-container③" data->alignment
containers</a>.</figcaption>
</figure>

### 6.5. Baseline Alignment

Item [baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) inside the [grid axis](#grid-axis) tracks works as usual for a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container), and the [grid container]'s
baseline is determined the same as for a regular [grid
container] in that axis.

[Baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) is not supported in the [stacking
axis](#stacking-axis). The
[baseline alignment] values of the
[self-alignment
properties](https://drafts.csswg.org/css-align-3/#self-alignment-properties) on [grid
items](https://drafts.csswg.org/css-grid-2/#grid-item) are treated as their [fallback
alignment](https://drafts.csswg.org/css-align-3/#fallback-alignment) in this axis. The first baseline set of the [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) in this axis is generated from the highest [alignment
baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) among the [grid items] placed
first in each track, and the last baseline set from the lowest
[alignment baseline] among the [grid
items] placed last in each track.

 Whether an item is "first" or "last" depends only on
placement (including
[dense](https://drafts.csswg.org/css-grid-2/#valdef-grid-auto-flow-dense) packing adjustments), and is not affected by its
actual position on the page, e.g. negative margins or [relative
positioning](https://www.w3.org/TR/CSS2/visuren.html#x34) are not considered.

## 7. Fragmentation

### 7.1. Fragmentation in the stacking axis

Each [grid axis](#grid-axis) track
is fragmented independently in the [stacking
axis](#stacking-axis). If a
[grid
item](https://drafts.csswg.org/css-grid-2/#grid-item) is fragmented, or has a [forced
break](https://drafts.csswg.org/css-break-4/#forced-break) before/after it, then the [running
position](#running-position)
for the tracks that it spans in the [grid axis]
are set to the size of the
[fragmentainer](https://drafts.csswg.org/css-break-4/#fragmentainer) so that no further items will be placed in those
tracks. An item that is split into multiple fragments retains its
placement in the [grid axis] for all its
fragments. A grid item that is pushed, however, is placed again by the
next [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) fragment. Placement continues until all items are
placed or pushed to a new fragment.

Here's an
[example](examples/fragmentation-block-axis-example.html) illustrating
fragmentation of grid lanes layout with
[stacking](#stacking-axis) in
its [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis). It renders like this:

<figure style="max-width:100%">

<figcaption>Visualization of fragmentation in a <a
href="https://drafts.csswg.org/css-writing-modes-4/#block-axis"
id="ref-for-block-axis④" data->block-axis</a> <a
href="#grid-lanes-layout" id="ref-for-grid-lanes-layout①②"
data->grid lanes layout</a>.</figcaption>
</figure>

### 7.2. Fragmentation in the Grid Axis

Fragmentation in the [grid axis](#grid-axis) of a [grid lanes
container](#grid-lanes-container) is also supported. In this case the fragmentation
behaves more like in a regular [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container); however, there's a separate step to determine which
[grid-axis] track each item is placed into, before
fragmentation occurs.

Here's an
[example](examples/fragmentation-inline-axis-example.html) illustrating
fragmentation of grid lanes layout with
[stacking](#stacking-axis) in
its [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis). In this case the breaks occurs between the
[grid-axis](#grid-axis) rows. It
renders like this:

<figure style="max-width:100%">

<figcaption>Visualization of fragmentation in the <a
href="https://drafts.csswg.org/css-writing-modes-4/#block-axis"
id="ref-for-block-axis⑤" data->block axis</a> with <a
href="https://drafts.csswg.org/css-writing-modes-4/#inline-axis"
id="ref-for-inline-axis⑤" data->inline-axis</a> <a
href="#grid-lanes-layout" id="ref-for-grid-lanes-layout①③"
data->grid lanes layout</a>.</figcaption>
</figure>

## 8. Absolute Positioning

[Grid-aligned absolute-positioned
descendants](https://drafts.csswg.org/css-grid-1/#abspos-items) are
supported in [grid lanes
containers](#grid-lanes-container) just as for regular [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container); however, in the [stacking
axis](#stacking-axis) there
exist only two lines (in addition to the [auto] lines) for
placement:

- line 1 (line -2) corresponds to the start edge of the [stacking
 range](#stacking-range)

- line 2 (line -1) corresponds to the end edge of the [stacking
 range](#stacking-range)

It might be useful to define a static
position in the [stacking axis](#stacking-axis). Maybe it could defined as the max (or min?) current
[running position](#running-position) of the [grid-axis](#grid-axis) tracks at that point? Or the end of the item before it?

## 9. Graceful Degradation

Typically, a grid lanes design can be expected to degrade quite nicely
in a UA that supports [grid
layout](https://drafts.csswg.org/css-grid-2/#grid-layout) but not [grid lanes
layout](#grid-lanes-layout).

Here's an [example](examples/graceful-degradation-example.html) to
illustrate this.

```
display: grid;
display: grid-lanes; /* ignored in UAs that don't support grid lanes layout */
grid-template-columns: 150px 100px 50px;
```

This creates a layout with three columns, but will have \"more gaps\" in
the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) if the UA doesn't support [grid lanes
layout](#grid-lanes-layout). Here's what it looks like with grid lanes support for
comparison:

<figure>

<figcaption>Rendering of the example in a UA with grid lanes
support.</figcaption>
</figure>

## 10. Acknowledgements

Special thanks goes to Cameron McCormack who wrote a masonry layout
explainer document (from which was lifted the Background chapter) and
presented it to the CSSWG, and to Mats Palmgren who developed the
original version of this specification alongside a prototype
implementation in Firefox. Thanks also to everyone who provided feedback
on the [initial
proposal](https://github.com/w3c/csswg-drafts/issues/4650) for this
feature as well as the [many subsequent
issues](https://github.com/w3c/csswg-drafts/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22topic%3A%20masonry%22),
and to Noam Rosenthal particularly for [naming
it](https://martinfowler.com/bliki/TwoHardThings.html).

## 11. Security Considerations

As a layout specification, this spec introduces no new security
considerations beyond that exposed by CSS layout in general.

## 12. Privacy Considerations

As a layout specification, this spec introduces no new privacy
considerations beyond that exposed by CSS layout in general.

## [ Changes]
### [ Additions Since Level 2]
The following features have been added since [Level
2](http://www.w3.org/TR/css-grid-2/):

- Added [grid lanes
 layout](#grid-lanes-layout).
- Expanded [repeat(auto-fill)] and [repeat(auto-fit)] to
 accept indefinite track sizing functions. ([Issue
 9321](https://github.com/w3c/csswg-drafts/issues/9321), [Issue
 12899](https://github.com/w3c/csswg-drafts/issues/12899))
- Introduced the
 [fit-tolerance](#propdef-fit-tolerance) property.

### [ Recent Changes]
The following changes have been made since the [21 January 2026 Working
Draft](https://www.w3.org/TR/2026/WD-css-grid-3-20260121/):

- Clarified that [flow-start]/[flow-end] and their
 [flex-start](https://drafts.csswg.org/css-align-3/#valdef-self-position-flex-start)/[flex-end](https://drafts.csswg.org/css-align-3/#valdef-self-position-flex-end) aliases follow the item-placement direction.
 ([Issue 14052](https://github.com/w3c/csswg-drafts/issues/14052))

- Dropped the [item-\*] proposal for unified flow controls across
 layout modes. ([Issue
 11480](https://github.com/w3c/csswg-drafts/issues/11480))

- Renamed
 [flow-tolerance](https://www.w3.org/TR/css-grid-3/#propdef-flow-tolerance) to
 [fit-tolerance](#propdef-fit-tolerance). ([Issue
 10884](https://github.com/w3c/csswg-drafts/issues/10884))

- Simplified the sizing calcs for automatic-positioned
 [subgrids](https://drafts.csswg.org/css-grid-2/#subgrid) in a [grid lanes
 container](#grid-lanes-container). ([Issue
 10926](https://github.com/w3c/csswg-drafts/issues/10926))

- Clarify that baseline values for [self-alignment
 properties](https://drafts.csswg.org/css-align-3/#self-alignment-properties) in the stacking axis fall back to their fallback
 value. ([Issue
 10275](https://github.com/w3c/csswg-drafts/issues/10275))

- Updated definition for the grid lanes gutters. ([Issue
 14153](https://github.com/w3c/csswg-drafts/issues/14153), [Issue
 14154](https://github.com/w3c/csswg-drafts/issues/14154))

See also [earlier
changes](https://www.w3.org/TR/2026/WD-css-grid-3-20260121/#recent-changes).
