import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const read = (relative) => readFileSync(new URL(relative, import.meta.url), "utf8");
const files = {
  current: read("../../formal/review-mux/review_mux_current.qnt"),
  repaired: read("../../formal/review-mux/review_mux_repaired.qnt"),
  lean: read("./ReviewMuxSpec.lean"),
  alloy: read("./review-mux.als"),
  mapping: read("../../formal/review-mux/README.md"),
  server: read("../../v2/src/server/main.mbt"),
  ffi: read("../../v2/src/server/ffi.mbt"),
  ui: read("../../v2/src/ui/app.mbt"),
  dom: read("../../v2/src/ui/dom.mbt"),
  css: read("../../v2/src/core/css.mbt"),
  contract: read("../../v2/e2e/review_mux_context_contract.ts"),
  reviewLoop: read("../../v2/e2e/review_loop.ts"),
  unanchoredContract: read("../../v2/e2e/approve_unanchored_regression.ts"),
};

const expectedRoutes = ["Html", "State", "Submit", "Sse", "Static", "Comment", "Reply", "Resolve", "Cli", "UiJs", "Healthz"];
const qntRoutes = (source) => {
  const declarations = [...source.matchAll(/module review_mux_(?:current|repaired) \{[\s\S]*?type Route = ([^\n]+)/g)];
  const body = declarations.at(-1)?.[1] || "";
  return expectedRoutes.filter((route) => body.includes(`${route}Route`));
};
const exactSet = (left, right) => left.length === right.length && left.every((value) => right.includes(value));
const hasAll = (source, fragments) => fragments.every((fragment) => source.includes(fragment));
const count = (source, pattern) => [...source.matchAll(pattern)].length;
const replaceLast = (source, before, after) => {
  const index = source.lastIndexOf(before);
  return index < 0 ? source : source.slice(0, index) + after + source.slice(index + before.length);
};
const blockAfterLast = (source, marker) => {
  const markerIndex = source.lastIndexOf(marker);
  const open = source.indexOf("{", markerIndex);
  if (markerIndex < 0 || open < 0) return "";
  let depth = 0;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(open + 1, index);
  }
  return "";
};
const valueAfterLast = (source, marker) => {
  const start = source.lastIndexOf(marker);
  if (start < 0) return "";
  const end = source.indexOf("\n  val ", start + marker.length);
  return source.slice(start, end < 0 ? source.length : end);
};

const observedRepairedRoutes = qntRoutes(files.repaired);
const breakSemantic = process.argv.includes("--break") || process.argv.includes("--break-semantic");
const breakLifecycle = process.argv.includes("--break-lifecycle") || process.argv.includes("--break-semantic");
const breakReplyLatch = process.argv.includes("--break-reply-latch");
const breakRoundResolveLatch = process.argv.includes("--break-round-resolve-latch");
const breakRoundCreateLatch = process.argv.includes("--break-round-create-latch");
const repairedForSemanticCheck = breakSemantic
  ? replaceLast(files.repaired, "input.context == Missing or input.context == Invalid", "input.context == Invalid")
  : files.repaired;
const repairedForLifecycleCheck = breakLifecycle
  ? replaceLast(files.repaired, "roundThread: Resolved", "roundThread: Open")
  : files.repaired;
const repairedForReplyLatchCheck = breakReplyLatch
  ? replaceLast(files.repaired, "st.lastBoundary != DeliverBoundary or\n    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or\n    st.lastInput.route != ReplyRoute or st.before.roundThread != Resolved or\n    (st.roundThread == Resolved and st.outcome == Rejected409 and effects(st) == st.before)", "st.roundThreadScenario != ScenarioReplyAfterResolve or\n    (st.roundThread == Resolved and st.outcome == Rejected409 and effects(st) == st.before)")
  : files.repaired;
const repairedForRoundResolveCheck = breakRoundResolveLatch
  ? replaceLast(files.repaired, "st.lastBoundary != DeliverBoundary or\n    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or\n    st.lastInput.route != ResolveRoute or st.before.roundThread != Open or\n    (st.roundThread == Resolved and st.outcome == Accepted and st.resolvePersisted and\n      st.retainedResolvedRound)", "st.roundThreadScenario != ScenarioResolveAttempted or\n    st.roundThread == Resolved")
  : files.repaired;
const repairedForRoundCreateCheck = breakRoundCreateLatch
  ? replaceLast(files.repaired, "st.lastBoundary != DeliverBoundary or\n    not(validOwned(st.lastInput)) or st.lastInput.scope != RoundThread or\n    st.lastInput.route != CommentRoute or st.before.roundThread != Resolved or\n    (st.roundThread == Open and st.outcome == Accepted and st.retainedResolvedRound)", "st.roundThreadScenario != ScenarioCreateAfterResolve or\n    (st.roundThread == Open and st.retainedResolvedRound)")
  : files.repaired;
