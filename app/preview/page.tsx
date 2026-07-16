import { Card, StatusBadge } from "@/components/ui";
import { getPreviewRoutesBySection, previewRoutes, previewSections } from "@/lib/mock/preview-routes";

const statusSummary = [
  { label: "Built routes", value: previewRoutes.filter((route) => route.status === "Built").length, tone: "success" as const },
  { label: "Mock routes", value: previewRoutes.filter((route) => route.status === "Mock").length, tone: "warning" as const },
  {
    label: "Frontend-only notes",
    value: previewRoutes.filter((route) => route.status === "Frontend only").length,
    tone: "info" as const
  }
];

export default function PreviewPage() {
  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-6 text-[var(--color-charcoal)] sm:px-6 lg:px-10">
      <div className="mx-auto max-w-7xl space-y-6">
        <header className="overflow-hidden rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white shadow-[var(--shadow-sm)]">
          <div className="grid gap-6 p-6 lg:grid-cols-[1.4fr_1fr] lg:p-8">
            <div>
              <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Risellar Frontend Preview</p>
              <h1 className="mt-3 text-3xl font-extrabold leading-tight sm:text-4xl">Screen launcher for frontend QA</h1>
              <p className="mt-3 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">
                Review every built Risellar frontend surface from one internal page. All sensitive flows remain static,
                mock-data driven, and frontend-only until backend phases are explicitly approved.
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                <StatusBadge status="PWA/mobile-first" tone="success" />
                <StatusBadge status="Admin desktop" tone="info" />
                <StatusBadge status="Mock data only" tone="warning" />
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-1">
              {statusSummary.map((item) => (
                <div
                  className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-primary-subtle)] p-4"
                  key={item.label}
                >
                  <p className="text-xs font-semibold text-[var(--color-muted)]">{item.label}</p>
                  <div className="mt-2 flex items-center justify-between gap-3">
                    <p className="text-2xl font-extrabold text-[var(--color-primary)]">{item.value}</p>
                    <StatusBadge status={item.label.split(" ")[0]} tone={item.tone} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </header>

        <section aria-labelledby="quick-jump-heading" className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)]">
          <h2 id="quick-jump-heading" className="text-base font-bold">
            Jump to section
          </h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {previewSections.map((section) => (
              <a
                className="rounded-full border border-[var(--color-border)] px-3 py-2 text-xs font-bold text-[var(--color-primary)] transition-[var(--transition-fast)] hover:border-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]"
                href={`#${sectionId(section)}`}
                key={section}
              >
                {section}
              </a>
            ))}
          </div>
        </section>

        {previewSections.map((section) => {
          const routes = getPreviewRoutesBySection(section);

          return (
            <section aria-labelledby={`${sectionId(section)}-heading`} className="space-y-4" id={sectionId(section)} key={section}>
              <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                  <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{routes.length} screens</p>
                  <h2 id={`${sectionId(section)}-heading`} className="mt-1 text-xl font-extrabold">
                    {section}
                  </h2>
                </div>
                <StatusBadge status="Frontend only" tone="info" />
              </div>

              <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                {routes.map((route) => (
                  <Card className="flex h-full flex-col justify-between p-4" key={`${route.section}-${route.path}`}>
                    <div>
                      <div className="flex items-start justify-between gap-3">
                        <h3 className="text-sm font-extrabold leading-5">{route.title}</h3>
                        <StatusBadge status={route.status} />
                      </div>
                      <p className="mt-2 break-all rounded-[var(--radius-md)] bg-[var(--color-surface-muted)] px-3 py-2 text-xs font-semibold text-[var(--color-muted)]">
                        {route.path}
                      </p>
                      {route.note ? <p className="mt-3 text-xs leading-5 text-[var(--color-muted)]">{route.note}</p> : null}
                    </div>
                    <a
                      className="mt-4 inline-flex min-h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] px-4 text-sm font-bold text-[var(--color-primary)] transition-[var(--transition-fast)] hover:bg-[var(--color-primary-subtle)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]"
                      href={route.path}
                    >
                      Open {route.title}
                    </a>
                  </Card>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </main>
  );
}

function sectionId(section: string) {
  return section.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}
