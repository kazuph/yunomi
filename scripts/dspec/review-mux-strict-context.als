module review_mux_strict_context

open util/ordering[StrictState] as strictOrder

abstract sig Actor {}
one sig Browser, Cli extends Actor {}
abstract sig Route {}
one sig StateRoute, SubmitRoute, SseRoute, StaticRoute, ReplyRoute, ResolveRoute, CliRoute, UiJsRoute, HealthzRoute extends Route {}
abstract sig File {}
one sig First, Second extends File {}
abstract sig Context {}
one sig Missing, ValidFirst, ValidSecond, Invalid, Global extends Context {}
abstract sig Generation {}
one sig G1, G2, G3 extends Generation {}
abstract sig Payload {}
one sig P1, P2 extends Payload {}
abstract sig Decision {}
one sig RequestChanges, Approve extends Decision {}
abstract sig Scope {}
one sig FileScope, RoundScope extends Scope {}
abstract sig Outcome {}
one sig Accepted, Rejected400, Rejected409 extends Outcome {}
abstract sig Phase {}
one sig Collecting, RoundComplete, WaitingGo, Exited extends Phase {}

sig Delivery {
  actor: one Actor, route: one Route, context: one Context, file: one File,
  owner: one File, generation: one Generation, payload: one Payload,
  decision: one Decision, scope: one Scope
}

sig StrictState {
  generation: one Generation, phase: one Phase, selected: one File,
  effect: one File, static: one File, sse: one File,
  owner: one File, replyTarget: one File, fileAudience: set File,
  roundAudience: set File, ledger: set Delivery, raw: set Delivery,
  emitted: set Generation, outcome: one Outcome
}

fun contextFile[c: Context]: set File {
  c = ValidFirst => First else c = ValidSecond => Second else none
}
pred validOwned[d: Delivery] { d.context in ValidFirst + ValidSecond and d.file in contextFile[d.context] }
pred sameKey[l, r: Delivery] { l.file = r.file and l.generation = r.generation }
pred samePayload[l, r: Delivery] { sameKey[l, r] and l.payload = r.payload and l.decision = r.decision }
pred complete[s: StrictState] { s.ledger.file = First + Second }
pred copy[s, t: StrictState] {
  t.generation = s.generation and t.phase = s.phase and t.selected = s.selected and t.effect = s.effect and t.static = s.static and t.sse = s.sse and
  t.owner = s.owner and t.replyTarget = s.replyTarget and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience and
  t.ledger = s.ledger and t.raw = s.raw and t.emitted = s.emitted
}
pred strictInit[s: StrictState] {
  s.generation = G1 and s.phase = Collecting and s.selected = Second and s.effect = Second and s.static = Second and s.sse = Second and
  s.owner = Second and s.replyTarget = Second and s.fileAudience = Second and s.roundAudience = First + Second and no s.ledger and no s.raw and no s.emitted and s.outcome = Accepted
}

