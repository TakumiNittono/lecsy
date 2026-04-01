import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";

export const Shimmer: React.FC<{
  delay?: number;
  duration?: number;
  angle?: number;
}> = ({ delay = 0, duration = 40, angle = 120 }) => {
  const frame = useCurrentFrame();

  const progress = interpolate(frame - delay, [0, duration], [-1, 2], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(${angle}deg, transparent ${progress * 100 - 30}%, rgba(255,255,255,0.12) ${progress * 100}%, transparent ${progress * 100 + 30}%)`,
        borderRadius: "inherit",
        pointerEvents: "none",
      }}
    />
  );
};
