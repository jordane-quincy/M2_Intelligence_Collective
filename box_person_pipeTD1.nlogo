;;Exo TD
;;Maxime DEGRES
;;Jean-Baptiste DURIEZ
;;Jordane QUINCY


globals[
  direction
  workspace-patches       ;; Patches où peuvent se déplacer les turtles.
  pipe-patches            ;; Passage d'un workspace à l'autre.
  world_width
  world_height
  left-light-patches      ;; Couleurs des feux permettant le passage ou le blocage des personnes dans le pipe.
  right-light-patches     ;; Rouge ? on bloque et vert et bien on laisse passer...
  current-ticks_lights    ;; Nombre de ticks indiquant quand un feu change de couleur
  open ; the open list of patches
  closed ; the closed list of patches
  optimal-path ; the optimal path, list of patches from source to destination
  people-in-pipe          ;; Nombre de personnes dans le tunnel.
  leftStayRed
  rightStayRed
]
breed[box]
breed[person]

person-own [
  hold_box
  path ; the optimal path from source to destination
  current-path ; part of the path that is left to be traversed
  pathFound
  from?                   ;; [left, right] en fonction du patche franchi.
  isInPipe ;If the person go through green patch, then he's in the tunnel
]

patches-own[
  belongsToWorkspace?     ;; Boolean that allow to determine if the patch selected belongs to the workspace
  belongsToPipe?          ;; Boolean that allow to determine if the patch selected belongs to the pipe
  parent-patch        ; path's predecessor
  f                   ; the value of knowledge plus heuristic cost function f()
  g                   ; the value of knowledge cost function g()
  h                   ; the value of heuristic cost function h()
  colorForAStar       ; color of the patch for a star (we don't want the patch colored in the environment)
]

box-own[
  current-ticks           ;; Give the number of ticks at which the box become yellow.
  source-x
  source-y
  target-x                ;; Target abscissa where the box need to be released after taken by a person.
  target-y                ;; Target ordonate where the box need to be released after taken by a person.
  oldTargetX
  oldTargetY
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set-default-shape person "person"
  set-default-shape box "box"
  set world_width 70
  set world_height 50
  set leftStayRed false
  set rightStayRed false

  resize-world 0 world_width 0 world_height

  setup-patches
  setup-boxes
  setup-persons

  reset-ticks
end

to setup-patches
  ;;GLOBAL PATCHES
  ask patches[
    set belongsToWorkspace? false
    set belongsToPipe? false
    ;set plabel "patch"
    ;show pxcor show pycor
  ]
  ;;WORKSPACE PATCHES
  set workspace-patches patches with [
   (
    pxcor < max-pxcor / workspace_width and
    pxcor > 1 and
    pycor > max-pycor / workspace_height and
    pycor < max-pycor - (max-pycor / workspace_height)
   )
   or
   (
    pxcor > max-pxcor - (max-pxcor / workspace_width) and
    pxcor < max-pxcor - 1 and
    pycor > max-pycor / workspace_height and
    pycor < max-pycor - (max-pycor / workspace_height)
   )
  ]
  ask workspace-patches[
    set belongsToWorkspace? true
    set belongsToPipe? false
    set pcolor white
    ;set plabel "workspace"
  ]

  ;;PIPE PATCHES
  let min-x (max-pxcor / workspace_width)
  let max-x (max-pxcor - (max-pxcor / workspace_width))
  let min-y (max-pycor / 2 - max-pycor / 20 + pipe_width)
  let max-y (max-pycor / 2 + max-pycor / 20)
   set pipe-patches patches with
   [
      pxcor > min-x and
      pxcor < max-x and
      pycor > min-y and
      pycor < max-y
   ]
  ask pipe-patches[
    set belongsToWorkspace? false
    set belongsToPipe? true
    set pcolor white
    ;set plabel "pipe"

  ]
  ;;LIGHT PATCHES

  set left-light-patches patches with
  [
    pxcor > min-x and
    pxcor < min-x + 1 and
    pycor > min-y and
    pycor < max-y
  ]
  ask left-light-patches
  [
    set pcolor red
  ]
  set right-light-patches patches with
  [
    pxcor > max-x - 1 and
    pxcor < max-x and
    pycor > min-y and
    pycor < max-y
  ]
  ask right-light-patches
  [
    set pcolor green
  ]
  set current-ticks_lights 0

end

to setup-boxes

  create-box nb_boxes[
    set current-ticks 0
      set color one-of [ blue red ]
      set size 1

      ; set depart dans le workspace et si la place est libre
      let start-x 0
      let start-y 0
      ask one-of workspace-patches with [ any? box-here = false] [
        set start-x pxcor
        set start-y pycor
      ]
      setxy start-x start-y
      set source-x start-x
      set source-y start-y
      ;print (word "source-x : " source-x ", source-y : " source-y )


      ; set destination dans le workspace et si la place est libre
      let stop-x 0
      let stop-y 0
      ask one-of workspace-patches with [ any? box-here = false] [
        set stop-x pxcor
        set stop-y pycor
      ]

      set target-x stop-x
      set target-y stop-y
      ;print (word "target-x : " target-x ", target-y : " target-y )

  ]
end



to setup-persons
  create-person nb_persons[
    set color violet
    set pathFound false
    set isInPipe false
    set size 1
    while [[belongsToWorkspace?] of patch-here = false]
    [
      setxy random-xcor random-ycor
    ]
    set hold_box false
  ]
end

to find-shortest-path-to-destination [xSource ySource xDest yDest]
  print (word "xDest yDest : " xDest " " yDest)
  set path find-a-path (patch xSource ySource) (patch xDest yDest)
  set optimal-path path
  set current-path path
  set pathFound true
end

; the actual implementation of the A* path finding algorithm
; it takes the source and destination patches as inputs
; and reports the optimal path if one exists between them as output
to-report find-a-path [ source-patch destination-patch ]

  ; initialize all variables to default values
  let search-done? false
  let search-path []
  let current-patch 0
  set open []
  set closed []

  print (word "source-patch : " source-patch)
  print (word "destination-patch : " destination-patch)

  ; add source path in the open list
  set open lput source-patch open

  ; loop until we reach the destination or the open list becomes empty
  while [ search-done? != true ]
  [
    ifelse length open != 0
    [
      ; sort the parches in open list in increasing order of their f() values
      set open sort-by [[f] of ?1 < [f] of ?2] open

      ; take the first patch in the open list
      ; as the current patch (which is currently being explored (n))
      ; and remove it from the open list
      set current-patch item 0 open
      set open remove-item 0 open

      ; add the current patch to the closed list
      set closed lput current-patch closed

      ask current-patch
      [
        ; if any of the neighbors is the destination stop the search process
        ifelse any? neighbors4 with [ (pxcor = [ pxcor ] of destination-patch) and (pycor = [pycor] of destination-patch)]
        [
          set search-done? true
        ]
        [
          ; the neighbors should not be obstacles or already explored patches (part of the closed list)
          ask neighbors4 with [ pcolor != black and (not member? self closed) and (self != parent-patch) ]
          [
            ; the neighbors to be explored should also not be the source or
            ; destination patches or already a part of the open list (unexplored patches list)
            if not member? self open and self != source-patch and self != destination-patch
            [
              set colorForAStar 45

              ; add the eligible patch to the open list
              set open lput self open

              ; update the path finding variables of the eligible patch
              set parent-patch current-patch
              set g [g] of parent-patch  + 1
              set h distance destination-patch
              set f (g + h)
            ]
          ]
        ]
        if self != source-patch
        [
          set colorForAStar 35
        ]
      ]
    ]
    [
      ; if a path is not found (search is incomplete) and the open list is exhausted
      ; display a user message and report an empty search path list.
      user-message( "A path from the source to the destination does not exist." )
      report []
    ]
  ]

  ; if a path is found (search completed) add the current patch
  ; (node adjacent to the destination) to the search path.
  set search-path lput current-patch search-path

   ; trace the search path from the current patch
  ; all the way to the source patch using the parent patch
  ; variable which was set during the search for every patch that was explored
  let temp first search-path
  while [ temp != source-patch ]
  [
    ask temp
    [
      set colorForAStar 85
    ]
    set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp
  ]

  ; add the destination patch to the front of the search path
  set search-path fput destination-patch search-path

  ; reverse the search path so that it starts from a patch adjacent to the
  ; source patch and ends at the destination patch
  set search-path reverse search-path

  ; report the search path
  report search-path
end

; make the turtle traverse (move through) the path all the way to the destination patch
to move [xSource ySource xDest yDest]
  if length current-path != 0 [
    go-to-next-patch-in-current-path xSource ySource xDest yDest
  ]
  if length current-path = 0
  [
    pu
  ]
end

to go-to-next-patch-in-current-path [xSource ySource xDest yDest]
  face first current-path
  let patchAheadIsRed false
  let personInTunnel isInPipe
  ask patch-ahead 1 [
    if pcolor = 15 and not personInTunnel[
      set patchAheadIsRed true
    ]
  ]
  if not patchAheadIsRed [
    fd 1
    move-to first current-path
    if [pxcor] of patch-here != xSource and [pycor] of patch-here != ySource and [pxcor] of patch-here != xDest and [pxcor] of patch-here != yDest
    [
      ask patch-here
      [
        set colorForAStar black
      ]
    ]
    set current-path remove-item 0 current-path
  ]

end



to-report accessDenied
  ;on ne peut pas se déplacer sur un patch de couleur noir
  let patchColor 9.9
  let boxPresentsInPatchAhead false
  ask patch-ahead 1[
    set patchColor pcolor
    if box-here = nobody [
      set boxPresentsInPatchAhead true
    ]
  ]
  let restrictedPatch false
  ;Si on a une boite, on ne peut pas se déplacer sur la même case qu'une autre boîte
  if hold_box and boxPresentsInPatchAhead[
    set restrictedPatch true
  ]
  ;On ne peut pas traverser le tunnel si la couleur du patch est rouge
  ;Mais si la personne est dans le tunnel, elle peut alors passer sur un patch rouge
  let colorPatchAheadIsRed patchColor = 15

  ;;Une personne sans boite ne peut pas rentrer dans le tunnel
  if not hold_box and (patchColor = 15 or patchColor = 55) [
    set restrictedPatch true
  ]
  report patchColor = 0 or restrictedPatch or (colorPatchAheadIsRed and not isInPipe)
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ask person[
    ifelse not hold_box [
      randomMove
      take-box
    ]
    [
      let xDest 0
      let yDest 0
      let xSource 0
      let ySource 0
      ;my-links.end1 is the box of the link with myself
      ;we used "ask box-here" before but sometimes it is not working because the box is not in the patch
      ;for example, we had patch (22,66) and box (22.31154245, 66.21545441545454), so box-here always returned nobody
      ;So it is better to use the link that we made when we took the box
      ;ask my-links [
        ;ask end1 [
          ;set xDest target-x
          ;set yDest target-y
         ; set xSource source-x
        ;  set ySource source-y
       ; ]
      ;]
      ask box-here [
        set xDest target-x
         set yDest target-y
         set xSource source-x
         set ySource source-y
      ]
      ;si on n'a pas encore trouvé le chemin on le cherche
      if not pathFound
      [
        find-shortest-path-to-destination xcor ycor xDest yDest
      ]
      ;si on a déjà trouvé le chemin on suit le chemin
      if pathFound
      [
        move xSource ySource xDest yDest
      ]
      if length current-path = 0
      [
        let-box
      ]

    ]
    ;set if we're in pipe or not
    let personInPipe false
    ask patch-here [
      set personInPipe belongsToPipe?
    ]
    set isInPipe personInPipe
  ]
  ask box with[color = yellow][
    if(ticks - current-ticks >= 50)
    [
      set color one-of [red blue]
    ]
  ]
  change-lights
  tick
end

to change-lights
  ifelse ticks - current-ticks_lights >= 50
  [
    ask left-light-patches
    [
      ifelse pcolor = green
      [
        set pcolor red
        set leftStayRed true

      ]
      [
        if not leftStayRed [
          let personInPipe false
          ask person with [isInPipe] [
            set personInPipe true
          ]
          if not personInPipe [
            set pcolor green
            set current-ticks_lights ticks
          ]
        ]
      ]
    ]
    ask right-light-patches
    [
      ifelse pcolor = green
      [
        set pcolor red
        set rightStayRed true
      ]
      [
        if not rightStayRed [
          let personInPipe false
          ask person with [isInPipe] [
            set personInPipe true
          ]
          if not personInPipe [
            set pcolor green
            set current-ticks_lights ticks
          ]
        ]
      ]
    ]
  ]
  [
    set leftStayRed false
    set rightStayRed false
  ]
end

to randomMove
  rt random 46
  lt random 46
  if (not can-move? 1) or (accessDenied) [ rt 180 ]
  fd 1
end

to move_to
  rt random 50
    lt random 50
  fd 1
    ;; Si la personne tient une boite
    if[belongsToWorkspace? or belongsToPipe?] of patch-here = false ;; et si elle s'est déplacée hors du Workspace et Pipe
    [
      fd -1 ;; Revenir en arriere
    ]
end

to take-box
  if not hold_box ;; Si la personne ne tient pas de boite
  [
     if box-here != nobody ;; et si une boite est présente
     [
       ask box-here[
       if count (my-links) = 0 and (color = red or color = blue) ;;and count ((box-on neighbors) with [color]) > 1
       [
         create-link-with myself[set tie-mode "fixed"]
         ask myself[set hold_box true]
         print (word "boite prise a amener en : " target-x ", " target-y )
        ]
       ]
     ]
  ]
end

to let-box
  let boxDropped false
  let actualX xcor
  let actualY ycor
  if hold_box[
    ;my-links.end1 is the box of the link with myself
    ;we used "ask box-here" before but sometimes it is not working because the box is not in the patch
    ;for example, we had patch (22,66) and box (22.31154245, 66.21545441545454), so box-here always returned nobody
    ;So it is better to use the link that we made when we took the box
    ask my-links [
      ask end1 [
        set current-ticks ticks
       ;;check with xcor and ycor of the person (the box can not be on a integer number with the link and so the comparaison will be false
       if patch-here = patch xcor ycor
       [
         print "On se prépare à lacher la boîte"
         set oldTargetX target-x
         set oldTargetY target-y
         ask my-links [die]
         set color yellow
         set boxDropped true
         ; set depart dans le workspace et si la place est libre
         let start-x actualX
         let start-y actualY
         setxy start-x start-y
         set source-x start-x
         set source-y start-y
         print (word "drop box at : " source-x " " source-y )
         ; set destination dans le workspace et si la place est libre
         let stop-x 0
         let stop-y 0
         ask one-of workspace-patches with [ any? box-here = false] [
           set stop-x pxcor
           set stop-y pycor
         ]

         set target-x stop-x
         set target-y stop-y
         print (word "next target-x : " target-x ", target-y : " target-y )
       ]
      ]
    ]
   ]
  if boxDropped[
    set pathFound false
    set hold_box false
    print "boxDropped !"
  ]
  ;ask my-out-links[die]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
930
551
-1
-1
10.0
1
10
1
1
1
0
1
1
1
0
70
0
50
1
1
1
ticks
30.0

BUTTON
28
13
91
46
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
119
13
182
46
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
58
183
91
nb_boxes
nb_boxes
1
100
23
1
1
NIL
HORIZONTAL

SLIDER
11
104
183
137
nb_persons
nb_persons
1
100
29
1
1
NIL
HORIZONTAL

TEXTBOX
51
179
201
197
Workspace / Pipe
11
0.0
0

SLIDER
16
208
188
241
pipe_width
pipe_width
0
4
1
1
1
NIL
HORIZONTAL

SLIDER
17
261
189
294
workspace_width
workspace_width
3
8
4
1
1
NIL
HORIZONTAL

SLIDER
16
309
188
342
workspace_height
workspace_height
3
10
3
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
