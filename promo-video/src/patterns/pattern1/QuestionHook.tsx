import React from "react";
import {
  AbsoluteFill,
  Sequence,
  staticFile,
} from "remotion";
import {
  TransitionSeries,
  linearTiming,
  springTiming,
} from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { wipe } from "@remotion/transitions/wipe";
import { Audio } from "@remotion/media";
import { HookScene } from "./scenes/HookScene";
import { ProblemScene } from "./scenes/ProblemScene";
import { SolutionScene } from "./scenes/SolutionScene";
import { FeaturesScene } from "./scenes/FeaturesScene";
import { CTAScene } from "./scenes/CTAScene";

/**
 * Pattern 1: "The Question Hook"
 *
 * Structure (600 frames @ 30fps = 20 seconds):
 *   Scene 1 (Hook):     0–90     "Still taking notes in lectures?"
 *   Scene 2 (Problem):  90–210   "Sound familiar? 90-min lectures / Incomplete notes / Panic"
 *   Scene 3 (Solution): 210–390  "Meet lecsy. Tap record. AI transcribes offline."
 *   Scene 4 (Features): 390–510  "Private · Offline · Free"
 *   Scene 5 (CTA):      510–600  "Download free on the App Store"
 *
 * Voiceover: Each scene has its own audio file, played sequentially (NO overlap).
 */
export const QuestionHook: React.FC = () => {
  return (
    <AbsoluteFill>
      {/* ── VOICEOVER AUDIO (sequential, no overlap) ── */}
      <Sequence from={5} layout="none">
        <Audio src={staticFile("voiceover/pattern1/scene1-hook.mp3")} />
      </Sequence>

      <Sequence from={95} layout="none">
        <Audio src={staticFile("voiceover/pattern1/scene2-problem.mp3")} />
      </Sequence>

      <Sequence from={215} layout="none">
        <Audio src={staticFile("voiceover/pattern1/scene3-solution.mp3")} />
      </Sequence>

      <Sequence from={395} layout="none">
        <Audio src={staticFile("voiceover/pattern1/scene4-features.mp3")} />
      </Sequence>

      <Sequence from={515} layout="none">
        <Audio src={staticFile("voiceover/pattern1/scene5-cta.mp3")} />
      </Sequence>

      {/* ── VIDEO SCENES ── */}
      <TransitionSeries>
        {/* Scene 1: Hook (90 frames / 3s) */}
        <TransitionSeries.Sequence durationInFrames={90}>
          <HookScene />
        </TransitionSeries.Sequence>

        {/* Fade: Hook → Problem (20 frames) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 20 })}
        />

        {/* Scene 2: Problem (120 frames / 4s) */}
        <TransitionSeries.Sequence durationInFrames={120}>
          <ProblemScene />
        </TransitionSeries.Sequence>

        {/* Wipe: Problem → Solution (20 frames) */}
        <TransitionSeries.Transition
          presentation={wipe({ direction: "from-bottom-left" })}
          timing={springTiming({
            config: { damping: 200 },
            durationInFrames: 20,
          })}
        />

        {/* Scene 3: Solution (180 frames / 6s) */}
        <TransitionSeries.Sequence durationInFrames={180}>
          <SolutionScene />
        </TransitionSeries.Sequence>

        {/* Fade: Solution → Features (18 frames) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 18 })}
        />

        {/* Scene 4: Features (120 frames / 4s) */}
        <TransitionSeries.Sequence durationInFrames={120}>
          <FeaturesScene />
        </TransitionSeries.Sequence>

        {/* Fade: Features → CTA (20 frames) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 20 })}
        />

        {/* Scene 5: CTA (128 frames / ~4.3s) */}
        <TransitionSeries.Sequence durationInFrames={128}>
          <CTAScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>
    </AbsoluteFill>
  );
};
