import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Sequence,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { Particles } from "../../../components/Particles";

const { fontFamily } = loadFont();

const ProblemItem: React.FC<{
  emoji: string;
  text: string;
  color: string;
  accentColor: string;
}> = ({ emoji, text, color, accentColor }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  const slideX = interpolate(entrance, [0, 1], [300, 0]);
  const opacity = interpolate(entrance, [0, 0.4], [0, 1], {
    extrapolateRight: "clamp",
  });
  const iconScale = spring({
    frame,
    fps,
    delay: 8,
    config: { damping: 8, stiffness: 200 },
  });

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 28,
        opacity,
        transform: `translateX(${slideX}px)`,
        marginBottom: 32,
        background: "rgba(255,255,255,0.04)",
        borderRadius: 20,
        padding: "24px 32px",
        border: `1px solid ${accentColor}22`,
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          bottom: 0,
          width: 4,
          background: `linear-gradient(180deg, ${accentColor}, transparent)`,
          borderRadius: 2,
        }}
      />
      <div
        style={{
          fontSize: 52,
          width: 72,
          textAlign: "center",
          transform: `scale(${iconScale})`,
          flexShrink: 0,
        }}
      >
        {emoji}
      </div>
      <div
        style={{
          fontFamily,
          fontSize: 40,
          fontWeight: 700,
          color,
          flex: 1,
          lineHeight: 1.2,
        }}
      >
        {text}
      </div>
    </div>
  );
};

export const ProblemScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleEntrance = spring({
    frame,
    fps,
    config: { damping: 200 },
  });
  const titleOpacity = interpolate(titleEntrance, [0, 1], [0, 1]);
  const titleScale = interpolate(titleEntrance, [0, 1], [0.9, 1]);

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 30%, #1E293B 0%, #0F172A 70%, #020617 100%)",
      }}
    >
      <Particles color="rgba(248,113,113,0.2)" />

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: 50,
        }}
      >
        <div
          style={{
            opacity: titleOpacity,
            transform: `scale(${titleScale})`,
            fontFamily,
            fontSize: 48,
            fontWeight: 600,
            color: "#94A3B8",
            textAlign: "center",
            marginBottom: 60,
            letterSpacing: 1,
          }}
        >
          Sound familiar?
        </div>

        <div style={{ width: "100%", paddingLeft: 20, paddingRight: 20 }}>
          <Sequence from={12} layout="none">
            <ProblemItem
              emoji="😴"
              text="90-min lectures..."
              color="#F87171"
              accentColor="#F87171"
            />
          </Sequence>

          <Sequence from={32} layout="none">
            <ProblemItem
              emoji="📝"
              text="Incomplete notes"
              color="#FB923C"
              accentColor="#FB923C"
            />
          </Sequence>

          <Sequence from={52} layout="none">
            <ProblemItem
              emoji="😱"
              text="Panic before exams!"
              color="#FBBF24"
              accentColor="#FBBF24"
            />
          </Sequence>
        </div>
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.5) 100%)",
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
