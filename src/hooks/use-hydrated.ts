import { useEffect, useState } from "react";

/** True after the first client render — gate anything that reads browser storage. */
export function useHydrated() {
  const [h, setH] = useState(false);
  useEffect(() => setH(true), []);
  return h;
}
