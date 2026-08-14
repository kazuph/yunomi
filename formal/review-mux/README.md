# Review mux: canonical-to-runtime mapping

## Canonical contract

`PLAN-v3.md` requires `yunomi review` to serve multiple changed files in one
process and switch them with `GET /?f=<idx>` (Task Card 2.1). The review state
table further defines current-file unresolved comments as the comments belonging
to the file currently displayed and resolvable on that screen
(`referent-table-review-counts-share-auth.md`). Therefore each context-bound
API request from a selected review page must act on that same selected file.

## State dimensions and side-effect boundaries

| Dimension | Current implementation source | Formal representation |
|---|---|---|
| selected review file | `selected_context` selects `active_servers[f]` only for HTML | `selected`, `effect`, `static`, `sse` |
| API route context | mux paths require `f`; non-mux paths are bare | `Mux`/`Single` request mode plus selected-versus-effective target invariant |
| submitted results | process-global `all_results` and `expected_count` | latest file payload/decision at the active natural-number generation |
| duplicate delivery | second `/exit` reaches `handle_submit` while `ctx.finished` is false | exact retry no-op; distinct payload latest replacement |
| terminal condition | `all_results.length() >= expected_count` | `collecting`, `roundComplete`, `waitingGo`, `exited` |
| loop decision | `request_changes` clears results and keeps the server alive | aggregate `request_changes > approve`, emitted generation set/list |
| SSE/review-state/post effects | each updates or reads its context-owned state | owner-only file audience; all-context round audience |
| unresolved approve gate | anchored unresolved comments block; unanchored history remains visible but does not block | per-file gate state plus retained-unanchored history |
| reply/resolve persistence | shared `review.json` write precedes context-owned or session-wide delivery | file owner, round persistence, resolve persistence, and audience effects |
| round conversation lifecycle | the non-mux bare endpoint and mux `f` route share thread semantics but differ in context validation | `Mux`/`Single` plus `NoThread` / `Open` / `Resolved`, reply count, retained resolved history, HTTP outcome; every reachable state × typed input follows the lifecycle decision table |

## Explicitly unmodeled dimensions

- share-token authorization
- comment/image payload contents and filesystem write failures
- browser tab instance replacement and network connection loss
- source-watch delivery loss and external notification-command failure
- three or more files (the two-file model is the smallest witness domain)

Static GET/HEAD/Range-header handling, SSE audience, history/video, `go`, CLI routing, and full
multi-file round aggregation are modeled as required product-test boundaries.
Round `Resolve` is also mode-specific in the model: `Single + Missing + NoThread`
is the legacy `200` no-op, while `Mux + Valid* + NoThread` is a `400` no-op;
`Open` and `Resolved` retain their shared `200` transition/idempotency semantics.
The Alloy `5 Int` scopes use a bounded integer carrier; its maximum is not a
product state. Delivery determinism checks therefore require a larger carrier
integer only for branches that increment a modeled counter.
The authoritative Lean, Alloy, and drift-check set is `scripts/dspec/`; the
authoritative Quint current/repaired models and generated ITF traces are under
`formal/review-mux/`. `formal/review-mux/ReviewMuxSpec.lean` and
`formal/review-mux/review_mux.als` are non-executable provenance snapshots and
cannot enter the evidence receipt.

These are not represented by the finite proofs below and must not be inferred
from a GREEN model result.

## Artifact mapping

