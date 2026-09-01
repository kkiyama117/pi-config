import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Default timeout (seconds) applied to bash tool calls that don't set one.
const DEFAULT_TIMEOUT = 300;

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event) => {
		if (event.toolName === "bash" && event.input?.timeout === undefined) {
			event.input.timeout = DEFAULT_TIMEOUT;
		}
	});
}
