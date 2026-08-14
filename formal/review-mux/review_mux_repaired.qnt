/* Historical pre-freeze transcription retained only as review provenance.
   It is not executable and is not an evidence source.
module review_mux_repaired {
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
  type Delivery = { actor: Actor, route: Route, context: Context, file: File, generation: Generation, payload: Payload, decision: Decision }
  type State = {
    selected: File, effectTarget: File, staticTarget: File, sseTarget: File, lastOwner: File, replyTarget: File,
    lastRoute: Route, lastContext: Context, lastScope: Scope, roundAudienceAll: bool,
    phase: Phase, generation: Generation, rawDeliveries: int,
    firstPresent: bool, secondPresent: bool, firstPayload: Payload, secondPayload: Payload,
    firstDecision: Decision, secondDecision: Decision, aggregate: Decision,
    emittedRounds: int, staleAccepted: bool, staleRejected: bool, outcome: Outcome, lastDelivery: Delivery,
  }
  var st: State

  pure def validOwned(input) =
    (input.context == ValidFirst and input.file == First) or
    (input.context == ValidSecond and input.file == Second)

  action init = {
    st' = { selected: First, effectTarget: First, staticTarget: First, sseTarget: First, lastOwner: First, replyTarget: First,
      lastRoute: HtmlRoute, lastContext: ValidFirst, lastScope: FileThread, roundAudienceAll: true,
      phase: Collecting, generation: G1, rawDeliveries: 0, firstPresent: false, secondPresent: false,
      firstPayload: P1, secondPayload: P1, firstDecision: NoDecision, secondDecision: NoDecision,
      aggregate: NoDecision, emittedRounds: 0, staleAccepted: false, staleRejected: false, outcome: Accepted,
      lastDelivery: { actor: Browser, route: HtmlRoute, context: ValidFirst, file: First, generation: G1, payload: P1, decision: Approve } }
  }

  // Only this SubmitRoute boundary can change the result ledger.  Invalid and
  // missing f, route/file mismatch, stale generation, and terminal phases are
  // rejected with no state mutation.
  action rejectSubmit = {
    nondet actor = Set(Browser, Cli).oneOf()
    nondet route = Set(StateRoute, SubmitRoute, SseRoute, StaticRoute, ReplyRoute, CliRoute).oneOf()
    nondet context = Set(Missing, ValidFirst, ValidSecond, Invalid).oneOf()
    nondet file = Set(First, Second).oneOf()
    nondet generation = Set(G1, G2, G3).oneOf()
    nondet payload = Set(P1, P2).oneOf()
    nondet decision = Set(RequestChanges, Approve).oneOf()
    nondet delivery = Set({ actor: actor, route: route, context: context, file: file, generation: generation, payload: payload, decision: decision }).oneOf()
    all { route != SubmitRoute or st.phase != Collecting or generation != st.generation or context == Missing or context == Invalid or
      (context == ValidFirst and file != First) or (context == ValidSecond and file != Second), st' = st }
  }
  action retrySubmit = {
    nondet actor = Set(Browser, Cli).oneOf(); nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    nondet payload = Set(P1, P2).oneOf(); nondet decision = Set(RequestChanges, Approve).oneOf()
    nondet delivery = Set({ actor: actor, route: SubmitRoute, context: context, file: file, generation: st.generation, payload: payload, decision: decision }).oneOf()
    all { st.phase == Collecting,
      (context == ValidFirst and file == First and st.firstPresent and st.firstPayload == payload and st.firstDecision == decision) or
      (context == ValidSecond and file == Second and st.secondPresent and st.secondPayload == payload and st.secondDecision == decision), st' = st }
  }
  action acceptSubmit = {
    nondet actor = Set(Browser, Cli).oneOf(); nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    nondet payload = Set(P1, P2).oneOf(); nondet decision = Set(RequestChanges, Approve).oneOf()
    nondet delivery = Set({ actor: actor, route: SubmitRoute, context: context, file: file, generation: st.generation, payload: payload, decision: decision }).oneOf()
    all { st.phase == Collecting, (context == ValidFirst and file == First) or (context == ValidSecond and file == Second),
      not((file == First and st.firstPresent and st.firstPayload == payload and st.firstDecision == decision) or (file == Second and st.secondPresent and st.secondPayload == payload and st.secondDecision == decision)),
      st' = { ...st, selected: file, effectTarget: file, lastRoute: SubmitRoute, lastContext: context, lastDelivery: delivery, rawDeliveries: st.rawDeliveries + 1,
        firstPresent: st.firstPresent or file == First, secondPresent: st.secondPresent or file == Second,
        firstPayload: if (file == First) payload else st.firstPayload, secondPayload: if (file == Second) payload else st.secondPayload,
        firstDecision: if (file == First) decision else st.firstDecision, secondDecision: if (file == Second) decision else st.secondDecision,
        aggregate: if ((st.firstPresent or file == First) and (st.secondPresent or file == Second)) (if ((if (file == First) decision else st.firstDecision) == RequestChanges or (if (file == Second) decision else st.secondDecision) == RequestChanges) RequestChanges else Approve) else NoDecision,
        phase: if ((st.firstPresent or file == First) and (st.secondPresent or file == Second)) RoundComplete else Collecting,
        emittedRounds: if ((st.firstPresent or file == First) and (st.secondPresent or file == Second)) st.emittedRounds + 1 else st.emittedRounds } }
  }
  action resolve = all { st.phase == RoundComplete,
    st' = { ...st, phase: if (st.aggregate == RequestChanges) WaitingGo else Exited } }
  action goOne = all { st.phase == WaitingGo, st.generation == G1,
    st' = { ...st, generation: G2, phase: Collecting,
      firstPresent: false, secondPresent: false, firstPayload: P1, secondPayload: P1,
      firstDecision: NoDecision, secondDecision: NoDecision, aggregate: NoDecision } }
  action goTwo = all { st.phase == WaitingGo, st.generation == G2,
    st' = { ...st, generation: G3, phase: Collecting, firstPresent: false, secondPresent: false, firstPayload: P1, secondPayload: P1,
      firstDecision: NoDecision, secondDecision: NoDecision, aggregate: NoDecision } }
  action stateRequest = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    all { (context == ValidFirst and file == First) or (context == ValidSecond and file == Second), st' = { ...st, selected: file, effectTarget: file, lastRoute: StateRoute, lastContext: context } } }
  action sseRequest = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    all { (context == ValidFirst and file == First) or (context == ValidSecond and file == Second), st' = { ...st, selected: file, sseTarget: file, lastRoute: SseRoute, lastContext: context } } }
  action staticRequest = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    all { (context == ValidFirst and file == First) or (context == ValidSecond and file == Second), st' = { ...st, selected: file, staticTarget: file, lastRoute: StaticRoute, lastContext: context } } }
  action cliRequest = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet file = Set(First, Second).oneOf()
    all { (context == ValidFirst and file == First) or (context == ValidSecond and file == Second), st' = { ...st, selected: file, effectTarget: file, lastRoute: CliRoute, lastContext: context } } }
  action fileReply = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet owner = Set(First, Second).oneOf()
    all { (context == ValidFirst and owner == First) or (context == ValidSecond and owner == Second), st' = { ...st, selected: owner, lastOwner: owner, replyTarget: owner, lastRoute: ReplyRoute, lastContext: context, lastScope: FileThread, roundAudienceAll: true } } }
  action roundReply = { nondet context = Set(ValidFirst, ValidSecond).oneOf(); nondet owner = Set(First, Second).oneOf()
    all { (context == ValidFirst and owner == First) or (context == ValidSecond and owner == Second), st' = { ...st, selected: owner, lastOwner: owner, replyTarget: owner, lastRoute: ReplyRoute, lastContext: context, lastScope: RoundThread, roundAudienceAll: true } } }
  action rejectContext = { nondet route = Set(StateRoute, SseRoute, StaticRoute, ReplyRoute, CliRoute).oneOf(); nondet context = Set(Missing, Invalid).oneOf(); st' = st }
  action globalBare = { nondet route = Set(UiJsRoute, HealthzRoute).oneOf(); st' = { ...st, lastRoute: route, lastContext: Missing } }
  action rejectGlobalWithF = { nondet route = Set(UiJsRoute, HealthzRoute).oneOf(); nondet context = Set(ValidFirst, ValidSecond, Invalid).oneOf(); st' = st }
  action step = any { rejectSubmit, retrySubmit, acceptSubmit, resolve, goOne, goTwo, stateRequest, sseRequest, staticRequest, cliRequest, fileReply, roundReply, rejectContext, globalBare, rejectGlobalWithF }

  val effectMatchesSelected = st.effectTarget == st.selected
  val staticMatchesSelected = st.staticTarget == st.selected
  val sseMatchesSelected = st.sseTarget == st.selected
  val fileReplyMatchesOwner = st.lastScope != FileThread or st.replyTarget == st.lastOwner
  val roundReplyBroadcasts = st.lastScope != RoundThread or st.roundAudienceAll
  val noEarlyExit = not(st.phase == Exited) or (st.firstPresent and st.secondPresent and st.aggregate == Approve)
  val latestOnePerFile = (not(st.firstPresent) or st.firstPayload == P1 or st.firstPayload == P2) and (not(st.secondPresent) or st.secondPayload == P1 or st.secondPayload == P2)
  val requestChangesWaits = not(st.phase == WaitingGo) or st.aggregate == RequestChanges
  val oldGenerationRejected = not(st.staleAccepted)
  val aggregateMatchesEntries = not(st.phase == RoundComplete) or ((st.firstDecision == RequestChanges or st.secondDecision == RequestChanges) and st.aggregate == RequestChanges) or (st.firstDecision == Approve and st.secondDecision == Approve and st.aggregate == Approve)
  val safety = all { effectMatchesSelected, staticMatchesSelected, sseMatchesSelected, fileReplyMatchesOwner, roundReplyBroadcasts, noEarlyExit, latestOnePerFile, requestChangesWaits, oldGenerationRejected, aggregateMatchesEntries }
  val collectingWitness = st.phase == Collecting
  val roundCompleteWitness = st.phase == RoundComplete
  val waitingGoWitness = st.phase == WaitingGo
  val exitedWitness = st.phase == Exited and st.aggregate == Approve
}
*/

