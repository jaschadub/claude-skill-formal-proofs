---- MODULE Counter ----
\* Model of hit() in counter.py: every order in which the threads can take their steps.
EXTENDS Naturals, FiniteSets
CONSTANTS Threads, Faults
VARIABLES count, locked, seen, pc
vars == <<count, locked, seen, pc>>

Init ==
  /\ count = 0
  /\ locked = FALSE
  /\ seen = [t \in Threads |-> 0]
  /\ pc = [t \in Threads |-> "start"]

\* `with lock:` waits until the lock is free and takes it.
\* Fault "no_lock": hit() does not take the lock.
TakeLock(t) ==
  /\ pc[t] = "start"
  /\ "no_lock" \in Faults \/ ~locked
  /\ locked' = ("no_lock" \notin Faults)
  /\ pc' = [pc EXCEPT ![t] = "read"]
  /\ UNCHANGED <<count, seen>>

\* `seen = count`
Read(t) ==
  /\ pc[t] = "read"
  /\ seen' = [seen EXCEPT ![t] = count]
  /\ pc' = [pc EXCEPT ![t] = "write"]
  /\ UNCHANGED <<count, locked>>

\* `count = seen + 1`, then the `with` block ends and frees the lock.
Write(t) ==
  /\ pc[t] = "write"
  /\ count' = seen[t] + 1
  /\ locked' = FALSE
  /\ pc' = [pc EXCEPT ![t] = "done"]
  /\ UNCHANGED seen

AllDone == (\A t \in Threads : pc[t] = "done") /\ UNCHANGED vars

Next == (\E t \in Threads : TakeLock(t) \/ Read(t) \/ Write(t)) \/ AllDone

\* Every finished hit is counted.
NoLostHit == count = Cardinality({t \in Threads : pc[t] = "done"})
====
