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
import { Shimmer } from "../../../components/Shimmer";

const { fontFamily } = loadFont();

const FeatureBadge: React.FC<{
  icon: string;
  label: string;
  accentColor: string;
}> = ({ icon, label, accentColor }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    config: { damping: 10, stiffness: 160 },
  });

  const scale = interpolate(entrance, [0, 1], [0, 1]);
  const opacity = interpolate(entrance, [0, 0.3], [0, 1], {
    extrapolateRight: "clamp",
  });

  const glowPulse = interpolate(
    Math.sin(frame * 0.08),
    [-1, 1],
    [0.15, 0.35]
  );

  return (
    <div
      style={{
        opacity,
        transform: `scale(${scale})`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 16,
      }}
    >
      <div
        style={{
          width: 120,
          height: 120,
          borderRadius: 32,
          background: `${accentColor}15`,
          border: `2px solid ${accentColor}40`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 56,
          boxShadow: `0 0 40px ${accentColor}${Math.round(glowPulse * 255)
            .toString(16)
            .padStart(2, "0")}`,
          position: "relative",
          overflow: "hidden",
        }}
      >
        <Shimmer delay={8} duration={30} />
        {icon}
      </div>
      <span
        style={{
          fontFamily,
          fontSize: 30,
          fontWeight: 800,
          color: accentColor,
          textAlign: "center",
        }}
      >
        {label}
      </span>
    </div>
  );
};

const SubtitleText: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const subEntrance = spring({
    frame,
    fps,
    config: { damping: 200 },
  });

  return (
    <div
      style={{
        opacity: interpolate(subEntrance, [0, 1], [0, 1]),
        fontFamily,
        fontSize: 28,
        fontWeight: 500,
        color: "#64748B",
        textAlign: "center",
        lineHeight: 1.5,
      }}
    >
      Your audio never leaves your iPhone.
      <br />
      No limits. No subscriptions.
    </div>
  );
};

export const FeaturesScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleEntrance = spring({
    frame,
    fps,
    config: { damping: 200 },
  });
  const titleOpacity = interpolate(titleEntrance, [0, 1], [0, 1]);
  const titleY = interpolate(titleEntrance, [0, 1], [-20, 0]);

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 50%, #1E293B 0%, #0F172A 70%, #020617 100%)",
      }}
    >
      <Particles color="rgba(59,130,246,0.2)" />

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: 50,
          gap: 60,
        }}
      >
        <div
          style={{
            opacity: titleOpacity,
            transform: `translateY(${titleY}px)`,
            fontFamily,
            fontSize: 52,
            fontWeight: 900,
            color: "#F1F5F9",
            textAlign: "center",
          }}
        >
          Why lecsy?
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "center",
            gap: 48,
            width: "100%",
          }}
        >
          <Sequence from={10} layout="none">
            <FeatureBadge
              icon="🔒"
              label="Private"
              accentColor="#8B5CF6"
            />
          </Sequence>
          <Sequence from={22} layout="none">
            <FeatureBadge
              icon="✈️"
              label="Offline"
              accentColor="#06B6D4"
            />
          </Sequence>
          <Sequence from={34} layout="none">
            <FeatureBadge
              icon="💰"
              label="Free"
              accentColor="#22C55E"
            />
          </Sequence>
        </div>

        <Sequence from={50} layout="none">
          <SubtitleText />
        </Sequence>
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
