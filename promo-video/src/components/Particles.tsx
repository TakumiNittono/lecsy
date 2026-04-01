import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";

const PARTICLES = Array.from({ length: 30 }, (_, i) => ({
  id: i,
  x: (i * 137.508) % 100,
  y: (i * 73.254) % 100,
  size: 2 + (i % 4) * 1.5,
  speed: 0.3 + (i % 5) * 0.15,
  delay: (i * 7) % 40,
  opacity: 0.15 + (i % 3) * 0.1,
}));

export const Particles: React.FC<{
  color?: string;
}> = ({ color = "rgba(59,130,246,0.4)" }) => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      {PARTICLES.map((p) => {
        const yOffset = interpolate(
          frame,
          [0, 600],
          [0, -200 * p.speed],
          { extrapolateRight: "extend" }
        );
        const xWobble =
          Math.sin((frame + p.delay) * 0.03 * p.speed) * 15;
        const pulse = interpolate(
          Math.sin((frame + p.delay) * 0.05),
          [-1, 1],
          [0.4, 1]
        );

        return (
          <div
            key={p.id}
            style={{
              position: "absolute",
              left: `${p.x}%`,
              top: `${p.y}%`,
              width: p.size,
              height: p.size,
              borderRadius: "50%",
              background: color,
              opacity: p.opacity * pulse,
              transform: `translate(${xWobble}px, ${yOffset}px)`,
              boxShadow: `0 0 ${p.size * 3}px ${color}`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};
