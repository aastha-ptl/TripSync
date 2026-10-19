import bcrypt from "bcryptjs";
import User from "../models/User.js";
import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import Expense from "../models/Expense.js";
import ChatMessage from "../models/ChatMessage.js";
import Document from "../models/Document.js";
import Photo from "../models/Photo.js";
import Poll from "../models/Poll.js";
import Notification from "../models/Notification.js";
import { generateAccessToken, generateRefreshToken } from "../utils/generateToken.js";
import { getIO } from "../socket.js";
import mongoose from "mongoose";
import { v2 as cloudinary } from "cloudinary";
import env from "../config/env.js";

cloudinary.config({
  cloud_name: env.CLOUDINARY_CLOUD_NAME,
  api_key: env.CLOUDINARY_API_KEY,
  api_secret: env.CLOUDINARY_API_SECRET,
});

/**
 * Admin Login
 */
export const adminLogin = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Please provide email and password." });
    }

    const user = await User.findOne({ email }).select("+passwordHash");
    if (!user) {
      return res.status(401).json({ success: false, message: "Invalid credentials." });
    }

    if (user.role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "Access restricted. You do not have administrator permissions.",
      });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid credentials." });
    }

    user.lastLoginAt = new Date();
    await user.save();

    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    return res.status(200).json({
      success: true,
      message: "Admin login successful",
      data: {
        admin: {
          id: user._id,
          email: user.email,
          role: user.role,
        },
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Bootstrap / Promote Initial Admin
 * Allows setting up the first admin or upgrading an account if none exists or with secret key
 */
export const bootstrapAdmin = async (req, res, next) => {
  try {
    const { email, password, setupKey } = req.body;

    // Check if an admin already exists
    const existingAdminCount = await User.countDocuments({ role: "admin" });
    const expectedKey = process.env.ADMIN_SETUP_KEY || "tripsync-admin-setup-2026";

    if (existingAdminCount > 0 && setupKey !== expectedKey) {
      return res.status(403).json({
        success: false,
        message: "An administrator already exists. Valid setupKey required to promote another.",
      });
    }

    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required." });
    }

    let user = await User.findOne({ email });

    if (user) {
      user.role = "admin";
      user.accountStatus = "active";
      user.isActive = true;
      if (password) {
        user.passwordHash = await bcrypt.hash(password, 10);
      }
      await user.save();
    } else {
      if (!password) {
        return res.status(400).json({ success: false, message: "Password is required for new admin user." });
      }
      const passwordHash = await bcrypt.hash(password, 10);
      user = await User.create({
        firstName: "System",
        lastName: "Admin",
        email,
        passwordHash,
        authProvider: "local",
        role: "admin",
        accountStatus: "active",
        isActive: true,
        isEmailVerified: true,
      });
    }

    const accessToken = generateAccessToken(user._id);

    return res.status(200).json({
      success: true,
      message: "Admin successfully configured.",
      data: {
        email: user.email,
        role: user.role,
        accessToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Platform Overview (Executive Metrics - Zero PII)
 */
export const getPlatformOverview = async (req, res, next) => {
  try {
    const now = new Date();
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfPreviousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfPreviousMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);

    // Concurrently aggregate key metrics
    const [
      totalUsers,
      activeUsers,
      suspendedUsers,
      totalTrips,
      tripsThisMonth,
      tripsLastMonth,
      activeTrips,
      completedTrips,
      expenseStats,
      chatCount,
      photoCount,
      docCount,
      pollCount,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ accountStatus: "active", isActive: true }),
      User.countDocuments({ accountStatus: "suspended" }),
      Trip.countDocuments({ isActive: true }),
      Trip.countDocuments({ isActive: true, createdAt: { $gte: startOfCurrentMonth } }),
      Trip.countDocuments({
        isActive: true,
        createdAt: { $gte: startOfPreviousMonth, $lte: endOfPreviousMonth },
      }),
      Trip.countDocuments({ isActive: true, status: "ongoing" }),
      Trip.countDocuments({ isActive: true, status: "completed" }),
      Expense.aggregate([
        { $match: { status: "active" } },
        {
          $group: {
            _id: null,
            totalAmount: { $sum: "$amount" },
            count: { $sum: 1 },
          },
        },
      ]),
      ChatMessage.countDocuments(),
      Photo.countDocuments(),
      Document.countDocuments(),
      Poll.countDocuments(),
    ]);

    // Calculate growth
    let tripGrowthPercent = 0;
    if (tripsLastMonth > 0) {
      tripGrowthPercent = Number((((tripsThisMonth - tripsLastMonth) / tripsLastMonth) * 100).toFixed(1));
    } else if (tripsThisMonth > 0) {
      tripGrowthPercent = 100;
    }

    return res.status(200).json({
      success: true,
      data: {
        users: {
          total: totalUsers,
          active: activeUsers,
          suspended: suspendedUsers,
        },
        trips: {
          total: totalTrips,
          thisMonth: tripsThisMonth,
          lastMonth: tripsLastMonth,
          growthPercent: tripGrowthPercent,
          activeNow: activeTrips,
          completed: completedTrips,
        },
        expenses: {
          totalAmount: expenseStats[0]?.totalAmount || 0,
          totalTransactions: expenseStats[0]?.count || 0,
        },
        engagement: {
          chatMessages: chatCount,
          photos: photoCount,
          documents: docCount,
          polls: pollCount,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Trip Analytics & Monthly Graphs (Zero PII)
 * Supports filtering by year, month, tripType, status
 */
export const getTripAnalytics = async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = req.query.month ? parseInt(req.query.month) : null; // 1-12
    const statusFilter = req.query.status || null;
    const tripTypeFilter = req.query.tripType || null;

    // Base query match
    const matchConditions = { isActive: true };

    if (statusFilter && statusFilter !== "all") {
      matchConditions.status = statusFilter;
    }
    if (tripTypeFilter && tripTypeFilter !== "all") {
      matchConditions.tripType = tripTypeFilter;
    }

    // Date range for the requested year
    const startOfYear = new Date(year, 0, 1);
    const endOfYear = new Date(year, 11, 31, 23, 59, 59);

    const yearMatch = {
      ...matchConditions,
      createdAt: { $gte: startOfYear, $lte: endOfYear },
    };

    // 1. Monthly distribution for the year (12 months)
    const monthlyAgg = await Trip.aggregate([
      { $match: yearMatch },
      {
        $group: {
          _id: { $month: "$createdAt" },
          count: { $sum: 1 },
        },
      },
    ]);

    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthlyData = monthNames.map((name, index) => {
      const found = monthlyAgg.find((m) => m._id === index + 1);
      return {
        monthIndex: index + 1,
        monthName: name,
        tripCount: found ? found.count : 0,
      };
    });

    // 2. Daily breakdown if specific month is requested
    let dailyData = [];
    if (month && month >= 1 && month <= 12) {
      const daysInMonth = new Date(year, month, 0).getDate();
      const startOfTargetMonth = new Date(year, month - 1, 1);
      const endOfTargetMonth = new Date(year, month - 1, daysInMonth, 23, 59, 59);

      const dailyAgg = await Trip.aggregate([
        {
          $match: {
            ...matchConditions,
            createdAt: { $gte: startOfTargetMonth, $lte: endOfTargetMonth },
          },
        },
        {
          $group: {
            _id: { $dayOfMonth: "$createdAt" },
            count: { $sum: 1 },
          },
        },
      ]);

      for (let day = 1; day <= daysInMonth; day++) {
        const found = dailyAgg.find((d) => d._id === day);
        dailyData.push({
          day: day,
          label: `${month}/${day}`,
          tripCount: found ? found.count : 0,
        });
      }
    }

    // 3. Status breakdown
    const statusAgg = await Trip.aggregate([
      { $match: yearMatch },
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    // 4. Trip Type breakdown
    const tripTypeAgg = await Trip.aggregate([
      { $match: yearMatch },
      {
        $group: {
          _id: "$tripType",
          count: { $sum: 1 },
        },
      },
    ]);

    // 5. Group size distribution (from TripParticipant)
    const groupSizeAgg = await TripParticipant.aggregate([
      { $match: { status: { $in: ["approved", "pending"] } } },
      {
        $group: {
          _id: "$tripId",
          participantCount: { $sum: 1 },
        },
      },
      {
        $bucket: {
          groupBy: "$participantCount",
          boundaries: [1, 2, 5, 9, 50],
          default: "50+",
          output: {
            count: { $sum: 1 },
          },
        },
      },
    ]);

    const groupSizeMapping = {
      1: "Solo (1)",
      2: "Small (2-4)",
      5: "Medium (5-8)",
      9: "Large (9+)",
    };

    const groupSizeData = groupSizeAgg.map((item) => ({
      category: groupSizeMapping[item._id] || `${item._id}+`,
      count: item.count,
    }));

    return res.status(200).json({
      success: true,
      data: {
        year,
        selectedMonth: month,
        monthlyTrends: monthlyData,
        dailyTrends: dailyData,
        statusDistribution: statusAgg.map((s) => ({ status: s._id || "unknown", count: s.count })),
        tripTypeDistribution: tripTypeAgg.map((t) => ({ type: t._id || "Other", count: t.count })),
        groupSizeDistribution: groupSizeData,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Aggregated Financial / Expense Analytics (Zero PII)
 */
export const getExpenseAnalytics = async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const startOfYear = new Date(year, 0, 1);
    const endOfYear = new Date(year, 11, 31, 23, 59, 59);

    const matchConditions = {
      status: "active",
      createdAt: { $gte: startOfYear, $lte: endOfYear },
    };

    // Category breakdown
    const categoryAgg = await Expense.aggregate([
      { $match: matchConditions },
      {
        $group: {
          _id: "$category",
          totalAmount: { $sum: "$amount" },
          transactionCount: { $sum: 1 },
        },
      },
      { $sort: { totalAmount: -1 } },
    ]);

    // Monthly volume breakdown
    const monthlyExpenseAgg = await Expense.aggregate([
      { $match: matchConditions },
      {
        $group: {
          _id: { $month: "$createdAt" },
          totalAmount: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthlyTrends = monthNames.map((name, index) => {
      const found = monthlyExpenseAgg.find((m) => m._id === index + 1);
      return {
        month: name,
        amount: found ? Math.round(found.totalAmount) : 0,
        transactions: found ? found.count : 0,
      };
    });

    // Split type distribution
    const splitTypeAgg = await Expense.aggregate([
      { $match: matchConditions },
      {
        $group: {
          _id: "$splitType",
          count: { $sum: 1 },
        },
      },
    ]);

    // Currency distribution
    const currencyAgg = await Expense.aggregate([
      { $match: matchConditions },
      {
        $group: {
          _id: "$currency",
          totalAmount: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    return res.status(200).json({
      success: true,
      data: {
        year,
        categories: categoryAgg.map((c) => ({
          category: c._id,
          totalAmount: Math.round(c.totalAmount),
          transactionCount: c.transactionCount,
        })),
        monthlyTrends,
        splitTypes: splitTypeAgg.map((s) => ({ type: s._id, count: s.count })),
        currencies: currencyAgg.map((c) => ({ currency: c._id, count: c.count, totalAmount: c.totalAmount })),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Users Directory
 * Returns users with email, account status, joined date, trip counts.
 */
export const getUsersDirectory = async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 15));
    const status = req.query.status;
    const search = req.query.search?.trim();

    const filter = {};
    if (status && status !== "all") {
      filter.accountStatus = status;
    }

    if (search) {
      if (mongoose.Types.ObjectId.isValid(search)) {
        filter.$or = [
          { _id: search },
          { email: { $regex: search, $options: "i" } },
          { firstName: { $regex: search, $options: "i" } },
          { lastName: { $regex: search, $options: "i" } }
        ];
      } else {
        filter.$or = [
          { email: { $regex: search, $options: "i" } },
          { firstName: { $regex: search, $options: "i" } },
          { lastName: { $regex: search, $options: "i" } }
        ];
      }
    }

    const totalUsers = await User.countDocuments(filter);

    const users = await User.find(filter)
      .select("_id email firstName lastName accountStatus isActive role createdAt lastLoginAt")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    // Attach trip counts for each user without fetching trip contents
    const userIds = users.map((u) => u._id);
    const tripCounts = await TripParticipant.aggregate([
      { $match: { userId: { $in: userIds } } },
      { $group: { _id: "$userId", count: { $sum: 1 } } },
    ]);

    const countMap = {};
    tripCounts.forEach((tc) => {
      countMap[tc._id.toString()] = tc.count;
    });

    const formattedUsers = users.map((u) => {
      const idStr = u._id.toString();
      const maskedId = `USR-${idStr.slice(-6).toUpperCase()}`;
      return {
        id: idStr,
        maskedId,
        email: u.email,
        name: [u.firstName, u.lastName].filter(Boolean).join(" "),
        accountStatus: u.accountStatus,
        isActive: u.isActive,
        role: u.role || "user",
        createdAt: u.createdAt,
        lastLoginAt: u.lastLoginAt,
        tripsCount: countMap[idStr] || 0,
      };
    });

    return res.status(200).json({
      success: true,
      data: {
        users: formattedUsers,
        pagination: {
          page,
          limit,
          total: totalUsers,
          totalPages: Math.ceil(totalUsers / limit),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Toggle Account Status (Suspend or Reactivate)
 */
export const updateUserStatus = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { accountStatus } = req.body;

    if (!["active", "suspended"].includes(accountStatus)) {
      return res.status(400).json({ success: false, message: "Invalid status. Must be 'active' or 'suspended'." });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found." });
    }

    if (user.role === "admin") {
      return res.status(400).json({ success: false, message: "Cannot suspend an administrator account." });
    }

    user.accountStatus = accountStatus;
    user.isActive = accountStatus === "active";
    await user.save();

    return res.status(200).json({
      success: true,
      message: `User account status updated to ${accountStatus}.`,
      data: {
        email: user.email,
        maskedId: `USR-${user._id.toString().slice(-6).toUpperCase()}`,
        accountStatus: user.accountStatus,
        isActive: user.isActive,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Broadcast System Announcement to All Active Users
 */
export const sendPlatformBroadcast = async (req, res, next) => {
  try {
    const { title, message } = req.body;

    if (!title || !message) {
      return res.status(400).json({ success: false, message: "Title and message are required for announcement." });
    }

    // Find all active users
    const activeUsers = await User.find({ accountStatus: "active", isActive: true }).select("_id").lean();

    if (activeUsers.length === 0) {
      return res.status(200).json({ success: true, message: "No active users to receive broadcast." });
    }

    const notifications = activeUsers.map((u) => ({
      userId: u._id,
      type: "announcement",
      title: `[Announcement] ${title}`,
      message,
    }));

    await Notification.insertMany(notifications);

    // Socket.io broadcast to all connected clients
    try {
      const io = getIO();
      if (io) {
        io.emit("system_announcement", {
          title,
          message,
          timestamp: new Date(),
        });
      }
    } catch (socketErr) {
      console.warn("Socket notification broadcast warning:", socketErr.message);
    }

    return res.status(200).json({
      success: true,
      message: `Announcement broadcasted to ${activeUsers.length} users successfully.`,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Generate Report Data (Aggregated summary for Month/Year)
 */
export const generateReport = async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = parseInt(req.query.month) || new Date().getMonth() + 1; // 1-12
    const format = req.query.format || "json"; // 'json' | 'csv'

    const daysInMonth = new Date(year, month, 0).getDate();
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month - 1, daysInMonth, 23, 59, 59);

    const [tripsCreated, tripsCompleted, newUsers, expensesInMonth] = await Promise.all([
      Trip.countDocuments({ createdAt: { $gte: startDate, $lte: endDate } }),
      Trip.countDocuments({ status: "completed", updatedAt: { $gte: startDate, $lte: endDate } }),
      User.countDocuments({ createdAt: { $gte: startDate, $lte: endDate } }),
      Expense.aggregate([
        { $match: { status: "active", createdAt: { $gte: startDate, $lte: endDate } } },
        {
          $group: {
            _id: null,
            totalSpend: { $sum: "$amount" },
            transactionCount: { $sum: 1 },
          },
        },
      ]),
    ]);

    const reportData = {
      title: `TripSync Platform Monthly Report - ${month}/${year}`,
      generatedAt: new Date().toISOString(),
      period: {
        year,
        month,
        startDate: startDate.toISOString().split("T")[0],
        endDate: endDate.toISOString().split("T")[0],
      },
      metrics: {
        newUsersRegistered: newUsers,
        tripsCreated,
        tripsCompleted,
        completionRate: tripsCreated > 0 ? `${((tripsCompleted / tripsCreated) * 100).toFixed(1)}%` : "0%",
        totalExpenseVolume: expensesInMonth[0]?.totalSpend || 0,
        totalExpenseTransactions: expensesInMonth[0]?.transactionCount || 0,
        averageTripsPerDay: (tripsCreated / daysInMonth).toFixed(2),
      },
    };

    if (format === "csv") {
      const csvRows = [
        "Metric,Value",
        `Report Period,${month}/${year}`,
        `New Users Registered,${reportData.metrics.newUsersRegistered}`,
        `Trips Created,${reportData.metrics.tripsCreated}`,
        `Trips Completed,${reportData.metrics.tripsCompleted}`,
        `Completion Rate,${reportData.metrics.completionRate}`,
        `Total Expense Volume (INR/Base),${reportData.metrics.totalExpenseVolume}`,
        `Expense Transactions Count,${reportData.metrics.totalExpenseTransactions}`,
        `Average Trips Created Per Day,${reportData.metrics.averageTripsPerDay}`,
      ];

      res.setHeader("Content-Type", "text/csv");
      res.setHeader("Content-Disposition", `attachment; filename="tripsync_report_${month}_${year}.csv"`);
      return res.status(200).send(csvRows.join("\n"));
    }

    return res.status(200).json({
      success: true,
      data: reportData,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * System Health and Infrastructure
 */
export const getSystemHealth = async (req, res, next) => {
  try {
    const memory = process.memoryUsage();
    const uptimeSeconds = Math.floor(process.uptime());

    const [userCount, tripCount, expenseCount, photoCount] = await Promise.all([
      User.countDocuments(),
      Trip.countDocuments(),
      Expense.countDocuments(),
      Photo.countDocuments(),
    ]);

    // Live Cloudinary storage & quota metrics
    let cloudinaryUsage = null;
    try {
      if (env.CLOUDINARY_CLOUD_NAME && env.CLOUDINARY_API_KEY && env.CLOUDINARY_API_SECRET) {
        const cRes = await cloudinary.api.usage();
        const storageBytes = cRes.storage?.usage || 0;
        const bandwidthBytes = cRes.bandwidth?.usage || 0;
        const storageMB = (storageBytes / (1024 * 1024)).toFixed(2);
        const storageGB = (storageBytes / (1024 * 1024 * 1024)).toFixed(3);
        const bandwidthMB = (bandwidthBytes / (1024 * 1024)).toFixed(2);
        
        // Percent calculation based on credits or direct percent
        const usedPercent = cRes.credits?.used_percent != null
          ? cRes.credits.used_percent
          : (cRes.storage?.used_percent || 0);

        cloudinaryUsage = {
          status: "Connected",
          cloudName: env.CLOUDINARY_CLOUD_NAME,
          plan: cRes.plan || "Free",
          lastUpdated: cRes.last_updated || new Date().toISOString().split("T")[0],
          storage: {
            usageBytes: storageBytes,
            usageMB: Number(storageMB),
            usageGB: Number(storageGB),
            usedPercent: Number(usedPercent.toFixed(2)),
            creditsUsage: cRes.storage?.credits_usage || 0,
          },
          bandwidth: {
            usageBytes: bandwidthBytes,
            usageMB: Number(bandwidthMB),
            creditsUsage: cRes.bandwidth?.credits_usage || 0,
          },
          objects: {
            totalMediaFiles: cRes.objects?.usage || 0,
          },
          transformations: {
            usage: cRes.transformations?.usage || 0,
          },
          credits: cRes.credits ? {
            usage: cRes.credits.usage,
            limit: cRes.credits.limit,
            usedPercent: cRes.credits.used_percent,
          } : null,
          rateLimit: {
            allowed: cRes.rate_limit_allowed || 500,
            remaining: cRes.rate_limit_remaining != null ? cRes.rate_limit_remaining : null,
            resetAt: cRes.rate_limit_reset_at || null,
          },
        };
      }
    } catch (cErr) {
      console.warn("Cloudinary usage fetch warning:", cErr.message);
      cloudinaryUsage = {
        status: "Unavailable",
        message: cErr.message,
      };
    }

    return res.status(200).json({
      success: true,
      data: {
        serverStatus: "Operational",
        nodeVersion: process.version,
        uptimeSeconds,
        uptimeHuman: `${Math.floor(uptimeSeconds / 3600)}h ${Math.floor((uptimeSeconds % 3600) / 60)}m ${uptimeSeconds % 60}s`,
        memoryUsage: {
          heapUsedMB: (memory.heapUsed / 1024 / 1024).toFixed(2),
          heapTotalMB: (memory.heapTotal / 1024 / 1024).toFixed(2),
          rssMB: (memory.rss / 1024 / 1024).toFixed(2),
        },
        database: {
          status: mongoose.connection.readyState === 1 ? "Connected" : "Disconnected",
          collections: {
            users: userCount,
            trips: tripCount,
            expenses: expenseCount,
            photos: photoCount,
          },
        },
        cloudinary: cloudinaryUsage,
      },
    });
  } catch (error) {
    next(error);
  }
};
