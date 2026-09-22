(rect    :x :y :w :h      :position/:matrix :style :visible :data :name               <children> ) ;; can refer to $frame, $bbox
(circle  :x :y :r         :position/:matrix :style :visible :data :name               <children> )
(ngon    :x :y :r :sides  :position/:matrix :style :visible :data :name               <children> ) ;; :sides is integer
(ellipse :x :y :w :h      :position/:matrix :style :visible :data :name               <children> )
(ellipse :p1 :p2 :major   :position/:matrix :style :visible :data :name               <children> ) ;; :p1 (x1 12) :p2 (x2 y2)
(polygon :vertices        :position/:matrix :style :visible :data :name               <children> ) ;; :vertices #((x1 y1) (x2 y2)...)
(line    :vertices        :position/:matrix :style :visible :data :name               <children> ) ;; :vertices #((x1 y1) (x2 y2)...)
(line    :vertices        :position/:matrix :style :visible :data :name               <children> ) ;; :vertices #((x1 y1) (x2 y2)...)
(hermite :vertices        :position/:matrix :style :visible :data :name :tangents     <children> ) ;; :vertices #((x1 y1) (x2 y2)...)
(text    :font            :position/:matrix :style :visible :data :name               <string>   )
(pin     :x :y :r :id     :position/:matrix :style :visible :data :name :bubble :ieee            ) ;; no children
(group   :origin          :position/:matrix :style :visible :data :name               <children> )
(net     :name            :vertices :segments :juncsize :style :data #(<pin ids>)                ) ;; #(pin ids) can go anywhere like the :key values
(bus     :name :n 8       :vertices :segments :juncsize :style :data                             )  ;; name contains $i
(harness :name            :vertices :segments :juncsize :style :data                      <nets> )
(repeat :index :index ... :position/:matrix <elements> ) ;; elements can refer to $index

;; A property expects as a following value either a literal or a form/expression of the same name
;; for example :apple might expect a string, float, int, or (apple ...)
;; depending on the type of thing that :apple is expected to fill.
;; In general a property's values can be used directly, recursively, in the parent 
;; if they don't collide with another property's properties or the parent's properties
;; and if the keyword name is the same as the form name and the argument resolves by type
;; For example
;;  (rect :pen "#97d8879f") -> :pen implies (pen...) and given "#97d8879f", :color is the ony arg in (pen...) that takes a string, so...
;;  (rect :pen (pen :color "#97d8879f")) -> :color implies (color ...) with string arg, so...
;;  (rect :pen (pen :color (color "#97d8879f")))
;; but (style :stops :colors ...) cannot expend as (style :fill ...) because both lineargradient and radialgradient take :stops and :colors

float = expression resolving to float
int = expression resolving to integer
string expression resolving to string
:x,y,w,h,r,major: float
:point = (point :x :y)
:p1,p2: (point, point)
:position = point
:origin = point
:vertices #(point point ...)
:sides, n: int
:style = (style :pen) ;; ambiguous whether this applies to closed shapes or lines, depends on where it is used
:style = (style :pen :corner :fill)           ;; used for closed shapes, warning when used on lines, curves
:style = (style :pen :corner :arrow1 :arrow2) ;; used for lines, curves; arrows can be left blank; warning if used on fills
:pen = (pen :color :weight :pattern)
:corner = float        ;; corner radius for all corners
:corner = #(float ...) ;; one float per corner radius
:fill = (solidfill :color )
:fill = (linearGradient :vector :stops :colors) ;; :vector #((0 0) (100 0)) :stops #(0 0.25 0.9) :colors #(red green blue)
:fill = (radialGradient :position :stops :colors)
:weight = float
:pattern = :solid | :dash | :dot
:arrow1,2 = float | nil
:color = steelblue                  ;; a standard web color name
:color = #4682b47f                ;; hex, unquoted — steelblue's own rgb (70 130 180), alpha 127/255
:color = "#4682b47f"              ;; the same hex value, quoted — identical to the line above
:color = (int int int)              ;; when it starts with a number, rgb is assumed
:color = (int int int int)
:color = (float float float)
:color = (float float float float)
:color = (rgb int int int)        
:color = (rgb int int int int)
:color = (rgb float float float)
:color = (rgb float float float float)
:color = (hsv int int int)        
:color = (hsv int int int int)
:color = (hsv float float float)
:color = (hsv float float float float)
:color = hsv#4d00cc                 ;; tagged hex, fused with no space — hh ss vv
:color = hsv#4d00cc7f               ;; tagged hex, fused with no space — hh ss vv aa
:color = "hsv#4d00cc"               ;; tagged hex, fused with no space — hh ss vv
:color = "hsv#4d00cc7f"             ;; tagged hex, fused with no space — hh ss vv aa
:matrix (matrix float float float float float float) ;; mij are floats for affine matrix
:matrix (float float float float float float)   ;; 6-tuples of floats
:visible = bool
:name,:id = string
:name,id = (text :position :style :font :halign :valign)
:font = (font :family :size)
:family = string
:size = float
:halign = :left | :middle | :right
:valign = :top | :middle | :bottom
:bubble = bool
:ieee = :clk | :invert | :open-drain
segment-target = pin_id | vertex_index
:segments = #(segment-target segment-target ...)
:juncsize = float
:data = (data :position :visible #(nvpair nvpair))
nvpair = (:name :value)
:data = (data :position datapoint datapoint ...)
datapoint = (datapoint :position :name :value :nameStyle :valueStyle :visible)
:index = name integer
:index = name range ;; range can be [2..5 12 15 14..8] or list of numbers or list of strings, etc.

;; can symbols have variants -- yes!
(schSymbol :name <shapes>) ;; pins must not be in another shape, but okay to be in a group, no nets or components allowed
(pcbFootprint :name shape1 shape2 ...) ;; ditto
(pcbFootprint :name (variant :name shape1 shape2 ...) (variant ...))  ;; should there be a # somewhere, or is it enough to trail with variants?
(component :name :data :symbols :footprints :pinmap)
;; need some way to collect small subcircuits and put them on one page for printing
(schSheet :shapes :components :nets :data) ;; needs to be both anonymous subcircuit viewer and main sheet
(pcbSheet ... to be determined)






