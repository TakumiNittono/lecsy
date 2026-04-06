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

// GET: 組織の用語集を取得
export async function GET(
  request: Request,
  { params }: { params: { slug: string } }
) {
  const result = await requireOrgRole(params.slug, 'student')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const { searchParams } = new URL(request.url)
  const language = searchParams.get('language')
  const category = searchParams.get('category')
  const search = searchParams.get('search')
  const page = parseInt(searchParams.get('page') || '1')
  const limit = Math.min(parseInt(searchParams.get('limit') || '50'), 100)
  const offset = (page - 1) * limit

  const supabase = createAdminClient()

  let query = supabase
    .from('org_glossaries')
    .select('id, term, definition, language, category, source_transcript_id, created_by, created_at, updated_at', { count: 'exact' })
    .eq('org_id', orgId)
    .order('term', { ascending: true })
    .range(offset, offset + limit - 1)

  if (language) query = query.eq('language', language)
  if (category) query = query.eq('category', category)
  if (search) query = query.ilike('term', `%${search}%`)

  const { data: terms, count, error } = await query

  if (error) {
    console.error('Failed to fetch glossary:', error)
    return NextResponse.json({ error: 'Failed to fetch glossary' }, { status: 500 })
  }

  // カテゴリ一覧も返す
  const { data: categories } = await supabase
    .from('org_glossaries')
    .select('category')
    .eq('org_id', orgId)
    .not('category', 'is', null)

  const uniqueCategories = [...new Set(categories?.map(c => c.category).filter(Boolean) || [])]

  // 言語一覧も返す
  const { data: languages } = await supabase
    .from('org_glossaries')
    .select('language')
    .eq('org_id', orgId)

  const uniqueLanguages = [...new Set(languages?.map(l => l.language) || [])]

  return NextResponse.json({
    terms: terms || [],
    total: count || 0,
    page,
    limit,
    categories: uniqueCategories,
    languages: uniqueLanguages,
  })
}

// POST: トランスクリプトから用語集を自動生成
export async function POST(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  // teacher以上のみ生成可
  const result = await requireOrgRole(params.slug, 'teacher')
  if (result instanceof NextResponse) return result
  const { orgId, userId, org } = result

  const body = await request.json()
  const { transcript_id, target_language = 'en', category } = body

  if (!transcript_id) {
    return NextResponse.json({ error: 'transcript_id is required' }, { status: 400 })
  }

  const targetLangName = LANGUAGE_NAMES[target_language]
  if (!targetLangName) {
    return NextResponse.json(
      { error: `Unsupported language: ${target_language}` },
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

  // 組織メンバーのトランスクリプトか確認
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

  const categoryInstruction = category
    ? `Focus specifically on terms related to "${category}".`
    : 'Extract all important academic and domain-specific terms.'

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
            content: `You are a terminology extraction specialist for educational institutions.
You analyze lecture transcripts and extract key terms with clear, concise definitions.
Definitions should be in ${targetLangName}.`,
          },
          {
            role: 'user',
            content: `Extract key terms from this lecture transcript and provide definitions in ${targetLangName}.

${categoryInstruction}

Lecture title: ${transcript.title}
Lecture content:
${transcript.content}

Return JSON in this exact format:
{
  "terms": [
    {
      "term": "The term (in its original language as used in the lecture)",
      "definition": "Clear, concise definition in ${targetLangName} (1-2 sentences)",
      "usage_example": "Example sentence from the lecture showing how the term is used",
      "difficulty": "beginner | intermediate | advanced"
    }
  ],
  "lecture_topic": "Brief topic description in ${targetLangName}",
  "total_terms_found": 0
}

Extract 10-25 of the most important terms.`,
          },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.2,
      }),
    })

    if (!response.ok) {
      console.error('OpenAI API error:', response.status)
      return NextResponse.json({ error: 'AI service unavailable' }, { status: 502 })
    }

    const completion = await response.json()
    const aiResult = JSON.parse(completion.choices[0].message.content || '{}')

    // 用語集をDBに保存（upsert）
    let savedCount = 0
    if (aiResult.terms && aiResult.terms.length > 0) {
      const glossaryRows = aiResult.terms.map((t: any) => ({
        org_id: orgId,
        term: t.term,
        definition: t.definition,
        language: target_language,
        category: category || null,
        source_transcript_id: transcript.id,
        created_by: userId,
      }))

      const { error: upsertError } = await supabase
        .from('org_glossaries')
        .upsert(glossaryRows, { onConflict: 'org_id,term,language' })

      if (upsertError) {
        console.error('Failed to save glossary:', upsertError)
      } else {
        savedCount = glossaryRows.length
      }
    }

    // 使用ログ記録
    await supabase.from('org_ai_usage_logs').insert({
      org_id: orgId,
      user_id: userId,
      action: 'glossary_generate',
      transcript_id: transcript.id,
      metadata: { target_language, category, org_plan: org.plan },
    })

    return NextResponse.json({
      ...aiResult,
      saved_count: savedCount,
      transcript_id: transcript.id,
      transcript_title: transcript.title,
    })
  } catch (error) {
    console.error('Glossary generation error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

// DELETE: 用語を削除（admin以上）
export async function DELETE(
  request: Request,
  { params }: { params: { slug: string } }
) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const result = await requireOrgRole(params.slug, 'admin')
  if (result instanceof NextResponse) return result
  const { orgId } = result

  const body = await request.json()
  const { term_ids } = body

  if (!term_ids || !Array.isArray(term_ids) || term_ids.length === 0) {
    return NextResponse.json({ error: 'term_ids array is required' }, { status: 400 })
  }

  const supabase = createAdminClient()

  const { error } = await supabase
    .from('org_glossaries')
    .delete()
    .eq('org_id', orgId)
    .in('id', term_ids)

  if (error) {
    console.error('Failed to delete glossary terms:', error)
    return NextResponse.json({ error: 'Failed to delete terms' }, { status: 500 })
  }

  return NextResponse.json({ success: true, deleted: term_ids.length })
}
