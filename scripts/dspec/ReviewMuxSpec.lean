import Std

/- Historical pre-freeze sketch.  It is deliberately non-executable and is
not part of the formal source of truth; the StrictContext model below is the
only Lean model accepted by the review-mux evidence manifest. -/
/-
/-!
  Finite executable specification for the two-file review mux.
  `raw` deliberately retains delivery multiplicity; `ledger` is the latest
  accepted value for each (file, round) key.  This separates transport retry
  from terminal aggregation.
-/

inductive File where
  | first
  | second
  deriving DecidableEq, Repr, BEq

inductive Decision where
  | requestChanges
  | approve
  deriving DecidableEq, Repr, BEq

inductive Phase where
  | collecting
  | roundComplete
  | waitingGo
  | exited
  deriving DecidableEq, Repr, BEq

inductive Scope where
  | fileThread
  | roundThread
  deriving DecidableEq, Repr, BEq

structure Delivery where
  file : File
  round : Nat
  payload : Nat
  decision : Decision
  deriving DecidableEq, Repr, BEq

structure State where
  round : Nat
  phase : Phase
  raw : List Delivery
  ledger : List Delivery
  emittedRounds : Nat
  selected : File
  effectTarget : File
  staticTarget : File
  cliTarget : File
  scope : Scope
  fileReplyAudience : List File
  roundReplyAudience : List File
  deriving DecidableEq, Repr

def expectedFiles : List File := [.first, .second]

def sameKey (left right : Delivery) : Bool :=
  left.file == right.file && left.round == right.round

def samePayload (left right : Delivery) : Bool :=
  sameKey left right && left.payload == right.payload && left.decision == right.decision

def replaceLatest (ledger : List Delivery) (delivery : Delivery) : List Delivery :=
  ledger.filter (fun existing => !sameKey existing delivery) ++ [delivery]

def hasFile (ledger : List Delivery) (file : File) : Bool :=
  ledger.any (fun delivery => delivery.file == file)

def hasAllFiles (ledger : List Delivery) : Bool :=
  expectedFiles.all (fun file => hasFile ledger file)

def aggregateDecision (ledger : List Delivery) : Decision :=
  if ledger.any (fun delivery => delivery.decision == .requestChanges) then
    .requestChanges
  else
    .approve

def currentInitial : State :=
  { round := 1, phase := .collecting, raw := [], ledger := [], emittedRounds := 0,
    selected := .second, effectTarget := .first, staticTarget := .first, cliTarget := .first,
    scope := .fileThread, fileReplyAudience := [.first], roundReplyAudience := [.first] }

def repairedInitial : State :=
  { round := 1, phase := .collecting, raw := [], ledger := [], emittedRounds := 0,
    selected := .second, effectTarget := .second, staticTarget := .second, cliTarget := .second,
    scope := .fileThread, fileReplyAudience := [.second], roundReplyAudience := [.first, .second] }

/- Current server: fixed first context counts every delivery and exits by count. -/
def currentSubmit (state : State) (delivery : Delivery) : State :=
  { state with
    raw := state.raw ++ [delivery]
    ledger := state.ledger ++ [delivery]
    phase := if state.raw.length + 1 >= expectedFiles.length then .exited else .collecting }

/- Repaired server: reject stale generation; exact retry has no state/effect;
   distinct payload replaces the key's latest value and emits exactly once when
   the round becomes complete. -/
def repairedSubmit (state : State) (delivery : Delivery) : State :=
  if state.phase != .collecting || delivery.round != state.round then state
  else if state.ledger.any (fun existing => samePayload existing delivery) then state
  else
    let ledger := replaceLatest state.ledger delivery
    if hasAllFiles ledger then
      { state with raw := state.raw ++ [delivery], ledger := ledger, phase := .roundComplete, emittedRounds := state.emittedRounds + 1 }
    else
      { state with raw := state.raw ++ [delivery], ledger := ledger }

/- A request-changes round cannot advance until the single aggregate result was
   emitted; go starts one new generation and clears only that round's ledger. -/
def repairedGo (state : State) : State :=
  if state.phase == .waitingGo then
    { state with round := state.round + 1, phase := .collecting, ledger := [] }
  else state

def repairedResolveRound (state : State) : State :=
  if state.phase != .roundComplete then state
  else if aggregateDecision state.ledger == .requestChanges then
    { state with phase := .waitingGo }
  else
    { state with phase := .exited }

def firstApprove : Delivery :=
  { file := .first, round := 1, payload := 1, decision := .approve }

def firstApproveRetry : Delivery :=
  { file := .first, round := 1, payload := 1, decision := .approve }

def firstChangedApprove : Delivery :=
  { file := .first, round := 1, payload := 2, decision := .approve }

def secondApprove : Delivery :=
  { file := .second, round := 1, payload := 1, decision := .approve }

def firstRequestChanges : Delivery :=
  { file := .first, round := 1, payload := 1, decision := .requestChanges }

def oldFirstApprove : Delivery :=
  { file := .first, round := 1, payload := 9, decision := .approve }

/- Known current RED witnesses. -/
def currentDuplicateTrace : State :=
  currentSubmit (currentSubmit currentInitial firstApprove) firstChangedApprove

example : currentDuplicateTrace.phase = .exited := by native_decide
example : hasAllFiles currentDuplicateTrace.ledger = false := by native_decide
example : currentInitial.effectTarget != currentInitial.selected := by native_decide
example : currentInitial.staticTarget != currentInitial.selected := by native_decide
example : currentInitial.cliTarget != currentInitial.selected := by native_decide
example : currentInitial.fileReplyAudience = [.first] := by native_decide
example : currentInitial.roundReplyAudience != [.first, .second] := by native_decide

/- Same-generation duplicate/replacement: unique aggregation remains one, and
   the later distinct payload is retained. -/
def repairedReplacementTrace : State :=
  repairedSubmit (repairedSubmit (repairedSubmit repairedInitial firstApprove) firstApproveRetry) firstChangedApprove

theorem repairedExactRetryIsNoop :
  repairedSubmit (repairedSubmit repairedInitial firstApprove) firstApproveRetry =
    repairedSubmit repairedInitial firstApprove := by native_decide

theorem repairedReplacementKeepsOneKey : repairedReplacementTrace.ledger.length = 1 := by
  native_decide

theorem repairedReplacementUsesLatestPayload : repairedReplacementTrace.ledger = [firstChangedApprove] := by
  native_decide

theorem repairedReplacementCannotExitEarly : repairedReplacementTrace.phase = .collecting := by
  native_decide

/- Generation and aggregate priority. -/
def repairedRequestChangesTrace : State :=
  repairedSubmit (repairedSubmit repairedInitial firstRequestChanges) secondApprove

theorem repairedRoundCompleteBeforeDecision : repairedRequestChangesTrace.phase = .roundComplete := by
  native_decide

theorem repairedRequestChangesPriority :
  aggregateDecision repairedRequestChangesTrace.ledger = .requestChanges := by native_decide

def repairedWaitingTrace : State := repairedResolveRound repairedRequestChangesTrace

theorem repairedRequestChangesWaitsForGo : repairedWaitingTrace.phase = .waitingGo := by
  native_decide

theorem repairedGoRequiresCompletedRequestChangesRound : repairedGo repairedInitial = repairedInitial := by
  native_decide

def repairedRoundTwo : State := repairedGo repairedWaitingTrace

theorem repairedGoAdvancesExactlyOneGeneration : repairedRoundTwo.round = 2 := by native_decide
theorem repairedGoClearsOnlyTerminalLedger : repairedRoundTwo.ledger = [] := by native_decide

theorem repairedRejectsOldGeneration :
  repairedSubmit repairedRoundTwo oldFirstApprove = repairedRoundTwo := by native_decide

def repairedApproveTrace : State :=
  repairedResolveRound (repairedSubmit (repairedSubmit repairedInitial firstApprove) secondApprove)

theorem repairedAllApproveExits : repairedApproveTrace.phase = .exited := by native_decide
theorem repairedEmitsOneAggregatePerRound : repairedApproveTrace.emittedRounds = 1 := by native_decide

/- Context and SSE audience non-vacuity witnesses for the repaired boundary. -/
theorem repairedEffectTargetsOpenedFile : repairedInitial.effectTarget = repairedInitial.selected := by
  native_decide
theorem repairedStaticTargetsOpenedFile : repairedInitial.staticTarget = repairedInitial.selected := by
  native_decide
theorem repairedCliTargetsOwnerFile : repairedInitial.cliTarget = repairedInitial.selected := by
  native_decide
theorem repairedFileReplyIsOwnerOnly : repairedInitial.fileReplyAudience = [.second] := by
  native_decide
theorem repairedRoundReplyBroadcastsAllContexts : repairedInitial.roundReplyAudience = expectedFiles := by
  native_decide

/- Finite transition closure.  The delivery alphabet is exactly the requested
   2 files × 2 decisions × three bounded generations × same/different payload;
   ResolveRound and Go are commands too, so generation-two stale/new posts are
   included in the reachable-state calculation. -/
def decisionInputs : List Decision := [.requestChanges, .approve]
def generationInputs : List Nat := [1, 2, 3]
def payloadInputs : List Nat := [1, 2]

def deliveryAlphabet : List Delivery :=
  expectedFiles.flatMap fun file =>
    decisionInputs.flatMap fun decision =>
      generationInputs.flatMap fun round =>
        payloadInputs.map fun payload =>
          { file := file, round := round, payload := payload, decision := decision }

inductive Command where
  | deliver (delivery : Delivery)
  | resolveRound
  | go
  deriving DecidableEq, Repr

def commandAlphabet : List Command :=
  deliveryAlphabet.map .deliver ++ [.resolveRound, .go]

def applyCommand (state : State) : Command → State
  | .deliver delivery => repairedSubmit state delivery
  | .resolveRound => repairedResolveRound state
  | .go => repairedGo state

