import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { expenseUpload } from "../middleware/expenseUpload.js";
import {
  createExpense,
  updateExpense,
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
  reportExpenseSplit,
  getExpenseReports,
  updateExpenseReportStatus,
} from "../controllers/expenseController.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

// PDF Expense Report Download
router.get("/report/pdf", downloadExpensePdf);

// Split Expense Dispute Reports (Must be before /:expenseId)
router.get("/reports", getExpenseReports);
router.patch("/reports/:reportId/status", updateExpenseReportStatus);

// Members eligible for splitting
router.get("/members", getTripExpenseMembers);

// Summary (Owed by you / Owed to you)
router.get("/summary", getExpenseSummary);

// Balances (Expenses tab overview)
router.get("/balances", getExpenseBalances);
router.get("/balances/:targetId", getBalanceDetail);
router.post("/settle-person", settlePersonExpenses);

// Expenses list and creation (Splits tab)
router.post("/", expenseUpload.single('receipt'), createExpense);
router.get("/", getTripExpenses);

// Specific expense
router.get("/:expenseId", getExpenseDetail);
router.put("/:expenseId", expenseUpload.single('receipt'), updateExpense);
router.post("/:expenseId/settle", settleParticipant);
router.post("/:expenseId/report", reportExpenseSplit);
router.delete("/:expenseId", deleteExpense);

export default router;
