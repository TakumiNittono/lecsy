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
import { LecsyLogo } from "../components/LecsyLogo";
import { GlowRing } from "../components/GlowRing";
import { Particles } from "../components/Particles";
import { Shimmer } from "../components/Shimmer";

const { fontFamily } = loadFont();

const StepCard: React.FC<{
  step: number;
  emoji: string;
  title: string;
  description: string;
}> = ({ step, emoji, title, description }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  const slideY = interpolate(entrance, [0, 1], [100, 0]);
  const opacity = interpolate(entrance, [0, 0.4], [0, 1], {
    extrapolateRight: "clamp",
  });
  const scale = interpolate(entrance, [0, 1], [0.85, 1]);

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${slideY}px) scale(${scale})`,
        background: "rgba(255,255,255,0.06)",
        borderRadius: 24,
        padding: "28px 36px",
        marginBottom: 20,
        width: "100%",
        border: "1px solid rgba(255,255,255,0.08)",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <Shimmer delay={5} duration={30} />
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        {/* Step number badge */}
        <div
          style={{
            width: 44,
            height: 44,
            borderRadius: 12,
            background: "linear-gradient(135deg, #3B82F6, #06B6D4)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily,
            fontSize: 22,
            fontWeight: 800,
            color: "#FFF",
            flexShrink: 0,
          }}
        >
          {step}
        </div>
        <span style={{ fontSize: 42 }}>{emoji}</span>
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontFamily,
              fontSize: 36,
              fontWeight: 700,
              color: "#E2E8F0",
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
              color: "#64748B",
              marginTop: 2,
            }}
          >
            {description}
          </div>
        </div>
      </div>
    </div>
  );
};

export const SolutionScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const taglineEntrance = spring({
    frame,
    fps,
    delay: 25,
    config: { damping: 200 },
  });
  const taglineOpacity = interpolate(taglineEntrance, [0, 1], [0, 1]);
  const taglineSpacing = interpolate(taglineEntrance, [0, 1], [12, 5]);

  // Connecting line between steps
  const lineHeight = interpolate(frame, [55, 120], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 30%, #1E3A5F 0%, #0F172A 70%, #020617 100%)",
      }}
    >
      <Particles color="rgba(59,130,246,0.25)" />

      {/* Glow ring behind logo */}
      <div
        style={{
          position: "absolute",
          top: 270,
          left: "50%",
          transform: "translateX(-50%)",
        }}
      >
        <GlowRing size={280} delay={5} />
      </div>

      {/* Logo */}
      <Sequence from={0} premountFor={30} layout="none">
        <div
          style={{
            position: "absolute",
            top: 340,
            left: 0,
            right: 0,
            display: "flex",
            justifyContent: "center",
          }}
        >
          <LecsyLogo size={110} delay={0} />
        </div>
      </Sequence>

      {/* Tagline */}
      <div
        style={{
          position: "absolute",
          top: 490,
          left: 0,
          right: 0,
          textAlign: "center",
          opacity: taglineOpacity,
        }}
      >
        <span
          style={{
            fontFamily,
            fontSize: 30,
            fontWeight: 500,
            color: "#94A3B8",
            letterSpacing: taglineSpacing,
          }}
        >
          Record  ×  Transcribe  ×  AI
        </span>
      </div>

      {/* Steps */}
      <div
        style={{
          position: "absolute",
          top: 590,
          left: 50,
          right: 50,
        }}
      >
        <Sequence from={40} premountFor={10} layout="none">
          <StepCard
            step={1}
            emoji="🎙️"
            title="One-tap record"
            description="Hit record, focus on learning"
          />
        </Sequence>
        <Sequence from={60} premountFor={10} layout="none">
          <StepCard
            step={2}
            emoji="🤖"
            title="AI transcription"
            description="100% offline, on your device"
          />
        </Sequence>
        <Sequence from={80} premountFor={10} layout="none">
          <StepCard
            step={3}
            emoji="📖"
            title="Review anytime"
            description="Phone, tablet, or laptop"
          />
        </Sequence>
      </div>

      {/* Vignette */}
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