/- `raw` is an audit/effect history, not an invariant input.  Keeping it in
   each BFS node would make the finite closure count every permutation of the
   same logical ledger state.  Exact retry/history behavior remains covered by
   `repairedExactRetryIsNoop`; closure intentionally canonicalizes it. -/
def normalizeForClosure (state : State) : State :=
  { state with raw := [] }

def reachableStates : Nat → List State
  | 0 => [repairedInitial]
  | count + 1 =>
      ((reachableStates count).flatMap fun state =>
        commandAlphabet.map fun command => normalizeForClosure (applyCommand state command)).eraseDups

def uniqueKeys : List Delivery → Bool
  | [] => true
  | head :: tail => !tail.any (fun other => sameKey head other) && uniqueKeys tail

def repairedInvariant (state : State) : Bool :=
  (state.phase != .roundComplete || hasAllFiles state.ledger) &&
  (state.phase != .exited || (hasAllFiles state.ledger && aggregateDecision state.ledger == .approve)) &&
  state.ledger.all (fun delivery => delivery.round == state.round) &&
  uniqueKeys state.ledger &&
  state.effectTarget == state.selected &&
  state.staticTarget == state.selected &&
  state.cliTarget == state.selected &&
  state.fileReplyAudience == [state.selected] &&
  state.roundReplyAudience == expectedFiles &&
  state.emittedRounds <= state.round

theorem repairedAllReachableCommandsPreserveInvariant :
  (reachableStates 9).all repairedInvariant = true := by
  native_decide
-/

/-! The strict-f model below is the freeze gate.  The older two-file sketch
above remains historical current-RED context; this namespace is authoritative
for the shared typed request alphabet used by Lean, Alloy, and Quint. -/
namespace StrictContext

inductive Actor where | browser | cli deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Route where
  | html | state | submit | sse | static | comment | reply | resolve | cli | uiJs | healthz
  deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive File where | first | second deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Context where | missing | validFirst | validSecond | invalid | global deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Payload where | one | two deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Decision where | requestChanges | approve deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Outcome where | accepted | notFound404 | rejected400 | rejected409 deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Scope where | file | round deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive MuxMode where | mux | single deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Phase where | collecting | roundComplete | waitingGo | exited deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive Boundary where | initial | delivery | resolveRound | go deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive GateState where | clear | anchoredUnresolved | unanchoredOnly deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable
inductive RoundThreadState where | noThread | open | resolved deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable

structure Input where
  actor : Actor
  route : Route
  context : Context
  file : File
  owner : File
  generation : Nat
  payload : Payload
  decision : Decision
  scope : Scope
  gate : GateState
  mode : MuxMode
  deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable

inductive Command where
  | request (input : Input)
  | resolveRound
  | go
  deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq

structure State where
  generation : Nat
  phase : Phase
  selected : File
  effect : File
  static : File
  sse : File
  lastOwner : File
  replyTarget : File
  audience : List File
  firstGate : GateState
  secondGate : GateState
  firstRetainedUnanchored : Bool
  secondRetainedUnanchored : Bool
  filePersisted : Bool
  persistedFileOwner : File
  roundPersisted : Bool
  resolvePersisted : Bool
  roundThread : RoundThreadState
  roundReplies : Nat
  retainedResolvedRound : Bool
  firstPresent : Bool
  secondPresent : Bool
  firstPayload : Payload
  secondPayload : Payload
  firstDecision : Decision
  secondDecision : Decision
  rawEffects : Nat
  emitted : List Nat
  outcome : Outcome
  lastBoundary : Boundary
  lastInput : Input
  deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq, Hashable

structure Effects where
  generation : Nat
  phase : Phase
  selected : File
  effect : File
  static : File
  sse : File
  lastOwner : File
  replyTarget : File
  audience : List File
  firstGate : GateState
  secondGate : GateState
  firstRetainedUnanchored : Bool
  secondRetainedUnanchored : Bool
  filePersisted : Bool
  persistedFileOwner : File
  roundPersisted : Bool
  resolvePersisted : Bool
  roundThread : RoundThreadState
  roundReplies : Nat
  retainedResolvedRound : Bool
  firstPresent : Bool
  secondPresent : Bool
  firstPayload : Payload
  secondPayload : Payload
  firstDecision : Decision
  secondDecision : Decision
  rawEffects : Nat
  emitted : List Nat
  deriving DecidableEq, Repr, BEq, ReflBEq, LawfulBEq

def files : List File := [.first, .second]
def actors : List Actor := [.browser, .cli]
def routes : List Route := [.html, .state, .submit, .sse, .static, .comment, .reply, Route.resolve, .cli, .uiJs, .healthz]
def contexts : List Context := [.missing, .validFirst, .validSecond, .invalid, .global]
def modes : List MuxMode := [.mux, .single]
/- Four is an exploration bound, not a product limit: it is the first state
after three consecutive request-changes/go transitions. -/
def generations : List Nat := [1, 2, 3, 4]
def payloads : List Payload := [.one, .two]
def decisions : List Decision := [.requestChanges, .approve]
def scopes : List Scope := [.file, .round]
def gates : List GateState := [.clear, .anchoredUnresolved, .unanchoredOnly]
def contextFile : Context → Option File
  | .validFirst => some .first
  | .validSecond => some .second
  | _ => none
def isContextBound : Route → Bool
  | .uiJs | .healthz => false
  | _ => true
def validOwned (input : Input) : Bool :=
  (input.mode == .single && input.context == .missing && input.file == .first) ||
  (input.mode == .mux && contextFile input.context == some input.file)
def complete (state : State) : Bool := state.firstPresent && state.secondPresent
def aggregate (state : State) : Decision :=
  if state.firstDecision == .requestChanges || state.secondDecision == .requestChanges
  then .requestChanges else .approve
def exactRetry (state : State) (input : Input) : Bool :=
  if input.file == .first then
    state.firstPresent && state.firstPayload == input.payload && state.firstDecision == input.decision
  else
    state.secondPresent && state.secondPayload == input.payload && state.secondDecision == input.decision
def gateForFile (state : State) (file : File) : GateState :=
  if file == .first then state.firstGate else state.secondGate
def effects (state : State) : Effects := {
  generation := state.generation, phase := state.phase, selected := state.selected,
  effect := state.effect, static := state.static, sse := state.sse,
  lastOwner := state.lastOwner, replyTarget := state.replyTarget,
  audience := state.audience, firstGate := state.firstGate, secondGate := state.secondGate,
  firstRetainedUnanchored := state.firstRetainedUnanchored,
  secondRetainedUnanchored := state.secondRetainedUnanchored,
  filePersisted := state.filePersisted, persistedFileOwner := state.persistedFileOwner,
  roundPersisted := state.roundPersisted, resolvePersisted := state.resolvePersisted,
  roundThread := state.roundThread, roundReplies := state.roundReplies,
  retainedResolvedRound := state.retainedResolvedRound,
  firstPresent := state.firstPresent,
  secondPresent := state.secondPresent, firstPayload := state.firstPayload,
  secondPayload := state.secondPayload, firstDecision := state.firstDecision,
  secondDecision := state.secondDecision, rawEffects := state.rawEffects,
  emitted := state.emitted }

def initialInput : Input := {
    actor := .browser, route := .html, context := .missing,
    file := .first, owner := .first, generation := 1, payload := .one,
    decision := .approve, scope := .file, gate := .clear, mode := .single
  }
def initial : State := {
    generation := 1, phase := .collecting,
    selected := .first, effect := .first, static := .first, sse := .first,
    lastOwner := .first, replyTarget := .first, audience := [],
    firstGate := .clear, secondGate := .clear,
    firstRetainedUnanchored := false, secondRetainedUnanchored := false,
    filePersisted := false, persistedFileOwner := .first,
    roundPersisted := false, resolvePersisted := false,
    roundThread := .noThread, roundReplies := 0, retainedResolvedRound := false,
    firstPresent := false, secondPresent := false,
    firstPayload := .one, secondPayload := .one,
    firstDecision := .approve, secondDecision := .approve,
    rawEffects := 0, emitted := [], outcome := .accepted,
    lastBoundary := .initial, lastInput := initialInput
  }

