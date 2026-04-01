import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

export const GlowRing: React.FC<{
  size?: number;
  delay?: number;
  color1?: string;
  color2?: string;
}> = ({
  size = 300,
  delay = 0,
  color1 = "#3B82F6",
  color2 = "#06B6D4",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    delay,
    config: { damping: 200 },
    durationInFrames: 30,
  });

  const scale = interpolate(entrance, [0, 1], [0.5, 1]);
  const opacity = interpolate(entrance, [0, 1], [0, 0.6]);
  const rotation = interpolate(frame, [0, 600], [0, 360], {
    extrapolateRight: "extend",
  });
  const pulse = interpolate(
    Math.sin(frame * 0.06),
    [-1, 1],
    [0.92, 1.08]
  );

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: "50%",
        border: "none",
        opacity,
        transform: `scale(${scale * pulse}) rotate(${rotation}deg)`,
        background: `conic-gradient(from 0deg, ${color1}, ${color2}, transparent, ${color1})`,
        mask: "radial-gradient(circle, transparent 60%, black 62%, black 68%, transparent 70%)",
        WebkitMask:
          "radial-gradient(circle, transparent 60%, black 62%, black 68%, transparent 70%)",
      }}
    />
  );
};