| Canonical requirement | Current guard/action | Lean | Alloy | Quint | Product contract |
|---|---|---|---|---|---|
| selected `?f=i` page owns state/static/CLI effect | `selected_context`, `handle_request` | `currentDisplayEffectMismatch`, `everyTypedInputIsStrictOrEffectFree` | `CurrentRoutePreservesSelection`, `RepairedDeliverySafety` | `displayEffectMismatch`, `acceptedTargetMatchesContext` | `review_mux_context_contract.ts` |
| each changed file has one latest terminal result | `handle_submit`, `all_results`, `expected_count` | `currentDuplicateExitsEarly`, first/second replacement and retry theorems | `CurrentDoesNotFinishEarly`, replacement/retry witnesses | `duplicateEarlyExit`, `exactRetryHasNoEffects`, `replacementWitness` | `review_mux_context_contract.ts` |
| `request_changes` dominates and waits for go | mux startup, submit, go | `requestChangesPriorityBothArrivalOrders`, generation-one/two wait theorems | forward/reverse waiting-go witnesses, `RepairedResolveSafety` | `requestChangesWaits`, `waitingGoWitness` | `review_mux_context_contract.ts` |
| all approve exits only after round completion | exit action boundary | `generationFourAllApproveExitsAndEmitsOnce`, bounded closure invariant | completion/generation-four witnesses, resolve safety | `noEarlyExit`, `allFourRoundsWitness` | `review_mux_context_contract.ts` |
| file/round SSE audience ownership | reply and CLI delivery | `replyTargetsExplicitOwner`, `roundReplyNotifiesAll` | file/round reply witnesses, delivery safety with `repairedAcceptedRoundResolveNoOp` | `fileThreadTargetsOwner`, `roundThreadBroadcasts` | `review_mux_context_contract.ts` |
| generation has no product cap | generation body, go signal | `generationThreeRequestChangesAdvancesWithoutProductCap` | `RepairedGenerationFourWitness` | integer generation and `generationFourWitness` | generation-three request changes advances to generation four |
| static GET/HEAD/same-path Range header/nested CSS/traversal and non-mux compatibility | static route handling | exhaustive `StaticRequest` decision table with `RangeHeader` | static total/deterministic assert and boundary witnesses | `staticMethodPathContract` with `RangeHeader` | mux-static and single-static cases |
| summaries emit in mux display order | result aggregation/YAML emission | `summaryOrderIsMuxOrderForBothArrivals` | `SummaryOrderIgnoresArrivalOrder`, `ReverseArrivalSummaryWitness` | `summaryAlwaysUsesMuxOrder` | round and context YAML assertions |
| unanchored unresolved history is retained but non-gating | approve gate count | connected current/repaired comment→submit theorems and resolve-clear theorem | connected current/repaired comment→submit and resolve-clear witnesses | `commentGateMatchesAcceptedDelivery`, `anchoredApproveRejected` | `approve_unanchored_regression.ts` |
| reply/resolve/CLI/round changes persist as well as notify | shared review JSON and SSE delivery | `replyResolveAndRoundPersistenceAreStateEffects` | `RepairedPersistenceTransitionWitness`, delivery safety | `threadPersistenceMatchesAcceptedDelivery` | context case rereads `review.json` after every boundary |
| resolved round/global thread rejects reply without side effect and permits a new thread | `review_comment_is_replyable`, `review_can_create_global_comment`, review-loop panel | principal `State.roundThread` trace and `everyTypedRoundLifecycleDeliveryMatchesDecisionTable` | principal `CurrentState`/`RepairedState` guard-label totality/exclusivity and all-field same-input checks: `CurrentDeliveryGuardsAreTotalAndExclusive`, `RepairedDeliveryGuardsAreTotalAndExclusive`, `CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain`, `RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain`, `CurrentRoundResolveBugWitness`, `CurrentRoundResolvePersists`, `RepairedRoundThreadLifecycleWitness`, `RepairedRoundThreadResolvedReplyHasNoEffect` | `roundThreadLifecycleSafety` binds accepted persisted resolved state to each valid Open Round Resolve delivery; `rejectedResolvedRoundReplyHasNoEffects` binds the 409/no-effect guarantee to each valid resolved Reply delivery; `resolvedRoundHistoryCanCreate` binds accepted replacement Open state to each valid resolved Round Comment delivery; `resolvedRoundHistoryIsRetained` keeps the trace history after replacement; principal `deliver` sets the creation outcome to `Accepted`, and `acceptedTargetMatchesContext` checks the target when the outcome is `Accepted` | resolve replay/missing-ID no-op cases in `review_loop.ts`, `review_mux_context_contract.ts` |
