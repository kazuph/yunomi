/* Superseded provenance snapshot. The only executable Alloy source for this
model is ../../scripts/dspec/review-mux.als; this block is intentionally
non-executable so stale commands cannot enter a receipt.
module review_mux

abstract sig File {}
one sig First, Second extends File {}

abstract sig Route {}
one sig Bare, ForFirst, ForSecond extends Route {}

fun requested[r: Route]: one File {
  (r = Bare or r = ForSecond) => Second else First
}

fun currentTarget[r: Route]: one File { First }

fun repairedTarget[r: Route]: one File {
  (r = ForSecond) => Second else First
}

assert CurrentRoutePreservesOpened {
  all r: Route | currentTarget[r] = requested[r]
}

assert RepairedRoutePreservesOpened {
  all r: Route - Bare | repairedTarget[r] = requested[r]
}

one sig CurrentDuplicate, RepairedDuplicate {
  currentResults: set File,
  repairedResults: set File
}

fact DuplicateDelivery {
  CurrentDuplicate.currentResults = First
  RepairedDuplicate.repairedResults = First
}

assert CurrentDuplicateCannotFinishEarly {
  all d: CurrentDuplicate |
    #(d.currentResults) >= 2 implies First + Second in d.currentResults
}

assert RepairedDuplicateCannotFinishEarly {
  all d: RepairedDuplicate |
    #(d.repairedResults) >= 2 implies First + Second in d.repairedResults
}

run CurrentRouteWitness for 3
check CurrentRoutePreservesOpened for 3
check RepairedRoutePreservesOpened for 3
check CurrentDuplicateCannotFinishEarly for 3
check RepairedDuplicateCannotFinishEarly for 3
*/
