import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import Expense from "../models/Expense.js";
import ExpenseParticipant from "../models/ExpenseParticipant.js";
import { computeTripBalances } from "./expenseController.js";

// Global user-level expense overview across all user's trips
export const getUserExpenseOverview = async (req, res) => {
  try {
    const userId = req.user._id;
    const { tripId, category, timePeriod, startDate, endDate } = req.query;

    // 1. Get all approved trips for this user
    const participants = await TripParticipant.find({
      userId,
      status: "approved",
    }).populate("tripId");

    let userTrips = participants.map((p) => p.tripId).filter(Boolean);

    // Apply trip filter if specified
    if (tripId && tripId !== "all" && tripId !== "All Trips") {
      userTrips = userTrips.filter((t) => t._id.toString() === tripId);
    }

    const tripIds = userTrips.map((t) => t._id);

    // 2. Fetch all active expenses for these trips
    const allExpenses = await Expense.find({
      tripId: { $in: tripIds },
      status: "active",
    })
      .sort({ date: 1, createdAt: 1 })
      .lean();

    // 3. Fetch user's participant records for these expenses
    const userParts = await ExpenseParticipant.find({
      expenseId: { $in: allExpenses.map((e) => e._id) },
      participantType: "user",
      userId,
    }).lean();

    const userPartsMap = new Map();
    for (const p of userParts) {
      userPartsMap.set(p.expenseId.toString(), p);
    }

    // Category metadata map
    const catMeta = {
      accommodation: { label: "Accommodation", color: "#3B82F6", icon: "hotel" },
      hotel: { label: "Accommodation", color: "#3B82F6", icon: "hotel" },
      travel: { label: "Transportation", color: "#00C6FF", icon: "flight_takeoff" },
      transport: { label: "Transportation", color: "#00C6FF", icon: "flight_takeoff" },
      transportation: { label: "Transportation", color: "#00C6FF", icon: "flight_takeoff" },
      food: { label: "Food & Dining", color: "#20C060", icon: "restaurant" },
      dining: { label: "Food & Dining", color: "#20C060", icon: "restaurant" },
      activities: { label: "Activities", color: "#F59E0B", icon: "local_activity" },
      activity: { label: "Activities", color: "#F59E0B", icon: "local_activity" },
      tickets: { label: "Tickets", color: "#06B6D4", icon: "confirmation_number" },
      ticket: { label: "Tickets", color: "#06B6D4", icon: "confirmation_number" },
      shopping: { label: "Shopping", color: "#8B5CF6", icon: "shopping_bag" },
      medical: { label: "Medical", color: "#EF4444", icon: "medical_services" },
      health: { label: "Medical", color: "#EF4444", icon: "medical_services" },
      other: { label: "Others", color: "#94A3B8", icon: "more_horiz" },
      others: { label: "Others", color: "#94A3B8", icon: "more_horiz" },
    };

    // Category matching helper
    const matchesCategoryFilter = (expCat, filter) => {
      if (!filter || filter === "All Categories" || filter === "all") return true;
      const normExp = (expCat || "other").toLowerCase().trim();
      const normFilter = filter.toLowerCase().trim();
      const label = catMeta[normExp]?.label || "Others";
      return label.toLowerCase() === normFilter || normExp === normFilter;
    };

    // Date matching helper
    const now = new Date();
    const matchesDateFilter = (expDate) => {
      if (!timePeriod || timePeriod === "All Time" || timePeriod === "all") return true;
      if (!expDate) return true;
      const d = new Date(expDate);
      if (isNaN(d.getTime())) return true;

      if (timePeriod === "This Month") {
        return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
      }
      if (timePeriod === "Last Month") {
        const lastMonthYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
        const lastMonth = now.getMonth() === 0 ? 11 : now.getMonth() - 1;
        return d.getFullYear() === lastMonthYear && d.getMonth() === lastMonth;
      }
      if (startDate && endDate) {
        const s = new Date(startDate);
        const e = new Date(endDate);
        e.setHours(23, 59, 59, 999);
        return d >= s && d <= e;
      }
      return true;
    };

    let totalUserExpense = 0;
    let totalUserSpending = 0;
    const categoryTotals = {};
    const tripStatsMap = new Map();

    for (const trip of userTrips) {
      tripStatsMap.set(trip._id.toString(), {
        userExpense: 0,
        mySpending: 0,
        groupTotal: 0,
      });
    }

    // Process expenses
    for (const exp of allExpenses) {
      const tripIdStr = exp.tripId.toString();
      const expAmt = exp.amount || 0;
      const expDate = exp.date || exp.createdAt;
      const expCat = (exp.category || "other").toLowerCase();

      // Trip group total
      const tripStats = tripStatsMap.get(tripIdStr);
      if (tripStats) {
        tripStats.groupTotal += expAmt;
      }

      // Check filters
      if (!matchesCategoryFilter(expCat, category)) continue;
      if (!matchesDateFilter(expDate)) continue;

      // Check user share
      let userShare = 0;
      const part = userPartsMap.get(exp._id.toString());
      if (part) {
        userShare = part.shareAmount || 0;
      } else {
        const isPayer = exp.paidBy?.type === "user" && exp.paidBy?.userId?.toString() === userId.toString();
        if (isPayer) {
          const pCount = await ExpenseParticipant.countDocuments({ expenseId: exp._id });
          if (pCount === 0) userShare = expAmt;
        }
      }

      // Check user paid (spending)
      let userPaid = 0;
      if (exp.paidBy?.type === "user" && exp.paidBy?.userId?.toString() === userId.toString()) {
        userPaid = expAmt;
      }

      totalUserExpense += userShare;
      totalUserSpending += userPaid;

      if (tripStats) {
        tripStats.userExpense += userShare;
        tripStats.mySpending += userPaid;
      }

      if (userShare > 0) {
        const label = catMeta[expCat]?.label || "Others";
        categoryTotals[label] = (categoryTotals[label] || 0) + userShare;
      }
    }

    // Format Categories Breakdown
    const categoriesResult = Object.entries(categoryTotals)
      .map(([label, spent]) => {
        const meta = Object.values(catMeta).find((m) => m.label === label) || {
          label,
          color: "#8B5CF6",
          icon: "category",
        };
        const percentage = totalUserExpense > 0 ? Number(((spent / totalUserExpense) * 100).toFixed(1)) : 0;
        return {
          category: label,
          spent: Number(spent.toFixed(2)),
          percentage,
          color: meta.color,
          icon: meta.icon,
        };
      })
      .sort((a, b) => b.spent - a.spent);

    // Compute Pairwise Balances across all matching trips
    let totalNeedToPay = 0;
    let totalNeedToReceive = 0;
    const payMap = new Map();
    const receiveMap = new Map();
    const tripBalanceMap = new Map();

    for (const trip of userTrips) {
      const { owedByYou, owedToYou, totalOwedByYou, totalOwedToYou } = await computeTripBalances(
        trip._id,
        userId.toString(),
        false,
        userId
      );

      tripBalanceMap.set(trip._id.toString(), {
        owedByYou: totalOwedByYou,
        owedToYou: totalOwedToYou,
      });

      totalNeedToPay += totalOwedByYou;
      totalNeedToReceive += totalOwedToYou;

      for (const item of owedByYou) {
        const key = (item.id || item.name).toString();
        if (!payMap.has(key)) {
          payMap.set(key, {
            targetId: item.id,
            name: item.name,
            avatar: item.avatar,
            amount: 0,
            isGuest: !!item.isGuest,
          });
        }
        payMap.get(key).amount += item.amount;
      }

      for (const item of owedToYou) {
        const key = (item.id || item.name).toString();
        if (!receiveMap.has(key)) {
          receiveMap.set(key, {
            targetId: item.id,
            name: item.name,
            avatar: item.avatar,
            amount: 0,
            isGuest: !!item.isGuest,
          });
        }
        receiveMap.get(key).amount += item.amount;
      }
    }

    const whoYouNeedToPay = Array.from(payMap.values())
      .filter((i) => i.amount > 0)
      .map((i) => ({ ...i, amount: Number(i.amount.toFixed(2)) }))
      .sort((a, b) => b.amount - a.amount);

    const whoNeedsToPayYou = Array.from(receiveMap.values())
      .filter((i) => i.amount > 0)
      .map((i) => ({ ...i, amount: Number(i.amount.toFixed(2)) }))
      .sort((a, b) => b.amount - a.amount);

    // Compute Monthly Trend for this user over last 6 calendar months
    const monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthlyTrend = [];
    const sparklineData = [];

    for (let i = 5; i >= 0; i--) {
      let y = now.getFullYear();
      let m = now.getMonth() - i;
      while (m < 0) {
        m += 12;
        y -= 1;
      }

      let mSum = 0;
      for (const exp of allExpenses) {
        const d = new Date(exp.date || exp.createdAt);
        if (d.getFullYear() === y && d.getMonth() === m) {
          const part = userPartsMap.get(exp._id.toString());
          if (part) {
            mSum += part.shareAmount || 0;
          } else {
            const isPayer = exp.paidBy?.type === "user" && exp.paidBy?.userId?.toString() === userId.toString();
            if (isPayer) {
              mSum += exp.amount;
            }
          }
        }
      }

      mSum = Number(mSum.toFixed(2));
      monthlyTrend.push({
        month: monthLabels[m],
        year: y,
        amount: mSum,
      });
      sparklineData.push(mSum);
    }

    const nonZeroMonths = sparklineData.filter((v) => v > 0);
    const monthlyAverage =
      nonZeroMonths.length > 0
        ? Number((sparklineData.reduce((a, b) => a + b, 0) / nonZeroMonths.length).toFixed(2))
        : 0;

    const curMonthVal = sparklineData[5] || 0;
    const prevMonthVal = sparklineData[4] || 0;
    let percentChange = 0;
    let isUp = true;
    if (prevMonthVal === 0) {
      percentChange = curMonthVal > 0 ? 100 : 0;
      isUp = true;
    } else {
      percentChange = Number((((curMonthVal - prevMonthVal) / prevMonthVal) * 100).toFixed(1));
      isUp = percentChange >= 0;
      percentChange = Math.abs(percentChange);
    }

    // Format Trip Wise Details
    const tripWiseDetails = userTrips.map((trip) => {
      const stats = tripStatsMap.get(trip._id.toString()) || { userExpense: 0, mySpending: 0, groupTotal: 0 };
      const balances = tripBalanceMap.get(trip._id.toString()) || { owedByYou: 0, owedToYou: 0 };

      let dateFormatted = "Dates TBD";
      if (trip.startDate && trip.endDate) {
        try {
          const d1 = new Date(trip.startDate);
          const d2 = new Date(trip.endDate);
          const opts1 = { month: "short", day: "numeric" };
          const opts2 = { month: "short", day: "numeric", year: "numeric" };
          dateFormatted = `${d1.toLocaleDateString("en-US", opts1)} - ${d2.toLocaleDateString("en-US", opts2)}`;
        } catch (_) {}
      }

      let isActive = true;
      let statusStr = "Active";
      if (trip.endDate) {
        try {
          const endDt = new Date(trip.endDate);
          if (endDt < new Date()) {
            isActive = false;
            statusStr = "Completed";
          }
        } catch (_) {}
      }

      return {
        tripId: trip._id,
        tripName: trip.name || trip.title || "Trip",
        startDate: trip.startDate,
        endDate: trip.endDate,
        dateFormatted,
        status: statusStr,
        isActive,
        userExpense: Number(stats.userExpense.toFixed(2)),
        tripTotalExpense: Number(stats.groupTotal.toFixed(2)),
        mySpending: Number(stats.mySpending.toFixed(2)),
        needToPay: Number(balances.owedByYou.toFixed(2)),
        needToReceive: Number(balances.owedToYou.toFixed(2)),
        rawTrip: trip,
      };
    });

    res.status(200).json({
      success: true,
      data: {
        summary: {
          totalExpenses: Number(totalUserExpense.toFixed(2)),
          mySpending: Number(totalUserSpending.toFixed(2)),
          needToPay: Number(totalNeedToPay.toFixed(2)),
          needToReceive: Number(totalNeedToReceive.toFixed(2)),
        },
        categories: categoriesResult,
        trend: {
          monthlyTrend,
          monthlyAverage,
          percentChange,
          isUp,
          sparklineData,
        },
        tripWiseDetails,
        paymentSplits: {
          whoYouNeedToPay,
          whoNeedsToPayYou,
          totalToPay: Number(totalNeedToPay.toFixed(2)),
          totalToReceive: Number(totalNeedToReceive.toFixed(2)),
        },
      },
    });
  } catch (error) {
    console.error("Error in getUserExpenseOverview:", error);
    res.status(500).json({ success: false, message: "Server error getting user expense overview" });
  }
};