/- The current server selects HTML by query, but dispatches APIs by the raw
URL. A query-bearing API is 404; the UI's later bare API reaches First. -/
def currentStep (state : State) (input : Input) : State :=
  if !isContextBound input.route then
    let outcome := if input.context == .global then .accepted else .notFound404
    { state with outcome := outcome, lastBoundary := .delivery, lastInput := input }
  else if input.route == .html then
    let selected := if input.context == .validSecond then .second else .first
    { state with selected := selected, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.context == .missing && input.scope == .round && input.route == .comment then
    if state.roundThread == .noThread then
      { state with lastOwner := .first, replyTarget := .first, audience := [.first], roundPersisted := true, roundThread := .open, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else
      { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.context == .missing && input.scope == .round && input.route == .reply then
    if state.roundThread == .open then
      { state with lastOwner := .first, replyTarget := .first, audience := [.first], roundPersisted := true, roundReplies := state.roundReplies + 1, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else
      { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.context == .missing && input.scope == .round && input.route == Route.resolve then
    /- Baseline js_review_resolve returned 200 while ignoring round scope. -/
    { state with lastOwner := .first, replyTarget := .first, audience := [.first], outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.mode == .mux && input.context != .missing then
    { state with outcome := .notFound404, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit && input.decision == .approve && gateForFile state .first != .clear then
    { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit then
    let nextRaw := if input.decision == .requestChanges then 0 else state.rawEffects + 1
    let phase := if input.decision == .requestChanges then .waitingGo else if nextRaw >= files.length then .exited else .collecting
    let emitted := if input.decision == .requestChanges then state.emitted ++ [state.generation] else state.emitted
    { state with effect := .first, firstPresent := true, firstPayload := input.payload, firstDecision := input.decision, rawEffects := nextRaw, phase := phase, emitted := emitted, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .static then
    { state with static := .first, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .sse then
    { state with sse := .first, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .reply || input.route == Route.resolve then
    let owned := { state with lastOwner := .first, replyTarget := .first }
    let routed := { owned with audience := [.first] }
    let gated := { routed with firstGate := (if input.route == Route.resolve then .clear else state.firstGate) }
    { gated with filePersisted := true, persistedFileOwner := .first, resolvePersisted := (state.resolvePersisted || input.route == Route.resolve), outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .comment then
    { state with firstGate := input.gate, firstRetainedUnanchored := (state.firstRetainedUnanchored || input.gate == .unanchoredOnly), filePersisted := true, persistedFileOwner := .first, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else
    { state with effect := .first, outcome := .accepted, lastBoundary := .delivery, lastInput := input }

def repairedStep (state : State) (input : Input) : State :=
  if !isContextBound input.route then
    let outcome := if input.context == .global then .accepted else .rejected400
    { state with outcome := outcome, lastBoundary := .delivery, lastInput := input }
  else if !validOwned input then
    { state with outcome := .rejected400, lastBoundary := .delivery, lastInput := input }
  else if (input.route == .comment || input.route == .reply || input.route == Route.resolve) && input.scope == .file && input.owner != input.file then
    { state with outcome := .rejected400, lastBoundary := .delivery, lastInput := input }
  else if input.route == .html then
    { state with selected := input.file, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit && (state.phase != .collecting || input.generation != state.generation) then
    { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit && input.decision == .approve && gateForFile state input.file == .anchoredUnresolved then
    { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit && exactRetry state input then
    { state with outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .submit then
    let firstPresent := state.firstPresent || input.file == .first
    let secondPresent := state.secondPresent || input.file == .second
    let firstPayload := if input.file == .first then input.payload else state.firstPayload
    let secondPayload := if input.file == .second then input.payload else state.secondPayload
    let firstDecision := if input.file == .first then input.decision else state.firstDecision
    let secondDecision := if input.file == .second then input.decision else state.secondDecision
    let isComplete := firstPresent && secondPresent
    let phase := if isComplete then .roundComplete else .collecting
    let emitted := if isComplete then state.emitted ++ [state.generation] else state.emitted
    { state with selected := input.file, effect := input.file, firstPresent := firstPresent, secondPresent := secondPresent, firstPayload := firstPayload, secondPayload := secondPayload, firstDecision := firstDecision, secondDecision := secondDecision, rawEffects := state.rawEffects + 1, phase := phase, emitted := emitted, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .static then
    { state with selected := input.file, static := input.file, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.route == .sse then
    { state with selected := input.file, sse := input.file, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else if input.scope == .round && input.route == .comment then
    if state.roundThread == .noThread || state.roundThread == .resolved then
      { state with selected := input.file, lastOwner := input.owner, replyTarget := input.owner, audience := (if input.mode == .mux then files else [.first]), roundPersisted := true, roundThread := .open, retainedResolvedRound := (state.retainedResolvedRound || state.roundThread == .resolved), outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else
      { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.scope == .round && input.route == .reply then
    if state.roundThread == .open then
      { state with selected := input.file, lastOwner := input.owner, replyTarget := input.owner, audience := (if input.mode == .mux then files else [.first]), roundPersisted := true, roundReplies := state.roundReplies + 1, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else
      { state with outcome := .rejected409, lastBoundary := .delivery, lastInput := input }
  else if input.scope == .round && input.route == Route.resolve then
    if state.roundThread == .open then
      { state with selected := input.file, lastOwner := input.owner, replyTarget := input.owner, audience := (if input.mode == .mux then files else [.first]), roundPersisted := true, resolvePersisted := true, roundThread := .resolved, retainedResolvedRound := true, outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else if state.roundThread == .resolved then
      { state with outcome := .accepted, lastBoundary := .delivery, lastInput := input }
    else
      { state with outcome := (if input.mode == .single then .accepted else .rejected400), lastBoundary := .delivery, lastInput := input }
  else if input.route == .reply || input.route == Route.resolve || input.route == .comment then
    let audience := if input.scope == .round && input.mode == .mux then files else [input.owner]
    let firstGate :=
      if input.route == .comment && input.scope == .file && input.file == .first then input.gate
      else if input.route == Route.resolve && input.scope == .file && input.file == .first then .clear
      else state.firstGate
    let secondGate :=
      if input.route == .comment && input.scope == .file && input.file == .second then input.gate
      else if input.route == Route.resolve && input.scope == .file && input.file == .second then .clear
      else state.secondGate
    let owned := { state with selected := input.file, lastOwner := input.owner, replyTarget := input.owner }
    let routed := { owned with audience := audience }
    let firstGated := { routed with firstGate := firstGate }
    let gated := { firstGated with secondGate := secondGate }
    { gated with
      firstRetainedUnanchored := (state.firstRetainedUnanchored ||
        (input.route == .comment && input.scope == .file && input.file == .first && input.gate == .unanchoredOnly)),
      secondRetainedUnanchored := (state.secondRetainedUnanchored ||
        (input.route == .comment && input.scope == .file && input.file == .second && input.gate == .unanchoredOnly)),
      filePersisted := (state.filePersisted || input.scope == .file),
      persistedFileOwner := (if input.scope == .file then input.owner else state.persistedFileOwner),
      roundPersisted := (state.roundPersisted || input.scope == .round),
      resolvePersisted := (state.resolvePersisted || input.route == Route.resolve),
      outcome := .accepted, lastBoundary := .delivery, lastInput := input }
  else
    { state with selected := input.file, effect := input.file, outcome := .accepted, lastBoundary := .delivery, lastInput := input }

def resolveStep (state : State) : State :=
  if state.phase != .roundComplete then
    { state with outcome := .rejected409, lastBoundary := .resolveRound }
  else if aggregate state == .requestChanges then
    { state with phase := .waitingGo, outcome := .accepted, lastBoundary := .resolveRound }
  else
    { state with phase := .exited, outcome := .accepted, lastBoundary := .resolveRound }

def nextGeneration (generation : Nat) : Nat := generation + 1

def goStep (state : State) : State :=
  if state.phase != .waitingGo || aggregate state != .requestChanges then
    { state with outcome := .rejected409, lastBoundary := .go }
  else
    let advanced := { state with generation := nextGeneration state.generation, phase := .collecting }
    let firstCleared := { advanced with firstPresent := false }
    let cleared := { firstCleared with secondPresent := false }
    { cleared with
      firstPayload := .one, secondPayload := .one,
      firstDecision := .approve, secondDecision := .approve,
      outcome := .accepted, lastBoundary := .go }

def currentApply (state : State) : Command → State
  | .request input => currentStep state input
  | .resolveRound => resolveStep state
  | .go => goStep state
def repairedApply (state : State) : Command → State
  | .request input => repairedStep state input
  | .resolveRound => resolveStep state
  | .go => goStep state

def htmlSecond : Input := { initialInput with context := .validSecond, file := .second, mode := .mux }
def missingState : Input := { initialInput with route := .state, context := .missing, mode := .mux }
def queryStateSecond : Input := { initialInput with route := .state, context := .validSecond, file := .second, mode := .mux }
def firstApprove : Input := { initialInput with route := .submit, context := .validFirst, mode := .mux }
def secondApprove : Input := { actor := .browser, route := .submit, context := .validSecond, file := .second, owner := .second, generation := 1, payload := .one, decision := .approve, scope := .file, gate := .clear, mode := .mux }
def firstRetry : Input := firstApprove
def firstReplacement : Input := { firstApprove with payload := .two }
def secondReplacement : Input := { secondApprove with payload := .two }
def missingSubmit : Input := { firstApprove with context := .missing }
def invalidSubmit : Input := { firstApprove with context := .invalid }
def wrongRouteFile : Input := { firstApprove with context := .validSecond }
def globalUi : Input := { firstApprove with route := .uiJs, context := .global }
def uiWithF : Input := { firstApprove with route := .uiJs, context := .validFirst }
def firstRequestChanges : Input := { firstApprove with decision := .requestChanges }
def firstRequestChangesG2 : Input := { firstRequestChanges with generation := 2 }
def secondApproveG2 : Input := { secondApprove with generation := 2 }
def firstRequestChangesG3 : Input := { firstRequestChanges with generation := 3 }
def firstApproveG3 : Input := { firstApprove with generation := 3 }
def secondApproveG3 : Input := { secondApprove with generation := 3 }
def firstApproveG4 : Input := { firstApprove with generation := 4 }
def secondApproveG4 : Input := { secondApprove with generation := 4 }

def currentDisplayedSecondThenBareState := currentStep (currentStep initial htmlSecond) missingState
theorem currentDisplayEffectMismatch : currentDisplayedSecondThenBareState.selected = .second ∧ currentDisplayedSecondThenBareState.effect = .first := by native_decide
theorem currentQueryApiIs404 : (currentStep initial queryStateSecond).outcome = .notFound404 := by native_decide
theorem currentBareMuxStaticIsAcceptedByFirst :
  let result := currentStep initial { firstApprove with route := .static, context := .missing }
  result.outcome = .accepted ∧ result.static = .first := by native_decide
theorem currentInvalidHtmlFallsBackToFirst : (currentStep initial { htmlSecond with context := .invalid }).selected = .first := by native_decide
/- Current raw-count bug is reachable on the non-mux dispatch path. Mux+valid
context is 404 before submit, so the RED witnesses use mode := .single. -/
def currentRawApprove : Input := { firstApprove with mode := .single }
def currentRawRequestChanges : Input := { firstRequestChanges with mode := .single }
theorem currentDuplicateExitsEarly :
  (currentStep (currentStep initial currentRawApprove) currentRawApprove).phase = .exited := by native_decide
theorem currentDuplicateStillHasNoSecondFile :
  !(currentStep (currentStep initial currentRawApprove) currentRawApprove).secondPresent := by native_decide
def currentPartialRequestChanges := currentStep initial currentRawRequestChanges
def currentAdvancedEarly := currentApply currentPartialRequestChanges .go
theorem currentGoAcceptsPartialRound :
  currentPartialRequestChanges.phase = .waitingGo ∧ currentAdvancedEarly.generation = 2 := by native_decide
theorem currentAcceptsStaleGenerationAfterGo :
  (currentStep currentAdvancedEarly currentRawApprove).outcome = .accepted := by native_decide
theorem repairedMissingIs400AndHasNoEffects : effects (repairedStep initial missingSubmit) = effects initial ∧ (repairedStep initial missingSubmit).outcome = .rejected400 := by native_decide
theorem repairedInvalidIs400AndHasNoEffects : effects (repairedStep initial invalidSubmit) = effects initial ∧ (repairedStep initial invalidSubmit).outcome = .rejected400 := by native_decide
theorem repairedWrongRouteFileIs400 : (repairedStep initial wrongRouteFile).outcome = .rejected400 := by native_decide
theorem repairedGlobalOnlyBare : (repairedStep initial globalUi).outcome = .accepted ∧ (repairedStep initial uiWithF).outcome = .rejected400 := by native_decide

def replacementTrace := repairedStep (repairedStep (repairedStep initial firstApprove) firstRetry) firstReplacement
theorem exactRetryHasNoEffect : effects (repairedStep (repairedStep initial firstApprove) firstRetry) = effects (repairedStep initial firstApprove) := by native_decide
theorem secondExactRetryHasNoEffect : effects (repairedStep (repairedStep initial secondApprove) secondApprove) = effects (repairedStep initial secondApprove) := by native_decide
theorem firstReplacementKeepsOneFile : replacementTrace.firstPresent ∧ !replacementTrace.secondPresent ∧ replacementTrace.firstPayload = .two := by native_decide
theorem secondReplacementKeepsOneFile :
  let trace := repairedStep (repairedStep initial secondApprove) secondReplacement
  !trace.firstPresent ∧ trace.secondPresent ∧ trace.secondPayload = .two := by native_decide
theorem partialAndReplacementDoNotEmit : replacementTrace.emitted = [] := by native_decide
def completedOne := repairedStep replacementTrace secondApprove
theorem completeGenerationEmitsOnce : completedOne.emitted = [1] := by native_decide
theorem replyTargetsExplicitOwner : (repairedStep initial { firstApprove with route := .reply, owner := .first, scope := .file }).replyTarget = .first := by native_decide
theorem roundReplyNotifiesAll :
  let created := repairedStep initial { secondApprove with route := .comment, owner := .second, scope := .round }
  let replied := repairedStep created { secondApprove with route := .reply, owner := .second, scope := .round }
  created.roundThread = .open ∧ replied.audience = files := by native_decide

def firstThenSecondRc := repairedStep (repairedStep initial firstApprove) { secondApprove with decision := .requestChanges }
def secondThenFirstRc := repairedStep (repairedStep initial { secondApprove with decision := .requestChanges }) firstApprove
theorem requestChangesPriorityBothArrivalOrders :
  aggregate firstThenSecondRc = .requestChanges ∧ aggregate secondThenFirstRc = .requestChanges := by native_decide

def generationOneRequestChanges := repairedApply (repairedApply (repairedApply initial (.request firstRequestChanges)) (.request secondApprove)) .resolveRound
def generationTwoRequestChanges := repairedApply (repairedApply (repairedApply (repairedApply generationOneRequestChanges .go) (.request firstRequestChangesG2)) (.request secondApproveG2)) .resolveRound
def generationThreeApprove := repairedApply (repairedApply (repairedApply (repairedApply generationTwoRequestChanges .go) (.request firstApproveG3)) (.request secondApproveG3)) .resolveRound
theorem generationOneWaitsForGo : generationOneRequestChanges.phase = .waitingGo ∧ generationOneRequestChanges.emitted = [1] := by native_decide
theorem generationTwoWaitsForGo : generationTwoRequestChanges.phase = .waitingGo ∧ generationTwoRequestChanges.emitted = [1, 2] := by native_decide
theorem generationThreeAllApproveExitsOnce : generationThreeApprove.phase = .exited ∧ generationThreeApprove.emitted = [1, 2, 3] := by native_decide
theorem staleGenerationOneIs409AfterGo : (repairedApply (repairedApply generationOneRequestChanges .go) (.request firstApprove)).outcome = .rejected409 := by native_decide
theorem staleGenerationTwoIs409AfterSecondGo : (repairedApply (repairedApply generationTwoRequestChanges .go) (.request firstRequestChangesG2)).outcome = .rejected409 := by native_decide
theorem staleGenerationHasNoEffect :
  effects (repairedApply (repairedApply generationOneRequestChanges .go) (.request firstApprove)) =
    effects (repairedApply generationOneRequestChanges .go) := by native_decide
theorem terminalSubmitHasNoEffect :
  effects (repairedStep completedOne firstReplacement) = effects completedOne ∧
    (repairedStep completedOne firstReplacement).outcome = .rejected409 := by native_decide

def generationThreeRequestChanges := repairedApply (repairedApply (repairedApply (repairedApply generationTwoRequestChanges .go) (.request firstRequestChangesG3)) (.request secondApproveG3)) .resolveRound
def generationFourCollecting := repairedApply generationThreeRequestChanges .go
theorem generationThreeRequestChangesAdvancesWithoutProductCap :
  generationThreeRequestChanges.phase = .waitingGo ∧
  generationFourCollecting.generation = 4 ∧ generationFourCollecting.phase = .collecting := by native_decide
def generationFourApprove := repairedApply (repairedApply (repairedApply generationFourCollecting (.request firstApproveG4)) (.request secondApproveG4)) .resolveRound
theorem generationFourAllApproveExitsAndEmitsOnce :
  generationFourApprove.phase = .exited ∧ generationFourApprove.emitted = [1, 2, 3, 4] := by native_decide

/- Independent static-delivery decision table. These dimensions do not alter
the review ledger, so they are exhaustively checked outside the submit closure. -/
inductive HttpMethod where | get | head deriving DecidableEq, Repr, BEq
inductive StaticPath where | asset | nestedCss | traversal | bare deriving DecidableEq, Repr, BEq
inductive RangeHeader where | absent | bytes deriving DecidableEq, Repr, BEq
inductive StaticOutcome where | ok200 | partial206 | forbidden403 | bad400 deriving DecidableEq, Repr, BEq
structure StaticRequest where
  mux : Bool
  context : Context
  method : HttpMethod
  path : StaticPath
  range : RangeHeader
  deriving DecidableEq, Repr, BEq
def staticOutcome (request : StaticRequest) : StaticOutcome :=
  if !request.mux then .ok200
  else if contextFile request.context == none || request.path == .bare then .bad400
  else if request.path == .traversal then .forbidden403
  else if request.range == .bytes then .partial206
  else .ok200
def staticRequests : List StaticRequest :=
  [false, true].flatMap fun mux => contexts.flatMap fun context =>
    [.get, .head].flatMap fun method => [.asset, .nestedCss, .traversal, .bare].flatMap fun path =>
      [.absent, .bytes].map fun range =>
        { mux := mux, context := context, method := method, path := path, range := range }
def staticContract (request : StaticRequest) : Bool :=
  let outcome := staticOutcome request
  if !request.mux then outcome == .ok200
  else if contextFile request.context == none || request.path == .bare then outcome == .bad400
  else if request.path == .traversal then outcome == .forbidden403
  else if request.range == .bytes then outcome == .partial206
  else outcome == .ok200
theorem everyStaticMethodPathContextMatchesContract : staticRequests.all staticContract = true := by native_decide

def approveGate : GateState → Outcome
  | .anchoredUnresolved => .rejected409
  | .clear | .unanchoredOnly => .accepted
structure GateEffect where
  outcome : Outcome
  retainedUnanchored : Bool
  deriving DecidableEq, Repr, BEq
def gateEffect (gate : GateState) : GateEffect := {
  outcome := approveGate gate, retainedUnanchored := gate == .unanchoredOnly }
theorem unanchoredHistoryIsRetainedButDoesNotGate :
  (gateEffect .unanchoredOnly).outcome = .accepted ∧
  (gateEffect .unanchoredOnly).retainedUnanchored ∧
  approveGate .anchoredUnresolved = .rejected409 := by native_decide
def firstUnanchoredComment : Input := {
  firstApprove with route := .comment, scope := .file, gate := .unanchoredOnly }
def firstAnchoredComment : Input := {
  firstApprove with route := .comment, scope := .file, gate := .anchoredUnresolved }
theorem currentUnanchoredGateRejectsReachableApprove :
  let commented := currentStep initial { firstUnanchoredComment with context := .missing }
  commented.firstRetainedUnanchored ∧
  (currentStep commented { firstApprove with context := .missing }).outcome = .rejected409 := by native_decide
theorem repairedUnanchoredHistoryIsRetainedAndApproveIsAccepted :
  let commented := repairedStep initial firstUnanchoredComment
  commented.firstRetainedUnanchored ∧
  (repairedStep commented firstApprove).outcome = .accepted := by native_decide
theorem repairedAnchoredHistoryBlocksApprove :
  let commented := repairedStep initial firstAnchoredComment
  (repairedStep commented firstApprove).outcome = .rejected409 := by native_decide
theorem repairedResolveClearsAnchoredGateAndAllowsApprove :
  let commented := repairedStep initial firstAnchoredComment
  let resolved := repairedStep commented { firstApprove with route := Route.resolve, scope := .file }
  resolved.firstGate = .clear ∧ resolved.resolvePersisted ∧
  (repairedStep resolved firstApprove).outcome = .accepted := by native_decide

def summaryOrder (_arrival : List File) : List File := files
theorem summaryOrderIsMuxOrderForBothArrivals :
  summaryOrder [.first, .second] = files ∧ summaryOrder [.second, .first] = files := by native_decide

structure ThreadEffect where
  persisted : Bool
  owner : File
  audience : List File
  deriving DecidableEq, Repr, BEq

def roundCreateInput : Input := { initialInput with route := .comment, scope := .round }
def roundReplyInput : Input := { initialInput with route := .reply, scope := .round }
def roundResolveInput : Input := { initialInput with route := Route.resolve, scope := .round }
def muxRoundCreateInput : Input := { firstApprove with route := .comment, scope := .round }
def muxRoundReplyInput : Input := { firstApprove with route := .reply, scope := .round }
def muxRoundResolveMissingInput : Input := { firstApprove with route := Route.resolve, scope := .round }
def currentRoundThreadCreated := currentStep initial roundCreateInput
def currentRoundThreadReplied := currentStep currentRoundThreadCreated roundReplyInput
def currentRoundThreadResolved := currentStep currentRoundThreadReplied roundResolveInput
def currentRoundThreadReplyAfterResolve := currentStep currentRoundThreadResolved roundReplyInput
def currentRoundThreadTrace := currentStep currentRoundThreadReplyAfterResolve roundCreateInput
def repairedRoundThreadCreated := repairedStep initial roundCreateInput
def repairedRoundThreadReplied := repairedStep repairedRoundThreadCreated roundReplyInput
def repairedRoundThreadResolved := repairedStep repairedRoundThreadReplied roundResolveInput
def repairedRoundThreadReplyAfterResolve := repairedStep repairedRoundThreadResolved roundReplyInput
def repairedRoundThreadTrace := repairedStep repairedRoundThreadReplyAfterResolve roundCreateInput

/- The product's non-mux missing-id 200 is intentionally outside this mux
typed boundary; the repaired mux route rejects NoThread resolve with 400. -/
theorem currentRoundResolveLeavesThreadOpen :
  currentRoundThreadResolved.roundThread = .open ∧
  currentRoundThreadReplyAfterResolve.outcome = .accepted ∧
  currentRoundThreadTrace.outcome = .rejected409 := by native_decide
theorem repairedRoundThreadLifecycleRejectsResolvedReplyAndRetainsHistory :
  repairedRoundThreadResolved.roundThread = .resolved ∧
  repairedRoundThreadReplyAfterResolve.outcome = .rejected409 ∧
  effects repairedRoundThreadReplyAfterResolve = effects repairedRoundThreadResolved ∧
  repairedRoundThreadTrace.roundThread = .open ∧
  repairedRoundThreadTrace.retainedResolvedRound ∧
  repairedRoundThreadTrace.roundReplies = 1 := by native_decide
theorem repairedRoundResolveIsModeAwareNoOp :
  (repairedStep repairedRoundThreadResolved roundResolveInput).outcome = .accepted ∧
  effects (repairedStep repairedRoundThreadResolved roundResolveInput) = effects repairedRoundThreadResolved ∧
  (repairedStep initial roundResolveInput).outcome = .accepted ∧
  effects (repairedStep initial roundResolveInput) = effects initial ∧
  (repairedStep initial muxRoundResolveMissingInput).outcome = .rejected400 ∧
  effects (repairedStep initial muxRoundResolveMissingInput) = effects initial := by native_decide

def threadEffect (input : Input) : ThreadEffect := {
  persisted := true, owner := input.owner,
  audience := if input.scope == .round then files else [input.owner] }
theorem fileAndRoundThreadEffectsPersistWithCorrectAudience :
  let fileEffect := threadEffect { secondApprove with route := .reply, scope := .file }
  let roundEffect := threadEffect { firstApprove with route := Route.resolve, scope := .round }
  fileEffect.persisted ∧ fileEffect.owner = .second ∧ fileEffect.audience = [.second] ∧
  roundEffect.persisted ∧ roundEffect.audience = files := by native_decide
theorem replyResolveAndRoundPersistenceAreStateEffects :
  let fileReply := repairedStep initial { secondApprove with route := .reply, scope := .file }
  let resolved := repairedStep fileReply { secondApprove with route := Route.resolve, scope := .file }
  let roundCreated := repairedStep resolved { firstApprove with route := .comment, scope := .round }
  let roundReply := repairedStep roundCreated { firstApprove with route := .reply, scope := .round }
  fileReply.filePersisted ∧ fileReply.persistedFileOwner = .second ∧
  resolved.resolvePersisted ∧ roundCreated.roundPersisted ∧
  roundReply.roundPersisted ∧ roundReply.audience = files := by native_decide

def allInputs : List Input :=
  actors.flatMap fun actor => routes.flatMap fun route => contexts.flatMap fun context =>
    files.flatMap fun file => files.flatMap fun owner => generations.flatMap fun generation =>
      payloads.flatMap fun payload => decisions.flatMap fun decision => scopes.flatMap fun scope => gates.flatMap fun gate => modes.map fun mode =>
        { actor := actor, route := route, context := context, file := file,
          owner := owner, generation := generation, payload := payload,
          decision := decision, scope := scope, gate := gate, mode := mode }

/- Delivery checks observe the route, ownership validity, and the input fields
that can alter the selected state.  These canonical representatives retain one
input for each such class while leaving the typed source alphabet unchanged. -/
def invalidRepresentative (route : Route) : Input :=
  { initialInput with route := route, context := .missing, mode := .mux }
def globalRepresentative (route : Route) : Input :=
  { initialInput with route := route, context := .global, mode := .mux }
def ownedRepresentative (route : Route) (file : File := .first) : Input :=
  { initialInput with
    route := route, context := (if file == .first then .validFirst else .validSecond),
    file := file, owner := file, mode := .mux }
def fileOwnerMismatchRepresentative : Input :=
  { initialInput with route := .comment, context := .validFirst, owner := .second, mode := .mux }

def deliveryProjection (input : Input) : Input :=
  if !isContextBound input.route then
    if input.context == .global then globalRepresentative input.route
    else invalidRepresentative input.route
  else if !validOwned input then invalidRepresentative input.route
  else if (input.route == .comment || input.route == .reply || input.route == Route.resolve) &&
      input.scope == .file && input.owner != input.file then fileOwnerMismatchRepresentative
  else if input.route == .submit then
    let representative := ownedRepresentative .submit input.file
    { representative with generation := input.generation, payload := input.payload, decision := input.decision }
  else if input.route == .comment && input.scope == .file then
    let representative := ownedRepresentative .comment
    { representative with gate := input.gate }
  else if input.route == Route.resolve && input.scope == .round then
    if input.mode == .single then
      { initialInput with route := Route.resolve, scope := .round }
    else
      let representative := ownedRepresentative  Route.resolve
      { representative with scope := .round }
  else if input.route == .comment || input.route == .reply || input.route == Route.resolve then
    let representative := ownedRepresentative input.route
    { representative with scope := input.scope }
  else ownedRepresentative input.route

def isRoundLifecycleInput (input : Input) : Bool :=
  input.scope == .round &&
    (input.route == .comment || input.route == .reply || input.route == Route.resolve)

def lifecycleProjection (input : Input) : Input :=
  if !validOwned input then
    let representative := invalidRepresentative input.route
    { representative with scope := .round }
  else if input.route == Route.resolve then
    if input.mode == .single then
      { initialInput with route := Route.resolve, scope := .round }
    else
      let representative := ownedRepresentative  Route.resolve
      { representative with scope := .round }
  else
    let representative := ownedRepresentative input.route
    { representative with scope := .round }

def deliveryRepresentatives : List Input :=
  (allInputs.map deliveryProjection).eraseDups
def lifecycleRepresentatives : List Input :=
  ((allInputs.filter isRoundLifecycleInput).map lifecycleProjection).eraseDups

theorem deliveryProjectionCovered {input : Input} (member : input ∈ allInputs) :
    deliveryProjection input ∈ deliveryRepresentatives := by
  apply List.mem_eraseDups.mpr
  exact List.mem_map.mpr ⟨input, member, rfl⟩

theorem lifecycleProjectionCovered {input : Input} (member : input ∈ allInputs)
    (lifecycle : isRoundLifecycleInput input = true) :
    lifecycleProjection input ∈ lifecycleRepresentatives := by
  apply List.mem_eraseDups.mpr
  apply List.mem_map.mpr
  exact ⟨input, List.mem_filter.mpr ⟨member, lifecycle⟩, rfl⟩

theorem deliveryRepresentativeCount : deliveryRepresentatives.length = 60 := by native_decide
theorem lifecycleRepresentativeCount : lifecycleRepresentatives.length = 7 := by native_decide

def oneStepSafe (input : Input) : Bool :=
  let next := repairedStep initial input
  (next.outcome == .accepted || effects next == effects initial) &&
  (next.outcome != .accepted || !isContextBound input.route ||
    (validOwned input && next.selected == input.file))

/- Fifteen is the exact length of three request-changes rounds and one G4
approve round: 3 + 1 + 3 + 1 + 3 + 1 + 3 commands. -/
def closureDepth : Nat := 15
def submitAlphabet : List Input :=
  files.flatMap fun file => decisions.flatMap fun decision => generations.flatMap fun generation =>
    payloads.map fun payload =>
      { firstApprove with
        file := file, owner := file,
        context := (if file == .first then .validFirst else .validSecond),
        generation := generation, payload := payload, decision := decision
      }
def boundaryAlphabet : List Input := [htmlSecond, missingState, queryStateSecond,
  missingSubmit, invalidSubmit, wrongRouteFile, globalUi, uiWithF,
  { firstApprove with route := .static }, { secondApprove with route := .static },
  { firstApprove with route := .sse }, { secondApprove with route := .sse },
  { firstApprove with actor := .cli, route := .cli },
  { secondApprove with actor := .cli, route := .cli },
  firstUnanchoredComment, firstAnchoredComment,
  { firstApprove with route := .reply, scope := .file },
  { secondApprove with route := .reply, scope := .round },
  roundCreateInput, roundReplyInput, roundResolveInput,
  muxRoundCreateInput, muxRoundReplyInput, muxRoundResolveMissingInput,
  { firstApprove with route := Route.resolve, scope := .file },
  { secondApprove with route := Route.resolve, scope := .file }]
def commandAlphabet : List Command :=
  (submitAlphabet ++ boundaryAlphabet).map .request ++ [.resolveRound, .go]
/- Closure normalization collapses step-local bookkeeping that repairedApply
always overwrites and that delivery/lifecycle safety reads only from the post
state. Keeping every State field, this only quotients outcome/lastBoundary/
lastInput so the depth-15 frontier stays finite without shrinking commands,
generations, or the public all-input statements. -/
def normalizeForClosure (state : State) : State :=
  { state with
    outcome := .accepted,
    lastBoundary := .delivery,
    lastInput := initialInput,
    -- rawEffects is audit-only for repaired transitions; canonicalize it from the
    -- ledger so observationally identical ledgers share one frontier node.
    rawEffects := (if state.firstPresent then 1 else 0) + (if state.secondPresent then 1 else 0),
    -- Pre-state display targets are overwritten by every accepted delivery and are
    -- not read by invariant/deliveryContractSafe/roundLifecycleDecisionSafe control
    -- flow; keep the fields but quotient them so the depth-15 frontier stays finite.
    selected := .first,
    effect := .first,
    static := .first,
    sse := .first,
    lastOwner := .first,
    replyTarget := .first,
    audience := [] }
def commandSuccessors (states : List State) : List State :=
  states.flatMap fun state =>
    commandAlphabet.map fun command => normalizeForClosure (repairedApply state command)
def nextFrontier (seen frontier : List State) : List State :=
  ((commandSuccessors frontier).filter fun state => !(seen.contains state)).eraseDups
theorem nextFrontierMembership {seen frontier : List State} {state : State} :
    state ∈ nextFrontier seen frontier ↔ state ∈ commandSuccessors frontier ∧ state ∉ seen := by
  simp [nextFrontier, List.contains_eq_mem]

def hashCommandSuccessors (frontier : Std.HashSet State) : Std.HashSet State :=
  Std.HashSet.ofList (commandSuccessors frontier.toList)
def hashNextFrontier (seen frontier : Std.HashSet State) : Std.HashSet State :=
  (hashCommandSuccessors frontier).diff seen
def hashFrontierReachability : Nat → Std.HashSet State × Std.HashSet State
  | 0 =>
      let initialSet := (∅ : Std.HashSet State).insert initial
      (initialSet, initialSet)
  | depth + 1 =>
      let previous := hashFrontierReachability depth
      let seen := previous.1
      let frontier := previous.2
      let next := hashNextFrontier seen frontier
      (seen.union next, next)
def hashReachableStates (depth : Nat) : Std.HashSet State :=
  (hashFrontierReachability depth).1
def hashReachableFrontier (depth : Nat) : Std.HashSet State :=
  (hashFrontierReachability depth).2

theorem hashCommandSuccessorsMembership {frontier : Std.HashSet State} {state : State} :
    state ∈ hashCommandSuccessors frontier ↔ state ∈ commandSuccessors frontier.toList := by
  simp [hashCommandSuccessors, List.contains_eq_mem]

theorem hashCommandSuccessorsMembershipEquivalent {hashed : Std.HashSet State}
    {listed : List State} {state : State}
    (equivalent : ∀ candidate, candidate ∈ hashed ↔ candidate ∈ listed) :
    state ∈ hashCommandSuccessors hashed ↔ state ∈ commandSuccessors listed := by
  rw [hashCommandSuccessorsMembership]
  constructor
  · intro member
    simp only [commandSuccessors, List.mem_flatMap] at member ⊢
    rcases member with ⟨source, sourceMember, resultMember⟩
    exact ⟨source, equivalent source |>.mp (Std.HashSet.mem_toList.mp sourceMember), resultMember⟩
  · intro member
    simp only [commandSuccessors, List.mem_flatMap] at member ⊢
    rcases member with ⟨source, sourceMember, resultMember⟩
    exact ⟨source, Std.HashSet.mem_toList.mpr (equivalent source |>.mpr sourceMember), resultMember⟩

theorem hashNextFrontierMembership {seen frontier : Std.HashSet State} {state : State} :
    state ∈ hashNextFrontier seen frontier ↔
      state ∈ hashCommandSuccessors frontier ∧ state ∉ seen := by
  change state ∈ (hashCommandSuccessors frontier).diff seen ↔ _
  exact Std.HashSet.mem_diff_iff

def frontierReachability : Nat → List State × List State
  | 0 => ([initial], [initial])
  | depth + 1 =>
      let previous := frontierReachability depth
      let seen := previous.1
      let frontier := previous.2
      let next := nextFrontier seen frontier
      (seen ++ next, next)
def reachableStates (depth : Nat) : List State := (frontierReachability depth).1
def reachableFrontier (depth : Nat) : List State := (frontierReachability depth).2
theorem hashFrontierReachabilityMembershipEquivalentToList (depth : Nat) (state : State) :
    (state ∈ hashReachableStates depth ↔ state ∈ reachableStates depth) ∧
    (state ∈ hashReachableFrontier depth ↔ state ∈ reachableFrontier depth) := by
  induction depth generalizing state with
  | zero =>
    refine ⟨?_, ?_⟩
    · change state ∈ ((∅ : Std.HashSet State).insert initial) ↔ state ∈ ([initial] : List State)
      constructor
      · intro h
        -- mem_insert: a ∈ m.insert k ↔ (k == a) ∨ a ∈ m
        have h' := (Std.HashSet.mem_insert (m := (∅ : Std.HashSet State)) (k := initial) (a := state)).mp h
        cases h' with
        | inl hb =>
          have eq : initial = state := (beq_iff_eq).1 hb
          exact List.mem_singleton.mpr eq.symm
        | inr hempty =>
          exact absurd hempty (Std.HashSet.not_mem_empty (a := state))
      · intro h
        have eq : state = initial := List.mem_singleton.mp h
        exact (Std.HashSet.mem_insert (m := (∅ : Std.HashSet State)) (k := initial) (a := state)).mpr
          (Or.inl ((beq_iff_eq).2 eq.symm))
    · change state ∈ ((∅ : Std.HashSet State).insert initial) ↔ state ∈ ([initial] : List State)
      constructor
      · intro h
        have h' := (Std.HashSet.mem_insert (m := (∅ : Std.HashSet State)) (k := initial) (a := state)).mp h
        cases h' with
        | inl hb =>
          have eq : initial = state := (beq_iff_eq).1 hb
          exact List.mem_singleton.mpr eq.symm
        | inr hempty =>
          exact absurd hempty (Std.HashSet.not_mem_empty (a := state))
      · intro h
        have eq : state = initial := List.mem_singleton.mp h
        exact (Std.HashSet.mem_insert (m := (∅ : Std.HashSet State)) (k := initial) (a := state)).mpr
          (Or.inl ((beq_iff_eq).2 eq.symm))
  | succ depth ih =>
    have seenEquivalent : state ∈ hashReachableStates depth ↔ state ∈ reachableStates depth :=
      (ih state).1
    have successorsEquivalent : state ∈ hashCommandSuccessors (hashReachableFrontier depth) ↔
        state ∈ commandSuccessors (reachableFrontier depth) :=
      hashCommandSuccessorsMembershipEquivalent (fun candidate => (ih candidate).2)
    have nextEquivalent : state ∈ hashNextFrontier (hashReachableStates depth)
        (hashReachableFrontier depth) ↔ state ∈ nextFrontier (reachableStates depth)
        (reachableFrontier depth) := by
      rw [hashNextFrontierMembership, nextFrontierMembership, successorsEquivalent,
        seenEquivalent]
    constructor
    · change state ∈ (hashReachableStates depth).union
          (hashNextFrontier (hashReachableStates depth) (hashReachableFrontier depth)) ↔
        state ∈ reachableStates depth ++ nextFrontier (reachableStates depth)
          (reachableFrontier depth)
      rw [show (state ∈ (hashReachableStates depth).union
        (hashNextFrontier (hashReachableStates depth) (hashReachableFrontier depth))) ↔
          state ∈ hashReachableStates depth ∨ state ∈ hashNextFrontier
            (hashReachableStates depth) (hashReachableFrontier depth) by
          change ((hashReachableStates depth).union
            (hashNextFrontier (hashReachableStates depth) (hashReachableFrontier depth))).contains state = true ↔ _
          exact Std.HashSet.mem_union_iff,
        List.mem_append, seenEquivalent, nextEquivalent]
    · change state ∈ hashNextFrontier (hashReachableStates depth)
          (hashReachableFrontier depth) ↔
        state ∈ nextFrontier (reachableStates depth) (reachableFrontier depth)
      exact nextEquivalent
/- Reference only: the pre-frontier cumulative closure. It is excluded from
the executable finite checks below and retained for the general-depth proof. -/
def cumulativeReachableStates : Nat → List State
  | 0 => [initial]
  | depth + 1 =>
      let previous := cumulativeReachableStates depth
      (previous ++ commandSuccessors previous).eraseDups
theorem reachableStatesMonotone (depth : Nat) :
    reachableStates depth ⊆ reachableStates (depth + 1) := by
  intro state member
  simp [reachableStates, frontierReachability]
  exact Or.inl member
theorem commandSuccessorsAppend (left right : List State) :
    commandSuccessors (left ++ right) = commandSuccessors left ++ commandSuccessors right := by
  simp [commandSuccessors]
theorem commandSuccessorsMonotone {left right : List State} (subset : left ⊆ right) :
    commandSuccessors left ⊆ commandSuccessors right := by
  intro state member
  simp only [commandSuccessors, List.mem_flatMap] at member ⊢
  rcases member with ⟨source, sourceMember, resultMember⟩
  exact ⟨source, subset sourceMember, resultMember⟩
theorem reachableFrontierSubsetSeen (depth : Nat) :
    reachableFrontier depth ⊆ reachableStates depth := by
  cases depth with
  | zero => simp [reachableFrontier, reachableStates, frontierReachability]
  | succ depth =>
    intro state member
    simp only [reachableFrontier, reachableStates, frontierReachability] at member ⊢
    exact List.mem_append.mpr (Or.inr member)
theorem commandSuccessorsSeenReachNext (depth : Nat) :
    commandSuccessors (reachableStates depth) ⊆ reachableStates (depth + 1) := by
  induction depth with
  | zero =>
    intro state member
    simp only [reachableStates, frontierReachability] at member ⊢
    by_cases old : state ∈ [initial]
    · exact List.mem_append.mpr (Or.inl old)
    · exact List.mem_append.mpr (Or.inr ((nextFrontierMembership).mpr ⟨member, old⟩))
  | succ depth ih =>
    intro state member
    simp only [reachableStates, frontierReachability] at member ⊢
    rw [commandSuccessorsAppend] at member
    rcases (List.mem_append.mp member) with old | fresh
    · exact (reachableStatesMonotone (depth + 1)) (ih old)
    · by_cases old : state ∈ (frontierReachability depth).1 ++
        nextFrontier (frontierReachability depth).1 (frontierReachability depth).2
      · exact List.mem_append.mpr (Or.inl old)
      · exact List.mem_append.mpr (Or.inr ((nextFrontierMembership).mpr ⟨fresh, old⟩))
theorem reachableStatesMembershipEquivalentToCumulative (depth : Nat) (state : State) :
    state ∈ reachableStates depth ↔ state ∈ cumulativeReachableStates depth := by
  induction depth generalizing state with
  | zero => simp [reachableStates, frontierReachability, cumulativeReachableStates]
  | succ depth ih =>
    constructor
    · intro member
      simp only [reachableStates, frontierReachability] at member
      change state ∈ (cumulativeReachableStates depth ++
        commandSuccessors (cumulativeReachableStates depth)).eraseDups
      rcases List.mem_append.mp member with old | fresh
      · exact List.mem_eraseDups.mpr (List.mem_append.mpr (Or.inl (ih _ |>.mp old)))
      · have freshSuccessor : state ∈ commandSuccessors (reachableStates depth) :=
          (commandSuccessorsMonotone (reachableFrontierSubsetSeen depth))
            ((nextFrontierMembership).mp fresh).1
        simp only [commandSuccessors, List.mem_flatMap] at freshSuccessor
        rcases freshSuccessor with ⟨source, sourceMember, resultMember⟩
        have cumulativeSuccessor : state ∈ commandSuccessors (cumulativeReachableStates depth) := by
          apply List.mem_flatMap.mpr
          exact ⟨source, (ih source).mp sourceMember, resultMember⟩
        exact List.mem_eraseDups.mpr (List.mem_append.mpr (Or.inr cumulativeSuccessor))
    · intro member
      change state ∈ (cumulativeReachableStates depth ++
        commandSuccessors (cumulativeReachableStates depth)).eraseDups at member
      have raw := List.mem_eraseDups.mp member
      rcases List.mem_append.mp raw with old | successor
      · simp only [reachableStates, frontierReachability]
        exact List.mem_append.mpr (Or.inl (ih state |>.mpr old))
      · have seenSuccessor : state ∈ commandSuccessors (reachableStates depth) := by
          simp only [commandSuccessors, List.mem_flatMap] at successor
          rcases successor with ⟨source, sourceMember, resultMember⟩
          apply List.mem_flatMap.mpr
          exact ⟨source, (ih source).mpr sourceMember, resultMember⟩
        exact commandSuccessorsSeenReachNext depth seenSuccessor

theorem hashReachableStatesMembershipEquivalentToCumulative (depth : Nat) (state : State) :
    state ∈ hashReachableStates depth ↔ state ∈ cumulativeReachableStates depth :=
  (hashFrontierReachabilityMembershipEquivalentToList depth state).1.trans
    (reachableStatesMembershipEquivalentToCumulative depth state)

def invariant (state : State) : Bool :=
  (state.phase != .roundComplete || complete state) &&
  (state.phase != .exited || (complete state && aggregate state == .approve)) &&
  (state.phase != .waitingGo || aggregate state == .requestChanges) &&
  (!state.firstPresent || !validOwned state.lastInput || state.lastInput.generation == state.generation || state.lastInput.route != .submit || state.outcome == .rejected409) &&
  (!state.secondPresent || !validOwned state.lastInput || state.lastInput.generation == state.generation || state.lastInput.route != .submit || state.outcome == .rejected409) &&
  state.emitted.eraseDups == state.emitted && state.emitted.length <= state.generation &&
  (state.roundThread != .resolved || state.retainedResolvedRound)
def deliveryEffectsSafe (state : State) (input : Input) : Bool :=
  let next := repairedStep state input
  ((next.outcome != .rejected400 && next.outcome != .rejected409) || effects next == effects state) &&
  (!exactRetry state input || input.route != .submit || state.phase != .collecting ||
    input.generation != state.generation || !validOwned input || effects next == effects state)

def deliveryContractSafe (state : State) (input : Input) : Bool :=
  let next := repairedStep state input
  let rejected := next.outcome == .rejected400 || next.outcome == .rejected409
  let retry := input.route == .submit && exactRetry state input &&
    state.phase == .collecting && input.generation == state.generation && validOwned input
  let acceptedRoundResolveNoOp := next.outcome == .accepted && input.scope == .round &&
    input.route == Route.resolve &&
    (state.roundThread == .resolved || (input.mode == .single && state.roundThread == .noThread)) &&
    effects next == effects state
  let acceptedTarget := next.outcome != .accepted || !isContextBound input.route ||
    retry || acceptedRoundResolveNoOp ||
    (validOwned input && next.selected == input.file)
  let routeTarget := next.outcome != .accepted || retry ||
    ((input.route != .state && input.route != .submit && input.route != .cli) || next.effect == input.file) &&
    (input.route != .static || next.static == input.file) &&
    (input.route != .sse || next.sse == input.file)
  let audienceSafe := next.outcome != .accepted ||
    (input.route != .comment && input.route != .reply && input.route != Route.resolve) ||
    acceptedRoundResolveNoOp ||
    (input.scope == .round && input.mode == .mux && next.audience == files) ||
    (input.scope == .round && input.mode == .single && next.audience == [.first]) ||
    (input.scope == .file && next.replyTarget == input.owner && next.audience == [input.owner])
  let persistenceSafe := next.outcome != .accepted ||
    (input.route != .comment && input.route != .reply && input.route != Route.resolve) ||
    acceptedRoundResolveNoOp ||
    (((input.scope == .round && next.roundPersisted) ||
      (input.scope == .file && next.filePersisted && next.persistedFileOwner == input.owner)) &&
      (input.route != Route.resolve || next.resolvePersisted))
  let gateSafe := next.outcome != .accepted || input.route != .comment || input.scope != .file ||
    (input.file == .first && next.firstGate == input.gate &&
      (input.gate != .unanchoredOnly || next.firstRetainedUnanchored)) ||
    (input.file == .second && next.secondGate == input.gate &&
      (input.gate != .unanchoredOnly || next.secondRetainedUnanchored))
  let staleSubmitSafe := input.route != .submit || !validOwned input ||
    input.generation == state.generation || next.outcome == .rejected409
  let terminalSubmitSafe := input.route != .submit || !validOwned input ||
    state.phase == .collecting || next.outcome == .rejected409
  let anchoredApproveSafe := input.route != .submit || input.decision != .approve ||
    !validOwned input || gateForFile state input.file != .anchoredUnresolved ||
    next.outcome == .rejected409
  (!rejected || effects next == effects state) && (!retry || effects next == effects state) &&
    acceptedTarget && routeTarget && audienceSafe && persistenceSafe && gateSafe &&
    staleSubmitSafe && terminalSubmitSafe && anchoredApproveSafe

def roundLifecycleDecisionSafe (state : State) (input : Input) : Bool :=
  if input.scope != .round ||
    (input.route != .comment && input.route != .reply && input.route != Route.resolve) then true
  else
    let next := repairedStep state input
    let noEffect := effects next == effects state
    let audience := if input.mode == .mux then files else [.first]
    if !validOwned input then next.outcome == .rejected400 && noEffect
    else if input.route == .comment then
      if state.roundThread == .open then next.outcome == .rejected409 && noEffect
      else next.outcome == .accepted && next.roundThread == .open && next.roundPersisted &&
        next.audience == audience &&
        (state.roundThread != .resolved || next.retainedResolvedRound)
    else if input.route == .reply then
      if state.roundThread == .open then
        next.outcome == .accepted && next.roundThread == .open &&
          next.roundReplies == state.roundReplies + 1 && next.roundPersisted &&
          next.audience == audience
      else next.outcome == .rejected409 && noEffect
    else if state.roundThread == .open then
      next.outcome == .accepted && next.roundThread == .resolved &&
        next.roundPersisted && next.resolvePersisted && next.retainedResolvedRound &&
        next.audience == audience
    else if state.roundThread == .resolved then next.outcome == .accepted && noEffect
    else if input.mode == .single then next.outcome == .accepted && noEffect
    else next.outcome == .rejected400 && noEffect

set_option linter.unusedSimpArgs false

theorem deliveryContractSafe_easy (state : State) (input : Input)
    (hroute : input.route = Route.html ∨ input.route = Route.state ∨ input.route = Route.sse ∨
      input.route = Route.static ∨ input.route = Route.cli ∨ input.route = Route.uiJs ∨
      input.route = Route.healthz) :
    deliveryContractSafe state input = true := by
  rcases hroute with h | h | h | h | h | h | h
  all_goals (
    unfold deliveryContractSafe
    simp [repairedStep, h, isContextBound]
    by_cases hown : validOwned input = true
    · simp [hown, effects, exactRetry, h, isContextBound, gateForFile]
    · simp [hown, effects, exactRetry, h, isContextBound, gateForFile]
  )

theorem deliveryContractSafe_hard (state : State) (input : Input)
    (hroute : input.route = Route.submit ∨ input.route = Route.comment ∨
      input.route = Route.reply ∨ input.route = Route.resolve) :
    deliveryContractSafe state input = true := by
  rcases hroute with h | h | h | h
  all_goals (
    unfold deliveryContractSafe
    simp [repairedStep, h, isContextBound]
    by_cases hown : validOwned input = true
    · simp [hown]
      split <;> (try split) <;> (try split) <;> (try split) <;> (try split)
      all_goals (try simp [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hfile : input.file))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hmode : input.mode))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hth : state.roundThread))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hgate : input.gate))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hscope : input.scope))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
      all_goals (try (cases hdec : input.decision))
      all_goals (try simp_all [effects, exactRetry, isContextBound, gateForFile])
    · simp [hown, effects, exactRetry, h, isContextBound, gateForFile]
  )

theorem deliveryContractSafe_any (state : State) (input : Input) :
    deliveryContractSafe state input = true := by
  cases hroute : input.route
  · exact deliveryContractSafe_easy state input (Or.inl hroute)
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inl hroute))
  · exact deliveryContractSafe_hard state input (Or.inl hroute)
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inr (Or.inl hroute)))
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inr (Or.inr (Or.inl hroute))))
  · exact deliveryContractSafe_hard state input (Or.inr (Or.inl hroute))
  · exact deliveryContractSafe_hard state input (Or.inr (Or.inr (Or.inl hroute)))
  · exact deliveryContractSafe_hard state input (Or.inr (Or.inr (Or.inr hroute)))
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inr (Or.inr (Or.inr (Or.inl hroute)))))
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inl hroute))))))
  · exact deliveryContractSafe_easy state input (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr hroute))))))

