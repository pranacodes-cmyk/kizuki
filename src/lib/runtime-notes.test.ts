import { describe, expect, it } from "vitest";
import { runtimeNotes } from "../../scripts/content/runtime-notes";

describe("runtime note export", () => {
  it("retains all learning content but excludes build-only metadata", () => {
    const source = { sig: "build-only", w: { "0.0": { m: "apple", n: "Names the fruit." } }, l: { "0": { lit: "Apple!", tip: "A noun exclamation." } } };
    expect(JSON.parse(runtimeNotes(source))).toEqual({ w: source.w, l: source.l });
    expect(runtimeNotes(source).length).toBeLessThan(JSON.stringify(source, null, 2).length);
  });
});