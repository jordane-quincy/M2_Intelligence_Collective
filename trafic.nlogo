;;Exo TP Traffic
;;Maxime DEGRES
;;Jean-Baptiste DURIEZ
;;Jordane QUINCY


breed[cars]
breed[banners]

globals[
  grid_x_inc
  grid_y_inc
  intersections
  roads
  sidewayColor
  nbrCarChangeDirectionDueToPatience
  nbrAccidents
]

patches-own[
  intersection?     ;; booleen a vrai si le patch est dans un carrefour
  road?             ;; boolean a vrai si le patch est sur la route.
  dir ;; "N", "E", etc.
  accidentCounted
  ;;TODO : cf modele librairy pour les accidents
]

cars-own[
  speed                    ;; Vitesse courante
  speed-max                ;; Vitesse desiree de l’agent
  patience                 ;; Niveau de patience (dans un stop ou pour depasser un autre agent)
  cptAvancement            ;; Permet de compter le nbr de fois qu'on avance sans s'arrêter
  change?                  ;; Vraie si le vehicule veut changer de voies
  direction                ;; La direction desiree courante (nord, sud, est, ouest)
  next_direction_          ;; La direction qu'il va prendre lors de l'arrivée sur le carrefour
  num_intersection_        ;; Permet de savoir si on peut set la prochaine direction
  wait-time                ;; Le temps passé depuis son dernier deplacement
  isInitialising?          ;; La voiture est en train d'être initialisé (true tant que la voiture n'est pas toute seule sur un patch, false sinon)
  turned?                  ;; Permet de savoir s'il on à tourner
  lane_                    ;; Numero de la voie sur laquelle se trouve la voiture avant l'intersection
]
banners-own[
  frequenceRedGreen ;Nombre de ticks avant passage du rouge au vert et du vert au orange.
  frequenceOrange   ;Nombre de ticks avant passage du orange au rouge.
  time  ;Nombre de ticks
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup_globals
  setup-patches
  setup-cars
  setup-banners
  setup-lights
  reset-ticks
end

to setup_globals
  set grid_x_inc floor(world-height / grid_x )
  ifelse grid_y = 0 [
    set grid_y_inc world-width * 2
  ]
  [
    set grid_y_inc floor(world-width / grid_y)
  ]
  set sidewayColor brown
end

to setup-banners
  ask banners[
    set frequenceRedGreen 50
    set frequenceOrange frequenceRedGreen / 5
    set time 0
  ]
end

to creerIntersection [X Y val]
  ;creation du banner au millieu de l'intersection
  let Xmin (X - road_size)
  let Xmax (X + road_size)
  let Ymin (Y - road_size)
  let Ymax (Y + road_size)
  create-banners 1 [
    setxy X Y
    set label val
    set hidden? false
  ]

  ;on prends les patchs dans le carre autour du banner
  ask patches with [(pxcor >= Xmin and pxcor < Xmax and pycor >= Ymin and pycor < Ymax)] [
    ;set pcolor blue
    set intersection? true
  ]

  ;ask patches with [(pxcor >= Xmin and pxcor < Xmax)] [
  ;  if (pcolor != blue) [
  ;    set pcolor white
  ;  ]
  ;]
  ;ask patches with [(pycor >= Ymin and pycor < Ymax)] [
  ;  if (pcolor != blue) [
  ;    set pcolor white
  ;  ]
  ;]

end

;Initialisation des routes
to setup-road
  let pos_x min-pxcor + 1 + floor (grid_y_inc / 2)
  let Xmin pos_x - road_size
  let Xmax pos_x + road_size

  while [pos_x < max-pxcor] [
     set roads patches with [pxcor >= Xmin and pxcor < Xmax and pycor <= max-pycor and pycor >= min-pycor]
     ask roads [
       set road? true
       if (intersection? = false) [
         set pcolor white
         ifelse (pxcor < pos_x) [
           set dir "S"
         ]
         [
           set dir "N"
         ]
       ]
     ]
     set pos_x pos_x + grid_y_inc
     set Xmin pos_x - road_size
     set Xmax pos_x + road_size
  ]
  let pos_y min-pycor + 1 + floor (grid_x_inc / 2)
  let Ymin pos_y - road_size
  let Ymax pos_y + road_size
  while [pos_y < max-pycor] [
     set roads patches with [pycor >= Ymin and pycor < Ymax and pxcor <= max-pxcor and pxcor >= min-pxcor]
     ask roads [
       set road? true
       if (intersection? = false) [
         set pcolor white
         ifelse (pycor < pos_y) [
           set dir "E"
         ]
         [
           set dir "O"
         ]
       ]
     ]
     set pos_y pos_y + grid_x_inc
     set Ymin pos_y - road_size
     set Ymax pos_y + road_size
  ]
  set roads patches with [pcolor = white]
  ask intersections [
    set pcolor white
  ]
end

;Initialisation globale des patchs
to setup-patches
  ;;Initialiser tous les patchs
  ask patches [
    set intersection? false
    set road? false
    set pcolor sidewayColor
    set accidentCounted false
  ]
  ;;creation intersection
  let pos_y min-pxcor + 1 + floor (grid_x_inc / 2)
  let i 0 ;numero (ID) de l'intersection
  while [pos_y < max-pycor] [
    let pos_x min-pycor + 1 + floor (grid_y_inc / 2)
    while [pos_x < max-pxcor] [
      set i (i + 1)
      creerIntersection pos_x pos_y i
      set pos_x pos_x + grid_y_inc
    ]
    set pos_y pos_y + grid_x_inc
  ]

  ; peuplement des intersections
  set intersections patches with [intersection? = true]

  ;creation routes
  setup-road

end

;Initialisation des voitures
to setup-cars
  set nbrCarChangeDirectionDueToPatience 0
  set nbrAccidents 0
  let value 0
  set-default-shape cars "car"
  create-cars num-cars [
    ;Les voitures ont une couleur aleatoire
    set color one-of [ blue red green orange violet ]
    set size 1
    set isInitialising? true
    let xCar 0
    let yCar 0
    ;on place les voitures sur les extremites des routes
    ask roads with [ (pxcor = min-pxcor or pxcor = max-pxcor) or (pycor = min-pycor or pycor = max-pycor) ] [
      set xCar pxcor
      set yCar pycor
    ]
    setxy xCar yCar

    ;au setup, la voiture va dans la direction de la voie sur laquelle elle est deposee
    let patchDirection 0
    ask patch-here [
      set patchDirection dir
    ]
    set direction patchDirection
    set next_direction_ findNextDirection
    set num_intersection_ 0
    ;set nb_patch_before_flag_ road_size
    ;set nb_patch_before_turning_ (road_size - getLane)
    set turned? false
    set lane_ getLane

    setHeadingAndShapeAccordingCarDirection

    ;le conducteur desire rouler a une vitesse maximum (inferieur a la reglementation)
    set speed-max ((random-float (speed-limit - acceleration)) + acceleration)

    ;on set la patience de l'agent (random avec le patience-max
    ;On inverse les patiences min et max si besoin (pb de paramétrage)
    if patience-min > patience-max [
      let patience-min-tmp patience-min
      set patience-min patience-max
      set patience-max patience-min-tmp
    ]
    set patience ((random-float (patience-max - patience-min)) + patience-min)

    set cptAvancement 0

    ;a l'init, le conducteur n'a pas encore attendu
    set wait-time 0
  ]
end

;Initialisation des feux
to setup-lights
  let i 0
  while[i < road_size][
    ask banners[
      ;Feu au Nord du carrefour
      ask patch-at (- road_size + i) road_size[
        set pcolor red
      ]
      ;Feu a l'Est du carrefour
      ask patch-at road_size i[
        set pcolor green
      ]
      ;Feu au Sud du carrefour
      ask patch-at (i) (- road_size - 1)[
        set pcolor red
      ]
      ;Feu a l'Ouest du carrefour
      ask patch-at (- road_size - 1) (- road_size + i)[
        set pcolor green
      ]
    ]
    set i (i + 1)
  ]
end

;Permet de modifier dynamiquement la frequence de changement des feux sur un carrefour.
;crossroads_num: Numero du carrefour(label du flag)
;frequence: entre 1 et l'infini !
to set-frequence [crossroads_num frequence]
  if frequence >= 0 and frequence < 500[
    ask banners[
      if label = crossroads_num[
        set frequenceRedGreen frequence
        set frequenceOrange (frequenceRedGreen / 5)
      ]
    ]
  ]
end

;On récupère la direction avec l'angle du heading qu'on passe en paramètre
to-report getDirectionWithHeading [headingRate]
  if headingRate = 0 [
    report "N"
  ]
  if headingRate = 90 [
    report "E"
  ]
  if headingRate = 180 [
    report "S"
  ]
  if headingRate = 270 [
    report "O"
  ]

end


;Gestion des feux
to change-lights
  let i 0
  let nb_ticks ticks

  while[i < road_size][
    ask banners[
        ;print(word "ticks: " ticks " time * frequenceRedGreen: " frequenceRedGreen)
        ifelse frequenceRedGreen > 0[
          if ticks - time = frequenceRedGreen or ticks - time = (frequenceRedGreen + frequenceOrange)[
            if ticks - time = frequenceRedGreen[
              ask patch-at road_size i[
                if pcolor = green[
                  set pcolor orange
                ]
              ]
              ask patch-at (- road_size - 1) (- road_size + i)[
                if pcolor = green[
                  set pcolor orange
                ]
              ]
              ask patch-at (- road_size + i) road_size[
                if pcolor = green[
                  set pcolor orange
                ]
              ]
              ask patch-at (i) (- road_size - 1)[
                if pcolor = green[
                  set pcolor orange
                ]
              ]
            ]
            if ticks - time = (frequenceRedGreen + frequenceOrange)[
              ask patch-at road_size i[
                if pcolor = red[
                  set pcolor green
                ]
              ]
              ask patch-at (- road_size - 1) (- road_size + i)[
                if pcolor = red[
                  set pcolor green
                ]
              ]
              ask patch-at (- road_size + i) road_size[
                if pcolor = red[
                  set pcolor green
                ]
              ]
              ask patch-at (i) (- road_size - 1)[
                if pcolor = red[
                  set pcolor green
                ]
              ]
            ]
            if ticks - time = (frequenceRedGreen + frequenceOrange)[
              if i = (road_size - 1)[set time (time + frequenceRedGreen)]
              ask patch-at road_size i[
                if pcolor = orange[
                  set pcolor red
                ]
              ]
              ask patch-at (- road_size - 1) (- road_size + i)[
                if pcolor = orange[
                  set pcolor red
                ]
              ]
              ask patch-at (- road_size + i) road_size[
                if pcolor = orange[
                  set pcolor red
                ]
              ]
              ask patch-at (i) (- road_size - 1)[
                if pcolor = orange[
                  set pcolor red
                ]
              ]
            ]
          ]
        ]
        [
          ask patch-at road_size i[
            set pcolor orange
              ]
          ask patch-at (- road_size - 1) (- road_size + i)[
            set pcolor orange
          ]
          ask patch-at (- road_size + i) road_size[
            set pcolor orange
          ]
          ask patch-at (i) (- road_size - 1)[
            set pcolor orange
          ]
        ]
    ]
    set i (i + 1)
  ]
end

;Lancement (ou reprise) de la simulation
to go
  ;Gestion de chaque voiture
  ask cars[
    ;;Check si la voiture n'est plus en initialisation
    if isInitialising? [
      let carIsInitialising? true
      ask patch-here [
        if count cars-here = 1 [
          set carIsInitialising? false
        ]
      ]
      set isInitialising? carIsInitialising?
    ]


    ifelse canMove? = 0 [
      move
      ;maj de la vitesse max après ce mouvement
      ifelse (speed + acceleration <= speed-max) [
        set speed (speed + acceleration)
      ]
      [
        set speed speed-max
      ]
    ]
    [
      ;On ralenti puis on move
      ;Si l'obstacle est une voiture, on regarde sa vitesse pour savoir s'il faut freiner ou non
      let speedCarAhead 0
      let patchAheadInIntersection? false
      let carAheadSameDirection? true
      let currentDirection direction
      ask cars-on patch-ahead canMove? [
        set speedCarAhead speed
        ask patch-here [
          if intersection? [
            set patchAheadInIntersection? true
          ]
        ]
        if direction != currentDirection [
           set carAheadSameDirection? false
        ]
      ]

      let currentCarInInteresection? false
      ask patch-here [
        set currentCarInInteresection? intersection?
      ]

      ;On ralenti si la vitesse de la voiture de devant est plus faible que la notre
      ;Ou si la voiture est dans un carrefour et dans une direction différente de la notre
      ;Ou si ma vitesse est 0 et que la voiture devant a une vitesse aussi égale à 0
      if speedCarAhead < speed or (speed = 0 and speedCarAhead = 0) or (not (carAheadSameDirection?) and patchAheadInIntersection?) [
        ifelse patchAheadInIntersection? and currentCarInInteresection? [
          ifelse (speed - deceleration) >= 0 [
            set speed (speed - deceleration)
          ]
          [
            ;Pour ne pas avoir de marche arrière, si on fait le calcul de la décélération et qu'on a un chiffre inférieur à 0
            ;Alors on set la speed à 0 sinon on aura des marches arrières
            ifelse (canMove? = 1 or (patchAheadInIntersection? and not currentCarInInteresection?)) [
              ;On set la speed à 0 uniquement si l'obstacle est 1 patch devant nous ou si l'obstacle est dans une intersection
              set speed 0
            ]
            [
              if speed = 0 [
                set speed (speed + deceleration)
              ]
            ]
          ]
        ]
        [
          ifelse (speed - (deceleration / (canMove? / ahead-vision))) >= 0 [

            set speed (speed - (deceleration / (canMove? / ahead-vision)))
          ]
          [
            ;Pour ne pas avoir de marche arrière, si on fait le calcul de la décélération et qu'on a un chiffre inférieur à 0
            ;Alors on set la speed à 0 sinon on aura des marches arrières
            ifelse canMove? = 1 [
              ;On set la speed à 0 uniquement si l'obstacle est 1 patch devant nous
              set speed 0
            ]
            [
              if speed = 0 [
                set speed (speed + deceleration)
              ]
            ]

          ]
        ]

      ]

      ;Si on est à l'arret depuis très longtemps dans une intersection
      ;On essaye d'aller à notre droite pour sortir du bouchon
      if speed = 0 and currentCarInInteresection? and wait-time > patience [
         ;On regarde si la voie est libre et si elle est dans la bonne direction pour nous
         let nextOrientation nextHeading (direction)
         let canGoNextOrientationCar? false
         let canGoNextOrientationDir? false
         ;il faut regarder sur le patch à 1 case de nous s'il y a une voiture ou pas
         ask patch-at-heading-and-distance nextOrientation 1 [
            if not (any? cars-here) [
              set canGoNextOrientationCar? true
            ]
         ]
         ;et il faut regarder si le patch à road_size de nous va bien dans la direction qu'on voudrait prendre
         ask patch-at-heading-and-distance nextOrientation road_size [
            if getDirectionWithHeading (nextOrientation) = dir [
              set canGoNextOrientationDir? true
            ]
         ]
         if canGoNextOrientationCar? and canGoNextOrientationDir? [
           ;print (word "la turtle " who " a changé de direction (de " direction " à " getDirectionWithHeading (nextOrientation) ") parcequ'elle a attendu trop longtemps")
           set nbrCarChangeDirectionDueToPatience nbrCarChangeDirectionDueToPatience + 1
           set direction (getDirectionWithHeading (nextOrientation))
         ]
      ]

      move
    ]
  ]
  ;comptage nbr accidents
    ask patches [
      ifelse (count cars-here > 1) and (not accidentCounted) [
        let accidentHasToBeCounted? true
        ask cars-here [
          if isInitialising? [
            set accidentHasToBeCounted? false
          ]
        ]
        if accidentHasToBeCounted? [
          set accidentCounted true
          set nbrAccidents nbrAccidents + 1
        ]
      ]
      [
        set accidentCounted false
      ]
    ]
  ;Gestion des feux
  change-lights
  tick
end

to-report moveAhead [dist]
  let moveEnabled? false
  let lightIsRed? false
  let carAhead? false
  let roadAhead? false
  ask patch-ahead dist [
    ;Si le feu(patch) est rouge on ne peut passer
    if pcolor = red[
      set lightIsRed? true
    ]
    ;S'il y a une voiture sur le patch devant
    if any? cars-here = true [
      set carAhead? true
    ]

    ;Si le patch devant est bien une route
    if road? = true [
      set roadAhead? true
    ]
  ]
  if lightIsRed? = false and carAhead? = false and roadAhead? = true[
    set moveEnabled? true
  ]

  if carAhead? [
    ;on attend derriere un autre conducteur
    set wait-time (wait-time + 1)
  ]

  report moveEnabled?
end

;Gestion de l'orientation et de la forme de la voiture selon sa direction
to setHeadingAndShapeAccordingCarDirection
  ;if direction = 0 [set direction one-of["N" "E" "S" "O"]] ;si on est dans un carrefour, on change de direction
  if direction = "N" [
    set heading 0
    set shape "cartonorth"
  ]
  if direction = "E" [
    set heading 90
    set shape "car"
  ]
  if direction = "S" [
    set heading 180
    set shape "cartosouth"
  ]
  if direction = "O" [
    set heading 270
    set shape "cartowest"
  ]
end

;Récupération de la direction à prendre si on est totalement bloqué dans une intersection (en fonction de la direction qu'on a)
to-report nextHeading [currentDir]
  if currentDir = "N" [
    report 90
  ]
  if currentDir = "E" [
    report 180
  ]
  if currentDir = "S" [
    report 270
  ]
  if currentDir = "O" [
    report 0
  ]
end

;On renvoie 0 si on peut bouger
;Sinon on renvoie 1, 2, 3 ..., en fonction de où l'obstacle nous block
;1 signifie l'obstacle est 1 patch-ahead, 2 signifie que l'obstacle est 2 patch ahead etc etc
to-report canMove?
  setHeadingAndShapeAccordingCarDirection
  let canMoveAhead? true
  let i 1
  let obstacleAtPatch 0
  while [i <= ahead-vision and canMoveAhead?] [
    if (not (moveAhead (i))) [
      set canMoveAhead? false
      set obstacleAtPatch i
    ]
    set i (i + 1)
  ]
  report obstacleAtPatch
end

to move
  let is_intersection? false
  let new_direction direction
  let can_turn? true
  let can_change_lane? false
  let lane_where_to_move 0

  ;reset du wait time si speed > 0 et qu'on avance au moins 4 fois de suite
  if speed = 0 [
    set cptAvancement 0
  ]
  if speed > 0 [
    set cptAvancement (cptAvancement + 1)
    if cptAvancement >= 10 [
      set wait-time 0
    ]
  ]

  ask patch-here[
    if intersection?[
      set is_intersection? true
    ]
  ]
  ifelse not is_intersection? or not can_turn?[
    ifelse can_change_lane?[
      set lane_where_to_move checkNeedChangingLane
      ifelse lane_where_to_move > 0[
        ;print(word "Changement de voie")
        ;changingLane lane_where_to_move
        ;Ne pas oublier apres le changement de lane de réinitialiser la valeur de nb_patch_before_turning_ qui dépend en partie de la lane sur laquelle se trouve la voiture !
      ]
      [
        forward speed
      ]
    ]
    [
       forward speed
    ]
  ]
  [
    ;;;;;;;;;;;;;;;;;;
    moveInIntersection
    ;;;;;;;;;;;;;;;;;;
  ]
end

;Permet en fonction de la prochaine direction à prendre tourner de suite(à droite), continuer tout droit, ou avancer apres le flage avant de tourner.
to moveInIntersection
  let num_intersection 0
  ;Récupère le numéro de l'intersection actuelle
  set num_intersection getNumIntersection pxcor pycor
  let in_intersection? false

  ;On regarde si on est pas déjà passé juste avant sur un patch de cette intersection.
;print(word "DIRECTION: " direction " PROCHAINE:" next_direction_)
  if num_intersection != num_intersection_ or (getNextDirection = "left" and turned? = false) [
;print(word "INTERSECTION 1")
    if num_intersection != num_intersection_[

      set turned? false
    ]
;print(word "NextDirection: " getNextDirection)
    ifelse getNextDirection = "right" or getNextDirection = "ahead"[
;print(word "TOURNER 1" getNextDirection)
      set direction next_direction_
      set next_direction_ findNextDirection
      set num_intersection_ num_intersection
      set turned? true
    ]
    [
;print(word "INTERSECTION 2 ")
      if not turned?[
;print(word "INTERSECTION 2.1 " getNextDirection " - speed: " speed)
        ;ask patch-ahead 1[
        ;  let x pxcor
        ;  let y pycor
        ;]
        let d ((road_size - lane_ + 1) + speed)
        ;if d >= 3[
        ;  set d (3 + speed)
        ;]
        let p patch-ahead d
;print(word "TURNING")
        ask intersections[
          if self = p[
            ;print(word "MATCH")
            set in_intersection? true
          ]
        ]
        if in_intersection? = false[
            set direction next_direction_
            set next_direction_ findNextDirection
            set num_intersection_ num_intersection

            ;set nb_patch_before_turning_ getLane

            set turned? true
        ]
      ]
    ]
  ]

  forward speed
end

to-report findNextDirection
  let next_direction ""
;print(word "findNextDirection")
  if direction = "N" [
    if allowed_movement = "all"[
      set next_direction one-of["N" "E" "O"]
    ]
    if allowed_movement = "avant"[
      set next_direction one-of["N"]
    ]
    if allowed_movement = "gauche"[
      set next_direction one-of["O"]
    ]
    if allowed_movement = "droite"[
      set next_direction one-of["E"]
    ]
    if allowed_movement = "gauche et avant"[
      set next_direction one-of["N" "O"]
    ]
    if allowed_movement = "droite et avant"[
      set next_direction one-of["N" "E"]
    ]
    if allowed_movement = "gauche et droite"[
      set next_direction one-of["E" "O"]
    ]
  ]
  if direction = "E" [
    if allowed_movement = "all"[
      set next_direction one-of["E" "S" "N"]
    ]
    if allowed_movement = "avant"[
      set next_direction one-of["E"]
    ]
    if allowed_movement = "gauche"[
      set next_direction one-of["N"]
    ]
    if allowed_movement = "droite"[
      set next_direction one-of["S"]
    ]
    if allowed_movement = "gauche et avant"[
      set next_direction one-of["E" "N"]
    ]
    if allowed_movement = "droite et avant"[
      set next_direction one-of["E" "S"]
    ]
    if allowed_movement = "gauche et droite"[
      set next_direction one-of["S" "N"]
    ]
  ]
  if direction = "S" [
    if allowed_movement = "all"[
      set next_direction one-of["S" "O" "E"]
    ]
    if allowed_movement = "avant"[
      set next_direction one-of["S"]
    ]
    if allowed_movement = "gauche"[
      set next_direction one-of["E"]
    ]
    if allowed_movement = "droite"[
      set next_direction one-of["O"]
    ]
    if allowed_movement = "gauche et avant"[
      set next_direction one-of["S" "E"]
    ]
    if allowed_movement = "droite et avant"[
      set next_direction one-of["S" "O"]
    ]
    if allowed_movement = "gauche et droite"[
      set next_direction one-of["O" "E"]
    ]
  ]
  if direction = "O" [
    if allowed_movement = "all"[
      set next_direction one-of["O" "N" "S"]
    ]
    if allowed_movement = "avant"[
      set next_direction one-of["O"]
    ]
    if allowed_movement = "gauche"[
      set next_direction one-of["S"]
    ]
    if allowed_movement = "droite"[
      set next_direction one-of["N"]
    ]
    if allowed_movement = "gauche et avant"[
      set next_direction one-of["O" "S"]
    ]
    if allowed_movement = "droite et avant"[
      set next_direction one-of["O" "N"]
    ]
    if allowed_movement = "gauche et droite"[
      set next_direction one-of["N" "S"]
    ]
  ]
  report next_direction
end

;Renvoie quelle dans quelle direction va prendre l'agent en penetrant dans l'intersection
to-report getNextDirection
;print(word "getNextDirection")
  if direction = "N" [
      if next_direction_ = "N"[
;print(word "N ahead " next_direction_)
        report "ahead"
      ]
      if next_direction_ = "O"[
;print(word "O left " next_direction_)
        report "left"
      ]
      if next_direction_ = "E"[
;print(word "E right " next_direction_)
        report "right"
      ]
    ]
    if direction = "E" [
      if next_direction_ = "E"[
;print(word "E ahead " next_direction_)
        report "ahead"
      ]
      if next_direction_ = "N"[
;print(word "E left " next_direction_)
        report "left"
      ]
      if next_direction_ = "S"[
;print(word "E right " next_direction_)
        report "right"
      ]
    ]
    if direction = "S" [
      if next_direction_ = "S"[
;print(word "S ahead " next_direction_)
        report "ahead"
      ]
      if next_direction_ = "E"[
;print(word "S left " next_direction_)
        report "left"
      ]
      if next_direction_ = "O"[
;print(word "S right " next_direction_)
        report "right"
      ]
    ]
    if direction = "O" [
      if next_direction_ = "O"[
;print(word "O ahead " next_direction_)
        report "ahead"
      ]
      if next_direction_ = "S"[
;print(word "O left " next_direction_)
        report "left"
      ]
      if next_direction_ = "N"[
;print(word "O right " next_direction_)
        report "right"
      ]
    ]
    report "unknown"
end

;Retourne le numero de l'intersection ou se trouve la voiture
to-report getNumIntersection [car-posx car-posy]
  let num 0

  let xMin (car-posx - road_size)
  let xMax (car-posx + road_size)
  let yMin (car-posy - road_size)
  let yMax (car-posy + road_size)
  ask banners-on intersections with [(pxcor >= xMin and pxcor <= xMax) and (pycor >= yMin and pycor <= yMax)] [
     set num label
  ]
  report num
end

;;Fonction qui permet si besoin quelle est la voie sur laquelle doit se déplacer la voiture(0 si aucun déplacement, sinon > 0)
;;Cette fonction suppose que la voiture ne se trouve pas dans une intersection
to-report checkNeedChangingLane
  let next_direction ""
  let lane getLane
  let lane_where_to_move 0

  ;print(word "checkNeedChangingLane - LANE="lane)

  if direction = "N" [
    if next_direction_ = "E" and lane != 1[
      set lane_where_to_move 1
    ]
  ]
  if direction = "E" [
    if next_direction_ = "S" and lane != 1[
      set lane_where_to_move 1
    ]
  ]
  if direction = "S" [
    if next_direction_ = "O" and lane != 1[
      set lane_where_to_move 1
    ]
  ]
  if direction = "O" [
    if next_direction_ = "N" and lane != 1[
      set lane_where_to_move 1
    ]
  ]

  report lane_where_to_move
end
;;Fonction qui permet de deplacer la voiture vers la voie numéro lane
to changingLane [lane]
  let bad_lane getLane
  ;print(word "Vers voie " lane)

  ifelse bad_lane > lane[
    set heading (heading + 90)
    fd 1
    set heading (heading - 90)
  ]
  [

  ]
end

to-report getLane
  let num_lane 1
  let lane_found? false

  set heading (heading + 90)
  while [num_lane <= road_size and not lane_found?][
    ask patch-ahead num_lane[
      if pcolor = sidewayColor[
        set lane_found? true
      ]
    ]
    set num_lane (num_lane + 1)
  ]
  set heading (heading - 90)

  report num_lane - 1
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
868
689
40
40
8.0
1
10
1
1
1
0
1
1
1
-40
40
-40
40
0
0
1
ticks
30.0

CHOOSER
5
10
97
55
grid_x
grid_x
1 2 3 4 5
4

CHOOSER
108
11
200
56
grid_y
grid_y
0 1 2 3 4 5
5

CHOOSER
36
64
174
109
road_size
road_size
1 2 3
1

BUTTON
18
125
81
158
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
113
124
176
157
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
13
238
185
271
num-cars
num-cars
0
400
33
1
1
NIL
HORIZONTAL

SLIDER
14
280
186
313
speed-limit
speed-limit
0
1
1
0.1
1
NIL
HORIZONTAL

SLIDER
14
324
186
357
acceleration
acceleration
0
0.099
0.0612
0.0001
1
NIL
HORIZONTAL

SLIDER
15
368
187
401
deceleration
deceleration
0
0.8
0.8
0.001
1
NIL
HORIZONTAL

SLIDER
15
411
187
444
ahead-vision
ahead-vision
0
3
3
1
1
NIL
HORIZONTAL

CHOOSER
15
452
153
497
crossroad-signal
crossroad-signal
"none" "signal4"
0

PLOT
881
10
1334
212
Speeds
time
speed
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"min speed" 1.0 0 -13345367 true "" "plot min [speed] of cars"
"max speed" 1.0 0 -2674135 true "" "plot max [speed] of cars"
"avg speed" 1.0 0 -10899396 true "" "plot mean [speed] of cars"

SLIDER
15
508
187
541
patience-max
patience-max
0
5000
2800
100
1
NIL
HORIZONTAL

SLIDER
15
549
187
582
patience-min
patience-min
0
5000
1700
100
1
NIL
HORIZONTAL

PLOT
884
283
1335
415
Voiture change direction
time
nbrOfCar
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"nbrChangeDir" 1.0 0 -16777216 true "" "plot nbrCarChangeDirectionDueToPatience"

MONITOR
895
233
1057
278
nbrVoitureChangeDirection
nbrCarChangeDirectionDueToPatience
17
1
11

MONITOR
1070
233
1155
278
NIL
nbrAccidents
17
1
11

CHOOSER
29
178
169
223
allowed_movement
allowed_movement
"all" "avant" "gauche" "droite" "gauche et avant" "droite et avant" "gauche et droite"
0

PLOT
885
425
1336
565
nombre d'accidents dans le temps
time
nbrAccidents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot nbrAccidents"

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

cartonorth
false
0
Polygon -7500403 true true 180 0 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 300 165 300 225 300 225 0 180 0
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

cartosouth
false
0
Polygon -7500403 true true 120 300 136 279 156 261 165 240 168 226 194 213 216 203 237 185 250 159 250 135 240 75 150 0 135 0 75 0 75 300 120 300
Circle -16777216 true false 30 180 90
Circle -16777216 true false 30 30 90
Polygon -16777216 true false 220 162 222 132 165 134 165 209 195 194 204 189 211 180
Circle -7500403 true true 47 47 58
Circle -7500403 true true 47 195 58

cartowest
false
0
Polygon -7500403 true true 0 180 21 164 39 144 60 135 74 132 87 106 97 84 115 63 141 50 165 50 225 60 300 150 300 165 300 225 0 225 0 180
Circle -16777216 true false 30 180 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 138 80 168 78 166 135 91 135 106 105 111 96 120 89
Circle -7500403 true true 195 195 58
Circle -7500403 true true 47 195 58

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
