'use client'

import { useState } from 'react'
import type { OrgRole } from '@/utils/api/org-auth'
import BulkInviteUpload from './BulkInviteUpload'

interface Member {
  id: string
  user_id: string | null
  role: string
  status: string
  joined_at: string
  email: string | null
  lastActive: string | null
}

interface MembersListProps {
  members: Member[]
  currentUserId: string
  currentUserRole: OrgRole
  slug: string
  maxSeats: number
}

const ROLE_BADGE_COLORS: Record<string, string> = {
  owner: 'bg-purple-100 text-purple-700',
  admin: 'bg-blue-100 text-blue-700',
  teacher: 'bg-green-100 text-green-700',
  student: 'bg-gray-100 text-gray-800',
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default function MembersList({
  members: initialMembers,
  currentUserId,
  currentUserRole,
  slug,
  maxSeats,
}: MembersListProps) {
  const [members, setMembers] = useState<Member[]>(initialMembers)
  const [search, setSearch] = useState('')
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loadingId, setLoadingId] = useState<string | null>(null)
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)

  // Add member form
  const [showAddForm, setShowAddForm] = useState(false)
  const [addEmails, setAddEmails] = useState('')
  const [addRole, setAddRole] = useState<string>('student')
  const [addLoading, setAddLoading] = useState(false)

  const canManage = currentUserRole === 'owner' || currentUserRole === 'admin'

  const filteredMembers = members.filter((m) => {
    if (!search) return true
    const q = search.toLowerCase()
    const display = m.email || m.user_id || ''
    return display.toLowerCase().includes(q) || m.role.toLowerCase().includes(q)
  })

  const seatUsage = members.length
  const seatPercent = maxSeats > 0 ? Math.min((seatUsage / maxSeats) * 100, 100) : 0

  function showMsg(type: 'success' | 'error', text: string) {
    setMessage({ type, text })
    setTimeout(() => setMessage(null), 4000)
  }

  function displayName(member: Member): string {
    if (member.email) return member.email
    if (member.user_id) return member.user_id.slice(0, 8) + '...'
    return 'Unknown'
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  async function handleAddMembers() {
    const emails = addEmails
      .split(/[,\n]/)
      .map((e) => e.trim().toLowerCase())
      .filter((e) => EMAIL_REGEX.test(e))

    if (emails.length === 0) {
      showMsg('error', 'Please enter valid email addresses')
      return
    }

    setAddLoading(true)
    try {
      const res = await fetch(`/api/org/${slug}/invites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ emails, role: addRole }),
      })
      const data = await res.json()
      if (!res.ok) {
        showMsg('error', data.error || 'Failed to add members')
        return
      }

      // Add new members to the list
      const newMembers: Member[] = (data.added || []).map((m: any) => ({
        ...m,
        user_id: null,
        lastActive: null,
      }))
      setMembers((prev) => [...prev, ...newMembers])

      const msgs = []
      if (newMembers.length > 0) msgs.push(`${newMembers.length} members added`)
      if (data.skipped?.length > 0) msgs.push(`${data.skipped.length} skipped (already members)`)
      showMsg('success', msgs.join(', '))

      setAddEmails('')
      setShowAddForm(false)
    } catch {
      showMsg('error', 'Network error. Please try again.')
    } finally {
      setAddLoading(false)
    }
  }

  async function handleRoleChange(memberId: string, newRole: string) {
    setLoadingId(memberId)
    setMessage(null)
    try {
      const res = await fetch(`/api/org/${slug}/members/${memberId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: newRole }),
      })
      const data = await res.json()
      if (!res.ok) {
        showMsg('error', data.error || 'Failed to update role')
        return
      }
      setMembers((prev) =>
        prev.map((m) => (m.id === memberId ? { ...m, role: newRole } : m))
      )
      showMsg('success', 'Role updated successfully')
    } catch {
      showMsg('error', 'Network error. Please try again.')
    } finally {
      setLoadingId(null)
    }
  }

  async function handleDelete(memberId: string) {
    setLoadingId(memberId)
    setConfirmDeleteId(null)
    setMessage(null)
    try {
      const res = await fetch(`/api/org/${slug}/members/${memberId}`, {
        method: 'DELETE',
      })
      const data = await res.json()
      if (!res.ok) {
        showMsg('error', data.error || 'Failed to remove member')
        return
      }
      setMembers((prev) => prev.filter((m) => m.id !== memberId))
      showMsg('success', 'Member removed successfully')
    } catch {
      showMsg('error', 'Network error. Please try again.')
    } finally {
      setLoadingId(null)
    }
  }

  function handleBulkAdded() {
    // Refresh the page to get updated member list
    window.location.reload()
  }

  return (
    <div className="space-y-6">
      {/* Seat usage */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-5">
        <div className="flex items-center justify-between mb-3">
          <div className="text-sm font-medium text-gray-900">
            Seat Usage
          </div>
          <div className="text-sm text-gray-900">
            <span className="font-semibold text-gray-900">{seatUsage}</span> / {maxSeats} seats used
          </div>
        </div>
        <div className="w-full bg-gray-100 rounded-full h-2.5">
          <div
            className={`h-2.5 rounded-full transition-all ${
              seatPercent >= 90 ? 'bg-red-500' : seatPercent >= 70 ? 'bg-amber-500' : 'bg-blue-500'
            }`}
            style={{ width: `${seatPercent}%` }}
          />
        </div>
      </div>

      {/* Message banner */}
      {message && (
        <div
          className={`px-4 py-3 rounded-lg text-sm font-medium ${
            message.type === 'success'
              ? 'bg-green-50 text-green-700 border border-green-200'
              : 'bg-red-50 text-red-700 border border-red-200'
          }`}
        >
          {message.text}
        </div>
      )}

      {/* Search + Add Member */}
      <div className="flex items-center gap-3">
        <div className="relative flex-1">
          <svg
            className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
          <input
            type="text"
            placeholder="Search members..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
        {canManage && (
          <button
            onClick={() => setShowAddForm(!showAddForm)}
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors shrink-0"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
              />
            </svg>
            Add Members
          </button>
        )}
      </div>

      {/* Add Members Form */}
      {showAddForm && canManage && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 space-y-4">
          <h3 className="font-semibold text-gray-900">Add Members by Email</h3>
          <p className="text-xs text-gray-900">
            Enter email addresses (comma or newline separated). Members will be activated automatically when they log in.
          </p>
          <textarea
            value={addEmails}
            onChange={(e) => setAddEmails(e.target.value)}
            placeholder="student1@example.com&#10;student2@example.com&#10;teacher@example.com"
            rows={4}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
          />
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <label className="text-sm text-gray-800">Role:</label>
              <select
                value={addRole}
                onChange={(e) => setAddRole(e.target.value)}
                className="text-sm border border-gray-300 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="student">Student</option>
                <option value="teacher">Teacher</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <div className="flex items-center gap-2 ml-auto">
              <button
                onClick={() => setShowAddForm(false)}
                className="px-4 py-2 text-sm text-gray-900 hover:text-gray-900"
              >
                Cancel
              </button>
              <button
                onClick={handleAddMembers}
                disabled={addLoading || !addEmails.trim()}
                className="px-5 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                {addLoading ? 'Adding...' : 'Add'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bulk CSV Upload */}
      {canManage && (
        <BulkInviteUpload slug={slug} onMembersAdded={handleBulkAdded} />
      )}

      {/* Members table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50/50">
                <th className="text-left px-6 py-3 font-medium text-gray-900">Member</th>
                <th className="text-left px-6 py-3 font-medium text-gray-900">Role</th>
                <th className="text-left px-6 py-3 font-medium text-gray-900">Status</th>
                <th className="text-left px-6 py-3 font-medium text-gray-900">Last Active</th>
                <th className="text-left px-6 py-3 font-medium text-gray-900">Added</th>
                {canManage && (
                  <th className="text-right px-6 py-3 font-medium text-gray-900">Actions</th>
                )}
              </tr>
            </thead>
            <tbody>
              {filteredMembers.length === 0 ? (
                <tr>
                  <td colSpan={canManage ? 6 : 5} className="px-6 py-12 text-center text-gray-800">
                    {search ? 'No members match your search.' : 'No members found.'}
                  </td>
                </tr>
              ) : (
                filteredMembers.map((member) => {
                  const isSelf = member.user_id === currentUserId
                  const isOwner = member.role === 'owner'
                  const canEdit = canManage && !isSelf && !isOwner
                  const isLoading = loadingId === member.id
                  const isPending = member.status === 'pending'

                  return (
                    <tr
                      key={member.id}
                      className={`border-b border-gray-50 hover:bg-gray-50 transition-colors ${isPending ? 'opacity-70' : ''}`}
                    >
                      {/* Member */}
                      <td className="px-6 py-3">
                        <div className="flex items-center gap-2">
                          <span className="text-gray-900 font-medium">
                            {displayName(member)}
                          </span>
                          {isSelf && (
                            <span className="px-1.5 py-0.5 rounded text-[10px] font-medium bg-gray-100 text-gray-800 uppercase">
                              You
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Role */}
                      <td className="px-6 py-3">
                        <span
                          className={`inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize ${
                            ROLE_BADGE_COLORS[member.role] || ROLE_BADGE_COLORS.student
                          }`}
                        >
                          {member.role}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="px-6 py-3">
                        {isPending ? (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                            <span className="w-1.5 h-1.5 bg-amber-500 rounded-full" />
                            Pending
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                            <span className="w-1.5 h-1.5 bg-green-500 rounded-full" />
                            Active
                          </span>
                        )}
                      </td>

                      {/* Last Active */}
                      <td className="px-6 py-3">
                        {isPending ? (
                          <span className="text-gray-800">--</span>
                        ) : member.lastActive ? (
                          <span className={
                            Date.now() - new Date(member.lastActive).getTime() > 30 * 24 * 60 * 60 * 1000
                              ? 'text-red-500 font-medium'
                              : Date.now() - new Date(member.lastActive).getTime() > 7 * 24 * 60 * 60 * 1000
                                ? 'text-amber-500'
                                : 'text-green-600'
                          }>
                            {formatDate(member.lastActive)}
                          </span>
                        ) : (
                          <span className="text-gray-800">Never</span>
                        )}
                      </td>

                      {/* Added */}
                      <td className="px-6 py-3 text-gray-900">
                        {formatDate(member.joined_at)}
                      </td>

                      {/* Actions */}
                      {canManage && (
                        <td className="px-6 py-3">
                          {canEdit ? (
                            <div className="flex items-center justify-end gap-2">
                              {/* Role selector */}
                              <select
                                value={member.role}
                                onChange={(e) => handleRoleChange(member.id, e.target.value)}
                                disabled={isLoading}
                                className="text-sm border border-gray-300 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
                              >
                                <option value="admin">Admin</option>
                                <option value="teacher">Teacher</option>
                                <option value="student">Student</option>
                              </select>

                              {/* Delete button */}
                              {confirmDeleteId === member.id ? (
                                <div className="flex items-center gap-1">
                                  <button
                                    onClick={() => handleDelete(member.id)}
                                    disabled={isLoading}
                                    className="px-2.5 py-1.5 text-xs font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50"
                                  >
                                    {isLoading ? 'Removing...' : 'Confirm'}
                                  </button>
                                  <button
                                    onClick={() => setConfirmDeleteId(null)}
                                    disabled={isLoading}
                                    className="px-2.5 py-1.5 text-xs font-medium text-gray-800 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors disabled:opacity-50"
                                  >
                                    Cancel
                                  </button>
                                </div>
                              ) : (
                                <button
                                  onClick={() => setConfirmDeleteId(member.id)}
                                  disabled={isLoading}
                                  className="p-1.5 text-gray-400 hover:text-red-600 rounded-lg hover:bg-red-50 transition-colors disabled:opacity-50"
                                  title="Remove member"
                                >
                                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path
                                      strokeLinecap="round"
                                      strokeLinejoin="round"
                                      strokeWidth={2}
                                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                                    />
                                  </svg>
                                </button>
                              )}
                            </div>
                          ) : (
                            <div className="text-right text-gray-300 text-xs" />
                          )}
                        </td>
                      )}
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Member count footer */}
      <div className="text-sm text-gray-800">
        {filteredMembers.length} {filteredMembers.length === 1 ? 'member' : 'members'}
        {search && ` matching "${search}"`}
        {' '}&middot; {members.filter(m => m.status === 'pending').length} pending
      </div>
    </div>
  )
}
