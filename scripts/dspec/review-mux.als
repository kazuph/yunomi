/* Historical pre-freeze sketch. It is retained for provenance only; the
authoritative generic-input model starts after this block.
module review_mux

open util/ordering[CurrentState] as currentOrder
open util/ordering[RepairedState] as repairedOrder

abstract sig File {}
one sig First, Second extends File {}

abstract sig Decision {}
one sig NoDecision, RequestChanges, Approve extends Decision {}

abstract sig Phase {}
one sig Collecting, RoundComplete, WaitingGo, Exited extends Phase {}

abstract sig Flag {}
one sig Yes, No extends Flag {}

abstract sig Audience {}
one sig OwnerOnly, BothContexts extends Audience {}

abstract sig Actor {}
one sig Browser, Cli extends Actor {}

abstract sig Route {}
one sig StateRoute, SubmitRoute, SseRoute, StaticRoute, ReplyRoute extends Route {}

sig Delivery { actor: one Actor, route: one Route, file: one File, generation: one Int, payload: one Int, decision: one Decision }
one sig A1, A2, B1, AOld, A2Approve, B2Approve extends Delivery {}

fact DeliveryValues {
  A1.file = First and A1.generation = 1 and A1.payload = 1 and A1.decision = RequestChanges
  A2.file = First and A2.generation = 1 and A2.payload = 2 and A2.decision = RequestChanges
  B1.file = Second and B1.generation = 1 and B1.payload = 1 and B1.decision = Approve
  AOld.file = First and AOld.generation = 1 and AOld.payload = 3 and AOld.decision = Approve
  A2Approve.file = First and A2Approve.generation = 2 and A2Approve.payload = 1 and A2Approve.decision = Approve
  B2Approve.file = Second and B2Approve.generation = 2 and B2Approve.payload = 1 and B2Approve.decision = Approve
}

sig CurrentState {
  selected, effective, staticTarget, cliTarget: one File,
  phase: one Phase,
  generation, emitted: one Int,
  raw, latest: set Delivery,
  aggregate: one Decision,
  staleAccepted: one Flag,
  fileAudience, roundAudience: one Audience
}

pred currentInit[s: CurrentState] {
  s.selected = Second and s.effective = First and s.staticTarget = First and s.cliTarget = First
  s.phase = Collecting and s.generation = 1 and s.emitted = 0
  no s.raw and no s.latest and s.aggregate = NoDecision and s.staleAccepted = No
  s.fileAudience = OwnerOnly and s.roundAudience = OwnerOnly
}

// Generic transport boundary: d carries actor, route, file, generation,
// payload, and decision. The current listener nevertheless records it in the
// first context and exits by delivery count.
pred currentDeliver[s, t: CurrentState, d: Delivery] {
  s.phase = Collecting and d not in s.raw
  t.raw = s.raw + d and t.latest = s.latest + d
  (#t.raw >= 2 implies t.phase = Exited)
  (#t.raw < 2 implies t.phase = Collecting)
  t.generation = s.generation and t.emitted = s.emitted and t.aggregate = d.decision
  t.selected = s.selected and t.effective = First and t.staticTarget = s.staticTarget and t.cliTarget = First
  (s.generation = 2 and d.generation = 1 implies t.staleAccepted = Yes)
  (not (s.generation = 2 and d.generation = 1) implies t.staleAccepted = No)
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred currentDuplicate[s, t: CurrentState] {
  s.phase = Collecting and no s.raw
  t.raw = A1 + A2 and t.latest = A1 + A2 and t.phase = Exited
  t.generation = s.generation and t.emitted = s.emitted and t.aggregate = s.aggregate
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.staleAccepted = s.staleAccepted and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred currentSubmitA[s, t: CurrentState] {
  s.phase = Collecting and no s.raw
  t.raw = A1 and t.latest = A1 and t.aggregate = RequestChanges
  t.phase = Collecting and t.generation = s.generation and t.emitted = s.emitted
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.staleAccepted = No and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred currentEarlyGo[s, t: CurrentState] {
  s.phase = Collecting and s.raw = A1 and s.aggregate = RequestChanges
  t.raw = s.raw and t.latest = s.latest and t.aggregate = s.aggregate and t.phase = Collecting
  t.generation = 2 and t.emitted = s.emitted
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.staleAccepted = No and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred currentAcceptsOldB[s, t: CurrentState] {
  s.generation = 2 and s.phase = Collecting and s.raw = A1
  t.raw = A1 + B1 and t.latest = A1 + B1 and t.aggregate = Approve and t.phase = Exited
  t.generation = 2 and t.emitted = 1 and t.staleAccepted = Yes
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred currentCopy[s, t: CurrentState] {
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.phase = s.phase and t.generation = s.generation and t.emitted = s.emitted
  t.raw = s.raw and t.latest = s.latest and t.aggregate = s.aggregate and t.staleAccepted = s.staleAccepted
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}
pred currentStutter[s, t: CurrentState] { currentCopy[s, t] }
pred currentNext[s, t: CurrentState] {
  (some d: Delivery | currentDeliver[s, t, d]) or currentEarlyGo[s, t] or currentAcceptsOldB[s, t] or currentStutter[s, t]
}
fact CurrentTrace { currentInit[currentOrder/first] and all s: CurrentState - currentOrder/last | currentNext[s, s.(currentOrder/next)] }

pred CurrentRouteWitness { currentOrder/first.selected != currentOrder/first.effective }
pred CurrentDuplicateWitness { some s: CurrentState | s.phase = Exited and #s.raw = 2 and #(s.raw.file) = 1 }
pred CurrentGenerationWitness { some s: CurrentState | s.staleAccepted = Yes and s.aggregate = Approve }

assert CurrentRoutePreservesSelection { all s: CurrentState | s.selected = s.effective }
assert CurrentDoesNotFinishEarly { all s: CurrentState | s.phase = Exited implies s.latest.file = First + Second }
assert CurrentRejectsOldGeneration { all s: CurrentState | s.staleAccepted = No }

sig RepairedState {
  selected, effective, staticTarget, cliTarget: one File,
  phase: one Phase,
  generation, emitted: one Int,
  raw, latest: set Delivery,
  aggregate: one Decision,
  staleAccepted: one Flag,
  fileAudience, roundAudience: one Audience
}

pred repairedInit[s: RepairedState] {
  s.selected = Second and s.effective = Second and s.staticTarget = Second and s.cliTarget = Second
  s.phase = Collecting and s.generation = 1 and s.emitted = 0
  no s.raw and no s.latest and s.aggregate = NoDecision and s.staleAccepted = No
  s.fileAudience = OwnerOnly and s.roundAudience = BothContexts
}

pred sameKey[left, right: Delivery] { left.file = right.file and left.generation = right.generation }

// Generic repaired delivery: old generations leave the ledger unchanged;
// exact payload retry is a no-op; a distinct payload replaces one key.
pred repairedRejectDelivery[s, t: RepairedState, d: Delivery] {
  s.phase = Collecting and d.generation != s.generation
  repairedCopy[s, t]
}

pred repairedAcceptDelivery[s, t: RepairedState, d: Delivery] {
  s.phase = Collecting and d.generation = s.generation
  no prior: s.latest | sameKey[prior, d] and prior.payload = d.payload and prior.decision = d.decision
  t.raw = s.raw + d
  t.latest = (s.latest - { prior: s.latest | sameKey[prior, d] }) + d
  t.generation = s.generation and t.emitted = s.emitted
  t.selected = s.selected and t.effective = d.file and t.staticTarget = s.staticTarget and t.cliTarget = d.file
  t.staleAccepted = No and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
  (t.latest.file = First + Second implies t.phase = RoundComplete)
  (t.latest.file != First + Second implies t.phase = Collecting)
  (t.phase = RoundComplete and some entry: t.latest | entry.decision = RequestChanges implies t.aggregate = RequestChanges)
  (t.phase = RoundComplete and no entry: t.latest | entry.decision = RequestChanges implies t.aggregate = Approve)
  (t.phase = RoundComplete implies t.emitted = t.generation)
}

pred repairedSubmitARequestChanges[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 1 and no s.latest
  t.raw = s.raw + A1 and t.latest = A1 and t.aggregate = NoDecision and t.phase = Collecting
  t.generation = 1 and t.emitted = 0 and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedSubmitBCompletesRound[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 1 and (s.latest = A1 or s.latest = A2)
  t.raw = s.raw + B1 and t.latest = s.latest + B1 and t.aggregate = RequestChanges and t.phase = RoundComplete
  t.generation = 1 and t.emitted = 1 and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedCopy[s, t: RepairedState] {
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.phase = s.phase and t.generation = s.generation and t.emitted = s.emitted
  t.raw = s.raw and t.latest = s.latest and t.aggregate = s.aggregate and t.staleAccepted = s.staleAccepted
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedRetry[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 1 and s.latest = A1
  repairedCopy[s, t]
}

pred repairedReplaceA[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 1 and s.latest = A1
  t.raw = s.raw + A2 and t.latest = A2 and t.aggregate = NoDecision and t.phase = Collecting
  t.generation = 1 and t.emitted = 0 and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedResolveRequestChanges[s, t: RepairedState] {
  s.phase = RoundComplete and s.aggregate = RequestChanges
  t.phase = WaitingGo and t.raw = s.raw and t.latest = s.latest and t.aggregate = s.aggregate
  t.generation = s.generation and t.emitted = s.emitted and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedGo[s, t: RepairedState] {
  s.phase = WaitingGo and s.aggregate = RequestChanges
  t.phase = Collecting and t.generation = 2 and t.emitted = 1 and no t.latest
  t.raw = s.raw and t.aggregate = NoDecision and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedRejectOldPost[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 2 and AOld.generation != s.generation
  repairedCopy[s, t]
}

pred repairedSubmitAApprove[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 2 and no s.latest
  t.raw = s.raw + A2Approve and t.latest = A2Approve and t.aggregate = NoDecision and t.phase = Collecting
  t.generation = 2 and t.emitted = 1 and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedSubmitBApproveCompletes[s, t: RepairedState] {
  s.phase = Collecting and s.generation = 2 and s.latest = A2Approve
  t.raw = s.raw + B2Approve and t.latest = A2Approve + B2Approve and t.aggregate = Approve and t.phase = RoundComplete
  t.generation = 2 and t.emitted = 2 and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedResolveApprove[s, t: RepairedState] {
  s.phase = RoundComplete and s.aggregate = Approve
  t.phase = Exited and t.raw = s.raw and t.latest = s.latest and t.aggregate = Approve
  t.generation = s.generation and t.emitted = s.emitted and t.staleAccepted = No
  t.selected = s.selected and t.effective = s.effective and t.staticTarget = s.staticTarget and t.cliTarget = s.cliTarget
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience
}

pred repairedStutter[s, t: RepairedState] { repairedCopy[s, t] }
pred repairedNext[s, t: RepairedState] {
  (some d: Delivery | repairedRejectDelivery[s, t, d] or repairedAcceptDelivery[s, t, d]) or repairedResolveRequestChanges[s, t] or repairedGo[s, t] or repairedResolveApprove[s, t] or repairedStutter[s, t]
}
fact RepairedTrace { repairedInit[repairedOrder/first] and all s: RepairedState - repairedOrder/last | repairedNext[s, s.(repairedOrder/next)] }

assert RepairedSafety {
  all s: RepairedState |
    s.selected = s.effective and s.selected = s.staticTarget and s.selected = s.cliTarget and
    s.staleAccepted = No and s.fileAudience = OwnerOnly and s.roundAudience = BothContexts and
    all f: File | lone { delivery: s.latest | delivery.file = f } and
    all delivery: s.latest | delivery.generation = s.generation and
    (s.phase = RoundComplete implies s.latest.file = First + Second and s.emitted = s.generation) and
    (s.phase = WaitingGo implies s.aggregate = RequestChanges) and
    (s.phase = Exited implies s.latest.file = First + Second and s.aggregate = Approve)
}

pred RepairedCompletionWitness {
  some s: RepairedState | s.phase = Exited and s.generation = 2 and s.aggregate = Approve and s.latest.file = First + Second and s.emitted = 2
}

pred RepairedReplacementWitness {
  some s: RepairedState | s.generation = 1 and s.latest = A2 and A1 in s.raw and A2 in s.raw
}

pred RepairedRetryWitness {
  some s: RepairedState - repairedOrder/last |
    s.generation = 1 and s.latest = A1 and repairedCopy[s, s.(repairedOrder/next)]
}

pred RepairedOldPostRejectedWitness {
  some s: RepairedState - repairedOrder/last |
    s.generation = 2 and AOld.generation != s.generation and repairedCopy[s, s.(repairedOrder/next)]
}

run CurrentRouteWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run CurrentDuplicateWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run CurrentGenerationWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
check CurrentRoutePreservesSelection for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
check CurrentDoesNotFinishEarly for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
check CurrentRejectsOldGeneration for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
check RepairedSafety for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run RepairedCompletionWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run RepairedReplacementWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run RepairedRetryWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
run RepairedOldPostRejectedWitness for exactly 4 CurrentState, exactly 8 RepairedState, 6 Delivery, 4 Int
*/