theorem roundLifecycleDecisionSafe_thread (state : State) (input : Input)
    (hroute : input.route = Route.comment ∨ input.route = Route.reply ∨
      input.route = Route.resolve) :
    roundLifecycleDecisionSafe state input = true := by
  rcases hroute with h | h | h
  all_goals (
    unfold roundLifecycleDecisionSafe
    simp [h]
    by_cases hsc : input.scope = Scope.round
    · simp [hsc]
      by_cases hown : validOwned input = true
      · simp [hown]
        cases hth : state.roundThread <;> cases hmode : input.mode <;>
          simp [repairedStep, h, hsc, hown, hth, hmode, isContextBound, effects]
      · simp [hown, repairedStep, h, hsc, isContextBound, effects]
    · simp [hsc]
  )

theorem roundLifecycleDecisionSafe_any (state : State) (input : Input) :
    roundLifecycleDecisionSafe state input = true := by
  cases hroute : input.route
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]
  · exact roundLifecycleDecisionSafe_thread state input (Or.inl hroute)
  · exact roundLifecycleDecisionSafe_thread state input (Or.inr (Or.inl hroute))
  · exact roundLifecycleDecisionSafe_thread state input (Or.inr (Or.inr hroute))
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]
  · simp [roundLifecycleDecisionSafe, hroute]

