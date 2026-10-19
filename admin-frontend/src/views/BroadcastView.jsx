import React, { useState } from "react";
import { adminApi } from "../services/api";
import { BellRing, Send, CheckCircle2, AlertCircle } from "lucide-react";

export default function BroadcastView() {
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [status, setStatus] = useState(null); // { type: 'success' | 'error', text: '' }

  const handleBroadcast = async (e) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;

    try {
      setSending(true);
      setStatus(null);
      const res = await adminApi.sendBroadcast(title, message);
      setStatus({ type: "success", text: res.message || "Announcement broadcasted successfully!" });
      setTitle("");
      setMessage("");
    } catch (err) {
      setStatus({ type: "error", text: err.message || "Failed to broadcast message." });
    } finally {
      setSending(false);
    }
  };

  return (
    <div style={{ maxWidth: "720px", margin: "0 auto" }}>
      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">
              <BellRing size={18} color="var(--accent-cyan)" />
              Broadcast System Announcement
            </div>
            <div className="card-subtitle">
              Dispatch high-priority in-app alerts and Socket notifications to all active mobile users
            </div>
          </div>
        </div>

        {status && (
          <div
            style={{
              padding: "12px 16px",
              borderRadius: "var(--radius-sm)",
              marginBottom: "20px",
              display: "flex",
              alignItems: "center",
              gap: "10px",
              fontSize: "0.86rem",
              background: status.type === "success" ? "rgba(16, 185, 129, 0.15)" : "rgba(244, 63, 94, 0.15)",
              color: status.type === "success" ? "var(--accent-emerald)" : "var(--accent-rose)",
              border: `1px solid ${status.type === "success" ? "rgba(16, 185, 129, 0.3)" : "rgba(244, 63, 94, 0.3)"}`,
            }}
          >
            {status.type === "success" ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
            <span>{status.text}</span>
          </div>
        )}

        <form onSubmit={handleBroadcast}>
          <div className="form-group">
            <label className="form-label">Notification Title</label>
            <input
              type="text"
              className="form-input"
              placeholder="e.g. Scheduled Infrastructure Maintenance, New Feature"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
              maxLength={100}
            />
          </div>

          <div className="form-group">
            <label className="form-label">Announcement Message Body</label>
            <textarea
              className="form-textarea"
              rows={5}
              placeholder="Provide a clear, helpful message for all mobile users..."
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              required
            />
          </div>

          <div
            style={{
              background: "var(--bg-surface-elevated)",
              padding: "14px",
              borderRadius: "var(--radius-sm)",
              marginBottom: "20px",
              fontSize: "0.78rem",
              color: "var(--text-muted)",
              lineHeight: 1.5,
            }}
          >
            ⚠️ <strong>Notice:</strong> This broadcast creates a persistent notification record in every active user's inbox and emits a real-time event through the TripSync Socket.IO cluster.
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            disabled={sending || !title.trim() || !message.trim()}
            style={{ width: "100%", padding: "12px" }}
          >
            <Send size={16} />
            {sending ? "Broadcasting to Users..." : "Send Announcement to All Users"}
          </button>
        </form>
      </div>
    </div>
  );
}
