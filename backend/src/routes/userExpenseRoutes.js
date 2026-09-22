import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { getUserExpenseOverview } from "../controllers/userExpenseController.js";

const router = express.Router();

router.use(protect);

// Global user-level expense overview across all user's trips
router.get("/user-overview", getUserExpenseOverview);

export default router;
