import React from "react";
import { RefreshCw, Shield, Clock } from "lucide-react";

export default function Header({ title, subtitle, onRefresh, loading }) {
  const currentTime = new Date().toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });

  return (
    <header className="top-header">
      <div className="header-left">
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>

      <div className="header-right">
        <div className="header-chip">
          <Clock size={14} color="var(--text-muted)" />
          <span>{currentTime}</span>
        </div>

        <div className="header-chip">
          <div className="status-dot"></div>
          <span>Production Core</span>
        </div>

        <button
          onClick={onRefresh}
          className="btn btn-secondary"
          style={{ padding: "7px 12px", gap: "6px" }}
          title="Refresh platform data"
          disabled={loading}
        >
          <RefreshCw size={14} className={loading ? "spinner" : ""} />
          <span style={{ fontSize: "0.78rem" }}>Refresh</span>
        </button>
      </div>
    </header>
  );
}
