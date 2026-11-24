# PHP targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is PHP. It adds to `SKILL.md` and replaces none of it. It covers web apps, such as Laravel apps, whose requests, queue jobs, and console commands share a database, a cache, and file storage.

## Pick the checker

No tool runs real PHP code under every order of steps. In a PHP app the bugs of order sit between processes: two requests, a request and a queue job, a scheduled command, a retried webhook. So for a question about order, write a TLA+ model, check it with `tla-check`, and tie it to the code with a trace from PHPUnit.

For logic inside one process, such as money math or the rules of a state machine, test the real code with generated inputs, and say that it is a test and not a proof. PHPStan and Psalm check types, not the rule.

## Where a model of PHP code goes wrong

A step of the model must be one indivisible step of the code. Check each of these against the code, and cite its line in the record.

- **Each request, queue job, and console command is a process of its own.** It shares nothing in memory with the others. They share the database, the cache, the session store, and file storage.
- **One step is one SQL statement outside a transaction, or the commit of a whole transaction.** Other processes see none of a transaction's rows before its commit. A read followed by a write is two steps for another process, also inside one transaction, unless the read locks the row with `lockForUpdate()` or the write checks the value that it read, as in `UPDATE ... WHERE col = ?`. Write down the isolation level of the production database: PostgreSQL defaults to READ COMMITTED, and MySQL with InnoDB to REPEATABLE READ.
- **The ORM hides steps.** `firstOrCreate` and `updateOrCreate` are a select and then an insert or an update. Loading a model, changing it, and calling `save()` is a read and then a write. `increment()` is one statement. Model events and observers run in the same process, just before their statement.
- **A value that a process keeps is the value from when it read it.** A static, a singleton, a memo for the request, or `once()` keeps what it read for the life of the process: the request, the job, or the whole console command. A step that uses it later uses an old value. Check what the app resets between queue jobs. Under Octane, or another server that keeps workers alive, a worker lives across requests.
- **A process can stop after any step.** A timeout, a fatal error, or a deploy ends a request. A queue job can run twice, after a failure or when it runs longer than the queue's `retry_after`. A job dispatched inside a transaction can run before that transaction commits, or after it rolled back, unless it is dispatched after the commit.
- **A cache lock expires.** A holder that runs longer than the lock's time lets a second holder in.
- **SQLite does not show a race.** `lockForUpdate()` does nothing on SQLite, and an in-memory SQLite test database is not visible to a second connection. Run a race on the database engine of production.

## Tie a model to the code with a trace

- **Run the processes in one PHPUnit test, and switch between them at the steps that matter.** A `DB::listen` callback runs after each statement, and before the code uses its result. To run one process whole in a gap of another, call it from that callback. To stop a process halfway and go on with it later, run each process as a `Fiber`, call `Fiber::suspend()` in the callback, and let a scheduler with a seed pick which one resumes. A fiber can stop also in the middle of `chunkById` and `lazyById`. An exception thrown from the callback stands for a process that dies there.
- **Give each simulated process state of its own.** In one test they share every static, singleton, and memo. Give each its own request, with `app()->instance('request', Request::create('/'))`, and clear the memos and statics of the app between them. A real HTTP call through the kernel binds its own request, so when a scheduler switches between fibers, it must put back that fiber's request, its signed-in user, and any other state that the app keeps globally, such as the current tenant. Read the result as a later request would. If you do not, a value that one process read is used by the next, and that hides the bug.
- **Give each simulated process its own database connection,** cloned from the default one in the config and made the default while that process runs. Transactions are per connection: on one shared connection, one process sees the rows that another has not committed.
- **Log from `DB::listen` and from storage.** The callback gets each statement and its bindings. For files, register a subclass of the storage adapter with `Storage::set`. Match each statement by its table and its kind, not by every clause: an exact match turns a changed statement into a missing line, where it should be a step that the model rejects.
- **Write the log before the code can throw,** or flush it in a `finally`, so that a run that fails still leaves its log.
- **On PostgreSQL,** `RefreshDatabase` runs each test inside a transaction that a second connection cannot see. Set `$connectionsToTransact = []` in that test, and start from `migrate:fresh`. A server for a test can come from `initdb` and `pg_ctl` with their folders in a scratch folder. A Unix socket path longer than about 100 bytes fails, so use TCP on 127.0.0.1. PHPUnit's `<env>` does not replace a variable that the environment already sets, so a `DB_HOST` or `DB_PORT` in the environment wins.

## Scratch copies and faults

- **Copy `vendor/` into a scratch copy, with `cp -a` or with hard links. Never link to it.** Composer's autoloader loads the app's classes from the folder next to `vendor/` as PHP resolves it, so through a link the check runs the code of the original tree, not the patched copy.
- `.env` is ignored by git, and the app needs one. Make it from `.env.example` with a new key. Never copy the real `.env`.
- Keep a replay of a race outside `tests/`, and run it by its path, so that the suite stays green while the finding stands.

## The record

- Name the database engine and its version for production, for the test suite, and for each replay, and the isolation level that the model assumes. When the repo does not show the version of production, say so.
- Name each value that a process keeps for its whole life and that the model depends on, such as a key or a setting read once per request.
- When the model trusts the database, such as a row lock or a unique index, say so: `drift.sh` sees the migration only when the record cites it.
