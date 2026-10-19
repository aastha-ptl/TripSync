import React, { useState, useEffect } from "react";
import { adminApi } from "../services/api";
import { Users, Search, ShieldAlert, CheckCircle, Ban, ArrowLeft, ArrowRight, Mail } from "lucide-react";

export default function UsersView() {
  const [users, setUsers] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 15, total: 0, totalPages: 1 });
  const [statusFilter, setStatusFilter] = useState("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Modal state
  const [selectedUser, setSelectedUser] = useState(null);
  const [actionType, setActionType] = useState(null); // 'suspend' | 'activate'
  const [actionLoading, setActionLoading] = useState(false);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await adminApi.getUsers({
        page: pagination.page,
        limit: pagination.limit,
        status: statusFilter,
        search: searchTerm,
      });
      setUsers(res.users);
      setPagination(res.pagination);
    } catch (err) {
      setError(err.message || "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [pagination.page, statusFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPagination((prev) => ({ ...prev, page: 1 }));
    fetchUsers();
  };

  const handleConfirmStatusChange = async () => {
    if (!selectedUser || !actionType) return;
    try {
      setActionLoading(true);
      const newStatus = actionType === "suspend" ? "suspended" : "active";
      await adminApi.updateUserStatus(selectedUser.id, newStatus);
      setSelectedUser(null);
      setActionType(null);
      fetchUsers();
    } catch (err) {
      alert(err.message || "Action failed");
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div>
      {/* Search & Filter Toolbar */}
      <div className="filter-bar">
        <form onSubmit={handleSearchSubmit} style={{ display: "flex", gap: "10px", flex: 1, maxWidth: "450px" }}>
          <div style={{ position: "relative", width: "100%" }}>
            <input
              type="text"
              placeholder="Search by name, email, or ID..."
              className="form-input"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: "100%", paddingLeft: "36px" }}
            />
            <Search
              size={16}
              color="var(--text-muted)"
              style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)" }}
            />
          </div>
          <button type="submit" className="btn btn-secondary">
            Search
          </button>
        </form>

        <div className="filter-group">
          <label className="filter-label">Account Status:</label>
          <select
            className="filter-select"
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPagination((prev) => ({ ...prev, page: 1 }));
            }}
          >
            <option value="all">All Accounts</option>
            <option value="active">Active Only</option>
            <option value="suspended">Suspended</option>
            <option value="pending_verification">Pending Verification</option>
          </select>
        </div>
      </div>

      {loading && (
        <div className="card loading-box">
          <div className="spinner"></div>
          <p>Loading user accounts...</p>
        </div>
      )}

      {error && (
        <div className="card" style={{ borderColor: "rgba(244, 63, 94, 0.4)", color: "var(--accent-rose)" }}>
          {error}
        </div>
      )}

      {!loading && !error && (
        <div className="card" style={{ padding: "0", overflow: "hidden" }}>
          <div style={{ padding: "20px 24px", borderBottom: "1px solid var(--border-subtle)" }}>
            <div className="card-title">
              <Users size={18} color="var(--accent-primary)" />
              User Account Management
            </div>
            <div className="card-subtitle">
              Manage registered user accounts, view user emails, and moderate account access.
            </div>
          </div>

          <div className="table-wrapper" style={{ border: "none" }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>System Role</th>
                  <th>Account Status</th>
                  <th>Registration Date</th>
                  <th>Last Active</th>
                  <th>Trips Joined</th>
                  <th style={{ textAlign: "right" }}>Moderation Action</th>
                </tr>
              </thead>
              <tbody>
                {users.length === 0 ? (
                  <tr>
                    <td colSpan="8" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                      No user accounts found matching this criteria.
                    </td>
                  </tr>
                ) : (
                  users.map((u) => {
                    const isSuspended = u.accountStatus === "suspended";
                    const isPending = u.accountStatus === "pending_verification";

                    return (
                      <tr key={u.id}>
                        <td>
                          <div style={{ display: "inline-flex", alignItems: "center", gap: "10px" }}>
                            <div
                              style={{
                                width: "30px",
                                height: "30px",
                                borderRadius: "50%",
                                background: "linear-gradient(135deg, var(--color-primary), #6366F1)",
                                color: "#ffffff",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                fontWeight: 700,
                                fontSize: "0.8rem",
                                flexShrink: 0,
                                textTransform: "uppercase",
                              }}
                            >
                              {u.name && u.name.trim() ? u.name.trim().charAt(0) : "U"}
                            </div>
                            <span style={{ fontWeight: 600, color: "var(--text-primary)", fontSize: "0.86rem" }}>
                              {u.name || "Unnamed User"}
                            </span>
                          </div>
                        </td>
                        <td>
                          <div style={{ display: "inline-flex", alignItems: "center", gap: "6px" }}>
                            <Mail size={13} color="var(--text-muted)" />
                            <span style={{ color: "var(--text-secondary)", fontSize: "0.84rem" }}>
                              {u.email || "—"}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontSize: "0.8rem", fontWeight: 600, color: u.role === "admin" ? "var(--accent-cyan)" : "var(--text-secondary)" }}>
                            {u.role.toUpperCase()}
                          </span>
                        </td>
                        <td>
                          <span
                            className={`status-badge ${
                              isSuspended
                                ? "status-suspended"
                                : isPending
                                ? "status-pending"
                                : "status-active"
                            }`}
                          >
                            {u.accountStatus}
                          </span>
                        </td>
                        <td>
                          {new Date(u.createdAt).toLocaleDateString("en-US", {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })}
                        </td>
                        <td>
                          {u.lastLoginAt
                            ? new Date(u.lastLoginAt).toLocaleDateString("en-US", {
                                month: "short",
                                day: "numeric",
                              })
                            : "Never"}
                        </td>
                        <td>
                          <span style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>
                            {u.tripsCount} trips
                          </span>
                        </td>
                        <td style={{ textAlign: "right" }}>
                          {u.role !== "admin" ? (
                            isSuspended ? (
                              <button
                                onClick={() => {
                                  setSelectedUser(u);
                                  setActionType("activate");
                                }}
                                className="btn btn-success"
                                style={{ padding: "5px 12px", fontSize: "0.75rem" }}
                              >
                                <CheckCircle size={14} />
                                <span>Reactivate</span>
                              </button>
                            ) : (
                              <button
                                onClick={() => {
                                  setSelectedUser(u);
                                  setActionType("suspend");
                                }}
                                className="btn btn-danger"
                                style={{ padding: "5px 12px", fontSize: "0.75rem" }}
                              >
                                <Ban size={14} />
                                <span>Suspend</span>
                              </button>
                            )
                          ) : (
                            <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>Protected Admin</span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination Controls */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "16px 24px",
              borderTop: "1px solid var(--border-subtle)",
            }}
          >
            <div style={{ fontSize: "0.78rem", color: "var(--text-muted)" }}>
              Showing {users.length} of {pagination.total} total accounts (Page {pagination.page} of{" "}
              {pagination.totalPages || 1})
            </div>
            <div style={{ display: "flex", gap: "8px" }}>
              <button
                disabled={pagination.page <= 1}
                onClick={() => setPagination((p) => ({ ...p, page: p.page - 1 }))}
                className="btn btn-secondary"
                style={{ padding: "6px 12px" }}
              >
                <ArrowLeft size={14} /> Previous
              </button>
              <button
                disabled={pagination.page >= pagination.totalPages}
                onClick={() => setPagination((p) => ({ ...p, page: p.page + 1 }))}
                className="btn btn-secondary"
                style={{ padding: "6px 12px" }}
              >
                Next <ArrowRight size={14} />
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Modal */}
      {selectedUser && actionType && (
        <div className="modal-overlay" onClick={() => setSelectedUser(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="modal-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                <ShieldAlert size={20} color={actionType === "suspend" ? "var(--accent-rose)" : "var(--accent-emerald)"} />
                <span>Confirm Account {actionType === "suspend" ? "Suspension" : "Reactivation"}</span>
              </div>
            </div>

            <p style={{ color: "var(--text-secondary)", fontSize: "0.88rem", lineHeight: 1.5, marginBottom: "20px" }}>
              Are you sure you want to {actionType === "suspend" ? "suspend" : "reactivate"} user account{" "}
              <strong style={{ color: "var(--color-primary)", fontWeight: 700 }}>
                {selectedUser.name ? `${selectedUser.name} (${selectedUser.email || selectedUser.maskedId})` : (selectedUser.email || selectedUser.maskedId)}
              </strong>
              ? {actionType === "suspend" ? "This will immediately restrict their ability to log in or create trips." : "This will restore full access to their mobile application."}
            </p>

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "10px" }}>
              <button onClick={() => setSelectedUser(null)} className="btn btn-secondary" disabled={actionLoading}>
                Cancel
              </button>
              <button
                onClick={handleConfirmStatusChange}
                className={`btn ${actionType === "suspend" ? "btn-danger" : "btn-success"}`}
                disabled={actionLoading}
              >
                {actionLoading ? "Processing..." : `Confirm ${actionType === "suspend" ? "Suspend" : "Activate"}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
