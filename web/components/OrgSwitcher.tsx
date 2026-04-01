'use client'

import { useState, useRef, useEffect } from 'react'
import { useRouter } from 'next/navigation'

interface Org {
  id: string
  name: string
  slug: string
  type: string
  plan: string
}

interface OrgSwitcherProps {
  currentSlug: string
  currentOrgName: string
  orgs: Array<{ role: string; org: Org }>
}

const ROLE_BADGE: Record<string, string> = {
  owner: 'bg-purple-100 text-purple-700',
  admin: 'bg-blue-100 text-blue-700',
  teacher: 'bg-green-100 text-green-700',
  student: 'bg-gray-100 text-gray-600',
}

export default function OrgSwitcher({ currentSlug, currentOrgName, orgs }: OrgSwitcherProps) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const router = useRouter()

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  if (orgs.length <= 1) {
    return <span className="text-lg font-semibold text-gray-800">{currentOrgName}</span>
  }

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 text-lg font-semibold text-gray-800 hover:text-blue-600 transition-colors"
      >
        {currentOrgName}
        <svg
          className={`w-4 h-4 transition-transform ${open ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {open && (
        <div className="absolute top-full left-0 mt-2 w-72 bg-white rounded-xl shadow-lg border border-gray-200 py-2 z-50">
          <div className="px-3 py-1.5 text-xs font-medium text-gray-400 uppercase tracking-wider">
            Organizations
          </div>
          {orgs.map(({ role, org }) => (
            <button
              key={org.slug}
              onClick={() => {
                if (org.slug !== currentSlug) {
                  router.push(`/org/${org.slug}`)
                }
                setOpen(false)
              }}
              className={`w-full text-left px-3 py-2.5 flex items-center justify-between hover:bg-gray-50 transition-colors ${
                org.slug === currentSlug ? 'bg-blue-50' : ''
              }`}
            >
              <div>
                <div className="font-medium text-gray-900 text-sm">{org.name}</div>
                <div className="text-xs text-gray-500 capitalize">{org.type.replace('_', ' ')}</div>
              </div>
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${ROLE_BADGE[role] || ROLE_BADGE.student}`}>
                {role}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