module review_mux

abstract sig Actor {}
one sig Browser, Cli extends Actor {}
abstract sig Route {}
one sig HtmlRoute, StateRoute, SubmitRoute, SseRoute, StaticRoute, CommentRoute,
  ReplyRoute, ResolveRoute, CliRoute, UiJsRoute, HealthzRoute extends Route {}
abstract sig File {}
one sig First, Second extends File {}
abstract sig Context {}
one sig Missing, ValidFirst, ValidSecond, Invalid, Global extends Context {}
abstract sig Payload {}
one sig P1, P2 extends Payload {}
abstract sig Decision {}
one sig RequestChanges, Approve extends Decision {}
abstract sig Scope {}
one sig FileThread, RoundThread extends Scope {}
abstract sig Phase {}
one sig Collecting, RoundComplete, WaitingGo, Exited extends Phase {}
abstract sig Outcome {}
one sig Accepted, NotFound404, Rejected400, Rejected409 extends Outcome {}
abstract sig Audience {}
one sig Nobody, OwnerOnly, AllContexts extends Audience {}
abstract sig HttpMethod {}
one sig GetMethod, HeadMethod extends HttpMethod {}
abstract sig StaticPath {}
one sig AssetPath, NestedCssAsset, TraversalAsset, BareAsset extends StaticPath {}
abstract sig RangeHeader {}
one sig NoRange, ByteRange extends RangeHeader {}
abstract sig StaticOutcome {}
one sig Static200, Static206, Static403, Static400 extends StaticOutcome {}
abstract sig MuxMode {}
one sig Mux, Single extends MuxMode {}
abstract sig GateState {}
one sig GateClear, AnchoredUnresolved, UnanchoredOnly extends GateState {}
abstract sig Persistence {}
one sig Persisted, NotPersisted extends Persistence {}

sig Input {
  actor: one Actor,
  route: one Route,
  context: one Context,
  file: one File,
  owner: one File,
  generation: one Int,
  payload: one Payload,
  decision: one Decision,
  scope: one Scope,
  gate: one GateState,
  mode: one MuxMode
}

abstract sig RoundThreadState {}
one sig NoThread, Open, Resolved extends RoundThreadState {}

abstract sig StaticRequest {
  staticMode: one MuxMode,
  staticContext: one Context,
  staticMethod: one HttpMethod,
  staticPath: one StaticPath,
  staticRange: one RangeHeader
}
one sig FullStaticRequest, RangeStaticRequest, NestedStaticRequest,
  TraversalStaticRequest, BareStaticRequest, MissingStaticRequest,
  InvalidStaticRequest, NonMuxStaticRequest extends StaticRequest {}
fact StaticRequestEquivalenceClasses {
  FullStaticRequest.staticMode = Mux and FullStaticRequest.staticContext = ValidSecond and FullStaticRequest.staticMethod = GetMethod and FullStaticRequest.staticPath = AssetPath and FullStaticRequest.staticRange = NoRange
  RangeStaticRequest.staticMode = Mux and RangeStaticRequest.staticContext = ValidSecond and RangeStaticRequest.staticMethod = GetMethod and RangeStaticRequest.staticPath = AssetPath and RangeStaticRequest.staticRange = ByteRange
  NestedStaticRequest.staticMode = Mux and NestedStaticRequest.staticContext = ValidSecond and NestedStaticRequest.staticMethod = HeadMethod and NestedStaticRequest.staticPath = NestedCssAsset and NestedStaticRequest.staticRange = NoRange
  TraversalStaticRequest.staticMode = Mux and TraversalStaticRequest.staticContext = ValidSecond and TraversalStaticRequest.staticMethod = GetMethod and TraversalStaticRequest.staticPath = TraversalAsset and TraversalStaticRequest.staticRange = NoRange
  BareStaticRequest.staticMode = Mux and BareStaticRequest.staticContext = ValidSecond and BareStaticRequest.staticMethod = GetMethod and BareStaticRequest.staticPath = BareAsset and BareStaticRequest.staticRange = NoRange
  MissingStaticRequest.staticMode = Mux and MissingStaticRequest.staticContext = Missing and MissingStaticRequest.staticMethod = GetMethod and MissingStaticRequest.staticPath = AssetPath and MissingStaticRequest.staticRange = NoRange
  InvalidStaticRequest.staticMode = Mux and InvalidStaticRequest.staticContext = Invalid and InvalidStaticRequest.staticMethod = HeadMethod and InvalidStaticRequest.staticPath = AssetPath and InvalidStaticRequest.staticRange = NoRange
  NonMuxStaticRequest.staticMode = Single and NonMuxStaticRequest.staticContext = Missing and NonMuxStaticRequest.staticMethod = HeadMethod and NonMuxStaticRequest.staticPath = BareAsset and NonMuxStaticRequest.staticRange = NoRange
}
pred staticResult[request: StaticRequest, outcome: StaticOutcome] {
  (request.staticMode = Single and outcome = Static200) or
  (request.staticMode = Mux and
    (request.staticContext = Missing or request.staticContext = Invalid or
      request.staticContext = Global or request.staticPath = BareAsset) and outcome = Static400) or
  (request.staticMode = Mux and
    (request.staticContext = ValidFirst or request.staticContext = ValidSecond) and
    request.staticPath = TraversalAsset and outcome = Static403) or
  (request.staticMode = Mux and
    (request.staticContext = ValidFirst or request.staticContext = ValidSecond) and
    (request.staticPath = AssetPath or request.staticPath = NestedCssAsset) and
    request.staticRange = ByteRange and outcome = Static206) or
  (request.staticMode = Mux and
    (request.staticContext = ValidFirst or request.staticContext = ValidSecond) and
    (request.staticPath = AssetPath or request.staticPath = NestedCssAsset) and
    request.staticRange = NoRange and outcome = Static200)
}
assert StaticDecisionTableIsTotalAndDeterministic {
  all request: StaticRequest | one outcome: StaticOutcome | staticResult[request, outcome]
}
pred StaticBoundaryWitnesses {
  staticResult[FullStaticRequest, Static200]
  staticResult[RangeStaticRequest, Static206]
  staticResult[NestedStaticRequest, Static200]
  staticResult[TraversalStaticRequest, Static403]
  staticResult[BareStaticRequest, Static400]
  staticResult[MissingStaticRequest, Static400]
  staticResult[InvalidStaticRequest, Static400]
  staticResult[NonMuxStaticRequest, Static200]
}
pred approveGate[gate: GateState, outcome: Outcome] {
  (gate = AnchoredUnresolved and outcome = Rejected409) or
  ((gate = GateClear or gate = UnanchoredOnly) and outcome = Accepted)
}
pred repairedGateEffect[gate: GateState, outcome: Outcome, retained: Persistence] {
  approveGate[gate, outcome]
  (gate = UnanchoredOnly implies retained = Persisted)
}
pred currentApproveGate[gate: GateState, outcome: Outcome] {
  (gate = GateClear and outcome = Accepted) or
  ((gate = AnchoredUnresolved or gate = UnanchoredOnly) and outcome = Rejected409)
}
pred CurrentUnanchoredGateWitness { currentApproveGate[UnanchoredOnly, Rejected409] }
assert CurrentUnanchoredDoesNotBlockApprove { currentApproveGate[UnanchoredOnly, Accepted] }
assert UnanchoredIsRetainedButDoesNotGate {
  repairedGateEffect[UnanchoredOnly, Accepted, Persisted] and
  approveGate[AnchoredUnresolved, Rejected409]
}
pred muxSummaryOrder[arrivalFirst, arrivalSecond, emittedFirst, emittedSecond: File] {
  arrivalFirst != arrivalSecond and emittedFirst = First and emittedSecond = Second
}
pred ReverseArrivalSummaryWitness {
  muxSummaryOrder[Second, First, First, Second]
}
assert SummaryOrderIgnoresArrivalOrder {
  all firstArrival, secondArrival, firstEmission, secondEmission: File |
    muxSummaryOrder[firstArrival, secondArrival, firstEmission, secondEmission]
      implies firstEmission = First and secondEmission = Second
}
pred globalRoute[r: Route] { r = UiJsRoute or r = HealthzRoute }
pred validOwned[i: Input] {
  (i.mode = Single and i.context = Missing and i.file = First) or
  (i.mode = Mux and ((i.context = ValidFirst and i.file = First) or
    (i.context = ValidSecond and i.file = Second)))
}
pred samePayload[a, b: Input] {
  a.file = b.file and a.generation = b.generation and
  a.payload = b.payload and a.decision = b.decision
}
pred nextGeneration[a, b: Int] { b = add[a, 1] }