module review_mux_repaired {
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
  type HttpMethod = GetMethod | HeadMethod
  type StaticPath = AssetPath | NestedCssAsset | TraversalAsset | BareAsset
  type RangeHeader = NoRange | ByteRange
  type StaticOutcome = Static200 | Static206 | Static403 | Static400
  type GateState = GateClear | AnchoredUnresolved | UnanchoredOnly
  type Input = { actor: Actor, route: Route, context: Context, file: File, owner: File,
    generation: int, payload: Payload, decision: Decision, scope: Scope, gate: GateState, mode: MuxMode }
  type Effects = {
    selected: File, effectTarget: File, staticTarget: File, sseTarget: File,
    replyTarget: File, lastOwner: File, audienceAll: bool,
    phase: Phase, rawEffects: int,
    firstPresent: bool, secondPresent: bool,
    firstPayload: Payload, secondPayload: Payload,
    firstDecision: Decision, secondDecision: Decision, aggregate: Decision,
    firstGate: GateState, secondGate: GateState,
    firstRetainedUnanchored: bool, secondRetainedUnanchored: bool,
    filePersisted: bool, persistedFileOwner: File,
    roundPersisted: bool, resolvePersisted: bool,
    roundThread: RoundThreadState, roundReplies: int, retainedResolvedRound: bool,
    emittedRounds: int, emittedG1: bool, emittedG2: bool, emittedG3: bool, emittedG4: bool,
  }
  type State = {
    selected: File, effectTarget: File, staticTarget: File, sseTarget: File,
    replyTarget: File, lastOwner: File, audienceAll: bool,
    phase: Phase, generation: int, rawEffects: int,
    firstPresent: bool, secondPresent: bool,
    firstPayload: Payload, secondPayload: Payload,
    firstDecision: Decision, secondDecision: Decision, aggregate: Decision,
    firstGate: GateState, secondGate: GateState,
    firstRetainedUnanchored: bool, secondRetainedUnanchored: bool,
    filePersisted: bool, persistedFileOwner: File,
    roundPersisted: bool, resolvePersisted: bool,
    roundThread: RoundThreadState, roundReplies: int, retainedResolvedRound: bool,
    roundThreadScenario: RoundThreadScenario,
    emittedRounds: int, emittedG1: bool, emittedG2: bool, emittedG3: bool, emittedG4: bool,
    outcome: Outcome, lastBoundary: Boundary, lastInput: Input, before: Effects,
  }
  var st: State

