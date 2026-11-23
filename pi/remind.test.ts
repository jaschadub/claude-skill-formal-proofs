// Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
// Self-check for the Pi extension, with a stand-in for Pi: an edit gets the reminder that remind.sh prints,
// and another tool is left alone. Run: node --test pi/remind.test.ts
import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "./remind.ts";

test("an edit gets the reminder, another tool does not", async () => {
	const calls: string[][] = [];
	let handler: (event: object, ctx: object) => Promise<{ content: { text: string }[] } | undefined>;
	const pi = {
		on: (_name: string, fn: typeof handler) => {
			handler = fn;
		},
		exec: async (_command: string, args: string[]) => {
			calls.push(args);
			return { stdout: "reminder\n" };
		},
	};
	extension(pi as never);
	const event = { toolName: "edit", input: { path: "src/a.rs" }, content: [{ type: "text", text: "done" }] };
	const result = await handler!(event, { cwd: "/repo" });
	assert.match(calls[0][0], /hooks[/\\]remind\.sh$/);
	assert.equal(calls[0][1], "/repo/src/a.rs");
	assert.deepEqual(result?.content.map((part) => part.text), ["done", "reminder"]);
	assert.equal(await handler!({ ...event, toolName: "bash" }, { cwd: "/repo" }), undefined);
	assert.equal(calls.length, 1);
});
