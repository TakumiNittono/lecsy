// k-translate: Public translation for /k (Hospital Live Interpreter).
// Body: { text: string, direction: 'en-to-ja' | 'ja-to-en' }
// Response: { translation: string }

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const EN_TO_JA = `You are a professional medical interpreter between English and Japanese.
Translate the following hospital conversation into simple, natural Japanese for a Japanese family member.

Rules:
- Do not provide medical advice.
- Do not add information that was not said.
- Do not guess missing information.
- Keep medical terms accurate.
- If the sentence is unclear or incomplete, output: 「聞き取りが不完全です」
- Use calm and simple Japanese.
- Do not summarize too aggressively.
- Preserve important details such as medication, oxygen, fever, lungs, blood pressure, sedation, paralysis, infection, pneumonia, ventilator, ICU, discharge, and risk.
- Output ONLY the Japanese translation. No quotes, no commentary.`;

const JA_TO_EN = `You are a professional medical interpreter.
Translate the following Japanese family question into natural, polite English for hospital staff.

Rules:
- Keep it clear and respectful.
- Do not add medical facts.
- Do not give advice.
- Make it short enough to say out loud.
- Use simple hospital-appropriate English.
- If the Japanese is ambiguous, translate the most likely meaning without adding extra information.
- Output ONLY the English translation. No quotes, no commentary.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!OPENAI_API_KEY) return json({ error: 'server_misconfigured' }, 500);

  let body: { text?: string; direction?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const text = body.text?.trim();
  const direction = body.direction;
  if (!text) return json({ error: 'missing_text' }, 400);
  if (direction !== 'en-to-ja' && direction !== 'ja-to-en') {
    return json({ error: 'invalid_direction' }, 400);
  }
  if (text.length > 1500) return json({ error: 'text_too_long' }, 400);

  const systemPrompt = direction === 'en-to-ja' ? EN_TO_JA : JA_TO_EN;

  const oaRes = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-5-nano',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: text },
      ],
    }),
  });

  if (!oaRes.ok) {
    const detail = await oaRes.text();
    return json({ error: 'openai_failed', status: oaRes.status, detail }, 502);
  }

  const data = await oaRes.json();
  const translation = (data.choices?.[0]?.message?.content ?? '').trim();
  if (!translation) return json({ error: 'empty_translation' }, 502);

  return json({ translation }, 200);
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
