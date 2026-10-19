import React, { useState } from "react";
import { adminApi } from "../services/api";
import { FileSpreadsheet, Download, Printer, Calendar, CheckCircle2, TrendingUp, Layers } from "lucide-react";

export default function ReportsView() {
  const currentYear = new Date().getFullYear();
  const currentMonth = new Date().getMonth() + 1;

  const [year, setYear] = useState(currentYear);
  const [month, setMonth] = useState(currentMonth);
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState(null);

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

  const handleGenerateReport = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.generateReport(year, month);
      setReport(data);
    } catch (err) {
      setError(err.message || "Failed to generate report");
    } finally {
      setLoading(false);
    }
  };

  const handleExportCsv = async () => {
    try {
      setExporting(true);
      await adminApi.exportReportCsv(year, month);
    } catch (err) {
      alert("Failed to export CSV: " + err.message);
    } finally {
      setExporting(false);
    }
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div>
      {/* Parameter Selection Bar */}
      <div className="filter-bar">
        <div className="filter-group">
          <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--accent-cyan)", fontWeight: 700 }}>
            <Calendar size={16} />
            <span>Report Parameters:</span>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <label className="filter-label">Month:</label>
            <select
              className="filter-select"
              value={month}
              onChange={(e) => setMonth(parseInt(e.target.value))}
            >
              {monthNames.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </div>

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

          <button onClick={handleGenerateReport} className="btn btn-primary" disabled={loading}>
            <FileSpreadsheet size={15} />
            {loading ? "Generating Report..." : "Generate Monthly Audit"}
          </button>
        </div>

        {report && (
          <div style={{ display: "flex", gap: "10px" }}>
            <button onClick={handleExportCsv} className="btn btn-secondary" disabled={exporting}>
              <Download size={15} />
              {exporting ? "Exporting..." : "Download CSV"}
            </button>
            <button onClick={handlePrint} className="btn btn-secondary">
              <Printer size={15} />
              Print / Save PDF
            </button>
          </div>
        )}
      </div>

      {error && (
        <div className="card" style={{ borderColor: "rgba(244, 63, 94, 0.4)", color: "var(--accent-rose)", marginBottom: "20px" }}>
          {error}
        </div>
      )}

      {!report && !loading && (
        <div className="card loading-box">
          <FileSpreadsheet size={48} strokeWidth={1.5} color="var(--accent-primary)" />
          <h3 style={{ fontSize: "1.1rem", color: "var(--text-primary)" }}>Generate Platform Compliance & Operations Report</h3>
          <p style={{ maxWidth: "460px", textAlign: "center", fontSize: "0.85rem", color: "var(--text-muted)" }}>
            Select the target month and year above to compile an executive audit. All trip and financial numbers are calculated in full aggregate with strict zero-knowledge of user identities.
          </p>
          <button onClick={handleGenerateReport} className="btn btn-primary" style={{ marginTop: "12px" }}>
            Generate October 2026 Report
          </button>
        </div>
      )}

      {loading && (
        <div className="card loading-box">
          <div className="spinner"></div>
          <p>Compiling cross-collection aggregations and calculating performance velocity...</p>
        </div>
      )}

      {report && !loading && (
        <div className="card" style={{ border: "1px solid rgba(99, 102, 241, 0.3)" }}>
          {/* Report Header */}
          <div
            style={{
              paddingBottom: "20px",
              borderBottom: "1px solid var(--border-subtle)",
              display: "flex",
              justifyContent: "space-between",
              alignItems: "flex-start",
              flexWrap: "wrap",
              gap: "14px",
            }}
          >
            <div>
              <div style={{ fontSize: "1.3rem", fontWeight: 800, color: "#ffffff" }}>
                {report.title}
              </div>
              <div style={{ fontSize: "0.78rem", color: "var(--text-muted)", marginTop: "4px" }}>
                Generated at: {new Date(report.generatedAt).toLocaleString()} | Timeframe: {report.period.startDate} to {report.period.endDate}
              </div>
            </div>

            <span className="masked-badge" style={{ fontSize: "0.74rem" }}>
              CONFIDENTIAL • SYSTEM AUDIT
            </span>
          </div>

          {/* Key Metrics Grid */}
          <div className="grid-3" style={{ marginTop: "24px", marginBottom: "24px" }}>
            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "20px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ fontSize: "0.78rem", color: "var(--text-muted)", textTransform: "uppercase", fontWeight: 700 }}>
                Trips Initiated
              </div>
              <div style={{ fontSize: "1.8rem", fontWeight: 800, marginTop: "6px", fontFamily: "var(--font-mono)" }}>
                {report.metrics.tripsCreated}
              </div>
              <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                Avg {report.metrics.averageTripsPerDay} trips / day
              </div>
            </div>

            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "20px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ fontSize: "0.78rem", color: "var(--text-muted)", textTransform: "uppercase", fontWeight: 700 }}>
                Completion Rate
              </div>
              <div style={{ fontSize: "1.8rem", fontWeight: 800, marginTop: "6px", color: "var(--accent-emerald)", fontFamily: "var(--font-mono)" }}>
                {report.metrics.completionRate}
              </div>
              <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                {report.metrics.tripsCompleted} trips concluded
              </div>
            </div>

            <div
              style={{
                background: "var(--bg-surface-elevated)",
                padding: "20px",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
              }}
            >
              <div style={{ fontSize: "0.78rem", color: "var(--text-muted)", textTransform: "uppercase", fontWeight: 700 }}>
                Shared Spend Volume
              </div>
              <div style={{ fontSize: "1.8rem", fontWeight: 800, marginTop: "6px", color: "var(--accent-amber)", fontFamily: "var(--font-mono)" }}>
                ₹{Math.round(report.metrics.totalExpenseVolume).toLocaleString()}
              </div>
              <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                Across {report.metrics.totalExpenseTransactions} transactions
              </div>
            </div>
          </div>

          {/* Full Audit Table */}
          <div className="table-wrapper">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Audit Metric</th>
                  <th>Aggregated Value</th>
                  <th>Calculation Scope</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td style={{ fontWeight: 600 }}>New User Registrations</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, color: "var(--accent-cyan)" }}>
                    {report.metrics.newUsersRegistered}
                  </td>
                  <td>Total user accounts created within selected monthly bounds</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 600 }}>Trips Created</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>
                    {report.metrics.tripsCreated}
                  </td>
                  <td>Total itinerary trip plans authored across all user groups</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 600 }}>Trips Successfully Completed</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, color: "var(--accent-emerald)" }}>
                    {report.metrics.tripsCompleted}
                  </td>
                  <td>Trips transitioned to 'completed' status</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 600 }}>Platform Completion Ratio</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>
                    {report.metrics.completionRate}
                  </td>
                  <td>Percentage of initiated trips finished successfully</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 600 }}>Gross Shared Expense Volume</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700, color: "var(--accent-amber)" }}>
                    ₹{Math.round(report.metrics.totalExpenseVolume).toLocaleString()}
                  </td>
                  <td>Aggregated currency volume split in groups</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 600 }}>Daily Trip Creation Velocity</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>
                    {report.metrics.averageTripsPerDay}
                  </td>
                  <td>Normalized frequency per calendar day</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