sig CurrentState {
  cSelected, cEffect, cStatic, cSse, cReply: one File,
  cAudience: one Audience,
  cPhase: one Phase,
  cGeneration: one Int,
  cCount: one Int,
  cPresent: set File,
  cOutcome: one Outcome,
  cLast: lone Input,
  cStaleAccepted: set Input,
  cGate: File -> one GateState,
  cRetained, cFilePersisted: set File,
  cRoundPersisted, cResolvePersisted: one Persistence,
  cRoundThread: one RoundThreadState,
  cRoundReplies: one Int,
  cRetainedResolvedRound: one Persistence
}

pred currentInit[s: CurrentState] {
  s.cSelected = First and s.cEffect = First and s.cStatic = First and
  s.cSse = First and s.cReply = First and s.cAudience = Nobody
  s.cPhase = Collecting and s.cGeneration = 1 and s.cCount = 0
  no s.cPresent and s.cOutcome = Accepted and no s.cLast and no s.cStaleAccepted
  s.cGate = First->GateClear + Second->GateClear and
  no s.cRetained and no s.cFilePersisted and
  s.cRoundPersisted = NotPersisted and s.cResolvePersisted = NotPersisted and
  s.cRoundThread = NoThread and s.cRoundReplies = 0 and
  s.cRetainedResolvedRound = NotPersisted
}

pred currentCopyEffects[s, t: CurrentState] {
  t.cSelected = s.cSelected and t.cEffect = s.cEffect and
  t.cStatic = s.cStatic and t.cSse = s.cSse and t.cReply = s.cReply and
  t.cAudience = s.cAudience and t.cPhase = s.cPhase and
  t.cGeneration = s.cGeneration and t.cCount = s.cCount and
  t.cPresent = s.cPresent and t.cStaleAccepted = s.cStaleAccepted and
  t.cGate = s.cGate and t.cRetained = s.cRetained and
  t.cFilePersisted = s.cFilePersisted and
  t.cRoundPersisted = s.cRoundPersisted and t.cResolvePersisted = s.cResolvePersisted and
  t.cRoundThread = s.cRoundThread and t.cRoundReplies = s.cRoundReplies and
  t.cRetainedResolvedRound = s.cRetainedResolvedRound
}

pred currentGlobalGuard[s: CurrentState, i: Input] { globalRoute[i.route] }
pred currentHtmlGuard[s: CurrentState, i: Input] { i.route = HtmlRoute }
pred currentQueryApiGuard[s: CurrentState, i: Input] {
  i.mode = Mux and not globalRoute[i.route] and i.route != HtmlRoute and i.context != Missing
}
pred currentBareSubmitGuard[s: CurrentState, i: Input] {
  i.route = SubmitRoute and (i.mode = Single or i.context = Missing) and
  (i.decision != Approve or First.(s.cGate) = GateClear)
}
pred currentGateRejectGuard[s: CurrentState, i: Input] {
  i.route = SubmitRoute and (i.mode = Single or i.context = Missing) and i.decision = Approve and
  First.(s.cGate) != GateClear
}
pred currentBareOtherGuard[s: CurrentState, i: Input] {
  not globalRoute[i.route] and i.route != HtmlRoute and i.route != SubmitRoute and
  ((i.mode = Mux and i.context = Missing) or i.mode = Single) and
  not (i.context = Missing and i.scope = RoundThread and
    (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute))
}
pred currentRoundDeliverGuard[s: CurrentState, i: Input] {
  i.context = Missing and i.scope = RoundThread and
  (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute)
}
pred currentGlobal[s, t: CurrentState, i: Input] {
  currentGlobalGuard[s, i]
  currentCopyEffects[s, t]
  t.cOutcome = (i.context = Global => Accepted else NotFound404)
  t.cLast = i
}
pred currentHtml[s, t: CurrentState, i: Input] {
  currentHtmlGuard[s, i]
  t.cSelected = (i.context = ValidSecond => Second else First)
  t.cEffect = s.cEffect and t.cStatic = s.cStatic and t.cSse = s.cSse and
  t.cReply = s.cReply and t.cAudience = s.cAudience and t.cPhase = s.cPhase and
  t.cGeneration = s.cGeneration and t.cCount = s.cCount and
  t.cPresent = s.cPresent and t.cStaleAccepted = s.cStaleAccepted and
  t.cGate = s.cGate and t.cRetained = s.cRetained and
  t.cFilePersisted = s.cFilePersisted and
  t.cRoundPersisted = s.cRoundPersisted and t.cResolvePersisted = s.cResolvePersisted and
  t.cRoundThread = s.cRoundThread and t.cRoundReplies = s.cRoundReplies and
  t.cRetainedResolvedRound = s.cRetainedResolvedRound
  t.cOutcome = Accepted and t.cLast = i
}
pred currentQueryApi[s, t: CurrentState, i: Input] {
  currentQueryApiGuard[s, i]
  currentCopyEffects[s, t]
  t.cOutcome = NotFound404 and t.cLast = i
}
pred currentBareSubmit[s, t: CurrentState, i: Input] {
  currentBareSubmitGuard[s, i]
  t.cSelected = s.cSelected and t.cEffect = First and t.cStatic = s.cStatic and
  t.cSse = s.cSse and t.cReply = s.cReply and t.cAudience = s.cAudience
  t.cGeneration = s.cGeneration
  t.cCount = (i.decision = RequestChanges => 0 else add[s.cCount, 1])
  t.cPresent = s.cPresent + First
  t.cPhase = (i.decision = RequestChanges => WaitingGo else
    (add[s.cCount, 1] >= 2 => Exited else Collecting))
  t.cStaleAccepted = (i.generation != s.cGeneration => s.cStaleAccepted + i else s.cStaleAccepted)
  t.cGate = s.cGate and t.cRetained = s.cRetained and
  t.cFilePersisted = s.cFilePersisted and
  t.cRoundPersisted = s.cRoundPersisted and t.cResolvePersisted = s.cResolvePersisted and
  t.cRoundThread = s.cRoundThread and t.cRoundReplies = s.cRoundReplies and
  t.cRetainedResolvedRound = s.cRetainedResolvedRound
  t.cOutcome = Accepted and t.cLast = i
}
pred currentGateReject[s, t: CurrentState, i: Input] {
  currentGateRejectGuard[s, i]
  currentCopyEffects[s, t]
  t.cOutcome = Rejected409 and t.cLast = i
}
pred currentBareOther[s, t: CurrentState, i: Input] {
  currentBareOtherGuard[s, i]
  t.cSelected = s.cSelected
  t.cEffect = ((i.route = StateRoute or i.route = CliRoute) => First else s.cEffect)
  t.cStatic = (i.route = StaticRoute => First else s.cStatic)
  t.cSse = (i.route = SseRoute => First else s.cSse)
  t.cReply = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) => First else s.cReply)
  t.cAudience = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) => OwnerOnly else s.cAudience)
  t.cPhase = s.cPhase and t.cGeneration = s.cGeneration and t.cCount = s.cCount
  t.cPresent = s.cPresent and t.cStaleAccepted = s.cStaleAccepted
  t.cGate = (i.route = CommentRoute => (s.cGate - (First->GateState)) + First->i.gate else
    (i.route = ResolveRoute => (s.cGate - (First->GateState)) + First->GateClear else s.cGate))
  t.cRetained = (i.route = CommentRoute and i.gate = UnanchoredOnly => s.cRetained + First else s.cRetained)
  t.cFilePersisted = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) => s.cFilePersisted + First else s.cFilePersisted)
  t.cRoundPersisted = s.cRoundPersisted
  t.cResolvePersisted = (i.route = ResolveRoute => Persisted else s.cResolvePersisted) and
  t.cRoundThread = s.cRoundThread and t.cRoundReplies = s.cRoundReplies and
  t.cRetainedResolvedRound = s.cRetainedResolvedRound
  t.cOutcome = Accepted and t.cLast = i
}
pred currentRoundDeliver[s, t: CurrentState, i: Input] {
  currentRoundDeliverGuard[s, i]
  ((i.route = CommentRoute and s.cRoundThread = NoThread and
      t.cSelected = s.cSelected and t.cEffect = s.cEffect and t.cStatic = s.cStatic and t.cSse = s.cSse and
      t.cReply = First and t.cAudience = OwnerOnly and t.cPhase = s.cPhase and
      t.cGeneration = s.cGeneration and t.cCount = s.cCount and t.cPresent = s.cPresent and
      t.cStaleAccepted = s.cStaleAccepted and t.cGate = s.cGate and t.cRetained = s.cRetained and
      t.cFilePersisted = s.cFilePersisted and t.cRoundPersisted = Persisted and
      t.cResolvePersisted = s.cResolvePersisted and t.cRoundThread = Open and
      t.cRoundReplies = s.cRoundReplies and t.cRetainedResolvedRound = s.cRetainedResolvedRound and
      t.cOutcome = Accepted and t.cLast = i) or
   (i.route = CommentRoute and s.cRoundThread != NoThread and
      currentCopyEffects[s, t] and t.cOutcome = Rejected409 and t.cLast = i) or
   (i.route = ReplyRoute and s.cRoundThread = Open and
      t.cSelected = s.cSelected and t.cEffect = s.cEffect and t.cStatic = s.cStatic and t.cSse = s.cSse and
      t.cReply = First and t.cAudience = OwnerOnly and t.cPhase = s.cPhase and
      t.cGeneration = s.cGeneration and t.cCount = s.cCount and t.cPresent = s.cPresent and
      t.cStaleAccepted = s.cStaleAccepted and t.cGate = s.cGate and t.cRetained = s.cRetained and
      t.cFilePersisted = s.cFilePersisted and t.cRoundPersisted = Persisted and
      t.cResolvePersisted = s.cResolvePersisted and t.cRoundThread = Open and
      t.cRoundReplies = add[s.cRoundReplies, 1] and t.cRetainedResolvedRound = s.cRetainedResolvedRound and
      t.cOutcome = Accepted and t.cLast = i) or
   (i.route = ReplyRoute and s.cRoundThread != Open and
      currentCopyEffects[s, t] and t.cOutcome = Rejected409 and t.cLast = i) or
   (i.route = ResolveRoute and
      t.cSelected = s.cSelected and t.cEffect = s.cEffect and t.cStatic = s.cStatic and t.cSse = s.cSse and
      t.cReply = First and t.cAudience = OwnerOnly and t.cPhase = s.cPhase and
      t.cGeneration = s.cGeneration and t.cCount = s.cCount and t.cPresent = s.cPresent and
      t.cStaleAccepted = s.cStaleAccepted and t.cGate = s.cGate and t.cRetained = s.cRetained and
      t.cFilePersisted = s.cFilePersisted and t.cRoundPersisted = s.cRoundPersisted and
      t.cResolvePersisted = s.cResolvePersisted and t.cRoundThread = s.cRoundThread and
      t.cRoundReplies = s.cRoundReplies and t.cRetainedResolvedRound = s.cRetainedResolvedRound and
      t.cOutcome = Accepted and t.cLast = i))
}
pred currentDeliver[s, t: CurrentState, i: Input] {
  currentGlobal[s, t, i] or currentHtml[s, t, i] or
  currentRoundDeliver[s, t, i] or currentQueryApi[s, t, i] or currentGateReject[s, t, i] or currentBareSubmit[s, t, i] or
  currentBareOther[s, t, i]
}
abstract sig CurrentDeliveryGuard {}
one sig CurrentGlobal, CurrentHtml, CurrentQueryApi, CurrentBareSubmit,
  CurrentGateReject, CurrentBareOther, CurrentRoundDeliver extends CurrentDeliveryGuard {}
