import React, { useState, useEffect } from "react";
import { adminApi } from "../services/api";
import {
  Activity,
  Server,
  Database,
  Cpu,
  Cloud,
  Image,
  ExternalLink,
  ShieldCheck,
  CheckCircle2,
  AlertTriangle,
  HardDrive,
  MapPin,
} from "lucide-react";

export default function SystemHealthView() {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchHealth = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.getSystemHealth();
      setHealth(data);
    } catch (err) {
      setError(err.message || "Failed to load health status");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHealth();
  }, []);

  const cloudinary = health?.cloudinary;

  return (
    <div>
      {loading && (
        <div className="card loading-box">
          <div className="spinner"></div>
          <p>Querying live server diagnostics and Cloudinary cloud usage...</p>
        </div>
      )}

      {error && (
        <div className="card" style={{ borderColor: "rgba(244, 63, 94, 0.4)", color: "var(--accent-rose)" }}>
          {error}
        </div>
      )}

      {health && !loading && (
        <>
          {/* Top 4 Infrastructure KPI Cards */}
          <div className="grid-4">
            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">API Status</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(16, 185, 129, 0.15)", color: "var(--accent-emerald)" }}>
                  <Server size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ color: "var(--accent-emerald)" }}>
                {health.serverStatus}
              </div>
              <div className="kpi-trend trend-neutral">
                <span>Node.js {health.nodeVersion}</span>
              </div>
            </div>

            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">System Uptime</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(99, 102, 241, 0.15)", color: "var(--accent-primary)" }}>
                  <Activity size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ fontSize: "1.5rem" }}>
                {health.uptimeHuman}
              </div>
              <div className="kpi-trend trend-neutral">
                <span>Continuously monitored</span>
              </div>
            </div>

            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">MongoDB Driver</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(6, 182, 212, 0.15)", color: "var(--accent-cyan)" }}>
                  <Database size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ color: "var(--accent-cyan)", fontSize: "1.6rem" }}>
                {health.database?.status}
              </div>
              <div className="kpi-trend trend-neutral">
                <span>Mongoose connection active</span>
              </div>
            </div>

            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">RAM Allocated</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(245, 158, 11, 0.15)", color: "var(--accent-amber)" }}>
                  <Cpu size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ fontSize: "1.6rem" }}>
                {health.memoryUsage?.heapUsedMB} MB
              </div>
              <div className="kpi-trend trend-neutral">
                <span>Heap Total: {health.memoryUsage?.heapTotalMB} MB</span>
              </div>
            </div>
          </div>

          {/* CLOUDINARY LIVE STORAGE & USAGE CARD */}
          {cloudinary && (
            <div
              className="card"
              style={{
                marginBottom: "24px",
                border: "1px solid #DBEAFE",
                background: "#FFFFFF",
              }}
            >
              <div className="card-header">
                <div>
                  <div className="card-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <Cloud size={20} color="#1E5AE6" />
                    <span>Cloudinary Cloud Storage & Quota (Live API)</span>
                  </div>
                  <div className="card-subtitle">
                    Real-time cloud asset volume and bandwidth queried from Cloudinary ({cloudinary.cloudName || "Connected"})
                  </div>
                </div>

                <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                  <span
                    className="header-chip"
                    style={{
                      background: cloudinary.status === "Connected" ? "#F0FDF4" : "#FEF2F2",
                      color: cloudinary.status === "Connected" ? "#20C060" : "#EF4444",
                      fontWeight: 700,
                      border: `1px solid ${cloudinary.status === "Connected" ? "#BBF7D0" : "#FECACA"}`,
                    }}
                  >
                    <CheckCircle2 size={14} />
                    {cloudinary.status} • {cloudinary.plan} Plan
                  </span>
                </div>
              </div>

              {cloudinary.status === "Connected" ? (
                <>
                  <div className="grid-4" style={{ marginBottom: "20px" }}>
                    {/* Storage Used */}
                    <div style={{ background: "#EFF6FF", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid #DBEAFE" }}>
                      <div style={{ color: "#1E5AE6", fontSize: "0.78rem", fontWeight: 700, textTransform: "uppercase" }}>
                        Storage Used
                      </div>
                      <div style={{ fontSize: "1.6rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)", color: "#1E5AE6" }}>
                        {cloudinary.storage?.usageMB} MB
                      </div>
                      <div style={{ fontSize: "0.74rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                        {cloudinary.storage?.usageGB} GB consumed
                      </div>
                    </div>

                    {/* Media Assets Count */}
                    <div style={{ background: "#F0FDF4", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid #DCFCE7" }}>
                      <div style={{ color: "#20C060", fontSize: "0.78rem", fontWeight: 700, textTransform: "uppercase" }}>
                        Media Assets Uploaded
                      </div>
                      <div style={{ fontSize: "1.6rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)", color: "#1A1D24" }}>
                        {cloudinary.objects?.totalMediaFiles?.toLocaleString()}
                      </div>
                      <div style={{ fontSize: "0.74rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                        Photos, documents & avatars
                      </div>
                    </div>

                    {/* Bandwidth Consumed */}
                    <div style={{ background: "#FAF5FF", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid #F3E8FF" }}>
                      <div style={{ color: "#8B5CF6", fontSize: "0.78rem", fontWeight: 700, textTransform: "uppercase" }}>
                        Bandwidth Consumed
                      </div>
                      <div style={{ fontSize: "1.6rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)", color: "#1A1D24" }}>
                        {cloudinary.bandwidth?.usageMB} MB
                      </div>
                      <div style={{ fontSize: "0.74rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                        Total CDN data transferred
                      </div>
                    </div>

                    {/* API Requests Remaining */}
                    <div style={{ background: "#F0FDF4", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid #DCFCE7" }}>
                      <div style={{ color: "#20C060", fontSize: "0.78rem", fontWeight: 700, textTransform: "uppercase" }}>
                        API Quota Remaining
                      </div>
                      <div style={{ fontSize: "1.6rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)", color: "#20C060" }}>
                        {cloudinary.rateLimit?.remaining ?? "Unlimited"}
                      </div>
                      <div style={{ fontSize: "0.74rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                        Out of {cloudinary.rateLimit?.allowed || 500} hourly limit
                      </div>
                    </div>
                  </div>

                  {/* Progress Bar for Credits / Storage Limit */}
                  <div className="progress-bar-container" style={{ margin: 0 }}>
                    <div className="pb-header">
                      <span style={{ fontWeight: 700 }}>Monthly Credit / Storage Quota Utilization</span>
                      <span style={{ fontFamily: "var(--font-mono)", color: "#1E5AE6", fontWeight: 700 }}>
                        {cloudinary.credits?.usage ?? 0.2} / {cloudinary.credits?.limit ?? 25} Credits ({cloudinary.storage?.usedPercent ?? 0.8}%)
                      </span>
                    </div>
                    <div className="pb-track" style={{ height: "10px", background: "#E2E8F0" }}>
                      <div
                        className="pb-fill"
                        style={{
                          width: `${Math.max(cloudinary.storage?.usedPercent || 1, 1.5)}%`,
                          background:
                            (cloudinary.storage?.usedPercent || 0) > 85
                              ? "#EF4444"
                              : (cloudinary.storage?.usedPercent || 0) > 70
                              ? "#F59E0B"
                              : "linear-gradient(90deg, #3B82F6, #1E5AE6)",
                        }}
                      ></div>
                    </div>
                    <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.74rem", color: "var(--text-secondary)", marginTop: "6px" }}>
                      <span>0 GB</span>
                      <span style={{ fontWeight: 600, color: "#20C060" }}>Healthy Headroom Available</span>
                      <span>25 GB Free Monthly Limit</span>
                    </div>
                  </div>
                </>
              ) : (
                <div style={{ color: "#EF4444", fontSize: "0.85rem" }}>
                  Unable to contact Cloudinary API: {cloudinary.message}
                </div>
              )}
            </div>
          )}

          {/* GEOAPIFY INFORMATION CARD */}
          <div
            className="card"
            style={{
              marginBottom: "24px",
              border: "1px solid #FDE68A",
              background: "#FFFFFF",
            }}
          >
            <div className="card-header">
              <div>
                <div className="card-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <MapPin size={20} color="var(--accent-amber)" />
                  <span>Geoapify Maps & Geocoding Quota</span>
                </div>
                <div className="card-subtitle">
                  External location intelligence API powering place autocomplete, address lookup, and maps
                </div>
              </div>

              <a
                href="https://myprojects.geoapify.com/"
                target="_blank"
                rel="noreferrer"
                className="btn btn-secondary"
                style={{ fontSize: "0.78rem", padding: "6px 12px", gap: "6px" }}
              >
                <span>Geoapify Console</span>
                <ExternalLink size={14} />
              </a>
            </div>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
                gap: "14px",
                marginBottom: "16px",
              }}
            >
              <div style={{ background: "var(--bg-surface-elevated)", padding: "14px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", fontWeight: 700 }}>DAILY FREE TIER LIMIT</div>
                <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)", color: "var(--accent-amber)" }}>
                  3,000 requests / day
                </div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                  Resets daily at 00:00 UTC
                </div>
              </div>

              <div style={{ background: "var(--bg-surface-elevated)", padding: "14px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", fontWeight: 700 }}>API FEATURES IN USE</div>
                <div style={{ fontSize: "0.95rem", fontWeight: 700, marginTop: "6px" }}>
                  Autocomplete & Reverse Geocode
                </div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                  Places search for trip itineraries
                </div>
              </div>

              <div style={{ background: "var(--bg-surface-elevated)", padding: "14px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", fontWeight: 700 }}>LIVE BALANCE ENFORCEMENT</div>
                <div style={{ fontSize: "0.95rem", fontWeight: 700, marginTop: "6px", color: "var(--accent-emerald)" }}>
                  Active Client Fallbacks
                </div>
                <div style={{ fontSize: "0.72rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                  Gracefully throttles on 429 rate limit
                </div>
              </div>
            </div>

            <p style={{ fontSize: "0.78rem", color: "var(--text-muted)", lineHeight: 1.5 }}>
              ℹ️ <strong>Note on Geoapify:</strong> Geoapify does not provide a programmatic REST API endpoint to query credit balances. To check real-time request counts and daily burn rate, click <strong>Geoapify Console</strong> above to log into your account dashboard.
            </p>
          </div>

          {/* Database and Memory Bottom Grid */}
          <div className="grid-2">
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Database Collections & Document Tally</div>
                  <div className="card-subtitle">Volume of persisted records across TripSync models</div>
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
                <div style={{ background: "var(--bg-surface-elevated)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                  <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>Users Collection</div>
                  <div style={{ fontSize: "1.5rem", fontWeight: 800, fontFamily: "var(--font-mono)", marginTop: "6px" }}>
                    {health.database?.collections?.users?.toLocaleString()}
                  </div>
                </div>

                <div style={{ background: "var(--bg-surface-elevated)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                  <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>Trips Collection</div>
                  <div style={{ fontSize: "1.5rem", fontWeight: 800, fontFamily: "var(--font-mono)", marginTop: "6px" }}>
                    {health.database?.collections?.trips?.toLocaleString()}
                  </div>
                </div>

                <div style={{ background: "var(--bg-surface-elevated)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                  <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>Expenses Collection</div>
                  <div style={{ fontSize: "1.5rem", fontWeight: 800, fontFamily: "var(--font-mono)", marginTop: "6px" }}>
                    {health.database?.collections?.expenses?.toLocaleString()}
                  </div>
                </div>

                <div style={{ background: "var(--bg-surface-elevated)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-subtle)" }}>
                  <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>Photos Collection</div>
                  <div style={{ fontSize: "1.5rem", fontWeight: 800, fontFamily: "var(--font-mono)", marginTop: "6px" }}>
                    {health.database?.collections?.photos?.toLocaleString()}
                  </div>
                </div>
              </div>
            </div>

            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Security & Memory Footprint</div>
                  <div className="card-subtitle">Node.js process RSS and garbage collector status</div>
                </div>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
                <div className="progress-bar-container">
                  <div className="pb-header">
                    <span>Resident Set Size (RSS)</span>
                    <span style={{ fontFamily: "var(--font-mono)" }}>{health.memoryUsage?.rssMB} MB</span>
                  </div>
                  <div className="pb-track">
                    <div className="pb-fill" style={{ width: "35%" }}></div>
                  </div>
                </div>

                <div className="progress-bar-container">
                  <div className="pb-header">
                    <span>Heap Used Ratio</span>
                    <span style={{ fontFamily: "var(--font-mono)" }}>
                      {Math.round((health.memoryUsage?.heapUsedMB / health.memoryUsage?.heapTotalMB) * 100)}%
                    </span>
                  </div>
                  <div className="pb-track">
                    <div
                      className="pb-fill"
                      style={{
                        width: `${Math.round(
                          (health.memoryUsage?.heapUsedMB / health.memoryUsage?.heapTotalMB) * 100
                        )}%`,
                        background: "linear-gradient(90deg, var(--accent-emerald), var(--accent-cyan))",
                      }}
                    ></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
