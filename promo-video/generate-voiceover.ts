import { writeFileSync, mkdirSync, existsSync } from "fs";

const API_KEY = process.env.ELEVENLABS_API_KEY!;

// Voice IDs — alternate between male/female across patterns
const VOICES = {
  male: "21m00Tcm4TlvDq8ikWAM", // Rachel → Adam (default male)
  female: "EXAVITQu4vr4xnSDxMaL", // Bella (female)
};

type PatternConfig = {
  id: string;
  voice: "male" | "female";
  scenes: { id: string; text: string }[];
};

const patterns: PatternConfig[] = [
  {
    id: "pattern1",
    voice: "male",
    scenes: [
      { id: "scene1-hook", text: "Still taking notes in lectures?" },
      { id: "scene2-problem", text: "Long lectures. Bad notes. Exam panic." },
      {
        id: "scene3-solution",
        text: "Meet lecsy. Tap record. AI transcribes everything offline.",
      },
      { id: "scene4-features", text: "Offline. Free. Private." },
      { id: "scene5-cta", text: "Download lecsy free today." },
    ],
  },
  // Add more patterns here as needed:
  // {
  //   id: "pattern2",
  //   voice: "female",
  //   scenes: [ ... ],
  // },
];

async function generateVoiceover(patternId?: string) {
  const toGenerate = patternId
    ? patterns.filter((p) => p.id === patternId)
    : patterns;

  if (toGenerate.length === 0) {
    console.error(`Pattern "${patternId}" not found.`);
    process.exit(1);
  }

  for (const pattern of toGenerate) {
    const outDir = `public/voiceover/${pattern.id}`;
    if (!existsSync(outDir)) {
      mkdirSync(outDir, { recursive: true });
    }

    const voiceId = VOICES[pattern.voice];
    console.log(
      `\n=== Generating ${pattern.id} (${pattern.voice} voice) ===\n`
    );

    for (const scene of pattern.scenes) {
      console.log(`  Generating: ${scene.id}...`);

      const response = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
        {
          method: "POST",
          headers: {
            "xi-api-key": API_KEY,
            "Content-Type": "application/json",
            Accept: "audio/mpeg",
          },
          body: JSON.stringify({
            text: scene.text,
            model_id: "eleven_multilingual_v2",
            voice_settings: {
              stability: 0.7,
              similarity_boost: 0.75,
              style: 0.3,
            },
          }),
        }
      );

      if (!response.ok) {
        const error = await response.text();
        console.error(
          `  Error for ${scene.id}: ${response.status} - ${error}`
        );
        continue;
      }

      const audioBuffer = Buffer.from(await response.arrayBuffer());
      const filePath = `${outDir}/${scene.id}.mp3`;
      writeFileSync(filePath, audioBuffer);
      console.log(`  Saved: ${filePath} (${audioBuffer.length} bytes)`);
    }
  }

  console.log("\nAll voiceovers generated!");
}

// Usage: npx tsx generate-voiceover.ts [patternId]
const targetPattern = process.argv[2];
generateVoiceover(targetPattern);