pred currentGuardLabel[s: CurrentState, i: Input, guard: CurrentDeliveryGuard] {
  (guard = CurrentGlobal and currentGlobalGuard[s, i]) or
  (guard = CurrentHtml and currentHtmlGuard[s, i]) or
  (guard = CurrentQueryApi and currentQueryApiGuard[s, i]) or
  (guard = CurrentBareSubmit and currentBareSubmitGuard[s, i]) or
  (guard = CurrentGateReject and currentGateRejectGuard[s, i]) or
  (guard = CurrentBareOther and currentBareOtherGuard[s, i]) or
  (guard = CurrentRoundDeliver and currentRoundDeliverGuard[s, i])
}
pred sameCurrentObservation[t, u: CurrentState] {
  t.cSelected = u.cSelected and t.cEffect = u.cEffect and
  t.cStatic = u.cStatic and t.cSse = u.cSse and t.cReply = u.cReply and
  t.cAudience = u.cAudience and t.cPhase = u.cPhase and
  t.cGeneration = u.cGeneration and t.cCount = u.cCount and
  t.cPresent = u.cPresent and t.cOutcome = u.cOutcome and t.cLast = u.cLast and
  t.cStaleAccepted = u.cStaleAccepted and t.cGate = u.cGate and
  t.cRetained = u.cRetained and t.cFilePersisted = u.cFilePersisted and
  t.cRoundPersisted = u.cRoundPersisted and t.cResolvePersisted = u.cResolvePersisted and
  t.cRoundThread = u.cRoundThread and t.cRoundReplies = u.cRoundReplies and
  t.cRetainedResolvedRound = u.cRetainedResolvedRound
}
pred currentGo[s, t: CurrentState] {
  s.cPhase = WaitingGo and nextGeneration[s.cGeneration, t.cGeneration]
  t.cSelected = s.cSelected and t.cEffect = s.cEffect and t.cStatic = s.cStatic and
  t.cSse = s.cSse and t.cReply = s.cReply and t.cAudience = s.cAudience
  t.cPhase = Collecting and t.cCount = 0 and no t.cPresent
  t.cOutcome = Accepted and no t.cLast and t.cStaleAccepted = s.cStaleAccepted
  t.cGate = s.cGate and t.cRetained = s.cRetained and
  t.cFilePersisted = s.cFilePersisted and
  t.cRoundPersisted = s.cRoundPersisted and t.cResolvePersisted = s.cResolvePersisted and
  t.cRoundThread = s.cRoundThread and t.cRoundReplies = s.cRoundReplies and
  t.cRetainedResolvedRound = s.cRetainedResolvedRound
}

pred CurrentRouteWitness {
  some s, shown, affected: CurrentState, h, api: Input |
    currentInit[s] and h.route = HtmlRoute and h.context = ValidSecond and
    h.file = Second and currentDeliver[s, shown, h] and
    api.route = StateRoute and api.context = Missing and api.file = Second and
    currentDeliver[shown, affected, api] and
    affected.cSelected = Second and affected.cEffect = First
}
pred CurrentDuplicateWitness {
  some s, onceState, twice: CurrentState, retry: Input |
    currentInit[s] and retry.route = SubmitRoute and retry.context = Missing and
    retry.file = First and retry.decision = Approve and
    currentDeliver[s, onceState, retry] and currentDeliver[onceState, twice, retry] and
    twice.cPhase = Exited and twice.cPresent = First
}
pred CurrentGenerationWitness {
  some s, rc, advanced, stale: CurrentState, first, delayed: Input |
    currentInit[s] and first.route = SubmitRoute and first.context = Missing and
    first.decision = RequestChanges and first.generation = 1 and
    currentDeliver[s, rc, first] and currentGo[rc, advanced] and
    delayed.route = SubmitRoute and delayed.context = Missing and delayed.generation = 1 and
    currentDeliver[advanced, stale, delayed] and delayed in stale.cStaleAccepted
}
pred CurrentStaticWitness {
  some s, t: CurrentState, i: Input |
    currentInit[s] and i.route = StaticRoute and i.context = Missing and
    currentDeliver[s, t, i] and t.cOutcome = Accepted and t.cStatic = First
}
pred CurrentUnanchoredTransitionWitness {
  some s, commented, rejected: CurrentState, comment, submit: Input |
    currentInit[s] and comment.route = CommentRoute and comment.context = Missing and
    comment.file = First and comment.scope = FileThread and comment.gate = UnanchoredOnly and
    currentDeliver[s, commented, comment] and First in commented.cRetained and
    submit.route = SubmitRoute and submit.context = Missing and submit.file = First and
    submit.decision = Approve and currentDeliver[commented, rejected, submit] and
    rejected.cOutcome = Rejected409
}
assert CurrentRoutePreservesSelection {
  all s, t: CurrentState, i: Input |
    currentDeliver[s, t, i] and s.cSelected = Second and i.context = Missing and
    (i.route = StateRoute or i.route = SubmitRoute or i.route = CliRoute)
    implies t.cEffect = Second
}
assert CurrentDoesNotFinishEarly {
  all s, t: CurrentState, i: Input |
    currentDeliver[s, t, i] and s.cPhase != Exited and t.cPhase = Exited
      implies t.cPresent = First + Second
}
assert CurrentRejectsOldGeneration {
  all s, t: CurrentState, i: Input |
    currentDeliver[s, t, i] and i.route = SubmitRoute and
    i.context = Missing and i.generation != s.cGeneration
      implies i not in t.cStaleAccepted
}

sig RepairedState {
  rSelected, rEffect, rStatic, rSse, rReply, rOwner: one File,
  rAudience: one Audience,
  rPhase: one Phase,
  rGeneration: one Int,
  rLatest: File -> lone Input,
  rRawEffects: one Int,
  rEmitted: set Int,
  rOutcome: one Outcome,
  rLast: lone Input,
  rGate: File -> one GateState,
  rRetained, rFilePersisted: set File,
  rRoundPersisted, rResolvePersisted: one Persistence,
  rRoundThread: one RoundThreadState,
  rRoundReplies: one Int,
  rRetainedResolvedRound: one Persistence
}

