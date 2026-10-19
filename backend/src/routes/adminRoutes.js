import express from "express";
import {
  adminLogin,
  bootstrapAdmin,
  getPlatformOverview,
  getTripAnalytics,
  getExpenseAnalytics,
  getUsersDirectory,
  updateUserStatus,
  sendPlatformBroadcast,
  generateReport,
  getSystemHealth,
} from "../controllers/adminController.js";
import { protectAdmin } from "../middleware/adminMiddleware.js";

const router = express.Router();

// Public Admin Auth Routes
router.post("/auth/login", adminLogin);
router.post("/auth/setup", bootstrapAdmin);

// Protected Admin Routes (Require valid JWT and role === 'admin')
router.use(protectAdmin);

// Overview & Analytics (Zero PII)
router.get("/overview", getPlatformOverview);
router.get("/analytics/trips", getTripAnalytics);
router.get("/analytics/expenses", getExpenseAnalytics);

// User Moderation (Zero PII - Masked IDs only)
router.get("/users", getUsersDirectory);
router.patch("/users/:userId/status", updateUserStatus);

// System Broadcasts & Reports
router.post("/broadcast", sendPlatformBroadcast);
router.get("/reports/summary", generateReport);
router.get("/system/health", getSystemHealth);

export default router;
