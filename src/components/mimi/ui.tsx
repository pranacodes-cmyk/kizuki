import { AnimatePresence, motion } from "motion/react";
import { ChevronLeft } from "lucide-react";
import { useEffect, useState, type ButtonHTMLAttributes, type ReactNode } from "react";
import { createPortal } from "react-dom";

import { haptic } from "@/lib/haptics";
import { cn } from "@/lib/utils";

import { LivelyMascot, Mascot } from "./Mascot";

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "surface" | "ghost" | "danger" | "success"; size?: "lg" | "md" | "sm" };

/** 3D press button — mirrored by Button3D in mobile/lib/widgets/ui.dart. */
export function Button({ variant = "primary", size = "lg", className, children, onClick, ...rest }: BtnProps) {
  return (
    <button
      {...rest}
      onClick={onClick ? (e) => { haptic("tap"); onClick(e); } : undefined}
      className={cn(
        "inline-flex select-none items-center justify-center gap-2 rounded-2xl font-extrabold tracking-[0.01em] disabled:cursor-not-allowed",
        size === "lg" && "h-14 w-full px-6 text-[1.0625rem]",
        size === "md" && "h-12 px-5 text-[0.9375rem]",
        size === "sm" && "h-10 px-4 text-[0.875rem]",
        variant === "primary" && "btn-3d bg-primary text-primary-foreground disabled:bg-primary-dim disabled:text-primary-dim-foreground",
        variant === "surface" && "btn-3d-surface bg-surface-2 text-foreground",
        variant === "ghost" && "press bg-transparent text-muted-foreground",
        variant === "danger" && "press border-2 border-danger/70 bg-transparent text-danger",
        variant === "success" && "press bg-success text-primary-foreground",
        className,
      )}
    >
      {children}
    </button>
  );
}

/** Full-height screen column with safe-area padding. */
export function Screen({ children, className, scroll = true }: { children: ReactNode; className?: string; scroll?: boolean }) {
  return (
    <div
      className={cn(
        "absolute inset-0 flex flex-col bg-background pt-[calc(var(--sat)+8px)] pb-[calc(var(--sab)+12px)]",
        scroll ? "overflow-y-auto no-scrollbar" : "overflow-hidden",
        className,
      )}
    >
      {children}
    </div>
  );
}

/** Onboarding header: back chevron + orange progress with Kizuki riding the end — he hops
 * forward (or back) each time the progress changes. */
export function ProgressHeader({ progress, onBack }: { progress: number; onBack?: () => void }) {
  return (
    <div className="flex h-12 shrink-0 items-center gap-3 px-4">
      <button aria-label="Back" onClick={onBack} disabled={!onBack} className="press -ml-1 flex h-10 w-10 items-center justify-center rounded-full text-muted-foreground disabled:opacity-0">
        <ChevronLeft className="h-7 w-7" strokeWidth={2.6} />
      </button>
      <div className="relative h-3.5 flex-1 rounded-full bg-surface-2">
        <motion.div className="absolute inset-y-0 left-0 rounded-full bg-primary" initial={false} animate={{ width: `${Math.max(6, progress * 100)}%` }} transition={{ type: "spring", stiffness: 160, damping: 24 }} />
        <motion.div className="absolute -top-[11px] h-9 w-9" initial={false} animate={{ left: `calc(${Math.max(6, progress * 100)}% - 18px)` }} transition={{ type: "spring", stiffness: 160, damping: 24 }}>
          <LivelyMascot pose="face" size={36} idle="none" hopKey={progress} />
        </motion.div>
      </div>
      <div className="w-6" />
    </div>
  );
}

export function TopBar({ title, onBack, right }: { title?: ReactNode; onBack?: () => void; right?: ReactNode }) {
  return (
    <div className="flex h-12 shrink-0 items-center gap-2 px-3">
      {onBack ? (
        <button aria-label="Back" onClick={onBack} className="press flex h-10 w-10 items-center justify-center rounded-full text-foreground">
          <ChevronLeft className="h-7 w-7" strokeWidth={2.5} />
        </button>
      ) : (
        <div className="w-10" />
      )}
      <div className="flex-1 truncate text-center text-[1.0625rem] font-extrabold">{title}</div>
      <div className="flex min-w-10 justify-end">{right}</div>
    </div>
  );
}

export function Chip({ active, children, onClick, className }: { active?: boolean; children: ReactNode; onClick?: () => void; className?: string }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "press inline-flex h-9 shrink-0 items-center gap-1.5 rounded-full border-2 px-3.5 text-[0.875rem] font-bold",
        active ? "border-primary bg-primary/15 text-primary" : "border-border bg-surface text-muted-foreground",
        className,
      )}
    >
      {children}
    </button>
  );
}

