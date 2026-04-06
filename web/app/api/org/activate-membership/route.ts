import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

/**
 * POST /api/org/activate-membership
 * ログイン後に呼び出し: メールが一致する pending メンバーを自動的に active にする
 */
export async function POST() {
  const supabase = createClient()
  const admin = createAdminClient()

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user || !user.email) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // pending メンバーでメールが一致するものを検索
  const { data: pendingMembers, error: fetchError } = await admin
    .from('organization_members')
    .select('id, org_id, email, role')
    .eq('email', user.email.toLowerCase())
    .eq('status', 'pending')
    .is('user_id', null)

  if (fetchError || !pendingMembers || pendingMembers.length === 0) {
    return NextResponse.json({ activated: [] })
  }

  // 各 pending メンバーを active に更新
  const activated = []
  for (const member of pendingMembers) {
    const { error: updateError } = await admin
      .from('organization_members')
      .update({
        user_id: user.id,
        status: 'active',
      })
      .eq('id', member.id)

    if (!updateError) {
      activated.push({
        id: member.id,
        org_id: member.org_id,
        role: member.role,
      })
    }
  }

  return NextResponse.json({ activated })
}
