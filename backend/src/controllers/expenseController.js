import mongoose from "mongoose";
import Expense from "../models/Expense.js";
import ExpenseParticipant from "../models/ExpenseParticipant.js";
import TripParticipant from "../models/TripParticipant.js";
import Family from "../models/Family.js";
import Trip from "../models/Trip.js";
import User from "../models/User.js";
import PDFDocument from "pdfkit";

// Helper: check if user is a member of the trip
const verifyTripAccess = async (tripId, userId) => {
  const participant = await TripParticipant.findOne({
    tripId,
    userId,
    status: "approved",
  });
  return participant;
};

// 1. Get all members eligible for expense splitting in this trip
// Returns app users and non-app family members, plus marks family members belonging to current user
export const getTripExpenseMembers = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    // Get all approved participants
    const participants = await TripParticipant.find({
      tripId,
      status: "approved",
    })
      .populate("userId", "firstName lastName profilePhoto phone email")
      .lean();

    const members = [];
    const myNonAppFamilyMembers = [];

    for (const p of participants) {
      if (!p.userId) continue;
      const isCurrentUser = p.userId._id.toString() === userId.toString();

      members.push({
        id: p.userId._id.toString(),
        userId: p.userId._id.toString(),
        guestId: null,
        type: "user",
        name: isCurrentUser ? "You" : `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim() || "User",
        avatar: p.userId.profilePhoto || null,
        phone: p.userId.phone || "",
        isCurrentUser,
        role: p.role,
      });

      // If this participant is a family leader, fetch their non-app family members
      if (p.role === "familyLeader") {
        const family = await Family.findOne({
          tripId,
          familyLeaderId: p.userId._id,
        }).lean();

        if (family && family.members && family.members.length > 0) {
          for (const fm of family.members) {
            // Only non-app members (where userId is null or not set)
            if (!fm.userId) {
              const guestMember = {
                id: fm._id.toString(),
                userId: null,
                guestId: fm._id.toString(),
                type: "guest",
                name: fm.name,
                avatar: null,
                relationship: fm.relationship,
                age: fm.age,
                leaderId: p.userId._id.toString(),
                leaderName: `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim(),
                isMyFamilyMember: isCurrentUser,
                role: "guestFamilyMember",
              };

              members.push(guestMember);

              if (isCurrentUser) {
                myNonAppFamilyMembers.push(guestMember);
              }
            }
          }
        }
      }
    }

    res.status(200).json({
      success: true,
      data: {
        members,
        myNonAppFamilyMembers,
        isFamilyLeader: access.role === "familyLeader",
      },
    });
  } catch (error) {
    console.error("Error in getTripExpenseMembers:", error);
    res.status(500).json({ success: false, message: "Server error fetching members" });
  }
};

// 2. Create a new expense (Split bill)
export const createExpense = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const {
      title,
      description = "",
      amount,
      currency = "INR",
      category = "other",
      splitType = "equal",
      participants: rawParticipants, // array of { type: 'user'|'guest', userId, guestId, guestName, shareAmount }
      paidBy: customPaidBy,
    } = req.body;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      await session.abortTransaction();
      session.endSession();
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    if (!title || !title.trim()) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ success: false, message: "Title is required" });
    }

    const totalAmount = Number(amount);
    if (isNaN(totalAmount) || totalAmount <= 0) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ success: false, message: "Valid positive amount is required" });
    }

    if (!Array.isArray(rawParticipants) || rawParticipants.length === 0) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ success: false, message: "At least one participant is required" });
    }

    // Determine who paid
    let paidByInfo = {
      type: "user",
      userId: userId,
      guestId: null,
      guestName: null,
    };

    if (customPaidBy && customPaidBy.type === "guest" && customPaidBy.guestId) {
      // Validate that family leader is paying for their guest
      const family = await Family.findOne({
        tripId,
        familyLeaderId: userId,
        "members._id": customPaidBy.guestId,
      });
      if (!family) {
        await session.abortTransaction();
        session.endSession();
        return res.status(403).json({ success: false, message: "Cannot pay on behalf of unauthorized guest" });
      }
      paidByInfo = {
        type: "guest",
        userId: null,
        guestId: customPaidBy.guestId,
        guestName: customPaidBy.guestName || "Guest",
      };
    }

    // Calculate individual shares
    let participantsWithShares = [];
    const count = rawParticipants.length;
    const totalPaise = Math.round(totalAmount * 100);

    if (splitType === "equal") {
      const baseSharePaise = Math.floor(totalPaise / count);
      let remainderPaise = totalPaise - baseSharePaise * count;

      participantsWithShares = rawParticipants.map((p, idx) => {
        const addPaisa = idx < remainderPaise ? 1 : 0;
        const shareAmount = (baseSharePaise + addPaisa) / 100;
        return {
          ...p,
          shareAmount,
        };
      });
    } else {
      // Exact custom split
      let sumPaise = 0;
      participantsWithShares = rawParticipants.map((p) => {
        const share = Number(p.shareAmount || 0);
        const sharePaise = Math.round(share * 100);
        sumPaise += sharePaise;
        return {
          ...p,
          shareAmount: share,
        };
      });

      if (Math.abs(sumPaise - totalPaise) > 1) {
        await session.abortTransaction();
        session.endSession();
        return res.status(400).json({
          success: false,
          message: `Sum of shares (₹${(sumPaise / 100).toFixed(2)}) must equal total amount (₹${totalAmount.toFixed(2)})`,
        });
      }
    }

    // Create Expense document
    const [newExpense] = await Expense.create(
      [
        {
          tripId,
          title: title.trim(),
          description: description.trim(),
          amount: totalAmount,
          currency: currency.toUpperCase(),
          category,
          paidBy: paidByInfo,
          splitType,
          date: new Date(),
          status: "active",
          createdBy: userId,
        },
      ],
      { session }
    );

    // Create ExpenseParticipant records
    const expenseParticipantDocs = participantsWithShares.map((p) => {
      const isUser = p.type !== "guest";
      const isPayer = isUser
        ? paidByInfo.type === "user" && p.userId && p.userId.toString() === paidByInfo.userId.toString()
        : paidByInfo.type === "guest" && p.guestId && p.guestId.toString() === customPaidBy?.guestId?.toString();

      return {
        expenseId: newExpense._id,
        tripId,
        participantType: isUser ? "user" : "guest",
        userId: isUser ? p.userId : null,
        guestId: !isUser ? p.guestId : null,
        guestName: !isUser ? p.guestName || p.name : null,
        shareAmount: p.shareAmount,
        sharePercentage: totalAmount > 0 ? (p.shareAmount / totalAmount) * 100 : 0,
        paidAmount: isPayer ? p.shareAmount : 0,
        settlementStatus: isPayer ? "settled" : "pending",
        settledAt: isPayer ? new Date() : null,
      };
    });

    await ExpenseParticipant.insertMany(expenseParticipantDocs, { session });

    await session.commitTransaction();
    session.endSession();

    res.status(201).json({
      success: true,
      message: "Expense created successfully",
      data: newExpense,
    });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error("Error in createExpense:", error);
    res.status(500).json({ success: false, message: "Server error creating expense" });
  }
};

