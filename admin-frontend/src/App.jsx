import React, { useState, useEffect } from "react";
import Sidebar from "./components/Sidebar";
import Header from "./components/Header";
import DashboardView from "./views/DashboardView";
import TripAnalyticsView from "./views/TripAnalyticsView";
import ExpenseAnalyticsView from "./views/ExpenseAnalyticsView";
import UsersView from "./views/UsersView";
import ReportsView from "./views/ReportsView";
import BroadcastView from "./views/BroadcastView";
import SystemHealthView from "./views/SystemHealthView";
import LoginView from "./views/LoginView";
import { getToken, getStoredAdmin, adminApi } from "./services/api";

export default function App() {
  const [admin, setAdmin] = useState(getStoredAdmin());
  const [isAuthenticated, setIsAuthenticated] = useState(!!getToken());
  const [currentTab, setTab] = useState("dashboard");
  const [overview, setOverview] = useState(null);
  const [loadingOverview, setLoadingOverview] = useState(false);

  useEffect(() => {
    const handleExpired = () => {
      setIsAuthenticated(false);
      setAdmin(null);
    };
    window.addEventListener("admin_session_expired", handleExpired);
    return () => window.removeEventListener("admin_session_expired", handleExpired);
  }, []);

  const fetchOverview = async () => {
    if (!isAuthenticated) return;
    try {
      setLoadingOverview(true);
      const data = await adminApi.getOverview();
      setOverview(data);
    } catch (err) {
      console.error("Overview fetch error:", err);
    } finally {
      setLoadingOverview(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchOverview();
    }
  }, [isAuthenticated]);

  const handleLoginSuccess = (adminData) => {
    setAdmin(adminData);
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    adminApi.logout();
    setIsAuthenticated(false);
    setAdmin(null);
  };

  if (!isAuthenticated) {
    return <LoginView onLoginSuccess={handleLoginSuccess} />;
  }

  const getHeaderInfo = () => {
    switch (currentTab) {
      case "dashboard":
        return {
          title: "Executive Operations Overview",
          subtitle: "Aggregated health, key metric counters, and platform velocity",
        };
      case "trips":
        return {
          title: "Trip Analytics & Monthly Frequency",
          subtitle: "Cross-user trip creation graphs, time series filters, and group distributions",
        };
      case "expenses":
        return {
          title: "Ecosystem Expense Intelligence",
          subtitle: "Macro platform spend volumes, category allocation, and currency metrics",
        };
      case "users":
        return {
          title: "User Management & Moderation",
          subtitle: "Account lifecycle status, user directory, and security moderation",
        };
      case "reports":
        return {
          title: "Platform Report Generator & Export",
          subtitle: "Synthesize monthly compliance reports, export CSV data, or print summaries",
        };
      case "broadcast":
        return {
          title: "Global Mobile Broadcast",
          subtitle: "Dispatch high-priority system announcements to all active app users",
        };
      case "health":
        return {
          title: "System & Infrastructure Diagnostics",
          subtitle: "Live Node runtime statistics, memory footprints, and MongoDB telemetry",
        };
      default:
        return { title: "Admin Portal", subtitle: "TripSync Platform Management" };
    }
  };

  const { title, subtitle } = getHeaderInfo();

  return (
    <div className="app-layout">
      <Sidebar
        currentTab={currentTab}
        setTab={setTab}
        admin={admin}
        onLogout={handleLogout}
      />

      <div className="main-wrapper">
        <Header
          title={title}
          subtitle={subtitle}
          onRefresh={fetchOverview}
          loading={loadingOverview}
        />

        <main className="content-container">
          {currentTab === "dashboard" && (
            <DashboardView
              overview={overview}
              onNavigate={(tab) => setTab(tab)}
              onRefresh={fetchOverview}
            />
          )}

          {currentTab === "trips" && <TripAnalyticsView />}

          {currentTab === "expenses" && <ExpenseAnalyticsView />}

          {currentTab === "users" && <UsersView />}

          {currentTab === "reports" && <ReportsView />}

          {currentTab === "broadcast" && <BroadcastView />}

          {currentTab === "health" && <SystemHealthView />}
        </main>
      </div>
    </div>
  );
}
