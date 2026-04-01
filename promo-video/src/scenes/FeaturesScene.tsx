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
import { Particles } from "../components/Particles";
import { Shimmer } from "../components/Shimmer";

const { fontFamily } = loadFont();

const FeatureCard: React.FC<{
  icon: string;
  title: string;
  subtitle: string;
  accentColor: string;
  direction: "left" | "right";
}> = ({ icon, title, subtitle, accentColor, direction }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 140 },
  });

  const slideX = interpolate(
    entrance,
    [0, 1],
    [direction === "left" ? -400 : 400, 0]
  );
  const opacity = interpolate(entrance, [0, 0.4], [0, 1], {
    extrapolateRight: "clamp",
  });
  const scale = interpolate(entrance, [0, 1], [0.9, 1]);

  // Glow pulse
  const glowIntensity = interpolate(
    Math.sin(frame * 0.08),
    [-1, 1],
    [0.1, 0.25]
  );

  return (
    <div
      style={{
        opacity,
        transform: `translateX(${slideX}px) scale(${scale})`,
        background: `linear-gradient(135deg, ${accentColor}18, ${accentColor}08)`,
        borderRadius: 28,
        padding: "36px 44px",
        marginBottom: 24,
        width: "100%",
        display: "flex",
        alignItems: "center",
        gap: 24,
        border: `1px solid ${accentColor}30`,
        position: "relative",
        overflow: "hidden",
        boxShadow: `0 0 40px ${accentColor}${Math.round(glowIntensity * 255)
          .toString(16)
          .padStart(2, "0")}`,
      }}
    >
      <Shimmer delay={10} duration={35} />
      {/* Icon container with glow */}
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: 20,
          background: `${accentColor}20`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 40,
          flexShrink: 0,
          border: `1px solid ${accentColor}30`,
        }}
      >
        {icon}
      </div>
      <div style={{ flex: 1 }}>
        <div
          style={{
            fontFamily,
            fontSize: 36,
            fontWeight: 800,
            color: "#FFFFFF",
            marginBottom: 4,
            lineHeight: 1.2,
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontFamily,
            fontSize: 22,
            fontWeight: 500,
            color: "rgba(255,255,255,0.6)",
          }}
        >
          {subtitle}
        </div>
      </div>
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

  // Animated accent line
  const lineWidth = interpolate(frame, [5, 25], [0, 80], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 60%, #1E3A5F 0%, #0F172A 70%, #020617 100%)",
      }}
    >
      <Particles color="rgba(139,92,246,0.2)" />

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: 50,
        }}
      >
        <div style={{ textAlign: "center", marginBottom: 50 }}>
          <div
            style={{
              opacity: titleOpacity,
              transform: `translateY(${titleY}px)`,
              fontFamily,
              fontSize: 54,
              fontWeight: 900,
              color: "#F1F5F9",
            }}
          >
            Why lecsy?
          </div>
          {/* Accent line */}
          <div
            style={{
              width: lineWidth,
              height: 4,
              borderRadius: 2,
              background: "linear-gradient(90deg, #3B82F6, #8B5CF6)",
              margin: "12px auto 0",
            }}
          />
        </div>

        <div style={{ width: "100%", paddingLeft: 10, paddingRight: 10 }}>
          <Sequence from={12} premountFor={10} layout="none">
            <FeatureCard
              icon="📡"
              title="100% Offline"
              subtitle="No Wi-Fi needed. Works anywhere."
              accentColor="#3B82F6"
              direction="left"
            />
          </Sequence>
          <Sequence from={32} premountFor={10} layout="none">
            <FeatureCard
              icon="🆓"
              title="Completely Free"
              subtitle="Record & transcribe at no cost"
              accentColor="#10B981"
              direction="right"
            />
          </Sequence>
          <Sequence from={52} premountFor={10} layout="none">
            <FeatureCard
              icon="🔒"
              title="Privacy First"
              subtitle="Audio never leaves your device"
              accentColor="#8B5CF6"
              direction="left"
            />
          </Sequence>
        </div>
      </AbsoluteFill>

      {/* Vignette */}
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
