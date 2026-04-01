import React from "react";
import {
  AbsoluteFill,
  Sequence,
  staticFile,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
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

export const LecsyPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  /*
   * Actual scene start frames (accounting for transition overlaps):
   * Scene 1 (Hook):     0 → 90
   * Scene 2 (Problem):  90 → 210
   * Scene 3 (Solution): 190 → 370  (wipe overlaps 20f)
   * Scene 4 (Features): 352 → 472  (fade overlaps 18f)
   * Scene 5 (CTA):      472 → 600
   */

  return (
    <AbsoluteFill>
      {/* === VOICEOVER AUDIO TRACKS === */}
      <Sequence from={5} layout="none">
        <Audio src={staticFile("voiceover/scene1-hook.mp3")} />
      </Sequence>

      <Sequence from={95} layout="none">
        <Audio src={staticFile("voiceover/scene2-problem.mp3")} />
      </Sequence>

      <Sequence from={200} layout="none">
        <Audio src={staticFile("voiceover/scene3-solution.mp3")} />
      </Sequence>

      <Sequence from={365} layout="none">
        <Audio src={staticFile("voiceover/scene4-features.mp3")} />
      </Sequence>

      <Sequence from={482} layout="none">
        <Audio src={staticFile("voiceover/scene5-cta.mp3")} />
      </Sequence>

      {/* === VIDEO SCENES === */}
      <TransitionSeries>
        {/* Scene 1: Hook (90 frames) */}
        <TransitionSeries.Sequence durationInFrames={90}>
          <HookScene />
        </TransitionSeries.Sequence>

        {/* Fade transition Hook → Problem */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 20 })}
        />

        {/* Scene 2: Problem (120 frames) */}
        <TransitionSeries.Sequence durationInFrames={120}>
          <ProblemScene />
        </TransitionSeries.Sequence>

        {/* Wipe transition Problem → Solution */}
        <TransitionSeries.Transition
          presentation={wipe({ direction: "from-bottom-left" })}
          timing={springTiming({ config: { damping: 200 }, durationInFrames: 20 })}
        />

        {/* Scene 3: Solution (180 frames) */}
        <TransitionSeries.Sequence durationInFrames={180}>
          <SolutionScene />
        </TransitionSeries.Sequence>

        {/* Fade transition Solution → Features */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 18 })}
        />

        {/* Scene 4: Features (120 frames) */}
        <TransitionSeries.Sequence durationInFrames={120}>
          <FeaturesScene />
        </TransitionSeries.Sequence>

        {/* Fade transition Features → CTA */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 20 })}
        />

        {/* Scene 5: CTA (128 frames) */}
        <TransitionSeries.Sequence durationInFrames={128}>
          <CTAScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>
    </AbsoluteFill>
  );
};