  pure def validOwned(input) =
    (input.mode == Single and input.context == Missing and input.file == First) or
    (input.mode == Mux and ((input.context == ValidFirst and input.file == First) or
      (input.context == ValidSecond and input.file == Second)))

  pure def staticOutcome(mux, context, method, path, rangeHeader) =
    if (not(mux)) Static200
    else if (context == Missing or context == Invalid or context == Global or path == BareAsset) Static400
    else if (path == TraversalAsset) Static403
    else if (rangeHeader == ByteRange) Static206
    else Static200

  val staticMethodPathContract = all {
    staticOutcome(false, Missing, GetMethod, BareAsset, NoRange) == Static200,
    staticOutcome(false, Missing, HeadMethod, AssetPath, NoRange) == Static200,
    staticOutcome(true, ValidSecond, GetMethod, AssetPath, NoRange) == Static200,
    staticOutcome(true, ValidSecond, GetMethod, AssetPath, ByteRange) == Static206,
    staticOutcome(true, ValidSecond, HeadMethod, NestedCssAsset, NoRange) == Static200,
    staticOutcome(true, ValidSecond, GetMethod, TraversalAsset, NoRange) == Static403,
    staticOutcome(true, Missing, GetMethod, AssetPath, NoRange) == Static400,
    staticOutcome(true, ValidSecond, GetMethod, BareAsset, NoRange) == Static400,
  }
  pure def approveGate(gate) = if (gate == AnchoredUnresolved) Rejected409 else Accepted
  pure def gateEffect(gate) = { outcome: approveGate(gate), retainedUnanchored: gate == UnanchoredOnly }
  val unanchoredRetainedButNotGating = gateEffect(UnanchoredOnly).outcome == Accepted and
    gateEffect(UnanchoredOnly).retainedUnanchored and
    approveGate(AnchoredUnresolved) == Rejected409
  pure def summaryOrder(_firstArrival, _secondArrival) = [First, Second]
  val summaryAlwaysUsesMuxOrder =
    summaryOrder(First, Second) == [First, Second] and
    summaryOrder(Second, First) == [First, Second]
  pure def threadEffect(owner, scope) = {
    persisted: true, owner: owner, audienceAll: scope == RoundThread,
  }
  val threadEffectsPersist = all {
    threadEffect(Second, FileThread).persisted and not(threadEffect(Second, FileThread).audienceAll),
    threadEffect(First, RoundThread).persisted and threadEffect(First, RoundThread).audienceAll,
  }

