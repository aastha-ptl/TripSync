import React, { useState, useEffect } from "react";
import { adminApi } from "../services/api";
import {
  Compass,
  Filter,
  Calendar,
  Users,
  CheckCircle2,
  Clock,
  PieChart,
  BarChart3,
  TrendingUp,
} from "lucide-react";

export default function TripAnalyticsView() {
  const currentYear = new Date().getFullYear();
  const currentMonth = new Date().getMonth() + 1; // 1-12

  const [year, setYear] = useState(currentYear);
  const [month, setMonth] = useState(currentMonth); // Default to current month as requested!
  const [status, setStatus] = useState("all");
  const [tripType, setTripType] = useState("all");

  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchAnalytics = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.getTripAnalytics({
        year,
        month: month || undefined,
        status,
        tripType,
      });
      setAnalytics(data);
    } catch (err) {
      setError(err.message || "Failed to load trip analytics");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, [year, month, status, tripType]);

  const monthNames = [
    { value: 1, label: "January" },
    { value: 2, label: "February" },
    { value: 3, label: "March" },
    { value: 4, label: "April" },
    { value: 5, label: "May" },
    { value: 6, label: "June" },
    { value: 7, label: "July" },
    { value: 8, label: "August" },
    { value: 9, label: "September" },
    { value: 10, label: "October" },
    { value: 11, label: "November" },
    { value: 12, label: "December" },
  ];

  // Calculate maximum values for relative graph heights
  const monthlyTrends = analytics?.monthlyTrends || [];
  const maxMonthlyCount = Math.max(...monthlyTrends.map((m) => m.tripCount), 1);

  const dailyTrends = analytics?.dailyTrends || [];
  const maxDailyCount = Math.max(...dailyTrends.map((d) => d.tripCount), 1);

  const totalTripsInYear = monthlyTrends.reduce((acc, curr) => acc + curr.tripCount, 0);
  const selectedMonthObj = monthNames.find((m) => m.value === month);
  const tripsInSelectedMonth = monthlyTrends.find((m) => m.monthIndex === month)?.tripCount || 0;

  return (
    <div>
      {/* Interactive Filter Toolbar */}
      <div className="filter-bar">
        <div className="filter-group">
          <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--accent-cyan)", fontWeight: 700 }}>
            <Filter size={16} />
            <span>Filters:</span>
          </div>

          {/* Year Filter */}
          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <label className="filter-label">Year:</label>
            <select
              className="filter-select"
              value={year}
              onChange={(e) => setYear(parseInt(e.target.value))}
            >
              <option value={2026}>2026</option>
              <option value={2025}>2025</option>
              <option value={2024}>2024</option>
            </select>
          </div>

          {/* Month Filter */}
          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <label className="filter-label">Month Focus:</label>
            <select
              className="filter-select"
              value={month || ""}
              onChange={(e) => setMonth(e.target.value ? parseInt(e.target.value) : null)}
            >
              <option value="">Full Year (Overview)</option>
              {monthNames.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </div>

          {/* Status Filter */}
          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <label className="filter-label">Status:</label>
            <select
              className="filter-select"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="planning">Planning</option>
              <option value="ongoing">Ongoing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>

          {/* Trip Type Filter */}
          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <label className="filter-label">Trip Type:</label>
            <select
              className="filter-select"
              value={tripType}
              onChange={(e) => setTripType(e.target.value)}
            >
              <option value="all">All Types</option>
              <option value="Friends">Friends</option>
              <option value="Family">Family</option>
              <option value="Business">Business</option>
            </select>
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
          <button
            onClick={() => {
              setYear(currentYear);
              setMonth(currentMonth);
              setStatus("all");
              setTripType("all");
            }}
            className="btn btn-secondary"
            style={{ fontSize: "0.75rem", padding: "6px 12px" }}
          >
            Reset to Current Month
          </button>
        </div>
      </div>

      {loading && (
        <div className="card loading-box">
          <div className="spinner"></div>
          <p>Aggregating anonymous platform trip metrics...</p>
        </div>
      )}

      {error && (
        <div className="card" style={{ borderColor: "rgba(244, 63, 94, 0.4)", color: "var(--accent-rose)" }}>
          {error}
        </div>
      )}

      {!loading && !error && (
        <>
          {/* Highlight Cards for Filtered Results Matching Mobile App */}
          <div className="grid-3">
            <div
              className="card kpi-card"
              style={{ background: "#F0FDF4", border: "1px solid #DCFCE7" }}
            >
              <div className="kpi-top">
                <span className="kpi-label" style={{ color: "#20C060" }}>
                  {month ? `${selectedMonthObj?.label} Trips` : `Total ${year} Trips`}
                </span>
                <div className="kpi-icon-wrap" style={{ background: "#DCFCE7", color: "#20C060" }}>
                  <TrendingUp size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ color: "#1A1D24" }}>
                {month ? tripsInSelectedMonth.toLocaleString() : totalTripsInYear.toLocaleString()}
              </div>
              <div className="kpi-trend trend-neutral" style={{ color: "#166534" }}>
                <span>Aggregated from all registered platform users</span>
              </div>
            </div>

            <div
              className="card kpi-card"
              style={{ background: "#EFF6FF", border: "1px solid #DBEAFE" }}
            >
              <div className="kpi-top">
                <span className="kpi-label" style={{ color: "#1E5AE6" }}>Active Filter Criteria</span>
                <div className="kpi-icon-wrap" style={{ background: "#DBEAFE", color: "#1E5AE6" }}>
                  <Filter size={20} />
                </div>
              </div>
              <div style={{ fontSize: "1.1rem", fontWeight: 800, marginTop: "6px", color: "#1A1D24" }}>
                Status: <span style={{ color: "#1E5AE6", textTransform: "capitalize" }}>{status}</span>
              </div>
              <div className="kpi-trend trend-neutral" style={{ color: "#1E40AF" }}>
                <span>Type: {tripType} | Focus: {month ? selectedMonthObj?.label : "Full Year"}</span>
              </div>
            </div>

            <div
              className="card kpi-card"
              style={{ background: "#FAF5FF", border: "1px solid #F3E8FF" }}
            >
              <div className="kpi-top">
                <span className="kpi-label" style={{ color: "#8B5CF6" }}>Yearly Velocity ({year})</span>
                <div className="kpi-icon-wrap" style={{ background: "#F3E8FF", color: "#8B5CF6" }}>
                  <Calendar size={20} />
                </div>
              </div>
              <div className="kpi-value" style={{ color: "#1A1D24" }}>{totalTripsInYear.toLocaleString()}</div>
              <div className="kpi-trend trend-neutral" style={{ color: "#6B21A8" }}>
                <span>Average {(totalTripsInYear / 12).toFixed(1)} trips / month</span>
              </div>
            </div>
          </div>

          {/* MAIN GRAPH 1: Monthly Trip Velocity (All Users) */}
          <div className="card" style={{ marginBottom: "24px" }}>
            <div className="card-header">
              <div>
                <div className="card-title">
                  <BarChart3 size={18} color="var(--accent-cyan)" />
                  Monthly Trips Frequency — {year} (All Users)
                </div>
                <div className="card-subtitle">
                  Click on any month column below to drill down into its day-by-day distribution
                </div>
              </div>
              <div style={{ display: "flex", gap: "8px" }}>
                <span className="header-chip" style={{ fontSize: "0.72rem" }}>
                  Peak Month: {monthlyTrends.reduce((max, m) => (m.tripCount > max.tripCount ? m : max), { monthName: "None", tripCount: 0 }).monthName}
                </span>
              </div>
            </div>

            {/* Visual Bar Chart */}
            <div className="chart-container">
              {monthlyTrends.map((item) => {
                const heightPercent = maxMonthlyCount > 0 ? (item.tripCount / maxMonthlyCount) * 100 : 0;
                const isSelected = month === item.monthIndex;

                return (
                  <div
                    key={item.monthIndex}
                    className="bar-column"
                    onClick={() => setMonth(item.monthIndex)}
                    title={`Click to view ${item.monthName} daily breakdown`}
                  >
                    <div className="bar-tooltip">
                      {item.monthName}: {item.tripCount} trips
                    </div>
                    <div
                      className={`bar-fill ${isSelected ? "active" : ""}`}
                      style={{ height: `${Math.max(heightPercent, 4)}%` }}
                    ></div>
                    <div
                      className="bar-label"
                      style={{
                        color: isSelected ? "var(--accent-cyan)" : "var(--text-muted)",
                        fontWeight: isSelected ? 800 : 500,
                      }}
                    >
                      {item.monthName}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* MAIN GRAPH 2: Day-by-Day Daily Breakdown (When Month is Selected) */}
          {month && dailyTrends.length > 0 && (
            <div className="card" style={{ marginBottom: "24px", borderColor: "rgba(6, 182, 212, 0.3)" }}>
              <div className="card-header">
                <div>
                  <div className="card-title" style={{ color: "var(--accent-cyan)" }}>
                    <Calendar size={18} />
                    Daily Trip Creation Breakdown: {selectedMonthObj?.label} {year}
                  </div>
                  <div className="card-subtitle">
                    Day 1 to {dailyTrends.length} progression for {selectedMonthObj?.label} across all users
                  </div>
                </div>
                <span className="header-chip" style={{ background: "rgba(6, 182, 212, 0.15)", color: "var(--accent-cyan)" }}>
                  {tripsInSelectedMonth} Total in {selectedMonthObj?.label}
                </span>
              </div>

              {/* Day-by-Day Bar Chart */}
              <div className="chart-container" style={{ gap: "4px", height: "240px" }}>
                {dailyTrends.map((d) => {
                  const heightPercent = maxDailyCount > 0 ? (d.tripCount / maxDailyCount) * 100 : 0;
                  return (
                    <div key={d.day} className="bar-column">
                      <div className="bar-tooltip">
                        Day {d.day}: {d.tripCount} trips
                      </div>
                      <div
                        className="bar-fill"
                        style={{
                          height: `${Math.max(heightPercent, 5)}%`,
                          background: d.tripCount > 0 ? "linear-gradient(180deg, #38bdf8 0%, #6366f1 100%)" : "rgba(255,255,255,0.06)",
                        }}
                      ></div>
                      <div className="bar-label" style={{ fontSize: "0.62rem" }}>
                        {d.day}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Breakdown Distributions */}
          <div className="grid-3">
            {/* Status Distribution */}
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">
                    <PieChart size={18} color="var(--accent-primary)" />
                    Trip Status Distribution
                  </div>
                  <div className="card-subtitle">Lifecycle state of trips in {year}</div>
                </div>
              </div>

              <div>
                {(analytics?.statusDistribution || []).map((s) => {
                  const percent = totalTripsInYear > 0 ? Math.round((s.count / totalTripsInYear) * 100) : 0;
                  return (
                    <div key={s.status} className="progress-bar-container">
                      <div className="pb-header">
                        <span style={{ textTransform: "capitalize", fontWeight: 600 }}>{s.status}</span>
                        <span style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
                          {s.count} ({percent}%)
                        </span>
                      </div>
                      <div className="pb-track">
                        <div className="pb-fill" style={{ width: `${percent}%` }}></div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Group Size Distribution */}
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">
                    <Users size={18} color="var(--accent-cyan)" />
                    Group Size Distribution
                  </div>
                  <div className="card-subtitle">Participant group volume analysis</div>
                </div>
              </div>

              <div>
                {(analytics?.groupSizeDistribution || []).map((g) => (
                  <div key={g.category} className="progress-bar-container">
                    <div className="pb-header">
                      <span style={{ fontWeight: 600 }}>{g.category}</span>
                      <span style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
                        {g.count} trips
                      </span>
                    </div>
                    <div className="pb-track">
                      <div
                        className="pb-fill"
                        style={{
                          width: `${Math.min(100, Math.max(10, g.count * 15))}%`,
                          background: "linear-gradient(90deg, var(--accent-cyan), var(--accent-emerald))",
                        }}
                      ></div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Trip Type Distribution */}
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">
                    <Compass size={18} color="var(--accent-amber)" />
                    Trip Classification
                  </div>
                  <div className="card-subtitle">Trip purpose categories</div>
                </div>
              </div>

              <div>
                {(analytics?.tripTypeDistribution || []).map((t) => {
                  const percent = totalTripsInYear > 0 ? Math.round((t.count / totalTripsInYear) * 100) : 0;
                  return (
                    <div key={t.type} className="progress-bar-container">
                      <div className="pb-header">
                        <span style={{ fontWeight: 600 }}>{t.type}</span>
                        <span style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
                          {t.count} ({percent}%)
                        </span>
                      </div>
                      <div className="pb-track">
                        <div
                          className="pb-fill"
                          style={{
                            width: `${percent}%`,
                            background: "linear-gradient(90deg, var(--accent-amber), var(--accent-rose))",
                          }}
                        ></div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
