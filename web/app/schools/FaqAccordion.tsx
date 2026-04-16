"use client";

interface FaqItem {
  q: string;
  a: string;
}

export default function FaqAccordion({ items }: { items: FaqItem[] }) {
  return (
    <div className="space-y-3">
      {items.map((item) => (
        <details
          key={item.q}
          className="group rounded-xl border border-[#E5E1D8] bg-white"
        >
          <summary className="flex items-center justify-between gap-4 p-5 cursor-pointer select-none list-none">
            <h3 className="font-[family-name:var(--font-display)] text-lg font-medium text-[#0B1E3F]">
              {item.q}
            </h3>
            <svg
              className="w-5 h-5 text-[#8A9BB5] group-open:rotate-45 transition-transform flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
          </summary>
          <p className="px-5 pb-5 text-[#4A5B74] text-[15px] leading-relaxed whitespace-pre-line">
            {item.a}
          </p>
        </details>
      ))}
    </div>
  );
}
