import React from "react";
import {
  LayoutDashboard,
  Compass,
  CreditCard,
  Users,
  FileSpreadsheet,
  BellRing,
  Activity,
  ShieldCheck,
  LogOut,
} from "lucide-react";

export default function Sidebar({ currentTab, setTab, admin, onLogout }) {
  const navItems = [
    { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
    { id: "trips", label: "Trip Analytics", icon: Compass },
    { id: "expenses", label: "Expense Metrics", icon: CreditCard },
    { id: "users", label: "User Moderation", icon: Users },
    { id: "reports", label: "Reports & Export", icon: FileSpreadsheet },
    { id: "broadcast", label: "Broadcast Alert", icon: BellRing },
    { id: "health", label: "System Health", icon: Activity },
  ];

  return (
    <aside className="sidebar">
      <div className="brand-wrapper">
        <div className="brand-icon-box">
          <img
            src="/logo.png"
            alt="TripSync"
            style={{ width: "38px", height: "38px", objectFit: "contain" }}
          />
        </div>
        <div>
          <div className="brand-title">
            <span style={{ color: "#1A1D24" }}>Trip</span>
            <span style={{ color: "#20C060" }}>Sync</span>
          </div>
          <span className="brand-badge">ADMIN CONTROL</span>
        </div>
      </div>

      <div className="nav-menu">
        <div className="nav-section-title">PLATFORM GOVERNANCE</div>
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              className={`nav-item ${isActive ? "active" : ""}`}
              onClick={() => setTab(item.id)}
            >
              <Icon size={18} className="nav-icon" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </div>

      <div className="sidebar-footer">
        <div className="privacy-pill">
          <ShieldCheck size={16} />
          <span>Zero-PII Mode Active</span>
        </div>

        <div style={{ padding: "0 4px" }}>
          <div style={{ fontSize: "0.76rem", color: "var(--text-muted)" }}>Logged in as</div>
          <div
            style={{
              fontSize: "0.82rem",
              fontWeight: 600,
              color: "var(--text-primary)",
              textOverflow: "ellipsis",
              overflow: "hidden",
              whiteSpace: "nowrap",
            }}
          >
            {admin?.email || "Platform Admin"}
          </div>
        </div>

        <button
          onClick={onLogout}
          className="btn btn-secondary"
          style={{ width: "100%", justifyContent: "center", gap: "8px" }}
        >
          <LogOut size={16} />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  );
}