// Helper: extract payer info (type: 'user'|'guest', entityId, name) from an expense document
const getExpensePayerInfo = (exp, families = []) => {
  if (exp.paidBy && exp.paidBy.type === "guest") {
    if (exp.paidBy.guestId) {
      return {
        type: "guest",
        entityId: exp.paidBy.guestId.toString(),
        name: exp.paidBy.guestName || "Guest",
      };
    }
    if (exp.paidBy.guestName) {
      for (const fam of families) {
        if (fam.members) {
          const match = fam.members.find(
            (m) => m.name && m.name.toLowerCase() === exp.paidBy.guestName.toLowerCase()
          );
          if (match) {
            return {
              type: "guest",
              entityId: match._id.toString(),
              name: match.name,
            };
          }
        }
      }
      return {
        type: "guest",
        entityId: `guest_name_${exp.paidBy.guestName}`,
        name: exp.paidBy.guestName,
      };
    }
  }

  if (exp.paidBy && exp.paidBy.type === "user" && exp.paidBy.userId) {
    return {
      type: "user",
      entityId: exp.paidBy.userId.toString(),
      name: "User",
    };
  }

  // Default fallback: createdBy user
  const creatorId = (exp.createdBy?._id || exp.createdBy)?.toString();
  return {
    type: "user",
    entityId: creatorId,
    name: "User",
  };
};

