import { create } from "zustand";

import { haptic } from "./haptics";

export type Toast = { id: number; title: string; description?: string; icon?: string; tone?: "default" | "achievement" | "error" };

type UI = {
  toasts: Toast[];
  /** True while the cold-start splash covers the app; entrances wait for it (SplashGate in Flutter). */
  splashing: boolean;
  setSplashing: (v: boolean) => void;
  toast: (t: Omit<Toast, "id">) => void;
  dismiss: (id: number) => void;
};

let seq = 1;

export const useUI = create<UI>((set, get) => ({
  toasts: [],
  splashing: true,
  setSplashing: (splashing) => set({ splashing }),
  toast: (t) => {
    const id = seq++;
    if (t.tone === "achievement") haptic("celebrate");
    if (t.tone === "error") haptic("error");
    set({ toasts: [...get().toasts.slice(-2), { ...t, id }] });
    setTimeout(() => get().dismiss(id), t.tone === "achievement" ? 4200 : 3000);
  },
  dismiss: (id) => set({ toasts: get().toasts.filter((x) => x.id !== id) }),
}));

export const toast = (t: Omit<Toast, "id">) => useUI.getState().toast(t);