  val initialInput = { actor: Browser, route: HtmlRoute, context: Missing,
    file: First, owner: First, generation: 1, payload: P1,
    decision: Approve, scope: FileThread, gate: GateClear, mode: Single }

  pure def effects(state) = {
    selected: state.selected, effectTarget: state.effectTarget,
    staticTarget: state.staticTarget, sseTarget: state.sseTarget,
    replyTarget: state.replyTarget, lastOwner: state.lastOwner,
    audienceAll: state.audienceAll, phase: state.phase,
    rawEffects: state.rawEffects,
    firstPresent: state.firstPresent, secondPresent: state.secondPresent,
    firstPayload: state.firstPayload, secondPayload: state.secondPayload,
    firstDecision: state.firstDecision, secondDecision: state.secondDecision,
    firstGate: state.firstGate, secondGate: state.secondGate,
    firstRetainedUnanchored: state.firstRetainedUnanchored,
    secondRetainedUnanchored: state.secondRetainedUnanchored,
    filePersisted: state.filePersisted, persistedFileOwner: state.persistedFileOwner,
    roundPersisted: state.roundPersisted, resolvePersisted: state.resolvePersisted,
    roundThread: state.roundThread, roundReplies: state.roundReplies,
    retainedResolvedRound: state.retainedResolvedRound,
    aggregate: state.aggregate, emittedRounds: state.emittedRounds,
    emittedG1: state.emittedG1, emittedG2: state.emittedG2,
    emittedG3: state.emittedG3, emittedG4: state.emittedG4,
  }

