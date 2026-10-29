// Tests for the presence switch in src/control/presence.ts: AGENT_OFFICE_PRESENCE turns the process
// scan off like --no-presence does (the Docker setup relies on it), anything else leaves it on.
import test, { after } from "node:test";
import assert from "node:assert/strict";
import { cleanup, load } from "./control.session-fakes.mjs";

const { presenceOffByEnv } = await load("src/control/presence.ts");
after(cleanup);

test("AGENT_OFFICE_PRESENCE=0, false, off or no turns presence off", () => {
  for (const v of ["0", "false", "off", "no", " OFF ", "No"]) assert.equal(presenceOffByEnv({ AGENT_OFFICE_PRESENCE: v }), true, v);
});

test("presence stays on when the variable is unset, empty or anything else", () => {
  assert.equal(presenceOffByEnv({}), false);
  for (const v of ["", "1", "true", "on", "yes"]) assert.equal(presenceOffByEnv({ AGENT_OFFICE_PRESENCE: v }), false, v);
});
