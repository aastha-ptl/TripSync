import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  createExpense,
  getTripExpenses,
  getExpenseDetail,
  settleParticipant,
  getExpenseSummary,
  getExpenseBalances,
  getBalanceDetail,
  settlePersonExpenses,
  deleteExpense,
  getTripExpenseMembers,
  downloadExpensePdf,
} from "../controllers/expenseController.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

// PDF Expense Report Download
router.get("/report/pdf", downloadExpensePdf);

// Members eligible for splitting
router.get("/members", getTripExpenseMembers);

// Summary (Owed by you / Owed to you)
router.get("/summary", getExpenseSummary);

// Balances (Expenses tab overview)
router.get("/balances", getExpenseBalances);
router.get("/balances/:targetId", getBalanceDetail);
router.post("/settle-person", settlePersonExpenses);

// Expenses list and creation (Splits tab)
router.post("/", createExpense);
router.get("/", getTripExpenses);

// Specific expense
router.get("/:expenseId", getExpenseDetail);
router.post("/:expenseId/settle", settleParticipant);
router.delete("/:expenseId", deleteExpense);

export default router;
