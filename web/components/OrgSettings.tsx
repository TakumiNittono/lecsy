'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

interface OrgSettingsProps {
  slug: string
  org: {
    name: string
    type: string
    plan: string
  }
  role: string
}

const planBadgeColors: Record<string, string> = {
  starter: 'bg-gray-100 text-gray-700',
  growth: 'bg-blue-100 text-blue-700',
  enterprise: 'bg-purple-100 text-purple-700',
}

export default function OrgSettings({ slug, org, role }: OrgSettingsProps) {
  const router = useRouter()
  const [name, setName] = useState(org.name)
  const [saving, setSaving] = useState(false)
  const [saveMessage, setSaveMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [deleteConfirm, setDeleteConfirm] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const handleSaveName = async () => {
    if (!name.trim() || name.trim() === org.name) return

    setSaving(true)
    setSaveMessage(null)
    try {
      const res = await fetch(`/api/org/${slug}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name.trim() }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error || 'Failed to update organization name')
      }
      setSaveMessage({ type: 'success', text: 'Organization name updated successfully.' })
      router.refresh()
    } catch (err: any) {
      setSaveMessage({ type: 'error', text: err.message })
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (deleteConfirm !== org.name) return

    setDeleting(true)
    setDeleteError(null)
    try {
      const res = await fetch(`/api/org/${slug}`, {
        method: 'DELETE',
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error || 'Failed to delete organization')
      }
      router.push('/app')
    } catch (err: any) {
      setDeleteError(err.message)
      setDeleting(false)
    }
  }

  return (
    <div className="space-y-8 max-w-2xl">
      {/* Edit org name */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Organization Name</h2>
        <div className="flex gap-3">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Organization name"
          />
          <button
            onClick={handleSaveName}
            disabled={saving || !name.trim() || name.trim() === org.name}
            className="px-5 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
        {saveMessage && (
          <p className={`mt-3 text-sm ${saveMessage.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>
            {saveMessage.text}
          </p>
        )}
      </div>

      {/* Org info */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Organization Info</h2>
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-500">Type</span>
            <span className="text-sm font-medium text-gray-900 capitalize">{org.type}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-500">Plan</span>
            <span className={`px-3 py-1 rounded-full text-xs font-semibold capitalize ${planBadgeColors[org.plan] || planBadgeColors.starter}`}>
              {org.plan}
            </span>
          </div>
        </div>
      </div>

      {/* Danger zone - owner only */}
      {role === 'owner' && (
        <div className="bg-white rounded-xl shadow-sm border-2 border-red-200 p-6">
          <h2 className="text-lg font-semibold text-red-700 mb-2">Danger Zone</h2>
          <p className="text-sm text-gray-500 mb-4">
            Once you delete an organization, there is no going back. All members will be removed and all data will be permanently deleted.
          </p>
          <button
            onClick={() => setShowDeleteModal(true)}
            className="px-5 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete Organization
          </button>
        </div>
      )}

      {/* Delete confirmation modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-lg max-w-md w-full mx-4 p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Delete Organization</h3>
            <p className="text-sm text-gray-600 mb-4">
              This action cannot be undone. To confirm, type <span className="font-semibold text-gray-900">{org.name}</span> below.
            </p>
            <input
              type="text"
              value={deleteConfirm}
              onChange={(e) => setDeleteConfirm(e.target.value)}
              placeholder={org.name}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent mb-4"
            />
            {deleteError && (
              <p className="text-sm text-red-600 mb-4">{deleteError}</p>
            )}
            <div className="flex justify-end gap-3">
              <button
                onClick={() => {
                  setShowDeleteModal(false)
                  setDeleteConfirm('')
                  setDeleteError(null)
                }}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                disabled={deleteConfirm !== org.name || deleting}
                className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {deleting ? 'Deleting...' : 'Delete Organization'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
