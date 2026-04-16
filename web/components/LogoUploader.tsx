'use client'

import { useRef, useState } from 'react'
import { useRouter } from 'next/navigation'

const MAX_BYTES = 512 * 1024
const ALLOWED = ['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']

interface Props {
  slug: string
  orgName: string
  currentLogoUrl: string | null
}

export default function LogoUploader({ slug, orgName, currentLogoUrl }: Props) {
  const router = useRouter()
  const fileInput = useRef<HTMLInputElement>(null)
  const [preview, setPreview] = useState<string | null>(currentLogoUrl)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  async function onChange(e: React.ChangeEvent<HTMLInputElement>) {
    setError(null)
    setSuccess(null)

    const file = e.target.files?.[0]
    if (!file) return

    if (!ALLOWED.includes(file.type)) {
      setError('Logo must be PNG, JPG, WebP, or SVG.')
      return
    }
    if (file.size > MAX_BYTES) {
      setError(`Logo must be under 512KB. Yours is ${(file.size / 1024).toFixed(0)}KB.`)
      return
    }

    // Local preview immediately.
    const reader = new FileReader()
    reader.onload = () => setPreview(reader.result as string)
    reader.readAsDataURL(file)

    setUploading(true)
    try {
      const fd = new FormData()
      fd.append('file', file)
      const res = await fetch(`/api/org/${slug}/logo`, {
        method: 'POST',
        body: fd,
      })
      const body = await res.json().catch(() => ({}))
      if (!res.ok) {
        const msg =
          body?.error === 'file_too_large'
            ? 'Logo must be under 512KB.'
            : body?.error === 'invalid_mime_type'
              ? 'Logo must be PNG, JPG, WebP, or SVG.'
              : body?.error || 'Upload failed.'
        setError(msg)
        setPreview(currentLogoUrl)
        return
      }
      setPreview(body.logo_url)
      setSuccess('Logo updated.')
      router.refresh()
    } catch {
      setError('Network error. Try again.')
      setPreview(currentLogoUrl)
    } finally {
      setUploading(false)
      if (fileInput.current) fileInput.current.value = ''
    }
  }

  async function onRemove() {
    if (!confirm(`Remove the logo for ${orgName}?`)) return
    setError(null)
    setSuccess(null)
    setUploading(true)
    try {
      const res = await fetch(`/api/org/${slug}/logo`, { method: 'DELETE' })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        setError(body?.error || 'Failed to remove logo.')
        return
      }
      setPreview(null)
      setSuccess('Logo removed.')
      router.refresh()
    } catch {
      setError('Network error. Try again.')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <h2 className="text-lg font-semibold text-gray-900 mb-1">Organization Logo</h2>
      <p className="text-sm text-gray-500 mb-4">
        Shown in the top-left of your dashboard and on the printable setup guide.
        PNG, JPG, WebP, or SVG. Max 512KB.
      </p>

      <div className="flex items-center gap-6">
        <div className="w-24 h-24 rounded-2xl border-2 border-dashed border-gray-200 bg-gray-50 flex items-center justify-center overflow-hidden shrink-0">
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={preview} alt={`${orgName} logo`} className="w-full h-full object-contain" />
          ) : (
            <span className="text-xs text-gray-400 text-center px-2 leading-tight">No logo</span>
          )}
        </div>

        <div className="flex-1 space-y-2">
          <div className="flex flex-wrap gap-2">
            <label
              className={`inline-flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium cursor-pointer transition-colors ${
                uploading
                  ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                  : 'bg-blue-600 text-white hover:bg-blue-700'
              }`}
            >
              <input
                ref={fileInput}
                type="file"
                accept={ALLOWED.join(',')}
                onChange={onChange}
                disabled={uploading}
                className="hidden"
              />
              {uploading ? 'Uploading…' : preview ? 'Replace logo' : 'Upload logo'}
            </label>
            {preview && !uploading && (
              <button
                type="button"
                onClick={onRemove}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 transition-colors"
              >
                Remove
              </button>
            )}
          </div>
          {error && <p className="text-sm text-red-600">{error}</p>}
          {success && <p className="text-sm text-green-600">{success}</p>}
        </div>
      </div>
    </div>
  )
}