pred repairedInit[s: RepairedState] {
  s.rSelected = First and s.rEffect = First and s.rStatic = First and
  s.rSse = First and s.rReply = First and s.rOwner = First and
  s.rAudience = Nobody and s.rPhase = Collecting and s.rGeneration = 1
  no s.rLatest and s.rRawEffects = 0 and no s.rEmitted
  s.rOutcome = Accepted and no s.rLast
  s.rGate = First->GateClear + Second->GateClear and
  no s.rRetained and no s.rFilePersisted and
  s.rRoundPersisted = NotPersisted and s.rResolvePersisted = NotPersisted and
  s.rRoundThread = NoThread and s.rRoundReplies = 0 and
  s.rRetainedResolvedRound = NotPersisted
}
pred repairedCopyEffects[s, t: RepairedState] {
  t.rSelected = s.rSelected and t.rEffect = s.rEffect and
  t.rStatic = s.rStatic and t.rSse = s.rSse and t.rReply = s.rReply and
  t.rOwner = s.rOwner and t.rAudience = s.rAudience and
  t.rPhase = s.rPhase and t.rGeneration = s.rGeneration and
  t.rLatest = s.rLatest and t.rRawEffects = s.rRawEffects and
  t.rEmitted = s.rEmitted and t.rGate = s.rGate and
  t.rRetained = s.rRetained and t.rFilePersisted = s.rFilePersisted and
  t.rRoundPersisted = s.rRoundPersisted and t.rResolvePersisted = s.rResolvePersisted and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound
}
pred allFilesPresent[latest: File -> Input] { some First.latest and some Second.latest }
pred aggregateRequestChanges[latest: File -> Input] {
  some i: File.latest | i.decision = RequestChanges
}
pred exactRetry[s: RepairedState, i: Input] {
  some prior: i.file.(s.rLatest) | samePayload[prior, i]
}
pred repairedRejected[s, t: RepairedState, i: Input, code: Outcome] {
  repairedCopyEffects[s, t] and t.rOutcome = code and t.rLast = i
}
pred repairedGlobalGuard[s: RepairedState, i: Input] { globalRoute[i.route] }
pred repairedContextRejectGuard[s: RepairedState, i: Input] {
  not globalRoute[i.route] and not validOwned[i]
}
pred repairedOwnerRejectGuard[s: RepairedState, i: Input] {
  (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and validOwned[i] and
  i.scope = FileThread and i.owner != i.file
}
pred repairedHtmlGuard[s: RepairedState, i: Input] { i.route = HtmlRoute and validOwned[i] }
pred repairedSubmitRejectGuard[s: RepairedState, i: Input] {
  i.route = SubmitRoute and validOwned[i] and
  (s.rPhase != Collecting or i.generation != s.rGeneration or
    (i.decision = Approve and i.file.(s.rGate) = AnchoredUnresolved))
}
pred repairedRetryGuard[s: RepairedState, i: Input] {
  i.route = SubmitRoute and validOwned[i] and s.rPhase = Collecting and
  i.generation = s.rGeneration and
  (i.decision != Approve or i.file.(s.rGate) != AnchoredUnresolved) and exactRetry[s, i]
}
pred repairedAcceptSubmitGuard[s: RepairedState, i: Input] {
  i.route = SubmitRoute and validOwned[i] and s.rPhase = Collecting and
  i.generation = s.rGeneration and
  (i.decision != Approve or i.file.(s.rGate) != AnchoredUnresolved) and not exactRetry[s, i]
}
pred repairedRouteGuard[s: RepairedState, i: Input] {
  not globalRoute[i.route] and validOwned[i] and
  i.route != HtmlRoute and i.route != SubmitRoute and
  not (i.scope = RoundThread and
    (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute)) and
  not ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
    i.scope = FileThread and i.owner != i.file)
}
pred repairedRoundDeliverGuard[s: RepairedState, i: Input] {
  validOwned[i] and i.scope = RoundThread and
  (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute)
}
pred repairedGlobal[s, t: RepairedState, i: Input] {
  repairedGlobalGuard[s, i]
  ((i.context = Global and repairedRejected[s, t, i, Accepted]) or
  (i.context != Global and repairedRejected[s, t, i, Rejected400]))
}
pred repairedContextReject[s, t: RepairedState, i: Input] {
  repairedContextRejectGuard[s, i]
  repairedRejected[s, t, i, Rejected400]
}
pred repairedOwnerReject[s, t: RepairedState, i: Input] {
  repairedOwnerRejectGuard[s, i]
  repairedRejected[s, t, i, Rejected400]
}
pred repairedHtml[s, t: RepairedState, i: Input] {
  repairedHtmlGuard[s, i]
  t.rSelected = i.file and t.rEffect = s.rEffect and t.rStatic = s.rStatic and
  t.rSse = s.rSse and t.rReply = s.rReply and t.rOwner = s.rOwner and
  t.rAudience = s.rAudience and t.rPhase = s.rPhase and
  t.rGeneration = s.rGeneration and t.rLatest = s.rLatest and
  t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and
  t.rGate = s.rGate and t.rRetained = s.rRetained and
  t.rFilePersisted = s.rFilePersisted and
  t.rRoundPersisted = s.rRoundPersisted and t.rResolvePersisted = s.rResolvePersisted and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound
  t.rOutcome = Accepted and t.rLast = i
}
pred repairedSubmitReject[s, t: RepairedState, i: Input] {
  repairedSubmitRejectGuard[s, i]
  repairedRejected[s, t, i, Rejected409]
}
pred repairedRetry[s, t: RepairedState, i: Input] {
  repairedRetryGuard[s, i]
  repairedRejected[s, t, i, Accepted]
}
pred repairedAcceptSubmit[s, t: RepairedState, i: Input] {
  repairedAcceptSubmitGuard[s, i]
  let next = (s.rLatest - (i.file -> Input)) + (i.file -> i) |
    t.rLatest = next and
    t.rPhase = (allFilesPresent[next] => RoundComplete else Collecting) and
    t.rEmitted = (allFilesPresent[next] => s.rEmitted + s.rGeneration else s.rEmitted)
  t.rSelected = i.file and t.rEffect = i.file and t.rStatic = s.rStatic and
  t.rSse = s.rSse and t.rReply = s.rReply and t.rOwner = s.rOwner and
  t.rAudience = s.rAudience and t.rGeneration = s.rGeneration and
  t.rRawEffects = add[s.rRawEffects, 1] and t.rGate = s.rGate and
  t.rRetained = s.rRetained and t.rFilePersisted = s.rFilePersisted and
  t.rRoundPersisted = s.rRoundPersisted and t.rResolvePersisted = s.rResolvePersisted and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound and
  t.rOutcome = Accepted and t.rLast = i
}
pred repairedRoute[s, t: RepairedState, i: Input] {
  repairedRouteGuard[s, i]
  t.rSelected = i.file
  t.rEffect = ((i.route = StateRoute or i.route = CliRoute) => i.file else s.rEffect)
  t.rStatic = (i.route = StaticRoute => i.file else s.rStatic)
  t.rSse = (i.route = SseRoute => i.file else s.rSse)
  t.rReply = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) => i.owner else s.rReply)
  t.rOwner = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) => i.owner else s.rOwner)
  t.rAudience = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) =>
    (i.scope = RoundThread => AllContexts else OwnerOnly) else s.rAudience)
  t.rPhase = s.rPhase and t.rGeneration = s.rGeneration and
  t.rLatest = s.rLatest and t.rRawEffects = s.rRawEffects and
  t.rEmitted = s.rEmitted
  t.rGate = (i.route = CommentRoute and i.scope = FileThread =>
    (s.rGate - (i.file->GateState)) + i.file->i.gate else
    (i.route = ResolveRoute and i.scope = FileThread =>
      (s.rGate - (i.file->GateState)) + i.file->GateClear else s.rGate))
  t.rRetained = (i.route = CommentRoute and i.scope = FileThread and i.gate = UnanchoredOnly =>
    s.rRetained + i.file else s.rRetained)
  t.rFilePersisted = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and i.scope = FileThread =>
    s.rFilePersisted + i.owner else s.rFilePersisted)
  t.rRoundPersisted = ((i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and i.scope = RoundThread =>
    Persisted else s.rRoundPersisted)
  t.rResolvePersisted = (i.route = ResolveRoute => Persisted else s.rResolvePersisted) and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound and
  t.rOutcome = Accepted and t.rLast = i
}
pred repairedRoundDeliver[s, t: RepairedState, i: Input] {
  repairedRoundDeliverGuard[s, i]
  ((i.route = CommentRoute and (s.rRoundThread = NoThread or s.rRoundThread = Resolved) and
      t.rSelected = i.file and t.rEffect = s.rEffect and t.rStatic = s.rStatic and t.rSse = s.rSse and
      t.rReply = i.owner and t.rOwner = i.owner and t.rAudience = (i.mode = Mux => AllContexts else OwnerOnly) and
      t.rPhase = s.rPhase and t.rGeneration = s.rGeneration and t.rLatest = s.rLatest and
      t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and t.rGate = s.rGate and
      t.rRetained = s.rRetained and t.rFilePersisted = s.rFilePersisted and
      t.rRoundPersisted = Persisted and t.rResolvePersisted = s.rResolvePersisted and
      t.rRoundThread = Open and t.rRoundReplies = s.rRoundReplies and
      t.rRetainedResolvedRound = (s.rRoundThread = Resolved => Persisted else s.rRetainedResolvedRound) and
      t.rOutcome = Accepted and t.rLast = i) or
   (i.route = CommentRoute and s.rRoundThread = Open and repairedRejected[s, t, i, Rejected409]) or
   (i.route = ReplyRoute and s.rRoundThread = Open and
      t.rSelected = i.file and t.rEffect = s.rEffect and t.rStatic = s.rStatic and t.rSse = s.rSse and
      t.rReply = i.owner and t.rOwner = i.owner and t.rAudience = (i.mode = Mux => AllContexts else OwnerOnly) and
      t.rPhase = s.rPhase and t.rGeneration = s.rGeneration and t.rLatest = s.rLatest and
      t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and t.rGate = s.rGate and
      t.rRetained = s.rRetained and t.rFilePersisted = s.rFilePersisted and
      t.rRoundPersisted = Persisted and t.rResolvePersisted = s.rResolvePersisted and
      t.rRoundThread = Open and t.rRoundReplies = add[s.rRoundReplies, 1] and
      t.rRetainedResolvedRound = s.rRetainedResolvedRound and t.rOutcome = Accepted and t.rLast = i) or
   (i.route = ReplyRoute and s.rRoundThread != Open and repairedRejected[s, t, i, Rejected409]) or
   (i.route = ResolveRoute and s.rRoundThread = Open and
      t.rSelected = i.file and t.rEffect = s.rEffect and t.rStatic = s.rStatic and t.rSse = s.rSse and
      t.rReply = i.owner and t.rOwner = i.owner and t.rAudience = (i.mode = Mux => AllContexts else OwnerOnly) and
      t.rPhase = s.rPhase and t.rGeneration = s.rGeneration and t.rLatest = s.rLatest and
      t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and t.rGate = s.rGate and
      t.rRetained = s.rRetained and t.rFilePersisted = s.rFilePersisted and
      t.rRoundPersisted = Persisted and t.rResolvePersisted = Persisted and
      t.rRoundThread = Resolved and t.rRoundReplies = s.rRoundReplies and
      t.rRetainedResolvedRound = Persisted and t.rOutcome = Accepted and t.rLast = i) or
   (i.route = ResolveRoute and s.rRoundThread = Resolved and repairedRejected[s, t, i, Accepted]) or
   (i.route = ResolveRoute and s.rRoundThread = NoThread and i.mode = Single and repairedRejected[s, t, i, Accepted]) or
   (i.route = ResolveRoute and s.rRoundThread = NoThread and i.mode = Mux and repairedRejected[s, t, i, Rejected400]))
}
pred repairedDeliver[s, t: RepairedState, i: Input] {
  repairedGlobal[s, t, i] or repairedContextReject[s, t, i] or
  repairedOwnerReject[s, t, i] or repairedHtml[s, t, i] or
  repairedSubmitReject[s, t, i] or repairedRetry[s, t, i] or
  repairedAcceptSubmit[s, t, i] or repairedRoundDeliver[s, t, i] or repairedRoute[s, t, i]
}
abstract sig RepairedDeliveryGuard {}
one sig RepairedGlobal, RepairedContextReject, RepairedOwnerReject, RepairedHtml,
  RepairedSubmitReject, RepairedRetry, RepairedAcceptSubmit, RepairedRoute,
  RepairedRoundDeliver extends RepairedDeliveryGuard {}
pred repairedGuardLabel[s: RepairedState, i: Input, guard: RepairedDeliveryGuard] {
  (guard = RepairedGlobal and repairedGlobalGuard[s, i]) or
  (guard = RepairedContextReject and repairedContextRejectGuard[s, i]) or
  (guard = RepairedOwnerReject and repairedOwnerRejectGuard[s, i]) or
  (guard = RepairedHtml and repairedHtmlGuard[s, i]) or
  (guard = RepairedSubmitReject and repairedSubmitRejectGuard[s, i]) or
  (guard = RepairedRetry and repairedRetryGuard[s, i]) or
  (guard = RepairedAcceptSubmit and repairedAcceptSubmitGuard[s, i]) or
  (guard = RepairedRoute and repairedRouteGuard[s, i]) or
  (guard = RepairedRoundDeliver and repairedRoundDeliverGuard[s, i])
}
pred sameRepairedObservation[t, u: RepairedState] {
  t.rSelected = u.rSelected and t.rEffect = u.rEffect and
  t.rStatic = u.rStatic and t.rSse = u.rSse and t.rReply = u.rReply and
  t.rOwner = u.rOwner and t.rAudience = u.rAudience and t.rPhase = u.rPhase and
  t.rGeneration = u.rGeneration and t.rLatest = u.rLatest and
  t.rRawEffects = u.rRawEffects and t.rEmitted = u.rEmitted and
  t.rOutcome = u.rOutcome and t.rLast = u.rLast and t.rGate = u.rGate and
  t.rRetained = u.rRetained and t.rFilePersisted = u.rFilePersisted and
  t.rRoundPersisted = u.rRoundPersisted and t.rResolvePersisted = u.rResolvePersisted and
  t.rRoundThread = u.rRoundThread and t.rRoundReplies = u.rRoundReplies and
  t.rRetainedResolvedRound = u.rRetainedResolvedRound
}
pred repairedResolve[s, t: RepairedState] {
  s.rPhase = RoundComplete and allFilesPresent[s.rLatest]
  t.rSelected = s.rSelected and t.rEffect = s.rEffect and
  t.rStatic = s.rStatic and t.rSse = s.rSse and t.rReply = s.rReply and
  t.rOwner = s.rOwner and t.rAudience = s.rAudience and
  t.rGeneration = s.rGeneration and t.rLatest = s.rLatest and
  t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and
  t.rGate = s.rGate and t.rRetained = s.rRetained and
  t.rFilePersisted = s.rFilePersisted and
  t.rRoundPersisted = s.rRoundPersisted and t.rResolvePersisted = s.rResolvePersisted and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound and
  t.rPhase = (aggregateRequestChanges[s.rLatest] => WaitingGo else Exited)
  t.rOutcome = Accepted and no t.rLast
}