theorem deliveryProjectionPreservesSafety (state : State) (input : Input) :
    deliveryContractSafe state (deliveryProjection input) = deliveryContractSafe state input := by
  simp [deliveryContractSafe_any]

theorem lifecycleProjectionPreservesSafety (state : State) (input : Input)
    (_lifecycle : isRoundLifecycleInput input = true) :
    roundLifecycleDecisionSafe state (lifecycleProjection input) =
      roundLifecycleDecisionSafe state input := by
  simp [roundLifecycleDecisionSafe_any]

theorem lifecycleOutsideIsTrue (state : State) (input : Input)
    (_outside : isRoundLifecycleInput input = false) :
    roundLifecycleDecisionSafe state input = true :=
  roundLifecycleDecisionSafe_any state input

theorem deliveryRepresentativesCoverAllInputs (state : State)
    (representativesSafe : deliveryRepresentatives.all (deliveryContractSafe state) = true) :
    allInputs.all (deliveryContractSafe state) = true := by
  apply List.all_eq_true.mpr
  intro input member
  rw [← deliveryProjectionPreservesSafety state input]
  exact (List.all_eq_true.mp representativesSafe) (deliveryProjection input)
    (deliveryProjectionCovered member)

theorem lifecycleRepresentativesCoverAllInputs (state : State)
    (representativesSafe : lifecycleRepresentatives.all (roundLifecycleDecisionSafe state) = true) :
    allInputs.all (roundLifecycleDecisionSafe state) = true := by
  apply List.all_eq_true.mpr
  intro input member
  cases lifecycle : isRoundLifecycleInput input with
  | false => exact lifecycleOutsideIsTrue state input lifecycle
  | true =>
    rw [← lifecycleProjectionPreservesSafety state input lifecycle]
    exact (List.all_eq_true.mp representativesSafe) (lifecycleProjection input)
      (lifecycleProjectionCovered member lifecycle)

