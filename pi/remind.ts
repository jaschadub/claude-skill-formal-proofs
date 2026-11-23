// Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
// Pi extension: after an edit to verified code that no longer matches its VERIFY.md record,
// add a reminder to the tool result. The work is done by hooks/remind.sh.
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const remind = resolve(dirname(fileURLToPath(import.meta.url)), "../hooks/remind.sh");

export default function (pi: ExtensionAPI) {
	pi.on("tool_result", async (event, ctx) => {
		const path = (event.input as { path?: string } | undefined)?.path;
		if (!path || (event.toolName !== "edit" && event.toolName !== "write")) return;
		const result = await pi.exec("sh", [remind, resolve(ctx.cwd, path)], { timeout: 10000 });
		const text = result.stdout.trim();
		if (!text) return;
		return {
			content: [...event.content, { type: "text" as const, text }],
			structuredContent: event.structuredContent,
		};
	});
}
