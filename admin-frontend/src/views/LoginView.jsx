import React, { useState } from "react";
import { adminApi } from "../services/api";
import { Compass, ShieldCheck, Lock, Mail, KeyRound, Sparkles } from "lucide-react";

export default function LoginView({ onLoginSuccess }) {
  const [isSetupMode, setIsSetupMode] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [setupKey, setSetupKey] = useState("tripsync-admin-setup-2026");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (isSetupMode) {
        const data = await adminApi.setupInitialAdmin(email, password, setupKey);
        onLoginSuccess({ email: data.email, role: data.role });
      } else {
        const data = await adminApi.login(email, password);
        onLoginSuccess(data.admin);
      }
    } catch (err) {
      setError(err.message || "Authentication failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px",
        background: "#F7F9FC",
      }}
    >
      <div
        className="card"
        style={{
          maxWidth: "440px",
          width: "100%",
          padding: "36px",
          background: "#FFFFFF",
          boxShadow: "0 10px 30px rgba(0, 0, 0, 0.08)",
          border: "1px solid #E5E7EB",
        }}
      >
        <div style={{ textAlign: "center", marginBottom: "28px" }}>
          <div
            className="brand-icon-box"
            style={{ margin: "0 auto 16px auto", width: "56px", height: "56px" }}
          >
            <img
              src="/logo.png"
              alt="TripSync"
              style={{ width: "46px", height: "46px", objectFit: "contain" }}
            />
          </div>
          <h2 style={{ fontSize: "1.5rem", fontWeight: 800, letterSpacing: "-0.02em" }}>
            <span style={{ color: "#1A1D24" }}>Trip</span>
            <span style={{ color: "#20C060" }}>Sync</span>
          </h2>
          <p style={{ fontSize: "0.82rem", color: "var(--text-secondary)", marginTop: "4px" }}>
            Zero-PII Platform Intelligence & Governance
          </p>
        </div>

        {error && (
          <div
            style={{
              padding: "10px 14px",
              background: "rgba(244, 63, 94, 0.15)",
              color: "var(--accent-rose)",
              border: "1px solid rgba(244, 63, 94, 0.3)",
              borderRadius: "var(--radius-sm)",
              fontSize: "0.82rem",
              marginBottom: "18px",
            }}
          >
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label">Administrator Email</label>
            <div style={{ position: "relative" }}>
              <input
                type="email"
                className="form-input"
                style={{ width: "100%", paddingLeft: "36px" }}
                placeholder="admin@tripsync.app"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
              <Mail
                size={16}
                color="var(--text-muted)"
                style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)" }}
              />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Admin Password</label>
            <div style={{ position: "relative" }}>
              <input
                type="password"
                className="form-input"
                style={{ width: "100%", paddingLeft: "36px" }}
                placeholder="••••••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <Lock
                size={16}
                color="var(--text-muted)"
                style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)" }}
              />
            </div>
          </div>

          {isSetupMode && (
            <div className="form-group">
              <label className="form-label">Initial Bootstrap Setup Key</label>
              <div style={{ position: "relative" }}>
                <input
                  type="text"
                  className="form-input"
                  style={{ width: "100%", paddingLeft: "36px" }}
                  placeholder="tripsync-admin-setup-2026"
                  value={setupKey}
                  onChange={(e) => setSetupKey(e.target.value)}
                  required
                />
                <KeyRound
                  size={16}
                  color="var(--text-muted)"
                  style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)" }}
                />
              </div>
              <span style={{ fontSize: "0.72rem", color: "var(--text-muted)", marginTop: "4px" }}>
                Default bootstrap key configured in server environment.
              </span>
            </div>
          )}

          <button
            type="submit"
            className="btn btn-primary"
            style={{ width: "100%", padding: "12px", marginTop: "8px" }}
            disabled={loading}
          >
            {loading ? (
              <span style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                <div className="spinner" style={{ width: "18px", height: "18px" }}></div>
                Authenticating...
              </span>
            ) : isSetupMode ? (
              "Configure & Bootstrap Admin"
            ) : (
              "Sign In to Control Center"
            )}
          </button>
        </form>

        <div style={{ marginTop: "22px", textAlign: "center", borderTop: "1px solid var(--border-subtle)", paddingTop: "16px" }}>
          <button
            type="button"
            onClick={() => {
              setIsSetupMode(!isSetupMode);
              setError(null);
            }}
            style={{
              background: "none",
              border: "none",
              color: "var(--accent-cyan)",
              fontSize: "0.8rem",
              fontWeight: 600,
              cursor: "pointer",
              display: "inline-flex",
              alignItems: "center",
              gap: "6px",
            }}
          >
            <Sparkles size={14} />
            {isSetupMode ? "Already have an admin account? Sign In" : "Need to setup initial admin? Click here"}
          </button>
        </div>

        <div
          style={{
            marginTop: "20px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: "6px",
            color: "var(--accent-emerald)",
            fontSize: "0.74rem",
            fontWeight: 600,
          }}
        >
          <ShieldCheck size={14} />
          <span>Strict Zero-PII Isolation Certified</span>
        </div>
      </div>
    </div>
  );
}
