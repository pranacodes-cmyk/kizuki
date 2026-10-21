import { create } from "zustand";

export type Toast = { id: number; title: string; description?: string; icon?: string; tone?: "default" | "achievement" | "error" };

type UI = {
  toasts: Toast[];
  toast: (t: Omit<Toast, "id">) => void;
  dismiss: (id: number) => void;
};

let seq = 1;

export const useUI = create<UI>((set, get) => ({
  toasts: [],
  toast: (t) => {
    const id = seq++;
    set({ toasts: [...get().toasts.slice(-2), { ...t, id }] });
    setTimeout(() => get().dismiss(id), t.tone === "achievement" ? 4200 : 3000);
  },
  dismiss: (id) => set({ toasts: get().toasts.filter((x) => x.id !== id) }),
}));

export const toast = (t: Omit<Toast, "id">) => useUI.getState().toast(t);
