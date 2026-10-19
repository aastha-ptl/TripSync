const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:5000/api/admin";

export const getToken = () => localStorage.getItem("tripsync_admin_token");
export const setToken = (token) => localStorage.setItem("tripsync_admin_token", token);
export const removeToken = () => localStorage.removeItem("tripsync_admin_token");

export const getStoredAdmin = () => {
  const data = localStorage.getItem("tripsync_admin_user");
  try {
    return data ? JSON.parse(data) : null;
  } catch (e) {
    return null;
  }
};

export const setStoredAdmin = (admin) => {
  localStorage.setItem("tripsync_admin_user", JSON.stringify(admin));
};

export const clearStoredAuth = () => {
  localStorage.removeItem("tripsync_admin_token");
  localStorage.removeItem("tripsync_admin_user");
};

async function apiRequest(endpoint, options = {}) {
  const token = getToken();
  const headers = {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  };

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    clearStoredAuth();
    window.dispatchEvent(new Event("admin_session_expired"));
  }

  // Handle CSV or file download
  const contentType = response.headers.get("content-type");
  if (contentType && contentType.includes("text/csv")) {
    return response.blob();
  }

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.message || "Request failed");
  }

  return data;
}

export const adminApi = {
  // Authentication
  login: async (email, password) => {
    const res = await apiRequest("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    if (res.data?.accessToken) {
      setToken(res.data.accessToken);
      setStoredAdmin(res.data.admin);
    }
    return res.data;
  },

  setupInitialAdmin: async (email, password, setupKey) => {
    const res = await apiRequest("/auth/setup", {
      method: "POST",
      body: JSON.stringify({ email, password, setupKey }),
    });
    if (res.data?.accessToken) {
      setToken(res.data.accessToken);
      setStoredAdmin({ email: res.data.email, role: res.data.role });
    }
    return res.data;
  },

  logout: () => {
    clearStoredAuth();
  },

  // Overview & Analytics (Zero PII)
  getOverview: async () => {
    const res = await apiRequest("/overview");
    return res.data;
  },

  getTripAnalytics: async (filters = {}) => {
    const params = new URLSearchParams();
    if (filters.year) params.append("year", filters.year);
    if (filters.month) params.append("month", filters.month);
    if (filters.status && filters.status !== "all") params.append("status", filters.status);
    if (filters.tripType && filters.tripType !== "all") params.append("tripType", filters.tripType);

    const query = params.toString() ? `?${params.toString()}` : "";
    const res = await apiRequest(`/analytics/trips${query}`);
    return res.data;
  },

  getExpenseAnalytics: async (filters = {}) => {
    const params = new URLSearchParams();
    if (filters.year) params.append("year", filters.year);

    const query = params.toString() ? `?${params.toString()}` : "";
    const res = await apiRequest(`/analytics/expenses${query}`);
    return res.data;
  },

  // User Directory & Moderation (Zero PII - Masked IDs)
  getUsers: async (params = {}) => {
    const query = new URLSearchParams();
    if (params.page) query.append("page", params.page);
    if (params.limit) query.append("limit", params.limit);
    if (params.status) query.append("status", params.status);
    if (params.search) query.append("search", params.search);

    const qStr = query.toString() ? `?${query.toString()}` : "";
    const res = await apiRequest(`/users${qStr}`);
    return res.data;
  },

  updateUserStatus: async (userId, accountStatus) => {
    const res = await apiRequest(`/users/${userId}/status`, {
      method: "PATCH",
      body: JSON.stringify({ accountStatus }),
    });
    return res.data;
  },

  // Broadcasts
  sendBroadcast: async (title, message) => {
    const res = await apiRequest("/broadcast", {
      method: "POST",
      body: JSON.stringify({ title, message }),
    });
    return res;
  },

  // Reports
  generateReport: async (year, month) => {
    const res = await apiRequest(`/reports/summary?year=${year}&month=${month}`);
    return res.data;
  },

  exportReportCsv: async (year, month) => {
    const blob = await apiRequest(`/reports/summary?year=${year}&month=${month}&format=csv`);
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `TripSync_Platform_Report_${month}_${year}.csv`;
    document.body.appendChild(a);
    a.click();
    a.remove();
  },

  // System Health
  getSystemHealth: async () => {
    const res = await apiRequest("/system/health");
    return res.data;
  },
};