const repairedDeliver = blockAfterLast(repairedForSemanticCheck, "action deliver(input)");
const repairedLifecycleDeliver = blockAfterLast(repairedForLifecycleCheck, "action deliver(input)");
const repairedReplyLatch = valueAfterLast(repairedForReplyLatchCheck, "val rejectedResolvedRoundReplyHasNoEffects =");
const repairedRoundResolveSafety = valueAfterLast(repairedForRoundResolveCheck, "val roundThreadLifecycleSafety =");
const repairedRoundCreateHistory = valueAfterLast(repairedForRoundCreateCheck, "val resolvedRoundHistoryCanCreate =");
const repairedGo = blockAfterLast(repairedForSemanticCheck, "action go =");
const repairedModule = blockAfterLast(files.repaired, "module review_mux_repaired");
const currentModule = blockAfterLast(files.current, "module review_mux_current");
const currentSampler = blockAfterLast(files.current, "action deliverInputStep");
const repairedSampler = blockAfterLast(files.repaired, "action deliverInputStep");
const strictGuard = repairedDeliver.slice(0, repairedDeliver.indexOf("input.route == HtmlRoute"));
const orderedMarkers = [
  "input.route == UiJsRoute or input.route == HealthzRoute",
  "input.context == Missing or input.context == Invalid",
  "input.route == HtmlRoute",
  "st.phase != Collecting or input.generation != st.generation",
  "st.firstPayload == input.payload",
  "else if (input.route == SubmitRoute)",
];
const ordered = orderedMarkers.map((marker) => repairedDeliver.indexOf(marker));

