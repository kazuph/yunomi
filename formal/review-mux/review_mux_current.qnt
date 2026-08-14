/* Historical pre-freeze transcription retained only as review provenance.
   It is not executable and is not an evidence source.
// Current review-mux transcription.  The Delivery vocabulary is deliberately
// identical to review_mux_repaired.qnt so the RED and repaired models quantify
// over the same actors, routes, strict-f contexts, generations, payloads, and
// decisions.
module review_mux_current {
  type Actor = Browser | Cli
  type Route = HtmlRoute | StateRoute | SubmitRoute | SseRoute | StaticRoute | ReplyRoute | CliRoute | UiJsRoute | HealthzRoute
  type File = First | Second
  type Context = Missing | ValidFirst | ValidSecond | Invalid | Global
  type Payload = P1 | P2
  type Decision = NoDecision | RequestChanges | Approve
  type Outcome = Accepted | NotFound404 | Rejected400 | Rejected409
  type Scope = FileThread | RoundThread
  type RoundThreadState = NoThread | Open | Resolved
  type RoundThreadScenario = ScenarioStart | ScenarioCreated | ScenarioReplied |
    ScenarioResolveAttempted | ScenarioReplyAfterResolve | ScenarioCreateAfterResolve
  type Phase = Collecting | RoundComplete | WaitingGo | Exited
  type Delivery = { actor: Actor, route: Route, context: Context, file: File,
    generation: Generation, payload: Payload, decision: Decision }
  type State = {
    selected: File, effectTarget: File, staticTarget: File, sseTarget: File,
    lastOwner: File, replyTarget: File, lastRoute: Route, lastContext: Context,
    lastScope: Scope, phase: Phase, generation: Generation, rawDeliveries: int,
    firstPresent: bool, secondPresent: bool, aggregate: Decision,
    emittedRounds: int, staleAccepted: bool, roundAudienceAll: bool, outcome: Outcome, lastDelivery: Delivery,
  }
  var st: State

  action init = {
    st' = { selected: First, effectTarget: First, staticTarget: First, sseTarget: First,
      lastOwner: First, replyTarget: First, lastRoute: HtmlRoute, lastContext: ValidFirst,
      lastScope: FileThread, phase: Collecting, generation: G1, rawDeliveries: 0,
      firstPresent: false, secondPresent: false, aggregate: NoDecision,
      emittedRounds: 0, staleAccepted: false, roundAudienceAll: false, outcome: Accepted,
      lastDelivery: { actor: Browser, route: HtmlRoute, context: ValidFirst, file: First,
        generation: G1, payload: P1, decision: Approve } }
  }

  // HTML query selection and raw-URL API dispatch are separate boundaries.
  // `/?f=1` renders Second; only a later bare API is accepted by First.
  action submitDeliver = {
    nondet actor = Set(Browser, Cli).oneOf()
    nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    nondet file = Set(First, Second).oneOf()
    nondet generation = Set(G1, G2, G3).oneOf()
    nondet payload = Set(P1, P2).oneOf()
    nondet decision = Set(RequestChanges, Approve).oneOf()
    nondet delivery = Set({ actor: actor, route: SubmitRoute, context: context, file: file,
      generation: generation, payload: payload, decision: decision }).oneOf()
    if (context == Missing) {
      st' = { ...st, effectTarget: First, lastRoute: SubmitRoute, lastContext: context, outcome: Accepted,
        lastDelivery: delivery, rawDeliveries: st.rawDeliveries + 1, firstPresent: true,
        aggregate: decision, staleAccepted: st.generation == G2 and generation == G1,
        phase: if (st.rawDeliveries + 1 >= 2) Exited else Collecting }
    } else { st' = { ...st, lastRoute: SubmitRoute, lastContext: context, lastDelivery: delivery, outcome: NotFound404 } }
  }
  // `parse_query_param` supplies one f value. Missing and Invalid (bad/oob/
  // negative/decimal; duplicate is an explicit non-400 RED category) fall
  // back to the listener First; only ValidSecond selects Second.
  action selectHtml = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    st' = { ...st, selected: if (context == ValidSecond) Second else First, lastRoute: HtmlRoute, lastContext: context, outcome: Accepted } }
  action stateRequest = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    if (context == Missing) { st' = { ...st, effectTarget: First, lastRoute: StateRoute, lastContext: context, outcome: Accepted } }
    else { st' = { ...st, lastRoute: StateRoute, lastContext: context, outcome: NotFound404 } } }
  action sseRequest = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    if (context == Missing) { st' = { ...st, sseTarget: First, lastRoute: SseRoute, lastContext: context, outcome: Accepted } }
    else { st' = { ...st, lastRoute: SseRoute, lastContext: context, outcome: NotFound404 } } }
  action staticRequest = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    if (context == Missing) { st' = { ...st, staticTarget: First, lastRoute: StaticRoute, lastContext: context, outcome: Accepted } }
    else { st' = { ...st, lastRoute: StaticRoute, lastContext: context, outcome: NotFound404 } } }
  action fileReply = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    if (context == Missing) { st' = { ...st, lastRoute: ReplyRoute, lastContext: context, lastScope: FileThread,
      lastOwner: First, replyTarget: First, roundAudienceAll: false, outcome: Accepted } }
    else { st' = { ...st, lastRoute: ReplyRoute, lastContext: context, outcome: NotFound404 } } }
  action roundReply = { nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    if (context == Missing) { st' = { ...st, lastRoute: ReplyRoute, lastContext: context, lastScope: RoundThread,
      lastOwner: First, replyTarget: First, roundAudienceAll: false, outcome: Accepted } }
    else { st' = { ...st, lastRoute: ReplyRoute, lastContext: context, outcome: NotFound404 } } }
  action globalBare = { nondet route = Set(UiJsRoute, HealthzRoute).oneOf()
    st' = { ...st, lastRoute: route, lastContext: Global, outcome: Accepted } }
  action globalWithF = { nondet route = Set(UiJsRoute, HealthzRoute).oneOf(); nondet context = Set(ValidFirst, ValidSecond, Invalid).oneOf()
    st' = { ...st, lastRoute: route, lastContext: context, outcome: NotFound404 } }
  action step = any { selectHtml, submitDeliver, stateRequest, sseRequest, staticRequest, fileReply, roundReply, globalBare, globalWithF }

  val noEarlyExit = not(st.phase == Exited) or (st.firstPresent and st.secondPresent)
  val contextBoundMissingAccepted = st.lastContext == Missing and st.outcome == Accepted
  val queryApiHasNoEffect = (st.lastContext == ValidFirst or st.lastContext == ValidSecond or st.lastContext == Invalid) and st.outcome == NotFound404
  val fileReplyMatchesOwner = st.lastScope != FileThread or st.replyTarget == st.lastOwner
  val roundReplyBroadcasts = st.lastScope != RoundThread or st.roundAudienceAll
  val oldGenerationRejected = not(st.staleAccepted)
}
*/

