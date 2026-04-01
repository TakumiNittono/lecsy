import React from "react";
import {
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";

const { fontFamily } = loadFont();

export const LecsyLogo: React.FC<{
  size?: number;
  delay?: number;
}> = ({ size = 80, delay = 0 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({
    frame,
    fps,
    delay,
    config: { damping: 8 },
  });

  const opacity = interpolate(frame - delay, [0, 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const glowPulse = interpolate(
    Math.sin((frame - delay) * 0.08),
    [-1, 1],
    [0.3, 0.7]
  );

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        opacity,
        transform: `scale(${scale})`,
        position: "relative",
      }}
    >
      <span
        style={{
          fontSize: size,
          fontWeight: 900,
          background: "linear-gradient(135deg, #3B82F6, #06B6D4, #8B5CF6)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          fontFamily,
          letterSpacing: -3,
          filter: `drop-shadow(0 0 ${20 * glowPulse}px rgba(59,130,246,${glowPulse}))`,
        }}
      >
        lecsy
      </span>
    </div>
  );
};