pred repairedAcceptedRoundResolveNoOp[s, t: RepairedState, i: Input] {
  validOwned[i] and i.scope = RoundThread and i.route = ResolveRoute and
  (s.rRoundThread = Resolved or (i.mode = Single and s.rRoundThread = NoThread)) and
  t.rOutcome = Accepted and repairedCopyEffects[s, t]
}

// The finite invariant domain is generations 1..4. The transition itself is
// unbounded; RepairedGenerationFiveWitness checks the next state explicitly.
pred repairedBoundedInvariant[s: RepairedState] {
  s.rGeneration >= 1 and s.rGeneration <= 4
  all f: File | lone f.(s.rLatest)
  all f: File, i: Input | f->i in s.rLatest implies i.file = f
  all i: File.(s.rLatest) | i.generation = s.rGeneration
  (s.rPhase = Collecting implies not allFilesPresent[s.rLatest])
  (s.rPhase = RoundComplete implies allFilesPresent[s.rLatest])
  (s.rPhase = WaitingGo implies
    allFilesPresent[s.rLatest] and aggregateRequestChanges[s.rLatest])
  (s.rPhase = Exited implies
    allFilesPresent[s.rLatest] and not aggregateRequestChanges[s.rLatest])
  (s.rPhase != Collecting implies s.rGeneration in s.rEmitted)
  all emitted: s.rEmitted |
    emitted >= 1 and emitted <= s.rGeneration and
    (emitted > 1 implies sub[emitted, 1] in s.rEmitted)
  all prior: Int |
    prior >= 1 and prior < s.rGeneration implies prior in s.rEmitted
}
pred repairedGo[s, t: RepairedState] {
  s.rPhase = WaitingGo and aggregateRequestChanges[s.rLatest] and
  nextGeneration[s.rGeneration, t.rGeneration]
  t.rSelected = s.rSelected and t.rEffect = s.rEffect and
  t.rStatic = s.rStatic and t.rSse = s.rSse and t.rReply = s.rReply and
  t.rOwner = s.rOwner and t.rAudience = s.rAudience and
  t.rPhase = Collecting and no t.rLatest and
  t.rRawEffects = s.rRawEffects and t.rEmitted = s.rEmitted and
  t.rGate = s.rGate and t.rRetained = s.rRetained and
  t.rFilePersisted = s.rFilePersisted and
  t.rRoundPersisted = s.rRoundPersisted and t.rResolvePersisted = s.rResolvePersisted and
  t.rRoundThread = s.rRoundThread and t.rRoundReplies = s.rRoundReplies and
  t.rRetainedResolvedRound = s.rRetainedResolvedRound and
  t.rOutcome = Accepted and no t.rLast
}