module review_mux_current {
  type Actor = Browser | Cli
  type Route = HtmlRoute | StateRoute | SubmitRoute | SseRoute | StaticRoute | CommentRoute | ReplyRoute | ResolveRoute | CliRoute | UiJsRoute | HealthzRoute
  type File = First | Second
  type Context = Missing | ValidFirst | ValidSecond | Invalid | Global
  // Generation is unbounded product state; 1..4 is only an exploration input bound.
  type Payload = P1 | P2
  type Decision = NoDecision | RequestChanges | Approve
  type Outcome = Accepted | NotFound404 | Rejected400 | Rejected409
  type Scope = FileThread | RoundThread
  type Phase = Collecting | RoundComplete | WaitingGo | Exited
  type Boundary = InitBoundary | DeliverBoundary | ResolveRoundBoundary | GoBoundary
  type MuxMode = Mux | Single
  type RoundThreadState = NoThread | Open | Resolved
  type RoundThreadScenario = ScenarioStart | ScenarioCreated | ScenarioReplied |
    ScenarioResolveAttempted | ScenarioReplyAfterResolve | ScenarioCreateAfterResolve
  type GateState = GateClear | AnchoredUnresolved | UnanchoredOnly
  type Input = { actor: Actor, route: Route, context: Context, file: File, owner: File,
    generation: int, payload: Payload, decision: Decision, scope: Scope, gate: GateState, mode: MuxMode }
  type State = {
    selected: File, effectTarget: File, staticTarget: File, sseTarget: File,
    replyTarget: File, lastOwner: File, audienceAll: bool,
    phase: Phase, generation: int, rawDeliveries: int,
    firstPresent: bool, secondPresent: bool, aggregate: Decision,
    firstGate: GateState, secondGate: GateState,
    firstRetainedUnanchored: bool, secondRetainedUnanchored: bool,
    filePersisted: bool, persistedFileOwner: File,
    roundPersisted: bool, resolvePersisted: bool,
    roundThread: RoundThreadState, roundReplies: int, retainedResolvedRound: bool,
    roundThreadScenario: RoundThreadScenario,
    emittedRounds: int, staleAccepted: bool, outcome: Outcome,
    lastBoundary: Boundary, lastInput: Input,
  }
  var st: State
  pure def currentApproveGate(gate) = if (gate == GateClear) Accepted else Rejected409
  val currentUnanchoredGateBug = currentApproveGate(UnanchoredOnly) == Rejected409