// Every result transition receives the same generic Delivery input.  It is the
// only Next branch that can alter raw/ledger/emitted.
pred acceptDeliver[s, t: StrictState, d: Delivery] {
  s.phase = Collecting and d.route = SubmitRoute and validOwned[d] and d.generation = s.generation and
  no prior: s.ledger | samePayload[prior, d]
  t.generation = s.generation and t.selected = d.file and t.effect = d.file and t.static = s.static and t.sse = s.sse and t.owner = s.owner and t.replyTarget = s.replyTarget and
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience and t.raw = s.raw + d and t.ledger = (s.ledger - { prior: s.ledger | sameKey[prior, d] }) + d and t.outcome = Accepted and
  (complete[t] implies t.phase = RoundComplete and t.emitted = s.emitted + s.generation) and
  (not complete[t] implies t.phase = Collecting and t.emitted = s.emitted)
}
pred retryDeliver[s, t: StrictState, d: Delivery] {
  s.phase = Collecting and d.route = SubmitRoute and validOwned[d] and d.generation = s.generation and some prior: s.ledger | samePayload[prior, d]
  copy[s, t] and t.outcome = Accepted
}
pred rejectDeliver[s, t: StrictState, d: Delivery] {
  d.route != SubmitRoute or s.phase != Collecting or not validOwned[d] or d.generation != s.generation
  copy[s, t] and t.outcome in Rejected400 + Rejected409
}
pred requestContext[s, t: StrictState, d: Delivery] {
  d.route in StateRoute + SseRoute + StaticRoute + CliRoute and validOwned[d]
  t.generation = s.generation and t.phase = s.phase and t.selected = d.file and t.effect = (d.route in StateRoute + CliRoute => d.file else s.effect) and
  t.static = (d.route = StaticRoute => d.file else s.static) and t.sse = (d.route = SseRoute => d.file else s.sse) and t.owner = s.owner and t.replyTarget = s.replyTarget and
  t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience and t.ledger = s.ledger and t.raw = s.raw and t.emitted = s.emitted and t.outcome = Accepted
}
pred rejectContext[s, t: StrictState, d: Delivery] {
  d.route in StateRoute + SseRoute + StaticRoute + ReplyRoute + ResolveRoute + CliRoute and d.context in Missing + Invalid
  copy[s, t] and t.outcome = Rejected400
}
pred replyContext[s, t: StrictState, d: Delivery] {
  d.route in ReplyRoute + ResolveRoute and validOwned[d] and d.owner = d.file
  t.generation = s.generation and t.phase = s.phase and t.selected = d.file and t.effect = s.effect and t.static = s.static and t.sse = s.sse and t.owner = d.owner and t.replyTarget = d.owner and
  t.fileAudience = (d.scope = FileScope => d.owner else s.fileAudience) and t.roundAudience = (d.scope = RoundScope => First + Second else s.roundAudience) and
  t.ledger = s.ledger and t.raw = s.raw and t.emitted = s.emitted and t.outcome = Accepted
}
pred globalBare[s, t: StrictState, d: Delivery] { d.route in UiJsRoute + HealthzRoute and d.context = Global and copy[s, t] and t.outcome = Accepted }
pred rejectGlobalWithF[s, t: StrictState, d: Delivery] { d.route in UiJsRoute + HealthzRoute and d.context != Global and copy[s, t] and t.outcome = Rejected400 }
pred resolveRound[s, t: StrictState] { s.phase = RoundComplete and t.generation = s.generation and t.phase = (some d: s.ledger | d.decision = RequestChanges => WaitingGo else Exited) and t.selected = s.selected and t.effect = s.effect and t.static = s.static and t.sse = s.sse and t.owner = s.owner and t.replyTarget = s.replyTarget and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience and t.ledger = s.ledger and t.raw = s.raw and t.emitted = s.emitted and t.outcome = Accepted }
pred go[s, t: StrictState] { s.phase = WaitingGo and (s.generation = G1 or s.generation = G2) and t.generation = (s.generation = G1 => G2 else G3) and t.phase = Collecting and t.selected = s.selected and t.effect = s.effect and t.static = s.static and t.sse = s.sse and t.owner = s.owner and t.replyTarget = s.replyTarget and t.fileAudience = s.fileAudience and t.roundAudience = s.roundAudience and no t.ledger and t.raw = s.raw and t.emitted = s.emitted and t.outcome = Accepted }
pred next[s, t: StrictState] { some d: Delivery | acceptDeliver[s,t,d] or retryDeliver[s,t,d] or rejectDeliver[s,t,d] or requestContext[s,t,d] or rejectContext[s,t,d] or replyContext[s,t,d] or globalBare[s,t,d] or rejectGlobalWithF[s,t,d] or resolveRound[s,t] or go[s,t] }
fact Trace { strictInit[strictOrder/first] and all s: StrictState - strictOrder/last | next[s, s.(strictOrder/next)] }

assert StrictSafety {
  all s: StrictState | s.replyTarget = s.owner and s.roundAudience = First + Second and
    all f: File | lone { d: s.ledger | d.file = f } and
    (s.phase = RoundComplete implies complete[s]) and (s.phase = Exited implies complete[s])
}
pred SubmitWitness { some s: StrictState - strictOrder/last, d: Delivery | acceptDeliver[s, s.(strictOrder/next), d] }
pred RetryWitness { some s: StrictState - strictOrder/last, d: Delivery | retryDeliver[s, s.(strictOrder/next), d] }
pred RejectWitness { some s: StrictState - strictOrder/last, d: Delivery | rejectDeliver[s, s.(strictOrder/next), d] }
pred StaticWitness { some s: StrictState - strictOrder/last, d: Delivery | requestContext[s, s.(strictOrder/next), d] and d.route = StaticRoute }
pred SseWitness { some s: StrictState - strictOrder/last, d: Delivery | requestContext[s, s.(strictOrder/next), d] and d.route = SseRoute }
pred CliWitness { some s: StrictState - strictOrder/last, d: Delivery | requestContext[s, s.(strictOrder/next), d] and d.route = CliRoute }
pred OwnerWitness { some s: StrictState - strictOrder/last, d: Delivery | replyContext[s, s.(strictOrder/next), d] and d.scope = FileScope }
pred RoundAudienceWitness { some s: StrictState - strictOrder/last, d: Delivery | replyContext[s, s.(strictOrder/next), d] and d.scope = RoundScope }

check StrictSafety for exactly 8 StrictState, exactly 8 Delivery
run SubmitWitness for exactly 8 StrictState, exactly 8 Delivery
run RetryWitness for exactly 8 StrictState, exactly 8 Delivery
run RejectWitness for exactly 8 StrictState, exactly 8 Delivery
run StaticWitness for exactly 8 StrictState, exactly 8 Delivery
run SseWitness for exactly 8 StrictState, exactly 8 Delivery
run CliWitness for exactly 8 StrictState, exactly 8 Delivery
run OwnerWitness for exactly 8 StrictState, exactly 8 Delivery
run RoundAudienceWitness for exactly 8 StrictState, exactly 8 Delivery
