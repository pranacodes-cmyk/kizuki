import type { Session } from "@supabase/supabase-js";
import { useEffect, useState } from "react";

import { getSession, onSession } from "@/lib/sync";

export function useSession() {
  const [s, setS] = useState<Session | null>(null);
  useEffect(() => {
    setS(getSession());
    const off = onSession(setS);
    return () => { off(); };
  }, []);
  return s;
}