assert RepairedDeliverySafety {
  all s, t: RepairedState, i: Input | repairedDeliver[s, t, i] implies {
    (t.rOutcome = Rejected400 or t.rOutcome = Rejected409) implies repairedCopyEffects[s, t]
    (i.route = SubmitRoute and exactRetry[s, i] and t.rOutcome = Accepted) implies repairedCopyEffects[s, t]
    (t.rOutcome = Accepted and not globalRoute[i.route]) implies
      (validOwned[i] and (exactRetry[s, i] or repairedAcceptedRoundResolveNoOp[s, t, i] or t.rSelected = i.file))
    (t.rOutcome = Accepted and (i.route = StateRoute or i.route = SubmitRoute or
      i.route = CliRoute) and not exactRetry[s, i]) implies t.rEffect = i.file
    (t.rOutcome = Accepted and i.route = StaticRoute) implies t.rStatic = i.file
    (t.rOutcome = Accepted and i.route = SseRoute) implies t.rSse = i.file
    (t.rOutcome = Accepted and (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
      i.scope = FileThread) implies (t.rReply = i.owner and t.rAudience = OwnerOnly)
    (t.rOutcome = Accepted and (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
      i.scope = RoundThread and i.mode = Mux and not repairedAcceptedRoundResolveNoOp[s, t, i]) implies t.rAudience = AllContexts
    (t.rOutcome = Accepted and (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
      i.scope = RoundThread and i.mode = Single and not repairedAcceptedRoundResolveNoOp[s, t, i]) implies t.rAudience = OwnerOnly
    (i.route = SubmitRoute and validOwned[i] and
      i.generation != s.rGeneration) implies t.rOutcome = Rejected409
    (t.rOutcome = Accepted and (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
      i.scope = FileThread) implies i.owner in t.rFilePersisted
    (t.rOutcome = Accepted and (i.route = CommentRoute or i.route = ReplyRoute or i.route = ResolveRoute) and
      i.scope = RoundThread) implies
      (repairedAcceptedRoundResolveNoOp[s, t, i] or
        t.rRoundPersisted = Persisted)
    (t.rOutcome = Accepted and i.route = ResolveRoute) implies
      (repairedAcceptedRoundResolveNoOp[s, t, i] or
        t.rResolvePersisted = Persisted)
    (t.rOutcome = Accepted and i.route = CommentRoute and i.scope = FileThread) implies {
      i.file.(t.rGate) = i.gate
      i.gate = UnanchoredOnly implies i.file in t.rRetained
    }
    (i.route = SubmitRoute and validOwned[i] and i.decision = Approve and
      i.file.(s.rGate) = AnchoredUnresolved) implies t.rOutcome = Rejected409
  }
}
assert RepairedGlobalRoutesAreBareOnly {
  all s, t: RepairedState, i: Input |
    repairedDeliver[s, t, i] and globalRoute[i.route] implies
      ((i.context = Global and t.rOutcome = Accepted) or
       (i.context != Global and t.rOutcome = Rejected400))
}
assert RepairedResolveSafety {
  all s, t: RepairedState | repairedResolve[s, t] implies {
    allFilesPresent[s.rLatest]
    (t.rPhase = WaitingGo iff aggregateRequestChanges[s.rLatest])
    (t.rPhase = Exited iff not aggregateRequestChanges[s.rLatest])
  }
}
assert RepairedGoSafety {
  all s, t: RepairedState | repairedGo[s, t] implies {
    s.rPhase = WaitingGo and t.rPhase = Collecting and no t.rLatest and
    nextGeneration[s.rGeneration, t.rGeneration] and t.rEmitted = s.rEmitted
  }
}
assert RepairedBoundedInvariantPreserved {
  all s, t: RepairedState, i: Input |
    repairedBoundedInvariant[s] and repairedDeliver[s, t, i] implies repairedBoundedInvariant[t]
  all s, t: RepairedState |
    repairedBoundedInvariant[s] and repairedResolve[s, t] implies repairedBoundedInvariant[t]
  all s, t: RepairedState |
    repairedBoundedInvariant[s] and repairedGo[s, t] and t.rGeneration <= 4 implies repairedBoundedInvariant[t]
}

pred RepairedContextWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = StateRoute and i.context = ValidSecond and
    i.file = Second and repairedDeliver[s, t, i] and t.rEffect = Second
}
pred RepairedRejectedContextWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = StateRoute and i.context = Missing and
    repairedDeliver[s, t, i] and t.rOutcome = Rejected400 and repairedCopyEffects[s, t]
}
pred RepairedReplacementWitness {
  some s, first, replaced: RepairedState, a, b: Input |
    repairedInit[s] and a.route = SubmitRoute and b.route = SubmitRoute and
    a.context = ValidFirst and b.context = ValidFirst and a.file = First and b.file = First and
    a.generation = 1 and b.generation = 1 and a.payload != b.payload and
    repairedDeliver[s, first, a] and repairedDeliver[first, replaced, b] and
    First.(replaced.rLatest) = b and no Second.(replaced.rLatest)
}
pred RepairedRetryWitness {
  some s, first, retried: RepairedState, a, retry: Input |
    repairedInit[s] and a.route = SubmitRoute and retry.route = SubmitRoute and
    a.context = ValidFirst and retry.context = ValidFirst and a.file = First and retry.file = First and
    samePayload[a, retry] and repairedDeliver[s, first, a] and
    repairedDeliver[first, retried, retry] and repairedCopyEffects[first, retried]
}
pred RepairedWaitingGoWitness {
  some s, aDone, complete, waiting: RepairedState, a, b: Input |
    repairedInit[s] and a.route = SubmitRoute and a.context = ValidFirst and a.file = First and
    a.generation = 1 and a.decision = RequestChanges and
    b.route = SubmitRoute and b.context = ValidSecond and b.file = Second and
    b.generation = 1 and b.decision = Approve and
    repairedDeliver[s, aDone, a] and repairedDeliver[aDone, complete, b] and
    repairedResolve[complete, waiting] and waiting.rPhase = WaitingGo
}
pred RepairedCompletionWitness {
  some s, aDone, complete, exited: RepairedState, a, b: Input |
    repairedInit[s] and a.route = SubmitRoute and a.context = ValidFirst and a.file = First and
    a.generation = 1 and a.decision = Approve and
    b.route = SubmitRoute and b.context = ValidSecond and b.file = Second and
    b.generation = 1 and b.decision = Approve and
    repairedDeliver[s, aDone, a] and repairedDeliver[aDone, complete, b] and
    repairedResolve[complete, exited] and exited.rPhase = Exited and exited.rEmitted = 1
}
pred RepairedOldPostRejectedWitness {
  some s, aDone, complete, waiting, advanced, rejected: RepairedState, a, b, old: Input |
    repairedInit[s] and a.route = SubmitRoute and a.context = ValidFirst and a.file = First and
    a.generation = 1 and a.decision = RequestChanges and
    b.route = SubmitRoute and b.context = ValidSecond and b.file = Second and b.generation = 1 and
    old.route = SubmitRoute and old.context = ValidFirst and old.file = First and old.generation = 1 and
    repairedDeliver[s, aDone, a] and repairedDeliver[aDone, complete, b] and
    repairedResolve[complete, waiting] and repairedGo[waiting, advanced] and
    repairedDeliver[advanced, rejected, old] and rejected.rOutcome = Rejected409 and
    repairedCopyEffects[advanced, rejected]
}
pred RepairedFileReplyWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = ReplyRoute and i.context = ValidSecond and
    i.mode = Mux and i.file = Second and i.owner = Second and i.scope = FileThread and
    repairedDeliver[s, t, i] and t.rAudience = OwnerOnly and t.rReply = Second and
    Second in t.rFilePersisted
}
pred RepairedRoundReplyWitness {
  some s, created, replied: RepairedState, create, reply: Input |
    repairedInit[s] and create.route = CommentRoute and create.context = ValidFirst and
    create.mode = Mux and create.file = First and create.scope = RoundThread and
    reply.route = ReplyRoute and reply.context = ValidFirst and reply.mode = Mux and
    reply.file = First and reply.scope = RoundThread and
    repairedDeliver[s, created, create] and repairedDeliver[created, replied, reply] and
    replied.rAudience = AllContexts and replied.rRoundPersisted = Persisted
}
pred RepairedUnanchoredTransitionWitness {
  some s, commented, approved: RepairedState, comment, submit: Input |
    repairedInit[s] and comment.route = CommentRoute and comment.context = ValidFirst and
    comment.file = First and comment.owner = First and comment.scope = FileThread and
    comment.gate = UnanchoredOnly and repairedDeliver[s, commented, comment] and
    First in commented.rRetained and First.(commented.rGate) = UnanchoredOnly and
    submit.route = SubmitRoute and submit.context = ValidFirst and submit.file = First and
    submit.owner = First and submit.generation = 1 and submit.decision = Approve and
    repairedDeliver[commented, approved, submit] and approved.rOutcome = Accepted
}
pred RepairedAnchoredTransitionWitness {
  some s, commented, rejected: RepairedState, comment, submit: Input |
    repairedInit[s] and comment.route = CommentRoute and comment.context = ValidFirst and
    comment.file = First and comment.owner = First and comment.scope = FileThread and
    comment.gate = AnchoredUnresolved and repairedDeliver[s, commented, comment] and
    submit.route = SubmitRoute and submit.context = ValidFirst and submit.file = First and
    submit.owner = First and submit.generation = 1 and submit.decision = Approve and
    repairedDeliver[commented, rejected, submit] and rejected.rOutcome = Rejected409
}
pred RepairedPersistenceTransitionWitness {
  some s, replied, resolved, roundCreated, roundReplied: RepairedState, fileReply, fileResolve, roundCreate, roundReply: Input |
    repairedInit[s] and fileReply.route = ReplyRoute and fileReply.context = ValidSecond and
    fileReply.mode = Mux and fileReply.file = Second and fileReply.owner = Second and fileReply.scope = FileThread and
    repairedDeliver[s, replied, fileReply] and Second in replied.rFilePersisted and
    fileResolve.route = ResolveRoute and fileResolve.context = ValidSecond and
    fileResolve.mode = Mux and fileResolve.file = Second and fileResolve.owner = Second and fileResolve.scope = FileThread and
    repairedDeliver[replied, resolved, fileResolve] and resolved.rResolvePersisted = Persisted and
    roundCreate.route = CommentRoute and roundCreate.context = ValidFirst and roundCreate.mode = Mux and
    roundCreate.file = First and roundCreate.scope = RoundThread and
    repairedDeliver[resolved, roundCreated, roundCreate] and
    roundReply.route = ReplyRoute and roundReply.context = ValidFirst and roundReply.mode = Mux and
    roundReply.file = First and roundReply.scope = RoundThread and
    repairedDeliver[roundCreated, roundReplied, roundReply] and
    roundReplied.rRoundPersisted = Persisted and roundReplied.rAudience = AllContexts
}
pred RepairedResolveClearsGateWitness {
  some s, commented, resolved, approved: RepairedState, comment, resolve, submit: Input |
    repairedInit[s] and comment.route = CommentRoute and comment.context = ValidFirst and
    comment.file = First and comment.owner = First and comment.scope = FileThread and
    comment.gate = AnchoredUnresolved and repairedDeliver[s, commented, comment] and
    resolve.route = ResolveRoute and resolve.context = ValidFirst and resolve.file = First and
    resolve.owner = First and resolve.scope = FileThread and repairedDeliver[commented, resolved, resolve] and
    First.(resolved.rGate) = GateClear and resolved.rResolvePersisted = Persisted and
    submit.route = SubmitRoute and submit.context = ValidFirst and submit.file = First and
    submit.owner = First and submit.generation = 1 and submit.decision = Approve and
    repairedDeliver[resolved, approved, submit] and approved.rOutcome = Accepted
}
pred RepairedHtmlWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = HtmlRoute and i.context = ValidSecond and
    i.file = Second and repairedDeliver[s, t, i] and t.rSelected = Second
}
pred RepairedGlobalWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = HealthzRoute and i.context = Global and
    repairedDeliver[s, t, i] and t.rOutcome = Accepted and repairedCopyEffects[s, t]
}
pred RepairedGlobalWithContextRejectedWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = UiJsRoute and i.context = ValidSecond and
    repairedDeliver[s, t, i] and t.rOutcome = Rejected400 and repairedCopyEffects[s, t]
}
pred RepairedOwnerRejectWitness {
  some s, t: RepairedState, i: Input |
    repairedInit[s] and i.route = ReplyRoute and i.context = ValidSecond and
    i.file = Second and i.owner = First and i.scope = FileThread and
    repairedDeliver[s, t, i] and t.rOutcome = Rejected400 and repairedCopyEffects[s, t]
}
pred RepairedSecondReplacementWitness {
  some s, firstState, replaced: RepairedState, a, b: Input |
    repairedInit[s] and a.route = SubmitRoute and b.route = SubmitRoute and
    a.context = ValidSecond and b.context = ValidSecond and
    a.file = Second and b.file = Second and a.generation = 1 and b.generation = 1 and
    a.payload != b.payload and repairedDeliver[s, firstState, a] and
    repairedDeliver[firstState, replaced, b] and Second.(replaced.rLatest) = b and
    no First.(replaced.rLatest)
}
pred RepairedReversePriorityWitness {
  some s, bDone, completeState, waitingState: RepairedState, a, b: Input |
    repairedInit[s] and b.route = SubmitRoute and b.context = ValidSecond and
    b.file = Second and b.generation = 1 and b.decision = Approve and
    a.route = SubmitRoute and a.context = ValidFirst and a.file = First and
    a.generation = 1 and a.decision = RequestChanges and
    repairedDeliver[s, bDone, b] and repairedDeliver[bDone, completeState, a] and
    repairedResolve[completeState, waitingState] and waitingState.rPhase = WaitingGo
}
pred RepairedTerminalSubmitRejectedWitness {
  some s, aDone, completeState, rejected: RepairedState, a, b, retry: Input |
    repairedInit[s] and a.route = SubmitRoute and a.context = ValidFirst and
    a.file = First and a.generation = 1 and
    b.route = SubmitRoute and b.context = ValidSecond and b.file = Second and b.generation = 1 and
    retry.route = SubmitRoute and retry.context = ValidFirst and retry.file = First and retry.generation = 1 and
    repairedDeliver[s, aDone, a] and repairedDeliver[aDone, completeState, b] and
    repairedDeliver[completeState, rejected, retry] and rejected.rOutcome = Rejected409 and
    repairedCopyEffects[completeState, rejected]
}
pred RepairedThreeGenerationWitness {
  some s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11: RepairedState,
    a1, b1, a2, b2, a3, b3: Input |
    repairedInit[s0] and
    a1.route = SubmitRoute and a1.context = ValidFirst and a1.file = First and a1.generation = 1 and a1.decision = RequestChanges and
    b1.route = SubmitRoute and b1.context = ValidSecond and b1.file = Second and b1.generation = 1 and b1.decision = Approve and
    repairedDeliver[s0, s1, a1] and repairedDeliver[s1, s2, b1] and repairedResolve[s2, s3] and repairedGo[s3, s4] and
    b2.route = SubmitRoute and b2.context = ValidSecond and b2.file = Second and b2.generation = 2 and b2.decision = Approve and
    a2.route = SubmitRoute and a2.context = ValidFirst and a2.file = First and a2.generation = 2 and a2.decision = RequestChanges and
    repairedDeliver[s4, s5, b2] and repairedDeliver[s5, s6, a2] and repairedResolve[s6, s7] and repairedGo[s7, s8] and
    b3.route = SubmitRoute and b3.context = ValidSecond and b3.file = Second and b3.generation = 3 and b3.decision = Approve and
    a3.route = SubmitRoute and a3.context = ValidFirst and a3.file = First and a3.generation = 3 and a3.decision = Approve and
    repairedDeliver[s8, s9, b3] and repairedDeliver[s9, s10, a3] and repairedResolve[s10, s11] and
    s11.rPhase = Exited and s11.rGeneration = 3 and #s11.rEmitted = 3 and
    1 in s11.rEmitted and 2 in s11.rEmitted and 3 in s11.rEmitted
}
pred RepairedGenerationFourWitness {
  some s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15: RepairedState,
    a1, b1, a2, b2, a3, b3, a4, b4: Input |
    repairedInit[s0] and
    a1.route = SubmitRoute and a1.context = ValidFirst and a1.file = First and a1.generation = 1 and a1.decision = RequestChanges and
    b1.route = SubmitRoute and b1.context = ValidSecond and b1.file = Second and b1.generation = 1 and b1.decision = Approve and
    repairedDeliver[s0, s1, a1] and repairedDeliver[s1, s2, b1] and repairedResolve[s2, s3] and repairedGo[s3, s4] and
    b2.route = SubmitRoute and b2.context = ValidSecond and b2.file = Second and b2.generation = 2 and b2.decision = Approve and
    a2.route = SubmitRoute and a2.context = ValidFirst and a2.file = First and a2.generation = 2 and a2.decision = RequestChanges and
    repairedDeliver[s4, s5, b2] and repairedDeliver[s5, s6, a2] and repairedResolve[s6, s7] and repairedGo[s7, s8] and
    b3.route = SubmitRoute and b3.context = ValidSecond and b3.file = Second and b3.generation = 3 and b3.decision = Approve and
    a3.route = SubmitRoute and a3.context = ValidFirst and a3.file = First and a3.generation = 3 and a3.decision = RequestChanges and
    repairedDeliver[s8, s9, b3] and repairedDeliver[s9, s10, a3] and repairedResolve[s10, s11] and repairedGo[s11, s12] and
    s12.rPhase = Collecting and s12.rGeneration = 4 and no s12.rLatest and
    a4.route = SubmitRoute and a4.context = ValidFirst and a4.file = First and a4.generation = 4 and a4.decision = Approve and
    b4.route = SubmitRoute and b4.context = ValidSecond and b4.file = Second and b4.generation = 4 and b4.decision = Approve and
    repairedDeliver[s12, s13, a4] and repairedDeliver[s13, s14, b4] and repairedResolve[s14, s15] and
    s15.rPhase = Exited and s15.rGeneration = 4 and #s15.rEmitted = 4 and
    1 in s15.rEmitted and 2 in s15.rEmitted and 3 in s15.rEmitted and 4 in s15.rEmitted
}
pred RepairedGenerationFiveWitness {
  some s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16: RepairedState,
    a1, b1, a2, b2, a3, b3, a4, b4: Input |
    repairedInit[s0] and
    a1.route = SubmitRoute and a1.context = ValidFirst and a1.file = First and a1.generation = 1 and a1.decision = RequestChanges and
    b1.route = SubmitRoute and b1.context = ValidSecond and b1.file = Second and b1.generation = 1 and b1.decision = Approve and
    repairedDeliver[s0, s1, a1] and repairedDeliver[s1, s2, b1] and repairedResolve[s2, s3] and repairedGo[s3, s4] and
    b2.route = SubmitRoute and b2.context = ValidSecond and b2.file = Second and b2.generation = 2 and b2.decision = Approve and
    a2.route = SubmitRoute and a2.context = ValidFirst and a2.file = First and a2.generation = 2 and a2.decision = RequestChanges and
    repairedDeliver[s4, s5, b2] and repairedDeliver[s5, s6, a2] and repairedResolve[s6, s7] and repairedGo[s7, s8] and
    b3.route = SubmitRoute and b3.context = ValidSecond and b3.file = Second and b3.generation = 3 and b3.decision = Approve and
    a3.route = SubmitRoute and a3.context = ValidFirst and a3.file = First and a3.generation = 3 and a3.decision = RequestChanges and
    repairedDeliver[s8, s9, b3] and repairedDeliver[s9, s10, a3] and repairedResolve[s10, s11] and repairedGo[s11, s12] and
    a4.route = SubmitRoute and a4.context = ValidFirst and a4.file = First and a4.generation = 4 and a4.decision = RequestChanges and
    b4.route = SubmitRoute and b4.context = ValidSecond and b4.file = Second and b4.generation = 4 and b4.decision = Approve and
    repairedDeliver[s12, s13, a4] and repairedDeliver[s13, s14, b4] and repairedResolve[s14, s15] and
    s15.rPhase = WaitingGo and s15.rGeneration = 4 and #s15.rEmitted = 4 and
    repairedGo[s15, s16] and s16.rGeneration = 5 and s16.rPhase = Collecting and no s16.rLatest
}

