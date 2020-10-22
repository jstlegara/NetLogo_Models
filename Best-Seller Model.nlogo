globals [
  waiting-area  ;; patches where the consumers will wait
  window-list   ;; to track moving average of consumer utility
]

breed [ goods good ]                    ;; white box shaped turtles
breed [ consumers consumer ]            ;; light brown person shaped turtles
directed-link-breed [ desires desire ]  ;; links between consumers and goods

goods-own [
  price              ;; price of goods set between 50 and max-price in increments of 5
  likes-count        ;; count of how many consumers like the good
  dislikes-count     ;; count of how many consumers dislike the good
  amount-purchased   ;; number of purchases for the good during a tick
  period-purchased   ;; number of purchases for the good in an evaluation period
  best-seller?       ;; best-seller status of the good during the evaluation period
  times-best-seller  ;; how many times the good became a best seller
]

consumers-own [
  budget                 ;; budget set between 50 and max-budget in increments of 5
  like                   ;; the good that is most favored by the consumer
  dislike                ;; the good that is least favored by the consumer
  basket                 ;; goods purchased in a tick
  utility                ;; happiness acquired through desire
  min-desire-to-buy      ;; random value from 0 to max-desire-to-buy-threshold
]

desires-own [
  level  ;; the level of desire by the consumers for a good
]

to setup
  clear-all

  ;; set up two tables for goods
  foreach (list min-pycor (min-pycor + 1) (max-pycor - 1) max-pycor) [ x ->
    ask patches with [pycor = x] [ set pcolor 26 ]
  ]

  ;; set area between the two tables as the waiting area for consumers
  set waiting-area patches with [
    ( pxcor > min-pxcor and pxcor < max-pxcor ) and
    ( pycor > min-pycor + 2 and pycor < max-pycor - 2 )
  ]

  ;; calls procedures to make goods and consumers
  make-goods
  make-consumers

  ;;;;; VISUALIZATION SETUP ;;;;;

  ;; label the goods with their the number of likes, dislikes, and their price
  ask goods [
    set label ( word likes-count "," dislikes-count "," price )
    set label-color black
  ]

  ;; label the consumers with their budget
  ask consumers [
    set label budget
    set label-color white
  ]

  ;; setup the moving-average report for the plot
  set window-list []
  ;; initialize an array of zeros with length equal to the smoothing window
  while [ length window-list < smoothing-window ] [
    set window-list lput 0 window-list
  ]

  reset-ticks
end

to make-goods
  ;; first 15 goods at the top table, next 15 at the bottom table
  ifelse products <= 15 [
    let cuts (world-width + 1) / (products + 1)
    foreach (range (min-pxcor - 1 + cuts) (max-pxcor + 1) cuts) [ x ->
      create-goods 1 [setxy x (max-pycor - 0.5)]
    ]
  ] [
    let cuts (world-width + 1) / 16
    foreach (range (min-pxcor - 1 + cuts) (max-pxcor + 1) cuts) [ x ->
      create-goods 1 [setxy x (max-pycor - 0.5)]
    ]
    set cuts (world-width + 1) / (products - 14)
    foreach (range (min-pxcor - 1 + cuts) (max-pxcor + 1) cuts) [ x ->
      create-goods 1 [setxy x (min-pycor + 0.5)]
    ]
  ]

  ask goods [
    set shape "box"
    set color white
    set price one-of ( range 50 ( max-price + 5 ) 5 )  ;; set price of goods
    set best-seller? false  ;; none of the goods are best-sellers at the start
    set times-best-seller 0  ;; initialize count for best-sellers
  ]
end

to make-consumers
  create-consumers customers [
    set shape "person"
    set color 36
    set budget one-of ( range 50 ( max-budget + 5 ) 5 )  ;; set budget of consumers
    set basket []  ;; give consumers empty baskets for shopping
    set utility 0  ;; initialize utility
    set min-desire-to-buy random max-desire-to-buy-threshold  ;; set threshold value of desire to buy

    ;; move the consumer to the waiting area
    move-to one-of waiting-area
    ;; if a consumer is alread positioned on the patch, transfer to a different patch
    while [ any? other consumers-here ] [
      move-to one-of waiting-area
    ]

    setup-likes-and-dislikes  ;; calls the procedure to setup likes and dislikes of the consumer
  ]