  action init = {
    st' = { selected: First, effectTarget: First, staticTarget: First,
      sseTarget: First, replyTarget: First, lastOwner: First,
      audienceAll: false, phase: Collecting, generation: 1,
      rawEffects: 0, firstPresent: false, secondPresent: false,
      firstPayload: P1, secondPayload: P1,
      firstDecision: NoDecision, secondDecision: NoDecision,
      firstGate: GateClear, secondGate: GateClear,
      firstRetainedUnanchored: false, secondRetainedUnanchored: false,
      filePersisted: false, persistedFileOwner: First,
      roundPersisted: false, resolvePersisted: false,
      roundThread: NoThread, roundReplies: 0, retainedResolvedRound: false,
      roundThreadScenario: ScenarioStart,
      aggregate: NoDecision, emittedRounds: 0,
      emittedG1: false, emittedG2: false, emittedG3: false, emittedG4: false,
      outcome: Accepted, lastBoundary: InitBoundary, lastInput: initialInput,
      before: { selected: First, effectTarget: First, staticTarget: First,
        sseTarget: First, replyTarget: First, lastOwner: First,
        audienceAll: false, phase: Collecting, rawEffects: 0,
        firstPresent: false, secondPresent: false,
        firstPayload: P1, secondPayload: P1,
        firstDecision: NoDecision, secondDecision: NoDecision,
        firstGate: GateClear, secondGate: GateClear,
        firstRetainedUnanchored: false, secondRetainedUnanchored: false,
        filePersisted: false, persistedFileOwner: First,
        roundPersisted: false, resolvePersisted: false,
        roundThread: NoThread, roundReplies: 0, retainedResolvedRound: false,
        aggregate: NoDecision, emittedRounds: 0,
        emittedG1: false, emittedG2: false, emittedG3: false, emittedG4: false } }
  }

  // This is the only request delivery boundary. Rejection records the HTTP
  // outcome but leaves ledger, effects, phase, emission, and audiences intact.
  action deliver(input) = {
    if (input.route == UiJsRoute or input.route == HealthzRoute) {
      st' = { ...st,
        outcome: if (input.context == Global) Accepted else Rejected400,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if ((input.mode == Mux and (input.context == Missing or input.context == Invalid or
      input.context == Global or
      (input.context == ValidFirst and input.file != First) or
      (input.context == ValidSecond and input.file != Second))) or
      (input.mode == Single and (input.context != Missing or input.file != First))) {
      st' = { ...st, outcome: Rejected400,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if (input.route == HtmlRoute) {
      st' = { ...st, selected: input.file, outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if ((input.route == CommentRoute or input.route == ReplyRoute or input.route == ResolveRoute) and
      input.scope == FileThread and input.owner != input.file) {
      st' = { ...st, outcome: Rejected400,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if (input.route == SubmitRoute and
      (st.phase != Collecting or input.generation != st.generation)) {
      st' = { ...st, outcome: Rejected409,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if (input.route == SubmitRoute and input.decision == Approve and
      ((input.file == First and st.firstGate == AnchoredUnresolved) or
       (input.file == Second and st.secondGate == AnchoredUnresolved))) {
      st' = { ...st, outcome: Rejected409,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if (input.route == SubmitRoute and
      ((input.file == First and st.firstPresent and
          st.firstPayload == input.payload and st.firstDecision == input.decision) or
       (input.file == Second and st.secondPresent and
          st.secondPayload == input.payload and st.secondDecision == input.decision))) {
      st' = { ...st, outcome: Accepted,
        lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
    } else if (input.route == SubmitRoute) {
      st' = { ...st, selected: input.file, effectTarget: input.file,
        rawEffects: st.rawEffects + 1,
        firstPresent: st.firstPresent or input.file == First,
        secondPresent: st.secondPresent or input.file == Second,
        firstPayload: if (input.file == First) input.payload else st.firstPayload,
        secondPayload: if (input.file == Second) input.payload else st.secondPayload,
        firstDecision: if (input.file == First) input.decision else st.firstDecision,
        secondDecision: if (input.file == Second) input.decision else st.secondDecision,
        aggregate: if ((st.firstPresent or input.file == First) and
            (st.secondPresent or input.file == Second))
          (if ((if (input.file == First) input.decision else st.firstDecision) == RequestChanges or
               (if (input.file == Second) input.decision else st.secondDecision) == RequestChanges)
            RequestChanges else Approve)
          else NoDecision,
        phase: if ((st.firstPresent or input.file == First) and
            (st.secondPresent or input.file == Second)) RoundComplete else Collecting,
        emittedRounds: if ((st.firstPresent or input.file == First) and
            (st.secondPresent or input.file == Second)) st.emittedRounds + 1 else st.emittedRounds,
        emittedG1: st.emittedG1 or (((st.firstPresent or input.file == First) and
          (st.secondPresent or input.file == Second)) and st.generation == 1),
        emittedG2: st.emittedG2 or (((st.firstPresent or input.file == First) and
          (st.secondPresent or input.file == Second)) and st.generation == 2),
        emittedG3: st.emittedG3 or (((st.firstPresent or input.file == First) and
          (st.secondPresent or input.file == Second)) and st.generation == 3),
        emittedG4: st.emittedG4 or (((st.firstPresent or input.file == First) and
          (st.secondPresent or input.file == Second)) and st.generation == 4),
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input,
        before: effects(st) }
    } else if (input.route == StaticRoute) {
      st' = { ...st, selected: input.file, staticTarget: input.file,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input,
        before: effects(st) }
    } else if (input.route == SseRoute) {
      st' = { ...st, selected: input.file, sseTarget: input.file,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input,
        before: effects(st) }
    } else if (input.scope == RoundThread and input.route == CommentRoute) {
      if (st.roundThread == NoThread or st.roundThread == Resolved) {
        st' = { ...st, selected: input.file, lastOwner: input.owner,
          replyTarget: input.owner, audienceAll: input.mode == Mux, roundPersisted: true,
          roundThread: Open,
          retainedResolvedRound: st.retainedResolvedRound or st.roundThread == Resolved,
          outcome: Accepted,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioStart) ScenarioCreated
            else if (st.roundThreadScenario == ScenarioReplyAfterResolve) ScenarioCreateAfterResolve
            else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      } else {
        st' = { ...st, outcome: Rejected409,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      }
    } else if (input.scope == RoundThread and input.route == ReplyRoute) {
      if (st.roundThread == Open) {
        st' = { ...st, selected: input.file, lastOwner: input.owner,
          replyTarget: input.owner, audienceAll: input.mode == Mux, roundPersisted: true,
          roundReplies: st.roundReplies + 1, outcome: Accepted,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioCreated) ScenarioReplied else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      } else {
        st' = { ...st, outcome: Rejected409,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioResolveAttempted) ScenarioReplyAfterResolve else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      }
    } else if (input.scope == RoundThread and input.route == ResolveRoute) {
      if (st.roundThread == Open) {
        st' = { ...st, selected: input.file, lastOwner: input.owner,
          replyTarget: input.owner, audienceAll: input.mode == Mux, roundPersisted: true,
          resolvePersisted: true, roundThread: Resolved, retainedResolvedRound: true,
          outcome: Accepted,
          roundThreadScenario: if (st.roundThreadScenario == ScenarioReplied) ScenarioResolveAttempted else st.roundThreadScenario,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      } else if (st.roundThread == Resolved) {
        st' = { ...st, outcome: Accepted,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      } else {
        st' = { ...st, outcome: if (input.mode == Single) Accepted else Rejected400,
          lastBoundary: DeliverBoundary, lastInput: input, before: effects(st) }
      }
    } else if (input.route == CommentRoute or input.route == ReplyRoute or input.route == ResolveRoute) {
      st' = { ...st, selected: input.file, lastOwner: input.owner,
        replyTarget: input.owner, audienceAll: input.scope == RoundThread,
        firstGate: if (input.route == CommentRoute and input.scope == FileThread and input.file == First)
          input.gate else if (input.route == ResolveRoute and input.scope == FileThread and input.file == First)
          GateClear else st.firstGate,
        secondGate: if (input.route == CommentRoute and input.scope == FileThread and input.file == Second)
          input.gate else if (input.route == ResolveRoute and input.scope == FileThread and input.file == Second)
          GateClear else st.secondGate,
        firstRetainedUnanchored: st.firstRetainedUnanchored or
          (input.route == CommentRoute and input.scope == FileThread and input.file == First and input.gate == UnanchoredOnly),
        secondRetainedUnanchored: st.secondRetainedUnanchored or
          (input.route == CommentRoute and input.scope == FileThread and input.file == Second and input.gate == UnanchoredOnly),
        filePersisted: st.filePersisted or input.scope == FileThread,
        persistedFileOwner: if (input.scope == FileThread) input.owner else st.persistedFileOwner,
        roundPersisted: st.roundPersisted or input.scope == RoundThread,
        resolvePersisted: st.resolvePersisted or input.route == ResolveRoute,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input,
        before: effects(st) }
    } else {
      st' = { ...st, selected: input.file, effectTarget: input.file,
        outcome: Accepted, lastBoundary: DeliverBoundary, lastInput: input,
        before: effects(st) }
    }
  }

  action resolveRound = {
    all { st.phase == RoundComplete,
      st' = { ...st,
        phase: if (st.aggregate == RequestChanges) WaitingGo else Exited,
        outcome: Accepted, lastBoundary: ResolveRoundBoundary } }
  }

  action go = {
    all { st.phase == WaitingGo, st.aggregate == RequestChanges,
      st' = { ...st,
        generation: st.generation + 1,
        phase: Collecting, firstPresent: false, secondPresent: false,
        firstPayload: P1, secondPayload: P1,
        firstDecision: NoDecision, secondDecision: NoDecision,
        aggregate: NoDecision, outcome: Accepted, lastBoundary: GoBoundary } }
  }

  // This sampler is textually identical to the current module's sampler;
  // --step=deliverInputStep therefore replays one typed input sequence.
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

  val acceptedTargetMatchesContext = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or st.lastInput.route == UiJsRoute or
    st.lastInput.route == HealthzRoute or
    (st.lastInput.route == SubmitRoute and effects(st) == st.before) or
    (st.lastInput.scope == RoundThread and st.lastInput.route == ResolveRoute and
      effects(st) == st.before) or
    ((st.lastInput.mode == Single and st.lastInput.context == Missing and st.selected == First) or
     (st.lastInput.mode == Mux and st.lastInput.context == ValidFirst and st.selected == First) or
     (st.lastInput.mode == Mux and st.lastInput.context == ValidSecond and st.selected == Second))
  val effectMatchesLastAcceptedRoute = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or
    (st.lastInput.route == SubmitRoute and effects(st) == st.before) or
    (st.lastInput.route != StateRoute and st.lastInput.route != SubmitRoute and
      st.lastInput.route != CliRoute) or st.effectTarget == st.selected
  val staticMatchesLastAcceptedRoute = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or st.lastInput.route != StaticRoute or
    st.staticTarget == st.selected
  val sseMatchesLastAcceptedRoute = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or st.lastInput.route != SseRoute or
    st.sseTarget == st.selected
  val fileThreadTargetsOwner = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or
    (st.lastInput.route != CommentRoute and st.lastInput.route != ReplyRoute and st.lastInput.route != ResolveRoute) or
    st.lastInput.scope != FileThread or
    (st.replyTarget == st.lastOwner and not(st.audienceAll))
  val acceptedRoundResolveNoOp = st.lastBoundary == DeliverBoundary and
    st.outcome == Accepted and st.lastInput.scope == RoundThread and
    st.lastInput.route == ResolveRoute and
    (st.before.roundThread == Resolved or
      (st.lastInput.mode == Single and st.before.roundThread == NoThread)) and
    effects(st) == st.before
  val roundThreadBroadcasts = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or
    (st.lastInput.route != CommentRoute and st.lastInput.route != ReplyRoute and st.lastInput.route != ResolveRoute) or
    st.lastInput.scope != RoundThread or acceptedRoundResolveNoOp or
    st.lastInput.mode == Single or st.audienceAll
  val threadPersistenceMatchesAcceptedDelivery = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or
    (st.lastInput.route != CommentRoute and st.lastInput.route != ReplyRoute and st.lastInput.route != ResolveRoute) or
    (st.lastInput.scope == FileThread and st.filePersisted and st.persistedFileOwner == st.lastInput.owner and
      (st.lastInput.route != ResolveRoute or st.resolvePersisted)) or
    acceptedRoundResolveNoOp or
    (st.lastInput.scope == RoundThread and st.roundPersisted and
      (st.lastInput.route != ResolveRoute or st.resolvePersisted))
  val commentGateMatchesAcceptedDelivery = st.lastBoundary != DeliverBoundary or
    st.outcome != Accepted or st.lastInput.route != CommentRoute or
    st.lastInput.scope != FileThread or
    (st.lastInput.file == First and st.firstGate == st.lastInput.gate and
      (st.lastInput.gate != UnanchoredOnly or st.firstRetainedUnanchored)) or
    (st.lastInput.file == Second and st.secondGate == st.lastInput.gate and
      (st.lastInput.gate != UnanchoredOnly or st.secondRetainedUnanchored))
  val anchoredApproveRejected = st.lastBoundary != DeliverBoundary or
    st.lastInput.route != SubmitRoute or st.lastInput.decision != Approve or
    not(validOwned(st.lastInput)) or
    ((st.before.firstGate != AnchoredUnresolved or st.lastInput.file != First) and
     (st.before.secondGate != AnchoredUnresolved or st.lastInput.file != Second)) or
    st.outcome == Rejected409
  val noEarlyExit = not(st.phase == Exited) or
    (st.firstPresent and st.secondPresent and st.aggregate == Approve)
  val roundCompleteHasAllFiles = st.phase != RoundComplete or
    (st.firstPresent and st.secondPresent)
  val requestChangesWaits = st.phase != WaitingGo or st.aggregate == RequestChanges
  val staleSubmitRejected = st.lastBoundary != DeliverBoundary or
    st.lastInput.route != SubmitRoute or st.lastInput.generation == st.generation or
    not(validOwned(st.lastInput)) or
    st.outcome == Rejected409
  val terminalSubmitRejected = st.lastBoundary != DeliverBoundary or
    st.lastInput.route != SubmitRoute or st.before.phase == Collecting or
    not(validOwned(st.lastInput)) or
    st.outcome == Rejected409
  val rejectedDeliveryHasNoEffects = st.lastBoundary != DeliverBoundary or
    st.outcome == Accepted or effects(st) == st.before
  val roundThreadLifecycleSafety = st.lastBoundary != DeliverBoundary or
    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or
    st.lastInput.route != ResolveRoute or st.before.roundThread != Open or
    (st.roundThread == Resolved and st.outcome == Accepted and st.resolvePersisted and
      st.retainedResolvedRound)
  val rejectedResolvedRoundReplyHasNoEffects = st.lastBoundary != DeliverBoundary or
    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or
    st.lastInput.route != ReplyRoute or st.before.roundThread != Resolved or
    (st.roundThread == Resolved and st.outcome == Rejected409 and effects(st) == st.before)
  val resolvedRoundHistoryCanCreate = st.lastBoundary != DeliverBoundary or
    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or
    st.lastInput.route != CommentRoute or st.before.roundThread != Resolved or
    (st.roundThread == Open and st.outcome == Accepted and st.retainedResolvedRound)
  val resolvedRoundHistoryIsRetained = st.roundThreadScenario != ScenarioCreateAfterResolve or
    st.retainedResolvedRound
  val exactRetryHasNoEffects = st.lastBoundary != DeliverBoundary or
    st.lastInput.route != SubmitRoute or st.outcome != Accepted or
    st.rawEffects != st.before.rawEffects or effects(st) == st.before
  val emissionFollowsGeneration =
    (not(st.emittedG2) or st.emittedG1) and
    (not(st.emittedG3) or (st.emittedG1 and st.emittedG2)) and
    (not(st.emittedG4) or (st.emittedG1 and st.emittedG2 and st.emittedG3)) and
    st.emittedRounds <= st.generation
  val safety = all { acceptedTargetMatchesContext, effectMatchesLastAcceptedRoute,
    staticMatchesLastAcceptedRoute, sseMatchesLastAcceptedRoute,
    fileThreadTargetsOwner, roundThreadBroadcasts,
    threadPersistenceMatchesAcceptedDelivery, commentGateMatchesAcceptedDelivery,
    anchoredApproveRejected, noEarlyExit,
    roundCompleteHasAllFiles, requestChangesWaits, staleSubmitRejected,
    terminalSubmitRejected, rejectedDeliveryHasNoEffects,
    roundThreadLifecycleSafety, rejectedResolvedRoundReplyHasNoEffects,
    resolvedRoundHistoryCanCreate, resolvedRoundHistoryIsRetained,
    exactRetryHasNoEffects, emissionFollowsGeneration,
    staticMethodPathContract, unanchoredRetainedButNotGating,
    summaryAlwaysUsesMuxOrder, threadEffectsPersist }
  val collectingWitness = st.phase == Collecting
  val roundCompleteWitness = st.phase == RoundComplete
  val waitingGoWitness = st.phase == WaitingGo
  val exitedWitness = st.phase == Exited and st.aggregate == Approve
  val replacementWitness = st.rawEffects >= 2 and
    ((st.firstPresent and not(st.secondPresent)) or
     (st.secondPresent and not(st.firstPresent)))
  val generationThreeWitness = st.generation == 3 and st.emittedG1 and st.emittedG2
  val generationFourWitness = st.generation == 4 and st.emittedG1 and st.emittedG2 and st.emittedG3
  val allThreeRoundsWitness = st.phase == Exited and st.generation == 3 and
    st.emittedG1 and st.emittedG2 and st.emittedG3 and st.emittedRounds == 3
  val allFourRoundsWitness = st.phase == Exited and st.generation == 4 and
    st.emittedG1 and st.emittedG2 and st.emittedG3 and st.emittedG4 and st.emittedRounds == 4

}