  val initialInput = { actor: Browser, route: HtmlRoute, context: Missing,
    file: First, owner: First, generation: 1, payload: P1,
    decision: Approve, scope: FileThread, gate: GateClear, mode: Single }

  action init = {
    st' = { selected: First, effectTarget: First, staticTarget: First,
      sseTarget: First, replyTarget: First, lastOwner: First,
      audienceAll: false, phase: Collecting, generation: 1,
      rawDeliveries: 0, firstPresent: false, secondPresent: false,
      firstGate: GateClear, secondGate: GateClear,
      firstRetainedUnanchored: false, secondRetainedUnanchored: false,
      filePersisted: false, persistedFileOwner: First,
      roundPersisted: false, resolvePersisted: false,
      roundThread: NoThread, roundReplies: 0, retainedResolvedRound: false,
      roundThreadScenario: ScenarioStart,
      aggregate: NoDecision, emittedRounds: 0, staleAccepted: false,
      outcome: Accepted, lastBoundary: InitBoundary, lastInput: initialInput }
  }

  // One typed transport boundary receives every browser and CLI input. HTML
  // selection is separate from the later bare API request produced by the UI.
  action deliver(input) = {
    if (input.route == UiJsRoute or input.route == HealthzRoute) {
      st' = { ...st, outcome: if (input.context == Global) Accepted else NotFound404,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == HtmlRoute) {
      st' = { ...st,
        selected: if (input.context == ValidSecond) Second else First,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.mode == Mux and input.context != Missing) {
      st' = { ...st, outcome: NotFound404,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == SubmitRoute and input.decision == Approve and st.firstGate != GateClear) {
      st' = { ...st, outcome: Rejected409,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == SubmitRoute) {
      st' = { ...st, effectTarget: First, firstPresent: true,
        rawDeliveries: if (input.decision == RequestChanges) 0 else st.rawDeliveries + 1,
        aggregate: input.decision,
        phase: if (input.decision == RequestChanges) WaitingGo
          else if (st.rawDeliveries + 1 >= 2) Exited else Collecting,
        emittedRounds: if (input.decision == RequestChanges) st.emittedRounds + 1 else st.emittedRounds,
        staleAccepted: st.staleAccepted or input.generation != st.generation,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == StaticRoute) {
      st' = { ...st, staticTarget: First, outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == SseRoute) {
      st' = { ...st, sseTarget: First, outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.context == Missing and input.scope == RoundThread and input.route == CommentRoute) {
      if (st.roundThread == NoThread) {
        st' = { ...st, lastOwner: First,
          replyTarget: First, audienceAll: false, roundPersisted: true,
          roundThread: Open, outcome: Accepted,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioStart) ScenarioCreated else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input }
      } else {
        st' = { ...st, outcome: Rejected409,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioReplyAfterResolve) ScenarioCreateAfterResolve else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input }
      }
    } else if (input.context == Missing and input.scope == RoundThread and input.route == ReplyRoute) {
      if (st.roundThread == Open) {
        st' = { ...st, lastOwner: First,
          replyTarget: First, audienceAll: false, roundPersisted: true,
          roundReplies: st.roundReplies + 1, outcome: Accepted,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioCreated) ScenarioReplied
            else if (st.roundThreadScenario == ScenarioResolveAttempted) ScenarioReplyAfterResolve
            else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input }
      } else {
        st' = { ...st, outcome: Rejected409,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioResolveAttempted) ScenarioReplyAfterResolve else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input }
      }
    } else if (input.context == Missing and input.scope == RoundThread and input.route == ResolveRoute) {
      // Baseline js_review_resolve returns HTTP 200 but ignores round scope.
      st' = { ...st, lastOwner: First,
        replyTarget: First, audienceAll: false, outcome: Accepted,
        roundThreadScenario: if (st.roundThreadScenario == ScenarioReplied) ScenarioResolveAttempted else st.roundThreadScenario,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == CommentRoute) {
      st' = { ...st, replyTarget: First, lastOwner: First, audienceAll: false,
        firstGate: input.gate,
        firstRetainedUnanchored: st.firstRetainedUnanchored or input.gate == UnanchoredOnly,
        filePersisted: true, persistedFileOwner: First,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input }
    } else if (input.route == ReplyRoute or input.route == ResolveRoute) {
      st' = { ...st, replyTarget: First, lastOwner: First,
        audienceAll: false, filePersisted: true, persistedFileOwner: First,
        firstGate: if (input.route == ResolveRoute) GateClear else st.firstGate,
        resolvePersisted: st.resolvePersisted or input.route == ResolveRoute,
        outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input }
    } else {
      st' = { ...st, effectTarget: First, outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input }
    }
  }

  action resolveRound = {
    st' = { ...st, lastBoundary: ResolveRoundBoundary, outcome: Accepted }
  }

  // Current go accepts the partial request-changes state and has no request
  // generation guard. A delayed old tab can therefore submit into the next round.
  action go = {
    all { st.phase == WaitingGo,
      st' = { ...st,
        generation: st.generation + 1,
        phase: Collecting, rawDeliveries: 0,
        firstPresent: false, secondPresent: false, aggregate: NoDecision,
        outcome: Accepted, lastBoundary: GoBoundary } }
  }

  // The same generic input sampler exists in the repaired module so one seed
  // replays the identical delivery sequence across both semantics.
  action deliverInputStep = {
    nondet actor = Set(Browser, Cli).oneOf()
    nondet route = Set(HtmlRoute, StateRoute, SubmitRoute, SseRoute, StaticRoute,
      CommentRoute, ReplyRoute, ResolveRoute, CliRoute, UiJsRoute, HealthzRoute).oneOf()
    nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid, Global).oneOf()
    nondet file = Set(First, Second).oneOf()
    nondet owner = Set(First, Second).oneOf()
    nondet generation = Set(1, 2, 3, 4).oneOf()
    nondet payload = Set(P1, P2).oneOf()
    nondet decision = Set(RequestChanges, Approve).oneOf()
    nondet scope = Set(FileThread, RoundThread).oneOf()
    nondet gate = Set(GateClear, AnchoredUnresolved, UnanchoredOnly).oneOf()
    nondet mode = Set(Mux, Single).oneOf()
    nondet input = Set({ actor: actor, route: route, context: context, file: file,
      owner: owner, generation: generation, payload: payload,
      decision: decision, scope: scope, gate: gate, mode: mode }).oneOf()
    deliver(input)
  }

  val roundCreateInput = { ...initialInput, route: CommentRoute, scope: RoundThread }
  val roundReplyInput = { ...initialInput, route: ReplyRoute, scope: RoundThread }
  val roundResolveInput = { ...initialInput, route: ResolveRoute, scope: RoundThread }
  action roundThreadScenarioStep = {
    if (st.roundThreadScenario == ScenarioStart) { deliver(roundCreateInput) }
    else if (st.roundThreadScenario == ScenarioCreated) { deliver(roundReplyInput) }
    else if (st.roundThreadScenario == ScenarioReplied) { deliver(roundResolveInput) }
    else if (st.roundThreadScenario == ScenarioResolveAttempted) { deliver(roundReplyInput) }
    else if (st.roundThreadScenario == ScenarioReplyAfterResolve) { deliver(roundCreateInput) }
    else { st' = st }
  }

  action step = any { deliverInputStep, roundThreadScenarioStep, resolveRound, go }

  val displayEffectMismatch = st.selected == Second and
    st.lastBoundary == DeliverBoundary and st.lastInput.context == Missing and
    (st.lastInput.route == StateRoute or st.lastInput.route == SubmitRoute or
      st.lastInput.route == CliRoute) and st.outcome == Accepted and
    st.effectTarget == First
  val duplicateEarlyExit = st.phase == Exited and st.rawDeliveries >= 2 and
    st.firstPresent and not(st.secondPresent)
  val currentUnanchoredCommentIsRetained = st.lastBoundary != DeliverBoundary or
    st.lastInput.route != CommentRoute or st.lastInput.gate != UnanchoredOnly or
    st.firstRetainedUnanchored
  val currentRetainedUnanchoredRejectsApprove = st.lastBoundary == DeliverBoundary and
    st.lastInput.route == SubmitRoute and st.lastInput.decision == Approve and
    st.firstRetainedUnanchored and st.outcome == Rejected409
  val queryRouteIsNotStrict400 = st.lastBoundary == DeliverBoundary and
    st.lastInput.context != Missing and st.lastInput.context != Global and
    st.lastInput.route != HtmlRoute and st.outcome == NotFound404
  val bareMuxStaticAccepted = st.lastBoundary == DeliverBoundary and
    st.lastInput.route == StaticRoute and st.lastInput.context == Missing and
    st.outcome == Accepted and st.staticTarget == First
  val roundReplyNotBroadcast = st.lastBoundary == DeliverBoundary and
    st.lastInput.route == ReplyRoute and st.lastInput.scope == RoundThread and
    st.outcome == Accepted and not(st.audienceAll)
  val oldGenerationAccepted = st.staleAccepted
  val currentRoundResolveSafety = st.roundThreadScenario != ScenarioResolveAttempted or
    st.roundThread == Resolved
  val currentRoundResolveBug = st.roundThreadScenario == ScenarioResolveAttempted and
    st.roundThread == Open and st.outcome == Accepted
  val noEarlyExit = not(st.phase == Exited) or
    (st.firstPresent and st.secondPresent and st.aggregate == Approve)
}
