// Crawl-readable copy of the pages that app stores fetch: /support (account deletion),
// /privacy and /terms. The interactive screens only mount after hydration, so without this
// the served HTML would be empty and a reviewer or crawler fetching the deletion link would
// see nothing. Plain markup, no animation, no browser-only state — it must render identically
// on the server and in the client's first render, or hydration would mismatch.
import { useLocation } from "@tanstack/react-router";

import { LEGAL_CONTACT_EMAIL, LEGAL_DELETE_ACCOUNT_URL, LEGAL_DEVELOPER_NAME, PRIVACY, TERMS, type LegalDoc } from "@/lib/legal";
import { DELETE_ACCOUNT_COPY, SUPPORT_FAQ } from "@/lib/support";

export function StaticRouteContent() {
  const { pathname } = useLocation();
  if (pathname === "/support") return <SupportStatic />;
  if (pathname === "/privacy") return <LegalStatic doc={PRIVACY} />;
  if (pathname === "/terms") return <LegalStatic doc={TERMS} />;
  return null;
}

const SHELL = "absolute inset-0 overflow-y-auto bg-background px-6 pb-20 pt-10 text-foreground";

function SupportStatic() {
  return (
    <div className={SHELL}>
      <h1 className="text-[1.5rem] font-black">Help &amp; support — Kizuki</h1>
      <p className="mt-2 text-[0.9375rem] leading-relaxed text-muted-foreground">
        Kizuki is the Japanese learning app for Android and iPhone, operated by {LEGAL_DEVELOPER_NAME} ({LEGAL_CONTACT_EMAIL}).
      </p>

      <h2 className="mt-8 text-[1.125rem] font-black">{DELETE_ACCOUNT_COPY.title}</h2>
      <p className="mt-2 text-[0.9375rem] leading-relaxed text-muted-foreground">{DELETE_ACCOUNT_COPY.intro}</p>
      <p className="mt-4 text-[0.9375rem] font-extrabold">{DELETE_ACCOUNT_COPY.stepsTitle}</p>
      <p className="mt-1 text-[0.9375rem] leading-relaxed text-muted-foreground">{DELETE_ACCOUNT_COPY.steps}</p>
      <p className="mt-4 text-[0.9375rem] font-extrabold">{DELETE_ACCOUNT_COPY.webTitle}</p>
      <p className="mt-1 text-[0.9375rem] leading-relaxed text-muted-foreground">
        Email {LEGAL_CONTACT_EMAIL} from the address you signed up with, or follow the instructions at{" "}
        {LEGAL_DELETE_ACCOUNT_URL}. We delete your account and data within 30
        days of a verified request.
      </p>
      <p className="mt-4 text-[0.8125rem] leading-relaxed text-faint">{DELETE_ACCOUNT_COPY.kept}</p>

      <h2 className="mt-8 text-[1.125rem] font-black">Common questions</h2>
      <dl className="mt-3 space-y-4">
        {SUPPORT_FAQ.map((f) => (
          <div key={f.q}>
            <dt className="text-[0.9375rem] font-extrabold">{f.q}</dt>
            <dd className="mt-1 text-[0.9375rem] leading-relaxed text-muted-foreground">{f.a}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

function LegalStatic({ doc }: { doc: LegalDoc }) {
  return (
    <div className={SHELL}>
      <h1 className="text-[1.5rem] font-black">{doc.title}</h1>
      <p className="mt-2 text-[0.8125rem] font-bold text-faint">Last updated: {doc.updated}</p>
      <p className="mt-3 text-[0.9375rem] leading-relaxed text-muted-foreground">{doc.intro}</p>
      {doc.sections.map((s) => (
        <section key={s.h} className="mt-7">
          <h2 className="text-[1.0625rem] font-black leading-snug">{s.h}</h2>
          <div className="mt-2 space-y-2">
            {s.body.map((line) => (
              <p key={line} className="text-[0.9375rem] leading-relaxed text-muted-foreground">
                {line}
              </p>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
