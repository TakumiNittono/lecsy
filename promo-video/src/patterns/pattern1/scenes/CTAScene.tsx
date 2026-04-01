import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { LecsyLogo } from "../../../components/LecsyLogo";
import { GlowRing } from "../../../components/GlowRing";
import { Particles } from "../../../components/Particles";
import { Shimmer } from "../../../components/Shimmer";

const { fontFamily } = loadFont();

export const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const buttonEntrance = spring({
    frame,
    fps,
    delay: 20,
    config: { damping: 10, stiffness: 150 },
  });
  const buttonScale = interpolate(buttonEntrance, [0, 1], [0, 1]);
  const buttonOpacity = interpolate(buttonEntrance, [0, 0.3], [0, 1], {
    extrapolateRight: "clamp",
  });

  const pulse = interpolate(
    Math.sin(frame * 0.1),
    [-1, 1],
    [0.97, 1.03]
  );

  const storeEntrance = spring({
    frame,
    fps,
    delay: 35,
    config: { damping: 200 },
  });
  const storeOpacity = interpolate(storeEntrance, [0, 1], [0, 1]);
  const storeY = interpolate(storeEntrance, [0, 1], [15, 0]);

  const ring1 = interpolate(frame, [25, 80], [0.5, 1.5], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ring1Opacity = interpolate(frame, [25, 80], [0.3, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ring2 = interpolate(frame, [40, 95], [0.5, 1.5], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ring2Opacity = interpolate(frame, [40, 95], [0.3, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 45%, #1E3A5F 0%, #0F172A 60%, #020617 100%)",
      }}
    >
      <Particles color="rgba(59,130,246,0.3)" />

      <div
        style={{
          position: "absolute",
          top: 640,
          left: "50%",
          transform: "translateX(-50%)",
        }}
      >
        <GlowRing size={350} delay={5} color1="#3B82F6" color2="#8B5CF6" />
      </div>

      {[
        { scale: ring1, opacity: ring1Opacity },
        { scale: ring2, opacity: ring2Opacity },
      ].map((ring, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: "50%",
            left: "50%",
            width: 200,
            height: 200,
            borderRadius: "50%",
            border: "2px solid rgba(59,130,246,0.4)",
            transform: `translate(-50%, -50%) scale(${ring.scale})`,
            opacity: ring.opacity,
          }}
        />
      ))}

      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: 60,
        }}
      >
        <LecsyLogo size={150} delay={0} />

        <div style={{ height: 60 }} />

        <div
          style={{
            opacity: buttonOpacity,
            transform: `scale(${buttonScale * pulse})`,
            background: "linear-gradient(135deg, #3B82F6, #06B6D4)",
            borderRadius: 28,
            padding: "32px 72px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow:
              "0 8px 40px rgba(59,130,246,0.5), 0 0 80px rgba(6,182,212,0.2)",
            position: "relative",
            overflow: "hidden",
          }}
        >
          <Shimmer delay={30} duration={40} />
          <span
            style={{
              fontFamily,
              fontSize: 46,
              fontWeight: 900,
              color: "#FFFFFF",
              letterSpacing: -0.5,
            }}
          >
            Download Free
          </span>
        </div>

        <div
          style={{
            opacity: storeOpacity,
            transform: `translateY(${storeY}px)`,
            marginTop: 28,
          }}
        >
          <span
            style={{
              fontFamily,
              fontSize: 26,
              fontWeight: 600,
              color: "#64748B",
              letterSpacing: 3,
              textTransform: "uppercase",
            }}
          >
            App Store
          </span>
        </div>
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.5) 100%)",
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