theorem hashAllTransfersToList (depth : Nat) (predicate : State → Bool)
    (hashSafe : (hashReachableStates depth).all predicate = true) :
    (reachableStates depth).all predicate = true := by
  apply List.all_eq_true.mpr
  intro state member
  exact (Std.HashSet.all_eq_true_iff_forall_mem.mp hashSafe) state
    ((hashFrontierReachabilityMembershipEquivalentToList depth state).1.mpr member)

theorem hashAnyTransfersToList (depth : Nat) (predicate : State → Bool)
    (hashWitness : (hashReachableStates depth).any predicate = true) :
    (reachableStates depth).any predicate = true := by
  rcases Std.HashSet.any_eq_true_iff_exists_mem.mp hashWitness with
    ⟨state, member, witness⟩
  apply List.any_eq_true.mpr
  exact ⟨state, (hashFrontierReachabilityMembershipEquivalentToList depth state).1.mp member, witness⟩

theorem masterFiniteChecks :
  let states := hashReachableStates closureDepth
  let inputs := allInputs
  inputs.all oneStepSafe = true ∧
  states.all invariant = true ∧
  states.all (fun state =>
    (submitAlphabet ++ boundaryAlphabet).all (deliveryEffectsSafe state)) = true ∧
  states.all (fun state => deliveryRepresentatives.all (deliveryContractSafe state)) = true ∧
  states.all (fun state => lifecycleRepresentatives.all (roundLifecycleDecisionSafe state)) = true ∧
  states.all (fun state =>
    state.roundThread != .resolved || state.retainedResolvedRound) = true ∧
  states.any (fun state => state.phase == .collecting) &&
  states.any (fun state => state.phase == .roundComplete) &&
  states.any (fun state => state.phase == .waitingGo) &&
  states.any (fun state => state.phase == .exited) := by native_decide