end

to setup-likes-and-dislikes
  create-desires-to goods [ set hidden? not show-desires? ]  ;; set up desire links for goods

  set like one-of goods  ;; set one of the goods as a like
  set dislike one-of goods  ;; set one of the goods as a dislike
  ;; if the dislike is the same as the like, choose a different good
  while [ dislike = like ] [
    set dislike one-of goods
  ]

  ;; update likeability counts of goods for visualization purposes
  ask like [ set likes-count likes-count + 1 ]
  ask dislike [ set dislikes-count dislikes-count + 1 ]
end

to go
  ask goods [ set amount-purchased 0 ]  ;; reset purchases count to 0 every tick

  ask consumers [ set label budget ]  ;; make budget initialization visible for all consumers per tick before the purchasing starts

  ask consumers [
    set utility 0  ;; reset happiness every tick
    set basket []  ;; reset shopping basket every tick

    ;; call temporary shopping variables
    let spend budget
    let option 0

    while [ (spend > 0) and (option < count goods) ] [  ;; if consumer can spend and has options to buy
      let choice item option sort-on [(- level)] my-desires  ;; the chosen good is the option according to desire
      ifelse [ level ] of choice > min-desire-to-buy [  ;; if the consumer's desire is sufficient to buy
        ifelse spend >= [ price ] of [ end2 ] of choice [  ;; if the good is affordable

          go-to-good choice  ;; go to the good of choice
          set spend spend - [ price ] of [ end2 ] of choice  ;; deduct price of good to budget
          set label spend  ;; update label to show how much money the consumer has left

          ask [ end2 ] of choice [
            set amount-purchased amount-purchased + 1  ;; record the purchase
          ]

          set utility utility + [ level ] of choice  ;; increase happiness by the desire for the good

          ask choice [ set level level - 1 ]  ;; decrease in desire for the good because it is already bought

          if member? [ end2 ] of choice basket [
            ask choice [ set level level - 1 ]  ;; diminishing marginal returns for same-day re-purchase
          ]

          set basket lput [ end2 ] of choice basket  ;; put purchased good in basket

        ] [
          ;; if the good is unaffordable, look at the next best option
          set option option + 1
        ]
      ] [
        ;; if the current option does not reach required desire, none of the next will
        ;; end while loop by being unable to spend
        set spend 0
      ]
    ]

    move-around  ;; transfer to a different spot in the waiting area

    ;;;;; NATURAL INCLINATIONS ;;;;;

    ;; if favorite was not bought, anticipate future purchase for it
    if (not member? like basket) and
       (random-float 1.0 < inclination-probability) [
      ask out-desire-to like [ set level level + 1 ]
    ]

    ;; a consumer is inclined to hate their dislike further
    if random-float 1.0 < inclination-probability [
      ask out-desire-to dislike [ set level level - 1 ]
    ]
  ]

  word-of-mouth radius-of-influence

  tick

  update-best-seller

  ask goods [
    set period-purchased period-purchased + amount-purchased  ;; add purchases for the tick to the period counter
  ]

  ;;;;; VISUALIZATION ;;;;;

  ;; scale colors to show best sellers
  ask goods [
    set color scale-color blue times-best-seller ( max [ times-best-seller ] of goods + 1 ) 0
    set label-color scale-color black times-best-seller 0 ( max [ times-best-seller ] of goods + 1 )
  ]

  ;; slide the window for the moving-average
  set window-list lput (mean [ utility ] of consumers) window-list
  set window-list but-first window-list
end

to reset-transactions

  ask desires [
    set hidden? not show-desires?
  ]

  ask consumers [
    set utility 0  ;; reset happiness
    set basket []  ;; reset shopping basket
    ask my-desires [ set level 0 ]
  ]

  ask goods [
    set best-seller? false  ;; none of the goods are best-sellers
    set times-best-seller 0  ;; initialize count for best-sellers
    set amount-purchased 0  ;; initialize amount purchased
    set period-purchased 0  ;; initialize period best-seller

    ;; reset scale colors
    set color scale-color blue times-best-seller ( max [ times-best-seller ] of goods + 1 ) 0
    set label-color scale-color black times-best-seller 0 ( max [ times-best-seller ] of goods + 1 )
  ]

  ;; setup the moving-average report for the plot
  clear-all-plots
  set window-list []
  while [ length window-list < smoothing-window ] [
    set window-list lput 0 window-list
  ]

  reset-ticks