pred CurrentRoundResolveBugWitness {
  some s0, s1, s2, s3, s4, s5: CurrentState, create, reply, resolve, replyAfter, createAgain: Input |
    currentInit[s0] and create.scope = RoundThread and create.route = CommentRoute and create.context = Missing and create.mode = Single and
    reply.scope = RoundThread and reply.route = ReplyRoute and reply.context = Missing and reply.mode = Single and
    resolve.scope = RoundThread and resolve.route = ResolveRoute and resolve.context = Missing and resolve.mode = Single and
    replyAfter.scope = RoundThread and replyAfter.route = ReplyRoute and replyAfter.context = Missing and replyAfter.mode = Single and
    createAgain.scope = RoundThread and createAgain.route = CommentRoute and createAgain.context = Missing and createAgain.mode = Single and
    currentDeliver[s0, s1, create] and currentDeliver[s1, s2, reply] and
    currentDeliver[s2, s3, resolve] and currentDeliver[s3, s4, replyAfter] and
    currentDeliver[s4, s5, createAgain] and s3.cRoundThread = Open and
    s4.cOutcome = Accepted and s5.cOutcome = Rejected409
}

pred RepairedRoundThreadLifecycleWitness {
  some s0, s1, s2, s3, s4, s5: RepairedState, create, reply, resolve, rejectedReply, createAgain: Input |
    repairedInit[s0] and create.scope = RoundThread and create.route = CommentRoute and create.context = Missing and create.mode = Single and create.file = First and
    reply.scope = RoundThread and reply.route = ReplyRoute and reply.context = Missing and reply.mode = Single and reply.file = First and
    resolve.scope = RoundThread and resolve.route = ResolveRoute and resolve.context = Missing and resolve.mode = Single and resolve.file = First and
    rejectedReply.scope = RoundThread and rejectedReply.route = ReplyRoute and rejectedReply.context = Missing and rejectedReply.mode = Single and rejectedReply.file = First and
    createAgain.scope = RoundThread and createAgain.route = CommentRoute and createAgain.context = Missing and createAgain.mode = Single and createAgain.file = First and
    repairedDeliver[s0, s1, create] and repairedDeliver[s1, s2, reply] and
    repairedDeliver[s2, s3, resolve] and repairedDeliver[s3, s4, rejectedReply] and
    repairedDeliver[s4, s5, createAgain] and s3.rRoundThread = Resolved and
    s4.rOutcome = Rejected409 and repairedCopyEffects[s3, s4] and
    s5.rRoundThread = Open and s5.rRetainedResolvedRound = Persisted
}

assert RepairedRoundThreadResolvedReplyHasNoEffect {
  all s, t: RepairedState, i: Input |
    repairedDeliver[s, t, i] and validOwned[i] and i.scope = RoundThread and i.route = ReplyRoute and s.rRoundThread = Resolved implies
      t.rOutcome = Rejected409 and repairedCopyEffects[s, t]
}

assert CurrentDeliveryGuardsAreTotalAndExclusive {
  all s: CurrentState, i: Input | one guard: CurrentDeliveryGuard | currentGuardLabel[s, i, guard]
}

assert RepairedDeliveryGuardsAreTotalAndExclusive {
  all s: RepairedState, i: Input | one guard: RepairedDeliveryGuard | repairedGuardLabel[s, i, guard]
}

pred currentDeterminismWithinFiniteIntDomain[s: CurrentState, i: Input] {
  (currentBareSubmitGuard[s, i] and i.decision = Approve implies
    some larger: Int | larger > s.cCount) and
  (currentRoundDeliverGuard[s, i] and i.route = ReplyRoute and s.cRoundThread = Open implies
    some larger: Int | larger > s.cRoundReplies)
}

pred repairedDeterminismWithinFiniteIntDomain[s: RepairedState, i: Input] {
  (repairedAcceptSubmitGuard[s, i] implies some larger: Int | larger > s.rRawEffects) and
  (repairedRoundDeliverGuard[s, i] and i.route = ReplyRoute and s.rRoundThread = Open implies
    some larger: Int | larger > s.rRoundReplies)
}

assert CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain {
  all s, t, u: CurrentState, i: Input |
    currentDeterminismWithinFiniteIntDomain[s, i] and
    currentDeliver[s, t, i] and currentDeliver[s, u, i] implies sameCurrentObservation[t, u]
}

assert RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain {
  all s, t, u: RepairedState, i: Input |
    repairedDeterminismWithinFiniteIntDomain[s, i] and
    repairedDeliver[s, t, i] and repairedDeliver[s, u, i] implies sameRepairedObservation[t, u]
}

assert RepairedRoundResolveSemantics {
  all s, t: RepairedState, i: Input |
    repairedDeliver[s, t, i] and validOwned[i] and i.scope = RoundThread and i.route = ResolveRoute implies
      ((s.rRoundThread = Open implies t.rRoundThread = Resolved and t.rOutcome = Accepted) and
       (s.rRoundThread = Resolved implies t.rOutcome = Accepted and repairedCopyEffects[s, t]) and
       (s.rRoundThread = NoThread and i.mode = Single implies t.rOutcome = Accepted and repairedCopyEffects[s, t]) and
       (s.rRoundThread = NoThread and i.mode = Mux implies t.rOutcome = Rejected400 and repairedCopyEffects[s, t]))
}

assert CurrentRoundResolvePersists {
  all s, t: CurrentState, i: Input |
    currentDeliver[s, t, i] and i.mode = Single and i.context = Missing and i.file = First and i.scope = RoundThread and i.route = ResolveRoute and s.cRoundThread = Open implies
      t.cRoundThread = Resolved
}

run CurrentRouteWitness for exactly 3 CurrentState, exactly 1 RepairedState, 2 Input, 5 Int
check StaticDecisionTableIsTotalAndDeterministic for 5 Int
run StaticBoundaryWitnesses for 5 Int
check UnanchoredIsRetainedButDoesNotGate for 5 Int
run CurrentUnanchoredGateWitness for 5 Int
run CurrentUnanchoredTransitionWitness for exactly 3 CurrentState, exactly 1 RepairedState, 2 Input, 5 Int
check CurrentUnanchoredDoesNotBlockApprove for 5 Int
check SummaryOrderIgnoresArrivalOrder for 5 Int
run ReverseArrivalSummaryWitness for 5 Int
run CurrentDuplicateWitness for exactly 3 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
run CurrentGenerationWitness for exactly 4 CurrentState, exactly 1 RepairedState, 2 Input, 5 Int
run CurrentStaticWitness for exactly 2 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
check CurrentRoutePreservesSelection for exactly 2 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
check CurrentDoesNotFinishEarly for exactly 2 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
check CurrentRejectsOldGeneration for exactly 2 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
check CurrentDeliveryGuardsAreTotalAndExclusive for exactly 3 CurrentState, exactly 1 RepairedState, 2 Input, 5 Int
check CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain for exactly 3 CurrentState, exactly 1 RepairedState, 2 Input, 5 Int
check RepairedDeliverySafety for exactly 1 CurrentState, exactly 2 RepairedState, 2 Input, 5 Int
check RepairedDeliveryGuardsAreTotalAndExclusive for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
check RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
check RepairedGlobalRoutesAreBareOnly for exactly 1 CurrentState, exactly 2 RepairedState, 2 Input, 5 Int
check RepairedResolveSafety for exactly 1 CurrentState, exactly 2 RepairedState, 2 Input, 5 Int
check RepairedGoSafety for exactly 1 CurrentState, exactly 2 RepairedState, 2 Input, 5 Int
check RepairedBoundedInvariantPreserved for exactly 1 CurrentState, exactly 2 RepairedState, 2 Input, 5 Int
run RepairedContextWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedRejectedContextWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedReplacementWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedRetryWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedWaitingGoWitness for exactly 1 CurrentState, exactly 4 RepairedState, 2 Input, 5 Int
run RepairedCompletionWitness for exactly 1 CurrentState, exactly 4 RepairedState, 2 Input, 5 Int
run RepairedOldPostRejectedWitness for exactly 1 CurrentState, exactly 6 RepairedState, 3 Input, 5 Int
run RepairedFileReplyWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedRoundReplyWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedUnanchoredTransitionWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedAnchoredTransitionWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedPersistenceTransitionWitness for exactly 1 CurrentState, exactly 5 RepairedState, 4 Input, 5 Int
run RepairedResolveClearsGateWitness for exactly 1 CurrentState, exactly 4 RepairedState, 3 Input, 5 Int
run RepairedHtmlWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedGlobalWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedGlobalWithContextRejectedWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedOwnerRejectWitness for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
run RepairedSecondReplacementWitness for exactly 1 CurrentState, exactly 3 RepairedState, 2 Input, 5 Int
run RepairedReversePriorityWitness for exactly 1 CurrentState, exactly 4 RepairedState, 2 Input, 5 Int
run RepairedTerminalSubmitRejectedWitness for exactly 1 CurrentState, exactly 4 RepairedState, 3 Input, 5 Int
run RepairedThreeGenerationWitness for exactly 1 CurrentState, exactly 12 RepairedState, 6 Input, 5 Int
run RepairedGenerationFourWitness for exactly 1 CurrentState, exactly 16 RepairedState, 8 Input, 5 Int
run RepairedGenerationFiveWitness for exactly 1 CurrentState, exactly 17 RepairedState, 8 Input, 5 Int
run CurrentRoundResolveBugWitness for exactly 6 CurrentState, exactly 1 RepairedState, 5 Input, 5 Int
run RepairedRoundThreadLifecycleWitness for exactly 1 CurrentState, exactly 6 RepairedState, 5 Input, 5 Int
check RepairedRoundThreadResolvedReplyHasNoEffect for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
check RepairedRoundResolveSemantics for exactly 1 CurrentState, exactly 2 RepairedState, 1 Input, 5 Int
check CurrentRoundResolvePersists for exactly 2 CurrentState, exactly 1 RepairedState, 1 Input, 5 Int