const checks = [
  ["same typed route domain", exactSet(qntRoutes(files.current), expectedRoutes) && exactSet(observedRepairedRoutes, expectedRoutes)],
  ["same typed Quint input sampler", currentSampler.length > 0 && currentSampler === repairedSampler],
  ["single Quint delivery boundary", count(files.current, /action deliver\(input\)/g) === 1 && count(files.repaired, /action deliver\(input\)/g) === 1],
  ["strict guard and update order", strictGuard.includes("input.context == Missing") && strictGuard.includes("input.context == Invalid") && strictGuard.includes("input.context == Global") && ordered.every((position) => position >= 0) && ordered.every((position, index) => index === 0 || ordered[index - 1] < position)],
  ["generation advances without product cap", repairedGo.includes("generation: st.generation + 1") && !repairedGo.includes("st.generation !=") && files.contract.includes("go advances generation three to generation four")],
  ["static method path and Range-header decision tables", hasAll(files.repaired, ["type RangeHeader", "rangeHeader == ByteRange", "staticMethodPathContract", "Static206", "Static403", "Static400"]) && hasAll(files.lean, ["inductive RangeHeader", "request.range == .bytes", "everyStaticMethodPathContextMatchesContract", "partial206", "forbidden403", "bad400"]) && hasAll(files.alloy, ["abstract sig RangeHeader", "staticRange = ByteRange", "StaticDecisionTableIsTotalAndDeterministic", "StaticBoundaryWitnesses"]) && hasAll(files.contract, ["partial-content semantics", "static traversal is rejected", "single-file static HEAD remains backward compatible"])],
  ["summary gate and persistence transitions", hasAll(files.repaired, ["summaryAlwaysUsesMuxOrder", "commentGateMatchesAcceptedDelivery", "threadPersistenceMatchesAcceptedDelivery", "anchoredApproveRejected", "input.route == ResolveRoute", "GateClear else st.firstGate"]) && hasAll(files.lean, ["summaryOrderIsMuxOrderForBothArrivals", "repairedUnanchoredHistoryIsRetainedAndApproveIsAccepted", "repairedResolveClearsAnchoredGateAndAllowsApprove", "replyResolveAndRoundPersistenceAreStateEffects", "boundaryAlphabet).map .request"]) && hasAll(files.alloy, ["ReverseArrivalSummaryWitness", "RepairedUnanchoredTransitionWitness", "RepairedResolveClearsGateWitness", "RepairedPersistenceTransitionWitness"]) && hasAll(files.contract, ["final YAML follows mux display order", "file-thread resolve persists its resolved status", "CLI round-thread reply persists"]) && hasAll(files.unanchoredContract, ["an unanchored prior thread is outside the approve gate", "Approve preserves the unanchored unresolved thread as review history"])],
  ["generic Alloy delivery guards and bounded observational determinism", hasAll(files.alloy, ["pred currentDeliver[s, t: CurrentState, i: Input]", "pred repairedDeliver[s, t: RepairedState, i: Input]", "pred currentGuardLabel", "pred repairedGuardLabel", "pred sameCurrentObservation", "pred sameRepairedObservation", "pred currentDeterminismWithinFiniteIntDomain", "pred repairedDeterminismWithinFiniteIntDomain", "assert CurrentDeliveryGuardsAreTotalAndExclusive", "assert RepairedDeliveryGuardsAreTotalAndExclusive", "assert CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain", "assert RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain", "check CurrentDeliveryGuardsAreTotalAndExclusive", "check RepairedDeliveryGuardsAreTotalAndExclusive", "check CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain", "check RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain"]) && hasAll(files.mapping, ["`CurrentDeliveryIsObservationallyDeterministicWithinFiniteIntDomain`", "`RepairedDeliveryIsObservationallyDeterministicWithinFiniteIntDomain`"]) && !files.mapping.includes("`CurrentDeliveryIsObservationallyDeterministic`") && !files.mapping.includes("`RepairedDeliveryIsObservationallyDeterministic`") && count(files.alloy, /assert CurrentDeliveryGuardsAreTotalAndExclusive/g) === 1 && count(files.alloy, /assert RepairedDeliveryGuardsAreTotalAndExclusive/g) === 1 && count(files.alloy, /check CurrentDeliveryGuardsAreTotalAndExclusive/g) === 1 && count(files.alloy, /check RepairedDeliveryGuardsAreTotalAndExclusive/g) === 1],
  ["Lean typed current and repaired steps", hasAll(files.lean, ["def currentStep (state : State) (input : Input)", "def repairedStep (state : State) (input : Input)", "everyTypedInputIsStrictOrEffectFree"])],
  ["display and API boundary counterexample", hasAll(files.current, ["input.route == HtmlRoute", "input.context != Missing", "displayEffectMismatch"]) && hasAll(files.lean, ["currentDisplayedSecondThenBareState", "currentQueryApiIs404"])],
  ["retry replacement and stale-generation contract", hasAll(files.repaired, ["exactRetryHasNoEffects", "staleSubmitRejected", "not(validOwned(st.lastInput))", "generationThreeWitness"]) && hasAll(files.contract, ["an identical selected-file retry", "a distinct payload replaces", "a delayed generation-two submit"])],
  ["active strict-owned priority mapping", count(repairedModule, /pure def validOwned\(input\)\s*=/g) === 1 && count(repairedModule, /not\(validOwned\(st\.lastInput\)\)/g) === 6 && hasAll(files.lean, ["staleSubmitSafe", "terminalSubmitSafe", "anchoredApproveSafe", "!validOwned state.lastInput"])],
  ["strict index matrix", hasAll(files.contract, ["rejects a missing mux index", "rejects a non-numeric mux index", "rejects an out-of-range mux index", "rejects a negative mux index", "rejects a decimal mux index", "rejects duplicate mux index parameters"])],
  ["thread owner and audience contract", hasAll(files.repaired, ["fileThreadTargetsOwner", "acceptedRoundResolveNoOp", "roundThreadBroadcasts", "threadPersistenceMatchesAcceptedDelivery"]) && hasAll(files.lean, ["acceptedRoundResolveNoOp", "audienceSafe", "persistenceSafe"]) && hasAll(files.alloy, ["pred repairedAcceptedRoundResolveNoOp", "repairedAcceptedRoundResolveNoOp[s, t, i]"]) && hasAll(files.contract, ["file-thread reply is not delivered", "round-scoped conversation is delivered to the first context", "CLI round reply second SSE"])],
  ["resolved reply guard is event-local", hasAll(repairedReplyLatch, ["st.lastBoundary != DeliverBoundary", "not(validOwned(st.lastInput))", "st.lastInput.scope != RoundThread", "st.lastInput.route != ReplyRoute", "st.before.roundThread != Resolved", "st.roundThread == Resolved", "st.outcome == Rejected409", "effects(st) == st.before"]) && !repairedReplyLatch.includes("st.roundThreadScenario != ScenarioReplyAfterResolve") && files.mapping.includes("`rejectedResolvedRoundReplyHasNoEffects`")],
  ["round thread lifecycle is connected to principal delivery state", hasAll(currentModule, ["type MuxMode = Mux | Single", "mode: MuxMode", "roundThread: RoundThreadState", "roundReplies: int", "action deliver(input)", "input.mode == Mux and input.context != Missing", "input.context == Missing and input.scope == RoundThread and input.route == ResolveRoute", "currentRoundResolveBug", "action roundThreadScenarioStep", "roundThreadScenario", "mode: Single"]) && hasAll(repairedModule, ["type MuxMode = Mux | Single", "mode: MuxMode", "roundThread: RoundThreadState", "roundReplies: int", "type Effects", "roundThread: state.roundThread", "input.mode == Single and (input.context != Missing or input.file != First)", "input.scope == RoundThread and input.route == ResolveRoute", "action roundThreadScenarioStep", "rejectedResolvedRoundReplyHasNoEffects", "roundThreadLifecycleSafety", "resolvedRoundHistoryCanCreate", "resolvedRoundHistoryIsRetained", "acceptedTargetMatchesContext"]) && hasAll(repairedRoundResolveSafety, ["st.lastBoundary != DeliverBoundary", "not(validOwned(st.lastInput))", "st.lastInput.scope != RoundThread", "st.lastInput.route != ResolveRoute", "st.before.roundThread != Open", "st.roundThread == Resolved", "st.outcome == Accepted", "st.resolvePersisted", "st.retainedResolvedRound"]) && !repairedRoundResolveSafety.includes("st.roundThreadScenario != ScenarioResolveAttempted") && hasAll(repairedRoundCreateHistory, ["st.lastBoundary != DeliverBoundary", "not(validOwned(st.lastInput))", "st.lastInput.scope != RoundThread", "st.lastInput.route != CommentRoute", "st.before.roundThread != Resolved", "st.roundThread == Open", "st.outcome == Accepted", "st.retainedResolvedRound"]) && !repairedRoundCreateHistory.includes("st.roundThreadScenario != ScenarioCreateAfterResolve") && hasAll(files.mapping, ["`roundThreadLifecycleSafety`", "`resolvedRoundHistoryCanCreate`", "`resolvedRoundHistoryIsRetained`"]) && hasAll(repairedLifecycleDeliver, ["roundThread: Resolved", "st.roundThread == Resolved", "if (input.mode == Single) Accepted else Rejected400"]) && hasAll(files.lean, ["inductive MuxMode where | mux | single", "mode : MuxMode", "input.mode == .single && input.context == .missing && input.file == .first", "roundThread : RoundThreadState", "roundReplies : Nat", "def currentStep (state : State) (input : Input)", "def repairedStep (state : State) (input : Input)", "roundLifecycleDecisionSafe", "everyTypedRoundLifecycleDeliveryMatchesDecisionTable", "currentRoundResolveLeavesThreadOpen", "repairedRoundResolveIsModeAwareNoOp", "muxRoundResolveMissingInput", "boundedClosureKeepsResolvedRoundHistory"]) && hasAll(files.alloy, ["one sig Mux, Single extends MuxMode", "mode: one MuxMode", "not (i.scope = RoundThread", "i.mode = Single and i.context = Missing and i.file = First", "cRoundThread: one RoundThreadState", "rRoundThread: one RoundThreadState", "pred currentRoundDeliver", "pred repairedRoundDeliver", "s.rRoundThread = NoThread and i.mode = Single", "s.rRoundThread = NoThread and i.mode = Mux", "CurrentRoundResolveBugWitness", "RepairedRoundThreadLifecycleWitness", "RepairedRoundResolveSemantics"]) && !files.alloy.includes("sig RoundThreadBoundary") && hasAll(files.ffi, ["comment.status !== \"resolved\"", "!latest || latest.status === \"resolved\""]) && hasAll(files.dom, ["review-loop-conversation-history", "pastConversations", "thread.status !== \"resolved\""]) && hasAll(files.css, [".review-loop-conversation .review-loop-resolve", ".review-loop-conversation-history > summary"]) && hasAll(files.reviewLoop, ["the visible resolve action accepts the global conversation", "review-loop-body > .review-loop-conversation:not(.is-resolved)", "a single-review missing resolve preserves the legacy 200 no-op", "expanded resolved history keeps its messages readable", "the visible new-global form creates a replacement conversation"]) && hasAll(files.contract, ["replaying a resolved round resolve remains an idempotent 200", "a mux missing round resolve rejects with 400", "round resolve reaches first SSE", "HTTP reply rejects a resolved round conversation", "a resolved round conversation permits a new round conversation"])],
  ["implementation boundary remains mapped", hasAll(files.server, ["fn selected_context", "fn handle_submit", "fn handle_go_signal"]) && hasAll(files.ui, ["/review-state", "/exit", "/sse"]) && files.dom.includes("/resolve-comment")],
];

const failed = checks.filter(([, passed]) => !passed).map(([label]) => label);
const hashes = Object.fromEntries(Object.entries(files).map(([name, source]) => [name, createHash("sha256").update(source).digest("hex")]));
const report = { status: failed.length === 0 ? "pass" : "fail", failed, hashes };

if (failed.length > 0) {
  console.error(JSON.stringify(report, null, 2));
  process.exit(1);
}

console.log(JSON.stringify(report, null, 2));
