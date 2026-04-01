import React from "react";
import { Composition } from "remotion";
import { QuestionHook } from "./patterns/pattern1/QuestionHook";

/*
 * Each pattern is registered as a separate Composition.
 * Render with:  npx remotion render Pattern1-QuestionHook out/pattern1-question-hook.mp4
 */
export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Pattern 1: The Question Hook (20 seconds) */}
      <Composition
        id="Pattern1-QuestionHook"
        component={QuestionHook}
        durationInFrames={600}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
