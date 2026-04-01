import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { Particles } from "../../../components/Particles";

const { fontFamily } = loadFont();

const StaggeredText: React.FC<{
  text: string;
  startFrame: number;
  fontSize: number;
  color: string;
  fontWeight: number;
}> = ({ text, startFrame, fontSize, color, fontWeight }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  return (
    <div
      style={{ display: "flex", justifyContent: "center", flexWrap: "wrap" }}
    >
      {text.split("").map((char, i) => {
        const charDelay = startFrame + i * 1.5;
        const charSpring = spring({
          frame,
          fps,
          delay: charDelay,
          config: { damping: 15, stiffness: 200 },
        });
        const y = interpolate(charSpring, [0, 1], [40, 0]);
        const opacity = interpolate(charSpring, [0, 0.5], [0, 1], {
          extrapolateRight: "clamp",
        });

        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              fontFamily,
              fontSize,
              fontWeight,
              color,
              transform: `translateY(${y}px)`,
              opacity,
              whiteSpace: char === " " ? "pre" : undefined,
            }}
          >
            {char}
          </span>
        );
      })}
    </div>
  );
};

export const HookScene: React.FC = () => {
  const frame = useCurrentFrame();

  const bgScale = interpolate(frame, [0, 90], [1.1, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  });

  const underlineWidth = interpolate(frame, [45, 65], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  });

  const pulse = interpolate(Math.sin(frame * 0.1), [-1, 1], [0.95, 1.05]);

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse at 50% 40%, #1E293B 0%, #0F172A 70%, #020617 100%)`,
        transform: `scale(${bgScale})`,
      }}
    >
      <Particles color="rgba(59,130,246,0.3)" />

      {/* Accent line top */}
      <div
        style={{
          position: "absolute",
          top: 600,
          left: "50%",
          transform: "translateX(-50%)",
          width: 60,
          height: 4,
          borderRadius: 2,
          background: "linear-gradient(90deg, #3B82F6, #06B6D4)",
          opacity: interpolate(frame, [0, 15], [0, 1], {
            extrapolateRight: "clamp",
          }),
        }}
      />

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: 60,
          gap: 16,
        }}
      >
        <StaggeredText
          text="Still taking notes"
          startFrame={5}
          fontSize={70}
          color="#F1F5F9"
          fontWeight={800}
        />
        <div style={{ position: "relative" }}>
          <StaggeredText
            text="in lectures?"
            startFrame={25}
            fontSize={82}
            color="#FBBF24"
            fontWeight={900}
          />
          <div
            style={{
              position: "absolute",
              bottom: -8,
              left: "50%",
              transform: `translateX(-50%) scaleX(${pulse})`,
              width: `${underlineWidth}%`,
              height: 6,
              borderRadius: 3,
              background:
                "linear-gradient(90deg, #F59E0B, #FBBF24, #F59E0B)",
              boxShadow: "0 0 20px rgba(251,191,36,0.5)",
            }}
          />
        </div>
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.4) 100%)",
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