export function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => { haptic("select"); onChange(!checked); }}
      className={cn("relative h-7 w-12 shrink-0 rounded-full transition-colors", checked ? "bg-success" : "bg-surface-3")}
    >
      <span className={cn("absolute top-0.5 h-6 w-6 rounded-full bg-foreground shadow transition-all", checked ? "left-[22px]" : "left-0.5")} />
    </button>
  );
}

/** Pill with a soft tint used for hints ("You can change this later"). */
export function Pill({ children, tone = "surface", className }: { children: ReactNode; tone?: "surface" | "success" | "primary"; className?: string }) {
  return (
    <div
      className={cn(
        "inline-flex items-center gap-2 rounded-full px-4 py-2 text-[0.875rem] font-bold",
        tone === "surface" && "bg-surface-2 text-muted-foreground",
        tone === "success" && "bg-success-soft text-success",
        tone === "primary" && "bg-primary/15 text-primary",
        className,
      )}
    >
      {children}
    </div>
  );
}

/** Bottom sheet rendered inside the device frame (#overlay-root). */
export function Sheet({ open, onClose, children, className, maxHeight = "86%" }: { open: boolean; onClose: () => void; children: ReactNode; className?: string; maxHeight?: string }) {
  const [root, setRoot] = useState<HTMLElement | null>(null);
  useEffect(() => setRoot(document.getElementById("overlay-root")), []);
  if (!root) return null;
  return createPortal(
    <AnimatePresence>
      {open && (
        <div className="pointer-events-auto absolute inset-0 z-50">
          <motion.div className="absolute inset-0 bg-stage/70" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} />
          <motion.div
            className={cn("absolute inset-x-0 bottom-0 flex flex-col overflow-hidden rounded-t-[28px] bg-surface pb-[calc(var(--sab)+8px)]", className)}
            style={{ maxHeight }}
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", stiffness: 380, damping: 36 }}
            drag="y"
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0, bottom: 0.6 }}
            onDragEnd={(_, info) => { if (info.offset.y > 120) onClose(); }}
          >
            <div className="mx-auto mt-2.5 h-1.5 w-10 shrink-0 rounded-full bg-surface-3" />
            {children}
          </motion.div>
        </div>
      )}
    </AnimatePresence>,
    root,
  );
}

/** Centered modal inside the device frame. */
export function Modal({ open, onClose, children, className }: { open: boolean; onClose?: () => void; children: ReactNode; className?: string }) {
  const [root, setRoot] = useState<HTMLElement | null>(null);
  useEffect(() => setRoot(document.getElementById("overlay-root")), []);
  if (!root) return null;
  return createPortal(
    <AnimatePresence>
      {open && (
        <div className="pointer-events-auto absolute inset-0 z-50 flex items-center justify-center px-6">
          <motion.div className="absolute inset-0 bg-stage/75" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} />
          <motion.div
            className={cn("relative w-full rounded-[28px] bg-surface p-6", className)}
            initial={{ opacity: 0, scale: 0.9, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ type: "spring", stiffness: 380, damping: 30 }}
          >
            {children}
          </motion.div>
        </div>
      )}
    </AnimatePresence>,
    root,
  );
}

export function SectionTitle({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return (
    <div className="mb-2 mt-6 flex items-center justify-between px-1">
      <h2 className="text-[1.0625rem] font-extrabold">{children}</h2>
      {right}
    </div>
  );
}

/** Bouncing mascot loader with an optional caption. */
export function MascotLoader({ label = "Loading…", className }: { label?: string; className?: string }) {
  return (
    <div className={cn("flex flex-col items-center justify-center gap-3", className)} role="status">
      <motion.div animate={{ y: [0, -14, 0] }} transition={{ repeat: Infinity, duration: 0.9, ease: "easeInOut" }}>
        <Mascot pose="listen" className="h-24 w-24" />
      </motion.div>
      <p className="text-[0.9375rem] font-bold text-muted-foreground">{label}</p>
    </div>
  );
}

/** Friendly error block with a retry action. */
export function ErrorState({ title = "Something went wrong", body, onRetry }: { title?: string; body?: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-8 text-center">
      <Mascot pose="think" className="h-24 w-24" />
      <p className="mt-1 text-[1.125rem] font-black">{title}</p>
      {body && <p className="text-[0.9375rem] text-muted-foreground">{body}</p>}
      {onRetry && <Button size="md" variant="surface" className="mt-3" onClick={onRetry}>Try again</Button>}
    </div>
  );
}
