import { validateOrigin } from '@/utils/api/auth'
import { requireOrgRole } from '@/utils/api/org-auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { NextResponse } from 'next/server'

const PLAN_DAILY_LIMITS: Record<string, number> = {
  starter: 10,
  growth: 50,
  enterprise: 200,
}

const LANGUAGE_NAMES: Record<string, string> = {
  ja: 'Japanese', en: 'English', es: 'Spanish', zh: 'Chinese',
  ko: 'Korean', fr: 'French', de: 'German', pt: 'Portuguese',
  it: 'Italian', ru: 'Russian', ar: 'Arabic', hi: 'Hindi',
}

export async function POST(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  // 組織メンバー確認（全ロールOK）
  const result = await requireOrgRole(params.slug, 'student')
  if (result instanceof NextResponse) return result
  const { orgId, userId, org } = result

  const body = await request.json()
  const { transcript_id, target_language } = body

  if (!transcript_id || !target_language) {
    return NextResponse.json(
      { error: 'transcript_id and target_language are required' },
      { status: 400 }
    )
  }

  if (!LANGUAGE_NAMES[target_language]) {
    return NextResponse.json(
      { error: `Unsupported language: ${target_language}. Supported: ${Object.keys(LANGUAGE_NAMES).join(', ')}` },
      { status: 400 }
    )
  }

  const supabase = createAdminClient()

  // プラン別日次リミット
  const dailyLimit = PLAN_DAILY_LIMITS[org.plan] || PLAN_DAILY_LIMITS.starter
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const { count: dailyCount } = await supabase
    .from('org_ai_usage_logs')
    .select('*', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .gte('created_at', today.toISOString())

  if ((dailyCount || 0) >= dailyLimit) {
    return NextResponse.json(
      { error: `Organization daily AI limit reached (${dailyLimit}/day on ${org.plan} plan).` },
      { status: 429 }
    )
  }

  // 組織メンバーのトランスクリプトにアクセス可能か確認
  const { data: orgMembers } = await supabase
    .from('organization_members')
    .select('user_id')
    .eq('org_id', orgId)

  const orgUserIds = orgMembers?.map(m => m.user_id) || []

  const { data: transcript } = await supabase
    .from('transcripts')
    .select('id, content, title, language')
    .eq('id', transcript_id)
    .in('user_id', orgUserIds)
    .single()

  if (!transcript) {
    return NextResponse.json({ error: 'Transcript not found or access denied' }, { status: 404 })
  }

  // OpenAI呼び出し
  const targetLangName = LANGUAGE_NAMES[target_language]
  const sourceLangName = LANGUAGE_NAMES[transcript.language || 'en'] || 'English'

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4-turbo',
        messages: [
          {
            role: 'system',
            content: `You are an expert multilingual lecture summarizer for educational institutions.
You receive lecture transcripts and produce comprehensive summaries in a DIFFERENT language from the source.
This is used by language schools and universities where students and teachers speak different languages.
ALL output MUST be in ${targetLangName}. Do NOT include any text in ${sourceLangName} except for proper nouns or technical terms.`,
          },
          {
            role: 'user',
            content: `Analyze the following lecture transcript (originally in ${sourceLangName}) and create a comprehensive cross-language summary in ${targetLangName}.

Lecture title: ${transcript.title}
Lecture content:
${transcript.content}

Return JSON in this exact format:
{
  "summary": "Comprehensive summary in ${targetLangName} (300-500 characters)",
  "key_points": ["Key point 1", "Key point 2", "..."],
  "sections": [
    {"heading": "Section heading", "content": "Section content"}
  ],
  "source_language": "${sourceLangName}",
  "target_language": "${targetLangName}",
  "key_terms_bilingual": [
    {"original": "Term in source language", "translated": "Term in ${targetLangName}", "context": "Brief context"}
  ]
}

IMPORTANT: All text values (except 'original' in key_terms_bilingual) MUST be in ${targetLangName}.`,
          },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.3,
      }),
    })

    if (!response.ok) {
      console.error('OpenAI API error:', response.status)
      return NextResponse.json({ error: 'AI service unavailable' }, { status: 502 })
    }

    const completion = await response.json()
    const aiResult = JSON.parse(completion.choices[0].message.content || '{}')

    // 使用ログ記録
    await supabase.from('org_ai_usage_logs').insert({
      org_id: orgId,
      user_id: userId,
      action: 'cross_summary',
      transcript_id: transcript.id,
      metadata: { target_language, source_language: transcript.language, org_plan: org.plan },
    })

    return NextResponse.json({
      ...aiResult,
      transcript_id: transcript.id,
      transcript_title: transcript.title,
    })
  } catch (error) {
    console.error('Cross-summary error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