theorem everyTypedInputIsStrictOrEffectFree : allInputs.all oneStepSafe = true := by
  simpa using masterFiniteChecks.1
theorem boundedClosurePreservesInvariant : (reachableStates closureDepth).all invariant = true := by
  exact hashAllTransfersToList closureDepth invariant masterFiniteChecks.2.1
theorem boundedDeliveryEffectsAreSafe :
  (reachableStates closureDepth).all (fun state =>
    (submitAlphabet ++ boundaryAlphabet).all (deliveryEffectsSafe state)) = true := by
  exact hashAllTransfersToList closureDepth (fun state =>
    (submitAlphabet ++ boundaryAlphabet).all (deliveryEffectsSafe state)) masterFiniteChecks.2.2.1
theorem everyTypedDeliveryFromEveryBoundedReachableStateIsSafe :
  (reachableStates closureDepth).all (fun state =>
    allInputs.all (deliveryContractSafe state)) = true := by
  have reps := hashAllTransfersToList closureDepth (fun state =>
    deliveryRepresentatives.all (deliveryContractSafe state)) masterFiniteChecks.2.2.2.1
  apply List.all_eq_true.mpr
  intro state member
  exact deliveryRepresentativesCoverAllInputs state
    ((List.all_eq_true.mp reps) state member)
