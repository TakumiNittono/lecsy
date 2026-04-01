import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Sequence,
  Easing,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { LecsyLogo } from "../../../components/LecsyLogo";
import { GlowRing } from "../../../components/GlowRing";
import { Particles } from "../../../components/Particles";

const { fontFamily } = loadFont();

/* ── Animated waveform bars inside the iPhone mockup ── */
const WaveformBar: React.FC<{ index: number; total: number }> = ({
  index,
  total,
}) => {
  const frame = useCurrentFrame();
  const phase = (index / total) * Math.PI * 2;
  const height = interpolate(
    Math.sin(frame * 0.15 + phase),
    [-1, 1],
    [8, 40]
  );

  return (
    <div
      style={{
        width: 4,
        height,
        borderRadius: 2,
        background: "linear-gradient(180deg, #22C55E, #16A34A)",
        opacity: 0.9,
      }}
    />
  );
};

/* ── iPhone mockup with recording UI ── */
const IPhoneMockup: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({
    frame,
    fps,
    delay: 10,
    config: { damping: 14, stiffness: 120 },
  });
  const slideY = interpolate(entrance, [0, 1], [400, 0]);
  const opacity = interpolate(entrance, [0, 0.3], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Recording dot pulse
  const dotPulse = interpolate(
    Math.sin(frame * 0.12),
    [-1, 1],
    [0.6, 1]
  );

  // Timer counting up
  const seconds = Math.min(Math.floor((frame - 15) / 6), 59);
  const minutes = Math.floor(seconds / 60);
  const displaySec = seconds % 60;
  const timer = `${String(minutes).padStart(2, "0")}:${String(Math.max(0, displaySec)).padStart(2, "0")}`;

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${slideY}px)`,
        width: 320,
        height: 560,
        borderRadius: 40,
        background: "#1A1A2E",
        border: "3px solid rgba(255,255,255,0.15)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        padding: "48px 24px 32px",
        position: "relative",
        overflow: "hidden",
        boxShadow:
          "0 20px 60px rgba(0,0,0,0.5), 0 0 40px rgba(34,197,94,0.15)",
      }}
    >
      {/* Notch */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: "50%",
          transform: "translateX(-50%)",
          width: 120,
          height: 28,
          borderRadius: "0 0 16px 16px",
          background: "#000",
        }}
      />

      {/* Recording indicator */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10,
          marginTop: 16,
          marginBottom: 24,
        }}
      >
        <div
          style={{
            width: 12,
            height: 12,
            borderRadius: "50%",
            background: "#EF4444",
            opacity: dotPulse,
            boxShadow: `0 0 ${12 * dotPulse}px rgba(239,68,68,${dotPulse})`,
          }}
        />
        <span
          style={{
            fontFamily,
            fontSize: 16,
            fontWeight: 600,
            color: "#EF4444",
            opacity: dotPulse,
          }}
        >
          Recording
        </span>
      </div>

      {/* Timer */}
      <div
        style={{
          fontFamily,
          fontSize: 56,
          fontWeight: 200,
          color: "#E2E8F0",
          letterSpacing: 2,
          marginBottom: 32,
        }}
      >
        {timer}
      </div>

      {/* Waveform */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 3,
          height: 50,
          marginBottom: 32,
        }}
      >
        {Array.from({ length: 28 }, (_, i) => (
          <WaveformBar key={i} index={i} total={28} />
        ))}
      </div>

      {/* Mic button */}
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: "50%",
          background: "linear-gradient(135deg, #EF4444, #DC2626)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0 4px 24px rgba(239,68,68,0.4)",
        }}
      >
        <div
          style={{
            width: 24,
            height: 24,
            borderRadius: 4,
            background: "#FFF",
          }}
        />
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
    delay: 5,
    config: { damping: 200 },
  });
  const taglineOpacity = interpolate(taglineEntrance, [0, 1], [0, 1]);

  const descEntrance = spring({
    frame,
    fps,
    delay: 40,
    config: { damping: 200 },
  });
  const descOpacity = interpolate(descEntrance, [0, 1], [0, 1]);
  const descY = interpolate(descEntrance, [0, 1], [20, 0]);

  // Green pulse accent on background
  const greenPulse = interpolate(
    Math.sin(frame * 0.05),
    [-1, 1],
    [0, 0.08]
  );

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse at 50% 30%, rgba(34,197,94,${greenPulse}) 0%, #0F172A 40%, #020617 100%)`,
      }}
    >
      <Particles color="rgba(34,197,94,0.2)" />

      {/* Glow ring behind logo */}
      <div
        style={{
          position: "absolute",
          top: 180,
          left: "50%",
          transform: "translateX(-50%)",
        }}
      >
        <GlowRing size={200} delay={0} color1="#22C55E" color2="#06B6D4" />
      </div>

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          padding: "0 50px",
        }}
      >
        {/* Logo */}
        <div style={{ marginTop: 210 }}>
          <LecsyLogo size={90} delay={0} />
        </div>

        {/* Tagline */}
        <div
          style={{
            opacity: taglineOpacity,
            fontFamily,
            fontSize: 28,
            fontWeight: 500,
            color: "#94A3B8",
            textAlign: "center",
            marginTop: 16,
            letterSpacing: 2,
          }}
        >
          Record × Transcribe × AI
        </div>

        {/* iPhone mockup */}
        <div style={{ marginTop: 40 }}>
          <IPhoneMockup />
        </div>

        {/* Description text */}
        <div
          style={{
            opacity: descOpacity,
            transform: `translateY(${descY}px)`,
            fontFamily,
            fontSize: 32,
            fontWeight: 700,
            color: "#E2E8F0",
            textAlign: "center",
            marginTop: 36,
            lineHeight: 1.4,
          }}
        >
          Tap record. AI transcribes
          <br />
          everything —{" "}
          <span style={{ color: "#22C55E" }}>offline</span>.
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
