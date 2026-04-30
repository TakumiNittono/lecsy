// k-translate: Public translation for /k (Hospital Live Interpreter).
// Body: { text: string, direction: 'en-to-ja' | 'ja-to-en' }
// Response: { translation: string }

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// 翻訳プロンプトはリアルタイム性優先で最小化。
// 入力は Deepgram nova-3 の確定済み transcript なので、断片的でも素直に訳す。
// 不完全/聞き取れない等のフォールバック文字列は出さない。常に短く即座に出す。
const EN_TO_JA = `You are a real-time medical interpreter (English→Japanese) at a hospital.
Translate the input to simple natural Japanese for a family member. Output ONLY the Japanese translation, no quotes, no commentary.
Even if the sentence looks short or fragmentary, translate what is said as-is. Never output meta phrases like "聞き取りが不完全です". Never refuse. Keep medical terms accurate. Do not add information.`;

const JA_TO_EN = `You are a medical interpreter (Japanese→English) at a hospital.
Translate the input to natural, polite, hospital-appropriate English for staff. Output ONLY the English translation, no quotes, no commentary. Keep it short enough to say out loud. Do not add facts.`;

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

  // SSE で常時ストリーミング。クライアントは delta が来た瞬間に画面更新する。
  const oaRes = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-5-nano',
      stream: true,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: text },
      ],
    }),
  });

  if (!oaRes.ok || !oaRes.body) {
    const detail = oaRes.body ? await oaRes.text() : '';
    return json({ error: 'openai_failed', status: oaRes.status, detail }, 502);
  }

  return new Response(oaRes.body, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'X-Accel-Buffering': 'no',
    },
  });
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
