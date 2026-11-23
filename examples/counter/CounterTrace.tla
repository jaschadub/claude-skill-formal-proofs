---- MODULE CounterTrace ----
\* Follows a log of a real run, one event at a time. skills/tla-check/trace.sh writes TraceLog from the log.
EXTENDS Counter, Sequences, TraceLog

VARIABLE traceAt   \* how many events of the log the model has followed

Event(e) ==
  \/ e.action = "TakeLock" /\ TakeLock(e.thread)
  \/ e.action = "Read" /\ Read(e.thread)
  \/ e.action = "Write" /\ Write(e.thread)

TraceInit == Init /\ traceAt = 0
TraceNext == traceAt < Len(TraceLog) /\ Event(TraceLog[traceAt + 1]) /\ traceAt' = traceAt + 1
TraceUnfinished == traceAt < Len(TraceLog)
====
