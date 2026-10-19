import React, { useState, useEffect } from "react";
import { adminApi } from "../services/api";
import { CreditCard, PieChart, TrendingUp, DollarSign } from "lucide-react";

export default function ExpenseAnalyticsView() {
  const currentYear = new Date().getFullYear();
  const [year, setYear] = useState(currentYear);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchExpenses = async () => {
      try {
        setLoading(true);
        setError(null);
        const res = await adminApi.getExpenseAnalytics({ year });
        setData(res);
      } catch (err) {
        setError(err.message || "Failed to load expense analytics");
      } finally {
        setLoading(false);
      }
    };
    fetchExpenses();
  }, [year]);

  const categories = data?.categories || [];
  const monthlyTrends = data?.monthlyTrends || [];
  const splitTypes = data?.splitTypes || [];
  const currencies = data?.currencies || [];

  const maxMonthlyAmount = Math.max(...monthlyTrends.map((m) => m.amount), 1);
  const totalVolume = categories.reduce((sum, c) => sum + c.totalAmount, 0);

  return (
    <div>
      {/* Filter Bar */}
      <div className="filter-bar">
        <div className="filter-group">
          <label className="filter-label">Analytics Year:</label>
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
        <div className="header-chip" style={{ color: "var(--accent-amber)" }}>
          Strict Macro Aggregation (No Individual Financial Records)
        </div>
      </div>

      {loading && (
        <div className="card loading-box">
          <div className="spinner"></div>
          <p>Calculating platform financial split volumes...</p>
        </div>
      )}

      {error && (
        <div className="card" style={{ borderColor: "rgba(244, 63, 94, 0.4)", color: "var(--accent-rose)" }}>
          {error}
        </div>
      )}

      {!loading && !error && (
        <>
          {/* Top KPI row */}
          <div className="grid-3">
            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">Total Platform Volume ({year})</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(245, 158, 11, 0.15)", color: "var(--accent-amber)" }}>
                  <CreditCard size={20} />
                </div>
              </div>
              <div className="kpi-value">₹{Math.round(totalVolume).toLocaleString()}</div>
              <div className="kpi-trend trend-neutral">
                <span>Total settled & active shared expenses</span>
              </div>
            </div>

            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">Active Currencies</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(6, 182, 212, 0.15)", color: "var(--accent-cyan)" }}>
                  <DollarSign size={20} />
                </div>
              </div>
              <div className="kpi-value">{currencies.length}</div>
              <div className="kpi-trend trend-neutral">
                <span>{currencies.map((c) => c.currency).join(", ") || "INR"}</span>
              </div>
            </div>

            <div className="card kpi-card">
              <div className="kpi-top">
                <span className="kpi-label">Top Expense Category</span>
                <div className="kpi-icon-wrap" style={{ background: "rgba(16, 185, 129, 0.15)", color: "var(--accent-emerald)" }}>
                  <TrendingUp size={20} />
                </div>
              </div>
              <div style={{ fontSize: "1.4rem", fontWeight: 800, marginTop: "6px", textTransform: "capitalize" }}>
                {categories[0]?.category || "None"}
              </div>
              <div className="kpi-trend trend-neutral">
                <span>₹{(categories[0]?.totalAmount || 0).toLocaleString()} recorded</span>
              </div>
            </div>
          </div>

          {/* Monthly Spend Chart */}
          <div className="card" style={{ marginBottom: "24px" }}>
            <div className="card-header">
              <div>
                <div className="card-title">
                  <TrendingUp size={18} color="var(--accent-amber)" />
                  Monthly Platform Expense Volume — {year}
                </div>
                <div className="card-subtitle">Aggregated shared expense totals across all trips (INR)</div>
              </div>
            </div>

            <div className="chart-container">
              {monthlyTrends.map((m) => {
                const heightPercent = maxMonthlyAmount > 0 ? (m.amount / maxMonthlyAmount) * 100 : 0;
                return (
                  <div key={m.month} className="bar-column">
                    <div className="bar-tooltip">
                      {m.month}: ₹{m.amount.toLocaleString()} ({m.transactions} trans)
                    </div>
                    <div
                      className="bar-fill"
                      style={{
                        height: `${Math.max(heightPercent, 4)}%`,
                        background: "linear-gradient(180deg, #f59e0b 0%, #d97706 100%)",
                      }}
                    ></div>
                    <div className="bar-label">{m.month}</div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Breakdown by Category and Split Type */}
          <div className="grid-2">
            {/* Category Breakdown */}
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">
                    <PieChart size={18} color="var(--accent-cyan)" />
                    Category Allocation
                  </div>
                  <div className="card-subtitle">Aggregated spend distribution across travel categories</div>
                </div>
              </div>

              <div>
                {categories.length === 0 ? (
                  <div style={{ color: "var(--text-muted)", fontSize: "0.85rem", padding: "20px 0" }}>
                    No expense entries recorded in {year}.
                  </div>
                ) : (
                  categories.map((c) => {
                    const percent = totalVolume > 0 ? Math.round((c.totalAmount / totalVolume) * 100) : 0;
                    return (
                      <div key={c.category} className="progress-bar-container">
                        <div className="pb-header">
                          <span style={{ textTransform: "capitalize", fontWeight: 600 }}>{c.category}</span>
                          <span style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
                            ₹{c.totalAmount.toLocaleString()} ({percent}%)
                          </span>
                        </div>
                        <div className="pb-track">
                          <div className="pb-fill" style={{ width: `${percent}%` }}></div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>

            {/* Split Type Distribution */}
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Expense Split Types</div>
                  <div className="card-subtitle">How groups split expenses in TripSync</div>
                </div>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
                {splitTypes.map((st) => (
                  <div
                    key={st.type}
                    style={{
                      background: "var(--bg-surface-elevated)",
                      padding: "16px",
                      borderRadius: "var(--radius-md)",
                      border: "1px solid var(--border-subtle)",
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 700, textTransform: "capitalize" }}>{st.type} Split</div>
                      <div style={{ fontSize: "0.74rem", color: "var(--text-muted)" }}>
                        {st.type === "equal" ? "Even split across all participants" : "Custom weighted amounts"}
                      </div>
                    </div>
                    <div style={{ fontSize: "1.2rem", fontWeight: 800, fontFamily: "var(--font-mono)" }}>
                      {st.count}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
