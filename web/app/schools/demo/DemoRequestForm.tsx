"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type FieldErrors = Partial<
  Record<"school_name" | "contact_name" | "contact_email" | "role" | "general", string>
>;

const ROLES = [
  "ELI / IEP Director",
  "ESL Coordinator",
  "Faculty",
  "IT / Procurement",
  "Other",
];

export default function DemoRequestForm() {
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors] = useState<FieldErrors>({});

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setErrors({});
    setSubmitting(true);

    const formData = new FormData(e.currentTarget);
    // Honeypot — bots auto-fill all fields; humans leave this empty.
    if (formData.get("website")) {
      setSubmitting(false);
      router.push("/schools/demo?sent=1");
      return;
    }

    const payload = {
      school_name: String(formData.get("school_name") ?? "").trim(),
      contact_name: String(formData.get("contact_name") ?? "").trim(),
      contact_email: String(formData.get("contact_email") ?? "").trim().toLowerCase(),
      role: String(formData.get("role") ?? "").trim(),
      phone: String(formData.get("phone") ?? "").trim() || undefined,
      notes: String(formData.get("notes") ?? "").trim() || undefined,
    };

    try {
      const res = await fetch("/api/schools/demo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        router.push("/schools/demo?sent=1");
        return;
      }

      const body = await res.json().catch(() => ({}));
      const code = body?.error ?? "unknown_error";
      const map: Record<string, FieldErrors> = {
        invalid_school_name: { school_name: "Please add your school name." },
        invalid_contact_name: { contact_name: "Please add your name." },
        invalid_email: { contact_email: "That doesn't look like a valid email." },
        invalid_role: { role: "Please select your role." },
        rate_limited: { general: "Too many requests. Try again in a minute." },
      };
      setErrors(map[code] ?? { general: "Something went wrong. Email founder@lecsy.app directly." });
    } catch {
      setErrors({ general: "Network error. Email founder@lecsy.app directly." });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="space-y-6 max-w-xl" noValidate>
      {/* Honeypot */}
      <input
        type="text"
        name="website"
        tabIndex={-1}
        autoComplete="off"
        className="hidden"
        aria-hidden="true"
      />

      <Field
        label="School / Program"
        name="school_name"
        placeholder="University of Florida — ELI"
        required
        error={errors.school_name}
      />

      <Field
        label="Your name"
        name="contact_name"
        placeholder="Jane Director"
        required
        error={errors.contact_name}
      />

      <Field
        label="Work email"
        name="contact_email"
        type="email"
        placeholder="jane.director@ufl.edu"
        required
        error={errors.contact_email}
      />

      <div>
        <label htmlFor="role" className="block text-sm font-medium text-[#0B1E3F] mb-2">
          Your role <span className="text-[#B03A2E]">*</span>
        </label>
        <select
          id="role"
          name="role"
          required
          defaultValue=""
          className="w-full h-11 px-3 rounded-xl border border-[#E5E1D8] bg-white text-[#0B1E3F] focus:border-[#0B1E3F] focus:ring-2 focus:ring-[#0B1E3F]/10 focus:outline-none"
        >
          <option value="" disabled>Select your role…</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>{r}</option>
          ))}
        </select>
        {errors.role && <p className="mt-1 text-sm text-[#B03A2E]">{errors.role}</p>}
      </div>

      <Field
        label="Phone (optional)"
        name="phone"
        type="tel"
        placeholder="+1 (352) 000-0000"
      />

      <div>
        <label htmlFor="notes" className="block text-sm font-medium text-[#0B1E3F] mb-2">
          What would be useful to talk through first? <span className="text-[#8A9BB5] font-normal">(optional)</span>
        </label>
        <textarea
          id="notes"
          name="notes"
          rows={4}
          placeholder="e.g. FERPA questions, seat count for summer cohort, integration with Canvas…"
          className="w-full px-3 py-3 rounded-xl border border-[#E5E1D8] bg-white text-[#0B1E3F] placeholder:text-[#8A9BB5] focus:border-[#0B1E3F] focus:ring-2 focus:ring-[#0B1E3F]/10 focus:outline-none resize-y"
        />
      </div>

      {errors.general && (
        <div className="rounded-xl border border-[#B03A2E]/30 bg-[#B03A2E]/5 px-4 py-3 text-sm text-[#B03A2E]">
          {errors.general}
        </div>
      )}

      <button
        type="submit"
        disabled={submitting}
        className="inline-flex items-center justify-center gap-2 h-12 px-8 rounded-full bg-[#0B1E3F] text-white font-semibold text-[15px] hover:bg-[#16315C] transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {submitting ? "Sending…" : "Request a pilot"}
        {!submitting && (
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
          </svg>
        )}
      </button>

      <p className="text-xs text-[#8A9BB5]">
        We reply within one business day. Your email goes to founder@lecsy.app only — never sold,
        never used for marketing.
      </p>
    </form>
  );
}

function Field({
  label,
  name,
  type = "text",
  required = false,
  placeholder,
  error,
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  placeholder?: string;
  error?: string;
}) {
  return (
    <div>
      <label htmlFor={name} className="block text-sm font-medium text-[#0B1E3F] mb-2">
        {label}
        {required && <span className="text-[#B03A2E]"> *</span>}
      </label>
      <input
        id={name}
        name={name}
        type={type}
        placeholder={placeholder}
        required={required}
        className="w-full h-11 px-3 rounded-xl border border-[#E5E1D8] bg-white text-[#0B1E3F] placeholder:text-[#8A9BB5] focus:border-[#0B1E3F] focus:ring-2 focus:ring-[#0B1E3F]/10 focus:outline-none"
      />
      {error && <p className="mt-1 text-sm text-[#B03A2E]">{error}</p>}
    </div>
  );
}
