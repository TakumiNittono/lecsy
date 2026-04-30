// k-tts: Public English TTS for /k (Hospital Live Interpreter).
// Body: { text: string }
// Response: audio/mpeg binary

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!OPENAI_API_KEY) return json({ error: 'server_misconfigured' }, 500);

  let body: { text?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const text = body.text?.trim();
  if (!text) return json({ error: 'missing_text' }, 400);
  if (text.length > 800) return json({ error: 'text_too_long' }, 400);

  const ttsRes = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini-tts',
      voice: 'alloy',
      input: text,
      instructions: 'Speak clearly, calmly, and slowly for hospital staff communication.',
      response_format: 'mp3',
    }),
  });

  if (!ttsRes.ok) {
    const detail = await ttsRes.text();
    return json({ error: 'tts_failed', status: ttsRes.status, detail }, 502);
  }

  const buf = await ttsRes.arrayBuffer();
  return new Response(buf, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'audio/mpeg',
      'Cache-Control': 'no-store',
    },
  });
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