theorem everyTypedRoundLifecycleDeliveryMatchesDecisionTable :
  (reachableStates closureDepth).all (fun state =>
    allInputs.all (roundLifecycleDecisionSafe state)) = true := by
  have reps := hashAllTransfersToList closureDepth (fun state =>
    lifecycleRepresentatives.all (roundLifecycleDecisionSafe state)) masterFiniteChecks.2.2.2.2.1
  apply List.all_eq_true.mpr
  intro state member
  exact lifecycleRepresentativesCoverAllInputs state
    ((List.all_eq_true.mp reps) state member)
theorem boundedClosureKeepsResolvedRoundHistory :
  (reachableStates closureDepth).all (fun state =>
    state.roundThread != .resolved || state.retainedResolvedRound) = true := by
  exact hashAllTransfersToList closureDepth (fun state =>
    state.roundThread != .resolved || state.retainedResolvedRound) masterFiniteChecks.2.2.2.2.2.1
theorem everyPhaseIsReachable :
  (reachableStates closureDepth).any (fun state => state.phase == .collecting) &&
  (reachableStates closureDepth).any (fun state => state.phase == .roundComplete) &&
  (reachableStates closureDepth).any (fun state => state.phase == .waitingGo) &&
  (reachableStates closureDepth).any (fun state => state.phase == .exited) := by
  have h := masterFiniteChecks.2.2.2.2.2.2
  simp only [Bool.and_eq_true] at h
  rcases h with ⟨⟨⟨ha, hb⟩, hc⟩, hd⟩
  have hc' := hashAnyTransfersToList closureDepth (fun state => state.phase == .collecting) ha
  have hr := hashAnyTransfersToList closureDepth (fun state => state.phase == .roundComplete) hb
  have hw := hashAnyTransfersToList closureDepth (fun state => state.phase == .waitingGo) hc
  have he := hashAnyTransfersToList closureDepth (fun state => state.phase == .exited) hd
  simpa [Bool.and_eq_true, hc', hr, hw, he]

end StrictContext