end


;;;;; MOVEMENT PROCEDURES ;;;;;

;; go to the good being purchased
to go-to-good [ choice ]
  face [ end2 ] of choice
  forward distance [ end2 ] of choice
end

;; go to an empty spot at the waiting area
to move-around
  let wait-here one-of waiting-area
  while [ any? turtles-on wait-here ] [
      set wait-here one-of waiting-area
  ]
  facexy [ pxcor ] of wait-here [ pycor ] of wait-here
  forward distancexy [ pxcor ] of wait-here [ pycor ] of wait-here
end


;;;;; INFLUENCE PROCEDURES ;;;;;

;; influence other consumers within the area of the circle with radius r
;; choose only a percent of the consumers to initiate influence
to word-of-mouth [ radius ]
  ask n-of ( count consumers * positive-influencers ) consumers [
    positive-influence radius
  ]
  ask n-of ( count consumers * negative-influencers ) consumers [
    negative-influence radius
    ]
end

to positive-influence [ radius ]
  let set-aside-color [ color ] of like  ;; set aside scaled color for the liked good
  ask self [ set color green ]  ;; tag positive influencer
  ask like [ set color green ]  ;; tag good being shared positively
  ask other consumers in-radius radius [
    set color 44  ;; tag consumers listening to the influencer
    ask out-desire-to one-of goods with [color = green] [
      if random-float 1.0 < belief-probability [  ;; believe according to the probability
        set level level + 1
      ]
    ]
  ]
  ;; return original colors before tagging
  ask like [ set color set-aside-color ]
  ask consumers in-radius radius [ set color 36 ]
end

to negative-influence [ radius ]
  let set-aside-color [ color ] of dislike  ;; set aside scaled color for the disliked good
  ask self [ set color red ]  ;; tag negative influencer
  ask dislike [ set color red ]  ;; tag good being shared negatively
  ask other consumers in-radius radius [
    set color 44  ;; tag consumers listening to the influencer
    ask out-link-to one-of goods with [color = red] [
      if random-float 1.0 < belief-probability [  ;; believe according to the probability
        set level level - 1
      ]
    ]
  ]
  ;; return original colors before tagging
  ask dislike [ set color set-aside-color ]
  ask consumers in-radius radius [ set color 36 ]
end

