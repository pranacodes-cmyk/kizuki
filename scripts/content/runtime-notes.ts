/** Only learner-facing fields are bundled; token signatures stay in the source cache. */
export function runtimeNotes(source: { w?: unknown; l?: unknown }) {
  return JSON.stringify({ w: source.w ?? {}, l: source.l ?? {} });
}