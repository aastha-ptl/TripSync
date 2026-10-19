import React from "react";
import {
  Users,
  Compass,
  CreditCard,
  Flame,
  ArrowUpRight,
  ArrowDownRight,
  MessageSquare,
  Image,
  FileText,
  BarChart2,
  Calendar,
} from "lucide-react";

export default function DashboardView({ overview, onNavigate, onRefresh }) {
  if (!overview) return null;

  const { users, trips, expenses, engagement } = overview;

  return (
    <div>
      {/* 4 KPI Cards Matching Mobile App Colors */}
      <div className="grid-4">
        {/* Total Users */}
        <div
          className="card kpi-card"
          style={{ background: "#EFF6FF", border: "1px solid #DBEAFE" }}
        >
          <div className="kpi-top">
            <span className="kpi-label" style={{ color: "#1E5AE6" }}>Platform Accounts</span>
            <div
              className="kpi-icon-wrap"
              style={{ background: "#DBEAFE", color: "#1E5AE6" }}
            >
              <Users size={20} />
            </div>
          </div>
          <div className="kpi-value">{users?.total?.toLocaleString() || 0}</div>
          <div className="kpi-trend trend-up" style={{ color: "#1E5AE6" }}>
            <span>{users?.active?.toLocaleString() || 0} currently active</span>
          </div>
        </div>

        {/* Trips This Month */}
        <div
          className="card kpi-card"
          style={{ background: "#F0FDF4", border: "1px solid #DCFCE7" }}
        >
          <div className="kpi-top">
            <span className="kpi-label" style={{ color: "#20C060" }}>Trips This Month</span>
            <div
              className="kpi-icon-wrap"
              style={{ background: "#DCFCE7", color: "#20C060" }}
            >
              <Calendar size={20} />
            </div>
          </div>
          <div className="kpi-value">{trips?.thisMonth?.toLocaleString() || 0}</div>
          <div
            className={`kpi-trend ${
              (trips?.growthPercent || 0) >= 0 ? "trend-up" : "trend-down"
            }`}
          >
            {(trips?.growthPercent || 0) >= 0 ? (
              <ArrowUpRight size={16} />
            ) : (
              <ArrowDownRight size={16} />
            )}
            <span>
              {trips?.growthPercent > 0 ? `+${trips?.growthPercent}%` : `${trips?.growthPercent || 0}%`} vs last month
            </span>
          </div>
        </div>

        {/* Active Ongoing Trips */}
        <div
          className="card kpi-card"
          style={{ background: "#FAF5FF", border: "1px solid #F3E8FF" }}
        >
          <div className="kpi-top">
            <span className="kpi-label" style={{ color: "#8B5CF6" }}>Live Ongoing Trips</span>
            <div
              className="kpi-icon-wrap"
              style={{ background: "#F3E8FF", color: "#8B5CF6" }}
            >
              <Flame size={20} />
            </div>
          </div>
          <div className="kpi-value">{trips?.activeNow?.toLocaleString() || 0}</div>
          <div className="kpi-trend trend-neutral" style={{ color: "#7C3AED" }}>
            <span>{trips?.completed?.toLocaleString() || 0} completed</span>
          </div>
        </div>

        {/* Total Expense Volume */}
        <div
          className="card kpi-card"
          style={{ background: "#FFFBEB", border: "1px solid #FDE68A" }}
        >
          <div className="kpi-top">
            <span className="kpi-label" style={{ color: "#D97706" }}>Shared Expense Volume</span>
            <div
              className="kpi-icon-wrap"
              style={{ background: "#FEF3C7", color: "#D97706" }}
            >
              <CreditCard size={20} />
            </div>
          </div>
          <div className="kpi-value" style={{ fontSize: "1.7rem" }}>
            ₹{Math.round(expenses?.totalAmount || 0).toLocaleString()}
          </div>
          <div className="kpi-trend trend-neutral" style={{ color: "#B45309" }}>
            <span>{expenses?.totalTransactions?.toLocaleString() || 0} transactions split</span>
          </div>
        </div>
      </div>

      {/* Engagement & Quick Actions */}
      <div className="grid-2">
        {/* Platform Engagement Metrics */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">
                <BarChart2 size={18} color="var(--accent-cyan)" />
                Platform Activity & Content Footprint
              </div>
              <div className="card-subtitle">Aggregated interaction counts without personal data exposure</div>
            </div>
          </div>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
              gap: "16px",
              marginTop: "12px",
            }}
          >
            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "16px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-muted)", fontSize: "0.8rem" }}>
                <MessageSquare size={16} color="var(--accent-primary)" />
                <span>Chat Messages</span>
              </div>
              <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "8px", fontFamily: "var(--font-mono)" }}>
                {engagement?.chatMessages?.toLocaleString() || 0}
              </div>
            </div>

            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "16px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-muted)", fontSize: "0.8rem" }}>
                <Image size={16} color="var(--accent-cyan)" />
                <span>Photos Shared</span>
              </div>
              <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "8px", fontFamily: "var(--font-mono)" }}>
                {engagement?.photos?.toLocaleString() || 0}
              </div>
            </div>

            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "16px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-muted)", fontSize: "0.8rem" }}>
                <FileText size={16} color="var(--accent-emerald)" />
                <span>Documents Stored</span>
              </div>
              <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "8px", fontFamily: "var(--font-mono)" }}>
                {engagement?.documents?.toLocaleString() || 0}
              </div>
            </div>

            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "16px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-muted)", fontSize: "0.8rem" }}>
                <BarChart2 size={16} color="var(--accent-amber)" />
                <span>Polls Conducted</span>
              </div>
              <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "8px", fontFamily: "var(--font-mono)" }}>
                {engagement?.polls?.toLocaleString() || 0}
              </div>
            </div>
          </div>
        </div>

        {/* Quick Launchpad */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Quick Intelligence Actions</div>
              <div className="card-subtitle">Frequently accessed administrative tools</div>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            <button
              onClick={() => onNavigate("trips")}
              className="btn btn-secondary"
              style={{ justifyContent: "flex-start", padding: "14px", borderRadius: "var(--radius-md)" }}
            >
              <Compass size={18} color="var(--accent-cyan)" />
              <div style={{ textAlign: "left", marginLeft: "8px" }}>
                <div style={{ fontSize: "0.86rem", fontWeight: 700 }}>Inspect Monthly Trip Graphs</div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-muted)" }}>
                  Filter this month's trip velocity, group sizes, and status
                </div>
              </div>
            </button>

            <button
              onClick={() => onNavigate("reports")}
              className="btn btn-secondary"
              style={{ justifyContent: "flex-start", padding: "14px", borderRadius: "var(--radius-md)" }}
            >
              <FileText size={18} color="var(--accent-primary)" />
              <div style={{ textAlign: "left", marginLeft: "8px" }}>
                <div style={{ fontSize: "0.86rem", fontWeight: 700 }}>Generate Monthly Report</div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-muted)" }}>
                  Export monthly compliance and growth audit as CSV/Print
                </div>
              </div>
            </button>

            <button
              onClick={() => onNavigate("broadcast")}
              className="btn btn-secondary"
              style={{ justifyContent: "flex-start", padding: "14px", borderRadius: "var(--radius-md)" }}
            >
              <MessageSquare size={18} color="var(--accent-emerald)" />
              <div style={{ textAlign: "left", marginLeft: "8px" }}>
                <div style={{ fontSize: "0.86rem", fontWeight: 700 }}>Broadcast Platform Announcement</div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-muted)" }}>
                  Send instantaneous alerts to all active mobile users
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