;; evaluate best-seller after the evaluation period
to update-best-seller
  if ticks mod period-in-days = 1 [
    ask goods [ set best-seller? false ]  ;; at the end of an evaluation period, reset status
    let period-best-seller first sort-on [(- period-purchased)] goods  ;; sort goods according to purchases in the period
    if [period-purchased] of period-best-seller != 0 [  ;; check if highest selling good does have sales
      ask period-best-seller [
        set best-seller? true  ;; update status as best seller
        set times-best-seller times-best-seller + 1  ;; update counter for best-seller
      ]
    ]
    ask goods [ set period-purchased 0 ]  ;; at the end of evaluation period, reset purchases
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
213
10
914
844
-1
-1
33.0
1
10
1
1
1
0
0
0
1
-10
10
-12
12
0
0
1
ticks
30.0

BUTTON
30
655
93
688
NIL
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
117
655
180
688
NIL
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
83
202
116
products
products
2
30
30.0
1
1
goods
HORIZONTAL

SLIDER
11
192
202
225
customers
customers
1
300
100.0
1
1
people
HORIZONTAL

SLIDER
11
232
202
265
max-budget
max-budget
50
1500
1500.0
5
1
Php
HORIZONTAL

SLIDER
11
123
202
156
max-price
max-price
50
1500
1500.0
5
1
Php
HORIZONTAL

SLIDER
11
558
203
591
radius-of-influence
radius-of-influence
0
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
11
463
203
496
positive-influencers
positive-influencers
0
1.0
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
11
503
203
536
negative-influencers
negative-influencers
0
1.0
0.5
0.01
1
NIL
HORIZONTAL

CHOOSER
924
175
1030
220
period-in-days
period-in-days
7 30 60 90 180 360
1

TEXTBOX
52
58
202
76
Product Variables
14
125.0
1

TEXTBOX
47
168
197
186
Consumer Variables
14
125.0
1

TEXTBOX
34
437
201
471
Word-of-Mouth Variables
14
125.0
1

SLIDER
11
598
203
631
belief-probability
belief-probability
0
1
0.7
0.01
1
NIL
HORIZONTAL

SLIDER
11
305
202
338
inclination-probability
inclination-probability
0
1
0.2
0.01
1
NIL
HORIZONTAL

PLOT
924
10
1263
160
consumer utility
days (ticks)
level of utility
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"mean consumer utility" 1.0 0 -4079321 true "" "plot mean [ utility ] of consumers"
"moving average" 1.0 0 -16449023 true "" "plot mean window-list"

SLIDER
11
344
203
377
max-desire-to-buy-threshold
max-desire-to-buy-threshold
1
100
50.0
1
1
NIL
HORIZONTAL

TEXTBOX
60
280
181
298
Desire Variables
14
125.0
1

MONITOR
1041
175
1263
232
Current Period Best-Seller
first [self] of goods with [best-seller?]
17
1
14

INPUTBOX
1149
97
1260
157
smoothing-window
100.0
1
0
Number

BUTTON
40
700
172
733
NIL
reset-transactions
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
40
390
172
423
show-desires?
show-desires?
1
1
-1000

BUTTON
1000
380
1087
413
scenario 3
set products 30\nset max-price 1500\nset customers 100\nset max-budget 1500\nset max-desire-to-buy-threshold 50\nset positive-influencers 0.5\nset negative-influencers 0.5\nset radius-of-influence 3\nset belief-probability 0.7\nrandom-seed 10\nsetup
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
1000
300
1087
333
scenario 1
set products 30\nset max-price 50\nset customers 100\nset max-budget 1500\nset max-desire-to-buy-threshold 50\nset positive-influencers 0.5\nset negative-influencers 0.5\nset radius-of-influence 3\nset belief-probability 0.7\nrandom-seed 10\nsetup
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
1000
340
1087
373
scenario 2
set products 30\nset max-price 800\nset customers 100\nset max-budget 1500\nset max-desire-to-buy-threshold 50\nset positive-influencers 0.5\nset negative-influencers 0.5\nset radius-of-influence 3\nset belief-probability 0.7\nrandom-seed 10\nsetup
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
1095
380
1182
413
scenario 4
set products 30\nset max-price 1500\nset customers 100\nset max-budget 1500\nset max-desire-to-buy-threshold 50\nset positive-influencers 0.1\nset negative-influencers 0.5\nset radius-of-influence 3\nset belief-probability 0.7\nrandom-seed 10\nsetup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This project simulates the rise of a good as a best-seller in an enterprise. It makes use of consumer theory in Economics for some of the agent rules (e.g. preferences, utility, the Walras Law, etc.) specifically in the purchase of goods. This project also integrates a method for spreading information: word-of-mouth, to influence other consumers whether to buy a good or not.

## HOW IT WORKS

The consumers are initially scattered around the waiting area between the two orange tables where the goods are placed. The consumers decide which goods to buy according to their budget and levels of desire for the goods. The level of desire is represented by the value of the "level" property in the links between the goods and consumers.

A consumer would only buy a good if the "level" of desire for the good reaches a certain threshold. If they bought the good, then their desire for the good is diminished by one; buying it has quenched their desire for it. If for some situation they buy a good they have already bought during the day/tick, the desire for the good is penalized twice in the purchase. The consumer desires for the good less and less in application of the Economic theory of Diminishing Marginal Returns.

For every good they buy, their utility (or happiness) is increased by the value of their desire for that good for the current day/tick. Note that utility resets every day. A plot is included in the interface to keep tabs of the average utility of the consumers in the model.

They shop for the good(s) and travel back to a random spot in the waiting area once they have no more good they want to buy. If they decide not to buy anything at all, they just transfer to another blank spot in the waiting area.

At setup, a consumer is tagged with a good they like, and tagged with another good they dislike. Their preferences do not change for the duration of the simulation. If during the shopping spree for the day/tick the consumer's shopping basket does not include the good they like, they are inclined to desire for it, increasing their level of desire for the good by one, by a certain probability. For each tick, the consumers are inclined to hate the good they dislike, decreasing the level of desire for the good by one, by a certain probability. 

After the shopping spree, a portion of the consumers discuss the goods which they like and dislike among the neighbors within a radius of influence. The influencer and the good they like turn green during this time if positive influence is being spread. On the other hand, the neighbor and the good they dislike turn red if negative influence is being spread. The neighbors within the radius of influence turn yellow. The neighbors then decide whether to take the word of the influencer, and have their desire for the discussed good be affected.

The model assumes that the consumers keep a certain level of budget primarily for this enterprise, but because of the desire threshold, it does not necessarily mean that the entire budget would be depleted for the goods shown in the model. It could be assumed however, that any left over budget per tick is used to buy other goods not presented in the model and so is not carried over to the next tick. This is in application of the Economic theory of Walras Law which states that the optimal choice of a bundle of goods is equal or less than the budget.

The enterprise showcases the best-seller as the good most bought in a certain period. The best-seller changes per period depending on which good sells the most during that time. The colors of the goods are scaled to reflect the number of times they became a best-seller: <strong> the darker shade of blue they are, the more times they have become a best-seller.</strong>

Notice the set of numbers separated by commas on each good. The first one is the number of consumers who like the good, the next is the number of consumers who dislike the good, and the last is the price set for the good. Note that the number of likes and dislikes per good does not affect decision making and is just shown for ease in analysis.

Similarly, a number is shown on top of each consumer. This shows the amount of money they can use to buy goods, and this diminishes for every purchase they make. This replenishes at the start of every tick.

## HOW TO USE IT

Click the SETUP button to set up the goods (boxes on the orange patches), and the consumers (tan people).

Click the GO button to start the simulation.

Click the RESET-TRANSACTIONS button to restart the simulation without changing the goods and consumers, as well as their properties from the previous setup like the price, budget, desire thresholds, likes, and dislikes.

The PRODUCTS slider controls how many goods are in the simulation. This can be set from from 2 to 30 (Note: Changes in the PRODUCTS slider does not take effect until the next SETUP)

The MAX-PRICE slider controls the possible prices tagged to the goods. The prices tagged would be between 50 and the MAX-PRICE, inclusive, at intervals of 5. (e.g. if set to 65, each of the goods are tagged randomly with one of the prices: 50, 55, 60 and 65). If you set the MAX-PRICE slider to 50, all the goods will be priced 50. The MAX-PRICE slider can be set from 50 to 1500 in increments of 5. (Note: Changes in the MAX-PRICE slider does not take effect until the next SETUP)

The CUSTOMERS slider controls how many consumers are in the simulation. The CUSTOMERS slider can be set from 1 to 300. (Note: Changes in the CUSTOMERS slider does not take effect until the next SETUP)

The MAX-BUDGET slider controls the possible budget values given to the consumers. The amount of budget would be between 50 and the MAX-BUDGET, inclusive, at intervals of 5. (e.g. if set to 65, each consumer is randomly assigned one of the values: 50, 55, 60 and 65, as their budget). If you set the MAX-BUDGET slider to 50, all the consumers will have a budget of 50. (Note: Changes in the MAX-BUDGET slider does not take effect until the next SETUP)

The INCLINATION-PROBABILITY slider controls the chances of a consumer's desires for their likes and dislikes to change intrinsically. It is the probability to have the level of desire for the good they like increase by one if they were not able to purchase it in the previous tick, as well as the probability to have the desire for the good they dislike decrease by one for every tick.

The MAX-DESIRE-TO-BUY-THRESHOLD slider controls the set of possible thresholds for each consumer to incline them to buy. (e.g. if set to 50, a consumer's threshold could be a value from 0 to 49). Their level of desire must exceed this value to qualify for a purchase. The MAX-DESIRE-TO-BUY-THRESHOLD slider can be set from 1 to 100 (Note: Changes in the MAX-DESIRE-TO-BUY-THRESHOLD slider does not take effect until the next SETUP)

The SHOW-DESIRES? switch makes the links (desires) between goods and consumers visible. (Note: Changes in the SHOW-DESIRES switch does not take effect until the next SETUP or RESET-TRANSACTIONS)'

The POSITIVE-INFLUENCERS slider controls the portion of the consumers that will spread good news about the goods they like. A different set of consumers are chosen per tick.

The NEGATIVE-INFLUENCERS slider controls the portion of the consumers that will spread bad news about the goods they dislike. A different set of consumers are chosen per tick.

The RADIUS-OF-INFLUENCE slider controls the size of the circle within which an influencer can spread news to other consumers regarding their preferences.

The BELIEF-PROBABILITY slider controls the probability that a consumer will believe an influencer once the former is within within the latter's radius of influence.

The PERIOD-IN-DAYS chooser controls how many days/ticks long an evaluation period for the best-seller is.

The SMOOTHING-WINDOW input takes in a number which would be the length of the span for the moving average in the average utility plot. This is for visualization of the utility property of the consumers in the model.


## THINGS TO NOTICE

With the varying parameters set in the model, would you expect a good to be hailed as a best-seller consistently through multiple periods of evaluation? If so, what are the properties evident for this good in the model? If not, what causes this variability such that no one good is consistently a best-seller?

Notice that the spread of information from one consumer to another is not through a network for this model. While creating a network is the more realistic approach in the spread of information, the version shown here returns properties for the best-seller that are quite appealing for Economic theories.

Despite not being a factor to answering the primary questions, a plot to show average utility is included. Notice how this is affected when you change the various parameters. Are the people getting too happy in this model? Or does it sustain over time?


## THINGS TO TRY

Included in the interface are three buttons (SCENARIO 1, SCENARIO 2, and SCENARIO 3) which lets you experiment on different levels of MAX-PRICE, while other parameters are held constant. The seed is set to 10 for these scenarios to maintain property values. 

Click on a scenario to setup the model and press GO to start the simulation for each scenario. 

For SCENARIO 1, the MAX-PRICE is set to 50. In this scenario we see that all goods are priced equally. Notice that the best-seller is unstable between GOOD 2 and GOOD 14. This is because the same number of people likes and dislikes them, and their price is equal each other.

For SCENARIO 2, we set the MAX-PRICE to 800, introducing a property that is different between GOOD 2 and GOOD 14. GOOD 14 becomes the best-seller for the most part since it is the cheaper choice of the two.

For SCENARIO 3, we set the MAX-PRICE to 1500. In this scenario, GOOD 2 and GOOD 14 have become too expensive for our population, and the best-seller came out to be GOOD 3.

A fourth scenario, SCENARIO 4, is included to help you experiment with the POSITIVE-INFLUENCERS. This has parameters similar to SCENARIO 3, but with the POSITIVE-INFLUENCERS slider set at 0.10. The choice for the best-seller is more variable for this scenario compared to the other 3, however, do note that if you ran this for a long time, GOOD 11 comes out to be the good that becomes the best-seller the most. Notice that GOOD 11 is much more expensive than GOOD 3, and GOOD 3 has more people liking it. What could be the reason for GOOD 11 rising as the best-seller often?

Try to experiment on the different parameters. You may use the RESET-TRANSACTIONS button to restart the simulation without changing the goods and consumers, as well as their properties from the previous setup like the price, budget, desire thresholds, likes, and dislikes. Ultimately, this is used to see how their position in the waiting area, the word-of-mouth variables, or their INCLINATION-PROBABILITY affects the outcome.

## EXTENDING THE MODEL

For the extension, the user may like to set the inclination to like and dislike goods different for each consumer. The usage of a network is also a property that could be introduced into the model. 

Broadcast influence may be included as well--the enterprise sets out commercials for the goods that they have, or maybe just the best-seller from the previous period. 
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
NetLogo 6.1.0
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
1
@#$#@#$#@
