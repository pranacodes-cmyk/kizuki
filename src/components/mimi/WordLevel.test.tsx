import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { dueKeysOf, useApp } from "@/lib/store";
import { WordLevelSheet } from "./WordLevel";

vi.mock("./ui", () => ({
  Sheet: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  Button: ({ children, variant: _variant, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: string }) => <button {...props}>{children}</button>,
  Hi: ({ text }: { text: string }) => <span>{text.replace(/[[\]]/g, "")}</span>,
}));

afterEach(cleanup);

describe("simple familiarity controls", () => {
  it("Learning keeps the existing spaced review date", () => {
    useApp.getState().reset();
    useApp.getState().saveWord({ dictId: null, base: "食べる", word: "食べる", reading: "たべる", romaji: "taberu", gloss: "to eat", pos: "verb", jlpt: 5, surface: "食べる", clipId: "test", line: 0, idx: 0 });
    const word = Object.values(useApp.getState().words)[0];
    if (!word) throw new Error("Saved word missing");
    useApp.getState().setWordLevel(word.key, 3);
    const before = useApp.getState().words[word.key]?.card.due;
    render(<WordLevelSheet open onClose={() => {}} wordKey={word.key} word={word.word} />);
    fireEvent.click(screen.getByRole("button", { name: /Learning/ }));
    expect(useApp.getState().words[word.key]?.card.due).toBe(before);
    expect(useApp.getState().words[word.key]?.card.interval).toBe(3);
    fireEvent.click(screen.getByRole("button", { name: /Known/ }));
    expect(useApp.getState().words[word.key]?.status).toBe("known");
    expect(dueKeysOf(useApp.getState())).toEqual([]);
  });
});