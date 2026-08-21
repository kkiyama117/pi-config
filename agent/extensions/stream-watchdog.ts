// Stream stall watchdog — plugin-level fix for pi issue #8331
// ("Agent loop hangs forever when a provider stream stalls mid-response").
//
// A provider SSE stream that stalls mid-response (no events, socket stays open)
// otherwise hangs the agent loop forever: the `for await` never resolves and the
// TUI freezes behind a live spinner. This extension tracks per-event activity
// during a turn and calls `ctx.abort()` after the inactivity threshold — the
// abort reaches the provider request (same path as Escape), tearing down the
// wedged connection and ending the turn with a normal provider error.
//
// Tune with PI_STREAM_INACTIVITY_MS (default 300000 ms = 5 min; 0 disables).
// Tool execution pauses the watchdog, so long-running tools are unaffected.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default function streamWatchdog(pi: ExtensionAPI): void {
	const ms = Number(process.env.PI_STREAM_INACTIVITY_MS ?? 300000);
	if (!ms || Number.isNaN(ms)) return;

	let lastActivity = 0; // 0 = not streaming
	let inTool = false;
	let ctx: ExtensionContext | undefined;

	const touch = (): void => {
		lastActivity = Date.now();
	};

	pi.on("turn_start", (_event, eventCtx) => {
		ctx = eventCtx;
		inTool = false;
		touch();
	});
	pi.on("message_start", touch);
	pi.on("message_update", touch);
	pi.on("tool_execution_start", () => {
		inTool = true;
		touch();
	});
	pi.on("tool_execution_end", () => {
		inTool = false;
		touch();
	});
	pi.on("turn_end", () => {
		lastActivity = 0;
	});
	pi.on("agent_settled", () => {
		lastActivity = 0;
	});

	const timer = setInterval(() => {
		if (!lastActivity || !ctx || inTool) return;
		try {
			if (ctx.isIdle()) {
				lastActivity = 0;
				return;
			}
		} catch {
			ctx = undefined;
			lastActivity = 0;
			return;
		}
		if (Date.now() - lastActivity > ms) {
			const stalledFor = Math.round((Date.now() - lastActivity) / 1000);
			console.warn(`[stream-watchdog] aborting stalled turn (no events for ${stalledFor}s)`);
			lastActivity = 0;
			try {
				ctx.abort();
			} catch {
				ctx = undefined;
			}
		}
	}, 15_000);
	timer.unref?.();
}