// 3. Get list of trip expenses (Splits tab)
// Only returns splits involving the current user (as payer or participant), or acting guest member
export const getTripExpenses = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { filter = "my", actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const families = await Family.find({ tripId }).lean();

    let expenseQuery = { tripId, status: "active" };

    if (filter === "my") {
      if (actingAsGuestId) {
        // Find guest member name for robust fallback matching
        let actingGuestName = null;
        for (const fam of families) {
          const mem = fam.members?.find((m) => m._id.toString() === actingAsGuestId.toString());
          if (mem) {
            actingGuestName = mem.name;
            break;
          }
        }

        // Acting as non-app family member:
        // Find expenses where this guest is participant OR this guest paid (even if not participating)
        const guestParts = await ExpenseParticipant.find({
          tripId,
          participantType: "guest",
          $or: [
            { guestId: actingAsGuestId },
            ...(actingGuestName ? [{ guestName: actingGuestName }] : []),
          ],
        }).select("expenseId");
        const participantExpenseIds = guestParts.map((gp) => gp.expenseId);

        const guestPaidConditions = [
          { "paidBy.type": "guest", "paidBy.guestId": actingAsGuestId },
        ];
        if (actingGuestName) {
          guestPaidConditions.push({ "paidBy.type": "guest", "paidBy.guestName": actingGuestName });
        }

        expenseQuery.$or = [
          ...guestPaidConditions,
          { _id: { $in: participantExpenseIds } },
        ];
      } else {
        // Acting as Myself (logged-in user):
        // Only personal splits: where user is participant OR user paid (NOT non-app guests' expenses)
        const userParts = await ExpenseParticipant.find({
          tripId,
          participantType: "user",
          userId,
        }).select("expenseId");
        const participantExpenseIds = userParts.map((up) => up.expenseId);

        expenseQuery.$or = [
          { "paidBy.type": "user", "paidBy.userId": userId },
          {
            createdBy: userId,
            $or: [{ "paidBy.type": { $exists: false } }, { "paidBy.type": "user" }, { paidBy: { $exists: false } }],
          },
          { _id: { $in: participantExpenseIds } },
        ];
      }
    }

    const expenses = await Expense.find(expenseQuery)
      .populate("createdBy", "firstName lastName profilePhoto")
      .sort({ createdAt: 1 })
      .lean();

    // Enrich expenses with participants and progress
    const enrichedExpenses = await Promise.all(
      expenses.map(async (exp) => {
        const parts = await ExpenseParticipant.find({ expenseId: exp._id })
          .populate("userId", "firstName lastName profilePhoto")
          .lean();

        const totalParticipants = parts.length;
        const settledParticipants = parts.filter((p) => p.settlementStatus === "settled");
        const paidCount = settledParticipants.length;
        const totalPaid = settledParticipants.reduce((sum, p) => sum + (p.shareAmount || 0), 0);
        const amountLeft = Math.max(0, exp.amount - totalPaid);

        // Find who paid for this expense
        const payer = getExpensePayerInfo(exp, families);
        const currentEntityId = actingAsGuestId ? actingAsGuestId.toString() : userId.toString();

        // Is the current entity the one who paid / requested this split?
        const isCreatedByMe = payer.entityId === currentEntityId;

        // Current entity's specific participant record
        const myPart = parts.find((p) => {
          if (actingAsGuestId) {
            return p.participantType === "guest" && p.guestId && p.guestId.toString() === actingAsGuestId.toString();
          }
          return p.participantType === "user" && p.userId && p.userId._id.toString() === userId.toString();
        });

        // Overlapping avatars info
        const avatars = parts.map((p) => {
          if (p.participantType === "user" && p.userId) {
            return {
              name: `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim(),
              avatar: p.userId.profilePhoto || null,
            };
          }
          return {
            name: p.guestName || "Guest",
            avatar: null,
          };
        });

        return {
          ...exp,
          totalParticipants,
          paidCount,
          totalPaid,
          amountLeft,
          isCreatedByMe,
          userShare: myPart ? myPart.shareAmount : 0,
          userStatus: myPart ? myPart.settlementStatus : null,
          myParticipantId: myPart ? myPart._id : null,
          canPay: myPart && myPart.settlementStatus === "pending" && !isCreatedByMe,
          avatars,
        };
      })
    );

    res.status(200).json({ success: true, data: enrichedExpenses });
  } catch (error) {
    console.error("Error in getTripExpenses:", error);
    res.status(500).json({ success: false, message: "Server error fetching expenses" });
  }
};

// 4. Get Expense Details (Deep dive breakdown)
export const getExpenseDetail = async (req, res) => {
  try {
    const { tripId, expenseId } = req.params;
    const userId = req.user._id;
    const { actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const families = await Family.find({ tripId }).lean();
    const expense = await Expense.findOne({ _id: expenseId, tripId })
      .populate("createdBy", "firstName lastName profilePhoto")
      .lean();

    if (!expense) {
      return res.status(404).json({ success: false, message: "Expense not found" });
    }

    const payer = getExpensePayerInfo(expense, families);
    const currentEntityId = actingAsGuestId ? actingAsGuestId.toString() : userId.toString();

    const participants = await ExpenseParticipant.find({ expenseId })
      .populate("userId", "firstName lastName profilePhoto")
      .lean();

    const formattedParticipants = participants.map((p) => {
      const isUser = p.participantType === "user" && p.userId;
      const pEntityId = isUser ? p.userId._id.toString() : p.guestId?.toString();
      const isCurrentUser = pEntityId === currentEntityId;
      const isCreator = pEntityId === payer.entityId;

      return {
        id: p._id,
        userId: isUser ? p.userId._id : null,
        guestId: p.guestId,
        name: isCurrentUser
          ? "You"
          : isUser
          ? `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim()
          : p.guestName || "Guest",
        avatar: isUser ? p.userId.profilePhoto : null,
        shareAmount: p.shareAmount,
        paidAmount: p.paidAmount,
        settlementStatus: p.settlementStatus,
        settledAt: p.settledAt,
        isCreator,
        isCurrentUser,
      };
    });

    const totalPaid = formattedParticipants
      .filter((p) => p.settlementStatus === "settled")
      .reduce((sum, p) => sum + p.shareAmount, 0);

    const paidCount = formattedParticipants.filter((p) => p.settlementStatus === "settled").length;
    const amountLeft = Math.max(0, expense.amount - totalPaid);

    const isCreatorOrPayer =
      expense.createdBy?._id?.toString() === userId.toString() ||
      payer.entityId === currentEntityId;

    res.status(200).json({
      success: true,
      data: {
        expense,
        participants: formattedParticipants,
        totalPaid,
        amountLeft,
        paidCount,
        totalParticipants: formattedParticipants.length,
        isCreator: isCreatorOrPayer,
      },
    });
  } catch (error) {
    console.error("Error in getExpenseDetail:", error);
    res.status(500).json({ success: false, message: "Server error fetching expense details" });
  }
};

// 5. Settle a single participant in an expense
export const settleParticipant = async (req, res) => {
  try {
    const { tripId, expenseId } = req.params;
    const userId = req.user._id;
    const { participantId } = req.body;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const expense = await Expense.findOne({ _id: expenseId, tripId });
    if (!expense) {
      return res.status(404).json({ success: false, message: "Expense not found" });
    }

    let participant;
    if (participantId) {
      participant = await ExpenseParticipant.findOne({ _id: participantId, expenseId });
    } else {
      // Default to current user's participant record
      participant = await ExpenseParticipant.findOne({ expenseId, userId });
    }

    if (!participant) {
      return res.status(404).json({ success: false, message: "Participant record not found" });
    }

    // Permission check
    const isSelf = participant.userId && participant.userId.toString() === userId.toString();
    const isCreator = expense.createdBy.toString() === userId.toString();
    const isTripLeader = access.role === "tripLeader";

    // Family leader can settle for their guest
    let isFamilyLeaderForGuest = false;
    if (participant.participantType === "guest" && access.role === "familyLeader") {
      const family = await Family.findOne({
        tripId,
        familyLeaderId: userId,
        "members._id": participant.guestId,
      });
      if (family) isFamilyLeaderForGuest = true;
    }

    if (!isSelf && !isCreator && !isTripLeader && !isFamilyLeaderForGuest) {
      return res.status(403).json({ success: false, message: "Not authorized to settle this participant" });
    }

    participant.settlementStatus = "settled";
    participant.settledAt = new Date();
    participant.paidAmount = participant.shareAmount;
    await participant.save();

    res.status(200).json({
      success: true,
      message: "Settled successfully",
      data: participant,
    });
  } catch (error) {
    console.error("Error in settleParticipant:", error);
    res.status(500).json({ success: false, message: "Server error settling participant" });
  }
};

// Helper: Compute pairwise netted balances (+/-) between current user/guest and all other trip members
const computeTripBalances = async (tripId, currentEntityId, isGuest = false) => {
  const families = await Family.find({ tripId }).lean();
  const guestInfoMap = new Map();
  for (const fam of families) {
    if (fam.members) {
      for (const m of fam.members) {
        guestInfoMap.set(m._id.toString(), {
          name: m.name || "Guest",
          avatar: null,
          isGuest: true,
        });
      }
    }
  }

  const tripParticipants = await TripParticipant.find({ tripId, status: "approved" })
    .populate("userId", "firstName lastName profilePhoto")
    .lean();
  const userInfoMap = new Map();
  for (const p of tripParticipants) {
    if (p.userId) {
      userInfoMap.set(p.userId._id.toString(), {
        name: `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim() || "Member",
        avatar: p.userId.profilePhoto || null,
        isGuest: false,
      });
    }
  }

  const activeExpenses = await Expense.find({ tripId, status: "active" })
    .select("_id createdBy paidBy")
    .lean();

  const expenseIds = activeExpenses.map((e) => e._id);

  const allParts = await ExpenseParticipant.find({
    expenseId: { $in: expenseIds },
  })
    .populate("userId", "firstName lastName profilePhoto")
    .lean();

  const expensePayerMap = new Map();
  for (const exp of activeExpenses) {
    expensePayerMap.set(exp._id.toString(), getExpensePayerInfo(exp, families));
  }

  const balanceMap = new Map();

  const getOrCreateEntry = (key, name, avatar, isGuestFlag, id) => {
    if (!balanceMap.has(key)) {
      balanceMap.set(key, {
        key,
        targetId: id,
        isGuest: isGuestFlag,
        name: name || "Member",
        avatar: avatar || null,
        netBalance: 0,
        unpaidCount: 0,
        settledCount: 0,
      });
    }
    return balanceMap.get(key);
  };

  // Process all participant records
  for (const p of allParts) {
    const payer = expensePayerMap.get(p.expenseId.toString());
    if (!payer || !payer.entityId) continue;

    const pEntityId = p.participantType === "guest" ? p.guestId?.toString() : p.userId?._id?.toString();
    if (!pEntityId) continue;

    // Self-funded share: no debt
    if (pEntityId === payer.entityId) continue;

    const unpaidShare = p.settlementStatus === "pending" ? p.shareAmount - (p.paidAmount || 0) : 0;
    const isSettled = p.settlementStatus === "settled";

    // Scenario 1: Current entity is the PAYER of this expense
    // -> Participant owes current entity (+)
    if (payer.entityId === currentEntityId) {
      const isTargetGuest = p.participantType === "guest";
      const key = isTargetGuest ? `guest_${pEntityId}` : `user_${pEntityId}`;
      const targetName = isTargetGuest
        ? p.guestName || guestInfoMap.get(pEntityId)?.name || "Guest"
        : `${p.userId?.firstName || ""} ${p.userId?.lastName || ""}`.trim() || userInfoMap.get(pEntityId)?.name || "Member";
      const targetAvatar = isTargetGuest ? null : p.userId?.profilePhoto || userInfoMap.get(pEntityId)?.avatar || null;

      const entry = getOrCreateEntry(key, targetName, targetAvatar, isTargetGuest, pEntityId);
      if (unpaidShare > 0) {
        entry.netBalance += unpaidShare;
        entry.unpaidCount += 1;
      }
      if (isSettled) {
        entry.settledCount += 1;
      }
    }

    // Scenario 2: Current entity is the PARTICIPANT (debtor) in an expense paid by someone else
    // -> Current entity owes the payer (-)
    if (pEntityId === currentEntityId) {
      const isPayerGuest = payer.type === "guest";
      const key = isPayerGuest ? `guest_${payer.entityId}` : `user_${payer.entityId}`;
      let payerDisplayName = isPayerGuest
        ? guestInfoMap.get(payer.entityId)?.name || payer.name || "Guest"
        : userInfoMap.get(payer.entityId)?.name || "Member";

      if (!isPayerGuest && !userInfoMap.has(payer.entityId)) {
        const u = await User.findById(payer.entityId).select("firstName lastName profilePhoto").lean();
        if (u) {
          payerDisplayName = `${u.firstName || ""} ${u.lastName || ""}`.trim() || "Member";
          userInfoMap.set(payer.entityId, { name: payerDisplayName, avatar: u.profilePhoto, isGuest: false });
        }
      }

      const payerAvatar = isPayerGuest ? null : userInfoMap.get(payer.entityId)?.avatar || null;

      const entry = getOrCreateEntry(key, payerDisplayName, payerAvatar, isPayerGuest, payer.entityId);
      if (unpaidShare > 0) {
        entry.netBalance -= unpaidShare;
        entry.unpaidCount += 1;
      }
      if (isSettled) {
        entry.settledCount += 1;
      }
    }
  }

  const owedByYou = [];
  const owedToYou = [];
  const settled = [];
  let totalOwedByYou = 0;
  let totalOwedToYou = 0;

  balanceMap.forEach((entry) => {
    const roundedNet = Number(entry.netBalance.toFixed(2));
    if (roundedNet < -0.01) {
      const positiveAmount = Math.abs(roundedNet);
      totalOwedByYou += positiveAmount;
      owedByYou.push({
        id: entry.targetId,
        key: entry.key,
        isGuest: entry.isGuest,
        name: entry.name,
        avatar: entry.avatar,
        amount: positiveAmount,
        unpaidCount: entry.unpaidCount,
      });
    } else if (roundedNet > 0.01) {
      totalOwedToYou += roundedNet;
      owedToYou.push({
        id: entry.targetId,
        key: entry.key,
        isGuest: entry.isGuest,
        name: entry.name,
        avatar: entry.avatar,
        amount: roundedNet,
        unpaidCount: entry.unpaidCount,
      });
    } else {
      settled.push({
        id: entry.targetId,
        key: entry.key,
        isGuest: entry.isGuest,
        name: entry.name,
        avatar: entry.avatar,
        amount: 0,
        expensesCount: entry.settledCount || 0,
      });
    }
  });

  return {
    owedByYou,
    owedToYou,
    settled,
    totalOwedByYou: Number(totalOwedByYou.toFixed(2)),
    totalOwedToYou: Number(totalOwedToYou.toFixed(2)),
    netBalance: Number((totalOwedToYou - totalOwedByYou).toFixed(2)),
  };
};

// 6. Expense Summary (Owed by you - Red, Owed to you - Green)
// Display data after calculating settle-up value (+/- net between you and others)
export const getExpenseSummary = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const isGuest = !!actingAsGuestId;
    const currentEntityId = isGuest ? actingAsGuestId : userId.toString();

    const { totalOwedByYou, totalOwedToYou, netBalance } = await computeTripBalances(
      tripId,
      currentEntityId,
      isGuest
    );

    res.status(200).json({
      success: true,
      data: {
        owedByYou: totalOwedByYou,
        owedToYou: totalOwedToYou,
        netBalance: netBalance,
      },
    });
  } catch (error) {
    console.error("Error in getExpenseSummary:", error);
    res.status(500).json({ success: false, message: "Server error getting summary" });
  }
};

// 7. Get Person-wise Balances (Expenses Tab)
// Categorizes into: Owed by you, People who owe you, Settled
export const getExpenseBalances = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const isGuest = !!actingAsGuestId;
    const currentEntityId = isGuest ? actingAsGuestId : userId.toString();

    const { owedByYou, owedToYou, settled } = await computeTripBalances(
      tripId,
      currentEntityId,
      isGuest
    );

    res.status(200).json({
      success: true,
      data: {
        owedByYou,
        owedToYou,
        settled,
      },
    });
  } catch (error) {
    console.error("Error in getExpenseBalances:", error);
    res.status(500).json({ success: false, message: "Server error getting balances" });
  }
};

// 8. Get Balance Detail for a specific person (Unpaid & Paid tabs)
export const getBalanceDetail = async (req, res) => {
  try {
    const { tripId, targetId } = req.params;
    const userId = req.user._id;
    const { isGuest = "false", actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const families = await Family.find({ tripId }).lean();
    const isCurrentGuest = !!actingAsGuestId;
    const currentEntityId = isCurrentGuest ? actingAsGuestId.toString() : userId.toString();
    const isTargetGuest = isGuest === "true";

    // Target person info
    let targetName = "Member";
    let targetAvatar = null;

    if (isTargetGuest) {
      for (const f of families) {
        const member = f.members?.find((m) => m._id.toString() === targetId);
        if (member) {
          targetName = member.name;
          break;
        }
      }
    } else {
      const targetUser = await User.findById(targetId).select("firstName lastName profilePhoto").lean();
      if (targetUser) {
        targetName = `${targetUser.firstName || ""} ${targetUser.lastName || ""}`.trim();
        targetAvatar = targetUser.profilePhoto;
      }
    }

    // Get all active expenses in this trip
    const tripExpenses = await Expense.find({ tripId, status: "active" })
      .populate("createdBy", "firstName lastName profilePhoto")
      .lean();

    const unpaidExpenses = [];
    const paidExpenses = [];
    let netBalance = 0; // > 0: target owes current entity; < 0: current entity owes target

    for (const exp of tripExpenses) {
      const payer = getExpensePayerInfo(exp, families);
      if (!payer || !payer.entityId) continue;

      const parts = await ExpenseParticipant.find({ expenseId: exp._id }).lean();

      // Case A: Current entity PAID for this expense, target was participant
      // -> Target owes current entity (+)
      if (payer.entityId === currentEntityId) {
        const targetPart = parts.find((p) => {
          if (isTargetGuest) return p.participantType === "guest" && p.guestId && p.guestId.toString() === targetId;
          return p.participantType === "user" && p.userId && p.userId.toString() === targetId;
        });

        if (targetPart) {
          const item = {
            expenseId: exp._id,
            participantId: targetPart._id,
            title: exp.title,
            date: exp.date || exp.createdAt,
            shareAmount: targetPart.shareAmount,
            settlementStatus: targetPart.settlementStatus,
            requestedBy: "you",
            youOwe: false, // Target owes current entity
          };

          if (targetPart.settlementStatus === "pending") {
            unpaidExpenses.push(item);
            netBalance += targetPart.shareAmount - (targetPart.paidAmount || 0);
          } else {
            paidExpenses.push(item);
          }
        }
      }

      // Case B: Target PAID for this expense, current entity was participant
      // -> Current entity owes target (-)
      if (payer.entityId === targetId) {
        const currentPart = parts.find((p) => {
          if (isCurrentGuest) return p.participantType === "guest" && p.guestId && p.guestId.toString() === currentEntityId;
          return p.participantType === "user" && p.userId && p.userId.toString() === currentEntityId;
        });

        if (currentPart) {
          const item = {
            expenseId: exp._id,
            participantId: currentPart._id,
            title: exp.title,
            date: exp.date || exp.createdAt,
            shareAmount: currentPart.shareAmount,
            settlementStatus: currentPart.settlementStatus,
            requestedBy: targetName,
            youOwe: true, // Current entity owes target
          };

          if (currentPart.settlementStatus === "pending") {
            unpaidExpenses.push(item);
            netBalance -= currentPart.shareAmount - (currentPart.paidAmount || 0);
          } else {
            paidExpenses.push(item);
          }
        }
      }
    }

    const roundedNet = Number(netBalance.toFixed(2));
    const title =
      roundedNet < 0
        ? `You owe ${targetName}`
        : roundedNet > 0
        ? `${targetName} owes you`
        : `Settled with ${targetName}`;

    res.status(200).json({
      success: true,
      data: {
        target: {
          id: targetId,
          name: targetName,
          avatar: targetAvatar,
          isGuest: isTargetGuest,
        },
        title,
        netAmount: Math.abs(roundedNet),
        isOwedByYou: roundedNet < 0,
        unpaidExpenses,
        paidExpenses,
      },
    });
  } catch (error) {
    console.error("Error in getBalanceDetail:", error);
    res.status(500).json({ success: false, message: "Server error getting balance detail" });
  }
};

// 9. Settle all (or selected) expenses with a specific person
export const settlePersonExpenses = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { participantIds } = req.body; // Array of ExpenseParticipant IDs to settle

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    if (!Array.isArray(participantIds) || participantIds.length === 0) {
      return res.status(400).json({ success: false, message: "participantIds array is required" });
    }

    const parts = await ExpenseParticipant.find({
      _id: { $in: participantIds },
      tripId,
    });

    for (const p of parts) {
      p.settlementStatus = "settled";
      p.settledAt = new Date();
      p.paidAmount = p.shareAmount;
      await p.save();
    }

    res.status(200).json({
      success: true,
      message: "Expenses settled successfully",
    });
  } catch (error) {
    console.error("Error in settlePersonExpenses:", error);
    res.status(500).json({ success: false, message: "Server error settling expenses" });
  }
};

// 10. Delete / Close an Expense request
export const deleteExpense = async (req, res) => {
  try {
    const { tripId, expenseId } = req.params;
    const userId = req.user._id;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const expense = await Expense.findOne({ _id: expenseId, tripId });
    if (!expense) {
      return res.status(404).json({ success: false, message: "Expense not found" });
    }

    // Only creator or trip leader can close/delete
    if (expense.createdBy.toString() !== userId.toString() && access.role !== "tripLeader") {
      return res.status(403).json({ success: false, message: "Not authorized to close this request" });
    }

    expense.status = "deleted";
    await expense.save();

    res.status(200).json({
      success: true,
      message: "Expense request closed successfully",
    });
  } catch (error) {
    console.error("Error in deleteExpense:", error);
    res.status(500).json({ success: false, message: "Server error deleting expense" });
  }
};

// 11. Download Comprehensive Expense PDF Report
// Covers own expenses, payments made for self vs others, category breakdown, and pairwise balance sheet
export const downloadExpensePdf = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { actingAsGuestId } = req.query;

    const access = await verifyTripAccess(tripId, userId);
    if (!access) {
      return res.status(403).json({ success: false, message: "Not a trip participant" });
    }

    const families = await Family.find({ tripId }).lean();
    const trip = await Trip.findById(tripId).lean();
    const tripParticipants = await TripParticipant.find({ tripId, status: "approved" })
      .populate("userId", "firstName lastName")
      .lean();
    const userInfoMap = new Map();
    for (const p of tripParticipants) {
      if (p.userId) {
        userInfoMap.set(p.userId._id.toString(), {
          name: `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim() || "Member",
        });
      }
    }
    const tripTitle = trip?.title || trip?.name || "Trip";
    const isGuest = !!actingAsGuestId;
    const currentEntityId = isGuest ? actingAsGuestId.toString() : userId.toString();

    let entityName = `${req.user.firstName || ""} ${req.user.lastName || ""}`.trim() || "User";
    if (isGuest) {
      const guestPart = await ExpenseParticipant.findOne({ tripId, guestId: actingAsGuestId }).lean();
      if (guestPart?.guestName) entityName = guestPart.guestName;
    }

    // 1. Fetch balances using pairwise mutual netting
    const balances = await computeTripBalances(tripId, currentEntityId, isGuest);

    // 2. Fetch all expenses
    const allExpenses = await Expense.find({ tripId, status: { $ne: "deleted" } })
      .populate("createdBy", "firstName lastName")
      .sort({ createdAt: 1 })
      .lean();

    const allParts = await ExpenseParticipant.find({ tripId })
      .populate("userId", "firstName lastName")
      .lean();

    // Group participants by expenseId
    const partsByExpense = new Map();
    for (const p of allParts) {
      const expId = p.expenseId.toString();
      if (!partsByExpense.has(expId)) partsByExpense.set(expId, []);
      partsByExpense.get(expId).push(p);
    }

    // Classify expenses
    const paidByYouExpenses = [];
    const paidByOthersExpenses = [];
    let totalPaidByYou = 0;
    let totalPaidForSelf = 0;
    let totalPaidForOthers = 0;
    let totalOthersPaidForYou = 0;

    const categorySummary = {};

    for (const exp of allExpenses) {
      const expId = exp._id.toString();
      const parts = partsByExpense.get(expId) || [];
      const payer = getExpensePayerInfo(exp, families);
      const isPayer = payer.entityId === currentEntityId;
      const cat = exp.category || "General";

      if (!categorySummary[cat]) {
        categorySummary[cat] = { count: 0, totalAmount: 0, paidForSelf: 0, paidForOthers: 0 };
      }
      categorySummary[cat].count += 1;
      categorySummary[cat].totalAmount += exp.amount || 0;

      if (isPayer) {
        let selfShare = 0;
        let othersShare = 0;

        for (const p of parts) {
          const pEntityId = p.participantType === "guest" ? p.guestId?.toString() : p.userId?._id?.toString();
          if (pEntityId === currentEntityId) {
            selfShare += p.shareAmount || 0;
          } else {
            othersShare += p.shareAmount || 0;
          }
        }

        totalPaidByYou += exp.amount || 0;
        totalPaidForSelf += selfShare;
        totalPaidForOthers += othersShare;
        categorySummary[cat].paidForSelf += selfShare;
        categorySummary[cat].paidForOthers += othersShare;

        paidByYouExpenses.push({
          title: exp.title,
          category: cat,
          amount: exp.amount,
          selfShare,
          othersShare,
          date: exp.createdAt,
        });
      } else {
        // Did current entity participate in this expense?
        const myPart = parts.find((p) => {
          const pEntityId = p.participantType === "guest" ? p.guestId?.toString() : p.userId?._id?.toString();
          return pEntityId === currentEntityId;
        });

        if (myPart) {
          const payerName =
            payer.type === "guest"
              ? payer.name || "Guest"
              : userInfoMap.get(payer.entityId)?.name ||
                `${exp.createdBy?.firstName || ""} ${exp.createdBy?.lastName || ""}`.trim() ||
                "Member";
          totalOthersPaidForYou += myPart.shareAmount || 0;

          paidByOthersExpenses.push({
            title: exp.title,
            category: cat,
            creatorName: payerName,
            totalAmount: exp.amount,
            yourShare: myPart.shareAmount || 0,
            status: myPart.settlementStatus,
            date: exp.createdAt,
          });
        }
      }
    }

    // Set PDF headers
    const safeTripName = tripTitle.replace(/[^a-zA-Z0-9_-]/g, "_");
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="Expense_Report_${safeTripName}.pdf"`
    );

    const doc = new PDFDocument({ margin: 40, size: "A4", bufferPages: true });
    doc.pipe(res);

    // Styling constants
    const primaryColor = "#1E5AE6";
    const darkColor = "#0F172A";
    const greyColor = "#64748B";
    const greenColor = "#16A34A";
    const redColor = "#EF4444";
    const lightBg = "#F8FAFC";
    const borderColor = "#CBD5E1";

    // 1. Document Header Banner
    doc.rect(40, 40, 515, 60).fill(primaryColor);
    doc.fillColor("#FFFFFF").fontSize(18).font("Helvetica-Bold").text("TRIP EXPENSE REPORT", 55, 52);
    doc.fontSize(10).font("Helvetica").text(`TripSync Financial Summary & Bill Breakdown`, 55, 75);

    let y = 115;

    // 2. Trip & User Details Section
    doc.rect(40, y, 515, 65).fillAndStroke(lightBg, borderColor);
    doc.fillColor(darkColor).fontSize(13).font("Helvetica-Bold").text(tripTitle, 55, y + 10);

    doc.fillColor(greyColor).fontSize(9).font("Helvetica");
    const datesStr = trip?.startDate
      ? `${new Date(trip.startDate).toLocaleDateString()} - ${trip.endDate ? new Date(trip.endDate).toLocaleDateString() : ""}`
      : "All Dates";
    doc.text(`Dates: ${datesStr}`, 55, y + 28);
    doc.text(`Report For: ${entityName} ${isGuest ? "(Family Member)" : ""}`, 55, y + 43);
    doc.text(`Generated On: ${new Date().toLocaleDateString()}`, 340, y + 28);
    doc.text(`Total Trip Expenses: ${allExpenses.length}`, 340, y + 43);

    y += 80;

    // 3. Executive Financial Summary Cards
    doc.fillColor(darkColor).fontSize(11).font("Helvetica-Bold").text("EXECUTIVE FINANCIAL SUMMARY", 40, y);
    y += 16;

    const cardWidth = 120;
    const cardHeight = 55;

    // Card 1: Total Paid By You
    doc.rect(40, y, cardWidth, cardHeight).fillAndStroke(lightBg, borderColor);
    doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("TOTAL PAID BY YOU", 48, y + 8);
    doc.fillColor(primaryColor).fontSize(12).font("Helvetica-Bold").text(`Rs. ${totalPaidByYou.toFixed(2)}`, 48, y + 24);

    // Card 2: Paid For Yourself
    doc.rect(170, y, cardWidth, cardHeight).fillAndStroke(lightBg, borderColor);
    doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("PAID FOR YOURSELF", 178, y + 8);
    doc.fillColor(darkColor).fontSize(12).font("Helvetica-Bold").text(`Rs. ${totalPaidForSelf.toFixed(2)}`, 178, y + 24);

    // Card 3: Paid For Others
    doc.rect(300, y, cardWidth, cardHeight).fillAndStroke(lightBg, borderColor);
    doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("PAID FOR OTHERS", 308, y + 8);
    doc.fillColor(darkColor).fontSize(12).font("Helvetica-Bold").text(`Rs. ${totalPaidForOthers.toFixed(2)}`, 308, y + 24);

    // Card 4: Net Settle-Up Balance
    doc.rect(430, y, 125, cardHeight).fillAndStroke(lightBg, borderColor);
    doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("NET BALANCE (+ / -)", 438, y + 8);
    const net = balances.netBalance;
    const netColor = net >= 0 ? greenColor : redColor;
    const netPrefix = net > 0 ? "+ Rs. " : (net < 0 ? "- Rs. " : "Rs. ");
    doc.fillColor(netColor).fontSize(12).font("Helvetica-Bold").text(`${netPrefix}${Math.abs(net).toFixed(2)}`, 438, y + 23);
    doc.fontSize(7).text(net >= 0 ? "You are owed" : "You owe others", 438, y + 40);

    y += 70;

    // 4. Category / Type Breakdown
    doc.fillColor(darkColor).fontSize(11).font("Helvetica-Bold").text("EXPENSES BY CATEGORY / TYPE", 40, y);
    y += 16;

    // Header row
    doc.rect(40, y, 515, 20).fill("#F1F5F9");
    doc.fillColor(darkColor).fontSize(8).font("Helvetica-Bold");
    doc.text("CATEGORY", 50, y + 6);
    doc.text("BILLS", 160, y + 6);
    doc.text("TOTAL BILL", 230, y + 6);
    doc.text("FOR YOURSELF", 330, y + 6);
    doc.text("FOR OTHERS", 440, y + 6);
    y += 20;

    const cats = Object.keys(categorySummary);
    if (cats.length === 0) {
      doc.rect(40, y, 515, 18).stroke(borderColor);
      doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("No expenses recorded yet.", 50, y + 5);
      y += 18;
    } else {
      for (const cat of cats) {
        const item = categorySummary[cat];
        doc.rect(40, y, 515, 18).stroke(borderColor);
        doc.fillColor(darkColor).fontSize(8).font("Helvetica");
        doc.text(cat, 50, y + 5);
        doc.text(item.count.toString(), 160, y + 5);
        doc.text(`Rs. ${item.totalAmount.toFixed(2)}`, 230, y + 5);
        doc.text(`Rs. ${item.paidForSelf.toFixed(2)}`, 330, y + 5);
        doc.text(`Rs. ${item.paidForOthers.toFixed(2)}`, 440, y + 5);
        y += 18;
      }
    }

    y += 16;

    // 5. Bills Paid by You (Breakdown of what you covered)
    if (y > 640) { doc.addPage(); y = 40; }
    doc.fillColor(darkColor).fontSize(11).font("Helvetica-Bold").text("BILLS PAID BY YOU (Covered for Yourself & Others)", 40, y);
    y += 16;

    doc.rect(40, y, 515, 20).fill("#F1F5F9");
    doc.fillColor(darkColor).fontSize(8).font("Helvetica-Bold");
    doc.text("DATE", 48, y + 6);
    doc.text("EXPENSE TITLE", 115, y + 6);
    doc.text("TOTAL BILL", 250, y + 6);
    doc.text("YOUR SHARE", 340, y + 6);
    doc.text("PAID FOR OTHERS", 430, y + 6);
    y += 20;

    if (paidByYouExpenses.length === 0) {
      doc.rect(40, y, 515, 18).stroke(borderColor);
      doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("You have not created any bills yet.", 48, y + 5);
      y += 18;
    } else {
      for (const exp of paidByYouExpenses) {
        if (y > 750) { doc.addPage(); y = 40; }
        doc.rect(40, y, 515, 18).stroke(borderColor);
        doc.fillColor(darkColor).fontSize(8).font("Helvetica");
        const dStr = exp.date ? new Date(exp.date).toLocaleDateString() : "-";
        doc.text(dStr, 48, y + 5);
        doc.font("Helvetica-Bold").text(exp.title.substring(0, 24), 115, y + 5);
        doc.font("Helvetica").text(`Rs. ${exp.amount.toFixed(2)}`, 250, y + 5);
        doc.text(`Rs. ${exp.selfShare.toFixed(2)}`, 340, y + 5);
        doc.text(`Rs. ${exp.othersShare.toFixed(2)}`, 430, y + 5);
        y += 18;
      }
    }

    y += 16;

    // 6. Bills Paid by Others For You
    if (y > 640) { doc.addPage(); y = 40; }
    doc.fillColor(darkColor).fontSize(11).font("Helvetica-Bold").text("BILLS PAID BY OTHERS (Your Share in Their Expenses)", 40, y);
    y += 16;

    doc.rect(40, y, 515, 20).fill("#F1F5F9");
    doc.fillColor(darkColor).fontSize(8).font("Helvetica-Bold");
    doc.text("DATE", 48, y + 6);
    doc.text("EXPENSE TITLE", 115, y + 6);
    doc.text("PAID BY", 250, y + 6);
    doc.text("YOUR SHARE", 350, y + 6);
    doc.text("STATUS", 445, y + 6);
    y += 20;

    if (paidByOthersExpenses.length === 0) {
      doc.rect(40, y, 515, 18).stroke(borderColor);
      doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("No bills paid by others for you.", 48, y + 5);
      y += 18;
    } else {
      for (const exp of paidByOthersExpenses) {
        if (y > 750) { doc.addPage(); y = 40; }
        doc.rect(40, y, 515, 18).stroke(borderColor);
        doc.fillColor(darkColor).fontSize(8).font("Helvetica");
        const dStr = exp.date ? new Date(exp.date).toLocaleDateString() : "-";
        doc.text(dStr, 48, y + 5);
        doc.font("Helvetica-Bold").text(exp.title.substring(0, 24), 115, y + 5);
        doc.font("Helvetica").text(exp.creatorName.substring(0, 18), 250, y + 5);
        doc.text(`Rs. ${exp.yourShare.toFixed(2)}`, 350, y + 5);
        const isSettled = exp.status === "settled";
        doc.fillColor(isSettled ? greenColor : redColor).font("Helvetica-Bold").text(isSettled ? "Settled" : "Pending", 445, y + 5);
        y += 18;
      }
    }

    y += 16;

    // 7. Settle-Up Balance Sheet (Person-by-Person Mutual Netting)
    if (y > 600) { doc.addPage(); y = 40; }
    doc.fillColor(darkColor).fontSize(11).font("Helvetica-Bold").text("FINAL SETTLEMENT BALANCE SHEET (Pairwise Mutual Netting)", 40, y);
    y += 16;

    doc.rect(40, y, 515, 20).fill("#F1F5F9");
    doc.fillColor(darkColor).fontSize(8).font("Helvetica-Bold");
    doc.text("MEMBER", 48, y + 6);
    doc.text("BALANCE TYPE", 220, y + 6);
    doc.text("NET SETTLE AMOUNT", 390, y + 6);
    y += 20;

    const allBalanceRows = [
      ...balances.owedToYou.map(b => ({ ...b, type: "Owes You (+)", color: greenColor })),
      ...balances.owedByYou.map(b => ({ ...b, type: "You Owe (-)", color: redColor })),
      ...balances.settled.map(b => ({ ...b, type: "All Settled", color: greyColor })),
    ];

    if (allBalanceRows.length === 0) {
      doc.rect(40, y, 515, 18).stroke(borderColor);
      doc.fillColor(greyColor).fontSize(8).font("Helvetica").text("No member balances found.", 48, y + 5);
      y += 18;
    } else {
      for (const row of allBalanceRows) {
        if (y > 750) { doc.addPage(); y = 40; }
        doc.rect(40, y, 515, 18).stroke(borderColor);
        doc.fillColor(darkColor).fontSize(8).font("Helvetica-Bold");
        doc.text(row.name, 48, y + 5);
        doc.font("Helvetica").fillColor(row.color).text(row.type, 220, y + 5);
        doc.font("Helvetica-Bold").fillColor(row.color).text(`Rs. ${row.amount.toFixed(2)}`, 390, y + 5);
        y += 18;
      }
    }

    // Footers on all pages
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      doc.switchToPage(i);
      doc.rect(40, 800, 515, 1).fill(borderColor);
      doc.fillColor(greyColor).fontSize(8).font("Helvetica").text(
        `TripSync • ${tripTitle} Expense Report • Page ${i + 1} of ${range.count}`,
        40,
        808,
        { align: "center", width: 515 }
      );
    }

    doc.end();
  } catch (error) {
    console.error("Error generating expense PDF report:", error);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: "Error generating expense report" });
    }
  }
};
