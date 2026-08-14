import Std

/- Superseded provenance snapshot. The only executable Lean source for this
model is ../../scripts/dspec/ReviewMuxSpec.lean; this block is intentionally
non-executable so stale theorems cannot be mistaken for freeze evidence.

inductive File where
  | first
  | second
  deriving DecidableEq, Repr

inductive Route where
  | bare
  | forFirst
  | forSecond
  deriving DecidableEq, Repr

def requested : Route → File
  | .bare => .second
  | .forFirst => .first
  | .forSecond => .second

-- The current UI sends bare API routes after loading `/?f=1`; the server's
-- callback then still owns the first context.
def currentTarget : Route → File
  | _ => .first

def repairedTarget : Route → File
  | .bare => .first
  | .forFirst => .first
  | .forSecond => .second

def routes : List Route := [.bare, .forFirst, .forSecond]

def currentRouteViolations : List Route :=
  routes.filter (fun route => currentTarget route != requested route)

example : currentRouteViolations = [.bare, .forSecond] := by native_decide

def muxRoutes : List Route := [.forFirst, .forSecond]

def repairedRouteViolations : List Route :=
  muxRoutes.filter (fun route => repairedTarget route != requested route)

theorem repairedRoutesPreserveContext : repairedRouteViolations = [] := by
  native_decide

def traces : List (List File) :=
  [[], [.first], [.second], [.first, .first], [.first, .second],
   [.second, .first], [.second, .second]]

def currentResults (trace : List File) : List File := trace

def repairedResults (trace : List File) : List File :=
  trace.foldl (fun results submitted =>
    if submitted ∈ results then results else results ++ [submitted]) []

def hasBothFiles (results : List File) : Prop :=
  .first ∈ results ∧ .second ∈ results

def currentDuplicateFinishesEarly : Prop :=
  (currentResults [.first, .first]).length >= 2 ∧
  ¬hasBothFiles (currentResults [.first, .first])

example : currentDuplicateFinishesEarly := by native_decide

def repairedViolation (trace : List File) : Bool :=
  decide ((repairedResults trace).length >= 2 ∧ ¬hasBothFiles (repairedResults trace))

def repairedViolations : List (List File) := traces.filter repairedViolation

theorem repairedNoViolations : repairedViolations = [] := by native_decide
-/
