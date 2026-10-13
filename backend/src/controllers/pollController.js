import Poll from "../models/Poll.js";
import PollVote from "../models/PollVote.js";
import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import User from "../models/User.js";
import { emitToTripRoom } from "../socket.js";
import { createAndSendNotification } from "../services/notificationService.js";

// Helper to check if requester is Trip Leader
const checkIsTripLeader = async (tripId, userId) => {
  const trip = await Trip.findById(tripId);
  if (trip && trip.createdBy && trip.createdBy.toString() === userId.toString()) {
    return true;
  }
  const participant = await TripParticipant.findOne({
    tripId,
    userId,
    status: "approved",
  });
  if (
    participant &&
    (participant.role === "tripLeader" || participant.permissions?.managePolls)
  ) {
    return true;
  }
  return false;
};

// Helper to format a single poll for client response
const formatPoll = (pollDoc, currentUserId) => {
  const currentUserIdStr = currentUserId ? currentUserId.toString() : null;

  let totalVotes = 0;
  for (const opt of pollDoc.options) {
    totalVotes += (opt.voterIds || []).length;
  }

  const userVotedOptionIds = [];

  const formattedOptions = pollDoc.options.map((opt) => {
    const voterIds = (opt.voterIds || []).map((id) => id.toString());
    const count = voterIds.length;
    const percentage = totalVotes > 0 ? Math.round((count / totalVotes) * 100) : 0;
    const hasVoted = currentUserIdStr ? voterIds.includes(currentUserIdStr) : false;

    if (hasVoted) {
      userVotedOptionIds.push(opt._id.toString());
    }

    return {
      id: opt._id.toString(),
      _id: opt._id.toString(),
      text: opt.text,
      voteCount: count,
      percentage,
      hasVoted,
      voterIds,
    };
  });

  const creator = pollDoc.createdBy;
  const creatorName = creator
    ? `${creator.firstName || ""} ${creator.lastName || ""}`.trim()
    : "Trip Leader";

  return {
    id: pollDoc._id.toString(),
    _id: pollDoc._id.toString(),
    tripId: pollDoc.tripId.toString(),
    createdBy: creator ? (creator._id ? creator._id.toString() : creator.toString()) : null,
    creatorName: creatorName.length > 0 ? creatorName : "Trip Leader",
    creatorAvatar: creator?.profilePhoto || null,
    question: pollDoc.question,
    description: pollDoc.description || "",
    options: formattedOptions,
    allowMultipleAnswers: !!pollDoc.allowMultipleAnswers,
    anonymous: !!pollDoc.anonymous,
    status: pollDoc.status || "active",
    totalVotes,
    hasUserVoted: userVotedOptionIds.length > 0,
    userVotedOptionIds,
    createdAt: pollDoc.createdAt ? pollDoc.createdAt.toISOString() : new Date().toISOString(),
    updatedAt: pollDoc.updatedAt ? pollDoc.updatedAt.toISOString() : new Date().toISOString(),
  };
};

// 1. Get all polls for a trip
export const getTripPolls = async (req, res) => {
  try {
    const { tripId } = req.params;

    const polls = await Poll.find({ tripId })
      .populate("createdBy", "firstName lastName profilePhoto")
      .sort({ createdAt: -1 })
      .lean();

    const formattedPolls = polls.map((p) => formatPoll(p, req.user?._id));

    return res.status(200).json({
      success: true,
      data: formattedPolls,
    });
  } catch (error) {
    console.error("Error fetching trip polls:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch polls." });
  }
};

// 2. Create a poll (Trip Leader only)
export const createPoll = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { question, options, allowMultipleAnswers } = req.body;

    const isLeader = await checkIsTripLeader(tripId, req.user._id);
    if (!isLeader) {
      return res.status(403).json({
        success: false,
        message: "Only the Trip Leader can create polls.",
      });
    }

    if (!question || question.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: "Poll question is required.",
      });
    }

    if (!Array.isArray(options) || options.length < 2) {
      return res.status(400).json({
        success: false,
        message: "At least 2 options are required to create a poll.",
      });
    }

    const cleanOptions = options
      .map((opt) => (typeof opt === "string" ? opt.trim() : (opt?.text || "").trim()))
      .filter((opt) => opt.length > 0);

    if (cleanOptions.length < 2) {
      return res.status(400).json({
        success: false,
        message: "At least 2 valid, non-empty options are required.",
      });
    }

    const newPoll = new Poll({
      tripId,
      createdBy: req.user._id,
      question: question.trim(),
      options: cleanOptions.map((text) => ({ text, voterIds: [] })),
      allowMultipleAnswers: !!allowMultipleAnswers,
      status: "active",
    });

    await newPoll.save();
    await newPoll.populate("createdBy", "firstName lastName profilePhoto");

    const formatted = formatPoll(newPoll, req.user._id);

    // Broadcast live to trip room
    emitToTripRoom(tripId, "poll_created", formatted);

    // Send notifications to trip participants
    try {
      const participants = await TripParticipant.find({ tripId, status: "approved" });
      const targetUserIds = participants
        .map((p) => (p.userId ? p.userId.toString() : null))
        .filter((id) => id && id !== req.user._id.toString());

      const trip = await Trip.findById(tripId).select("name title createdBy");
      if (
        trip?.createdBy &&
        trip.createdBy.toString() !== req.user._id.toString() &&
        !targetUserIds.includes(trip.createdBy.toString())
      ) {
        targetUserIds.push(trip.createdBy.toString());
      }

      const creatorName = req.user.firstName
        ? `${req.user.firstName} ${req.user.lastName || ""}`.trim()
        : req.user.name || "Trip Leader";

      await createAndSendNotification({
        targetUserIds,
        tripId,
        type: "pollCreated",
        title: "New Poll Created",
        message: `${creatorName} created a poll: "${newPoll.question}"`,
        referenceId: newPoll._id,
        referenceType: "Poll",
      });
    } catch (notifErr) {
      console.error("Error creating poll notification:", notifErr);
    }

    return res.status(201).json({
      success: true,
      message: "Poll created successfully.",
      data: formatted,
    });
  } catch (error) {
    console.error("Error creating poll:", error);
    return res.status(500).json({ success: false, message: "Failed to create poll." });
  }
};

// 3. Vote on a poll option (All approved trip members)
export const votePoll = async (req, res) => {
  try {
    const { tripId, pollId } = req.params;
    const { optionId } = req.body;

    if (!optionId) {
      return res.status(400).json({ success: false, message: "optionId is required to vote." });
    }

    const poll = await Poll.findOne({ _id: pollId, tripId });
    if (!poll) {
      return res.status(404).json({ success: false, message: "Poll not found." });
    }

    if (poll.status === "closed") {
      return res.status(400).json({ success: false, message: "This poll is closed." });
    }

    const targetOption = poll.options.id(optionId);
    if (!targetOption) {
      return res.status(404).json({ success: false, message: "Selected option not found in poll." });
    }

    const userIdStr = req.user._id.toString();
    const existingIndex = targetOption.voterIds.findIndex(
      (id) => id.toString() === userIdStr
    );

    if (existingIndex !== -1) {
      // Toggle off / un-vote
      targetOption.voterIds.splice(existingIndex, 1);
      await PollVote.deleteOne({
        pollId: poll._id,
        userId: req.user._id,
        optionId: targetOption._id,
      });
    } else {
      // If single-choice poll, remove user's vote from all other options
      if (!poll.allowMultipleAnswers) {
        for (const opt of poll.options) {
          opt.voterIds = opt.voterIds.filter((id) => id.toString() !== userIdStr);
        }
        await PollVote.deleteMany({ pollId: poll._id, userId: req.user._id });
      }

      // Add vote to chosen option
      targetOption.voterIds.push(req.user._id);
      await PollVote.findOneAndUpdate(
        { pollId: poll._id, tripId, userId: req.user._id, optionId: targetOption._id },
        { votedAt: new Date() },
        { upsert: true }
      );
    }

    await poll.save();
    await poll.populate("createdBy", "firstName lastName profilePhoto");

    const formatted = formatPoll(poll, req.user._id);

    // Live result update to all trip members via Socket.io
    emitToTripRoom(tripId, "poll_updated", formatted);

    return res.status(200).json({
      success: true,
      message: "Vote recorded successfully.",
      data: formatted,
    });
  } catch (error) {
    console.error("Error voting on poll:", error);
    return res.status(500).json({ success: false, message: "Failed to record vote." });
  }
};

// 4. Edit a poll (Trip Leader only)
export const editPoll = async (req, res) => {
  try {
    const { tripId, pollId } = req.params;
    const { question, options, allowMultipleAnswers } = req.body;

    const isLeader = await checkIsTripLeader(tripId, req.user._id);
    if (!isLeader) {
      return res.status(403).json({
        success: false,
        message: "Only the Trip Leader can edit polls.",
      });
    }

    const poll = await Poll.findOne({ _id: pollId, tripId });
    if (!poll) {
      return res.status(404).json({ success: false, message: "Poll not found." });
    }

    if (question && question.trim().length > 0) {
      poll.question = question.trim();
    }

    if (allowMultipleAnswers !== undefined) {
      poll.allowMultipleAnswers = !!allowMultipleAnswers;
    }

    if (Array.isArray(options) && options.length >= 2) {
      // Map existing options preserving votes, and add any newly created options
      const updatedOptions = [];

      for (const opt of options) {
        const text = (typeof opt === "string" ? opt : opt?.text || "").trim();
        if (text.length === 0) continue;

        const optId = opt?._id || opt?.id;
        if (optId) {
          const existingOpt = poll.options.id(optId);
          if (existingOpt) {
            existingOpt.text = text;
            updatedOptions.push(existingOpt);
            continue;
          }
        }

        // New option added during edit
        updatedOptions.push({ text, voterIds: [] });
      }

      if (updatedOptions.length >= 2) {
        poll.options = updatedOptions;
      }
    }

    await poll.save();
    await poll.populate("createdBy", "firstName lastName profilePhoto");

    const formatted = formatPoll(poll, req.user._id);

    // Broadcast updated poll live to all trip members
    emitToTripRoom(tripId, "poll_updated", formatted);

    // Send notifications to trip participants
    try {
      const participants = await TripParticipant.find({ tripId, status: "approved" });
      const targetUserIds = participants
        .map((p) => (p.userId ? p.userId.toString() : null))
        .filter((id) => id && id !== req.user._id.toString());

      const trip = await Trip.findById(tripId).select("name title createdBy");
      if (
        trip?.createdBy &&
        trip.createdBy.toString() !== req.user._id.toString() &&
        !targetUserIds.includes(trip.createdBy.toString())
      ) {
        targetUserIds.push(trip.createdBy.toString());
      }

      const creatorName = req.user.firstName
        ? `${req.user.firstName} ${req.user.lastName || ""}`.trim()
        : req.user.name || "Trip Leader";

      await createAndSendNotification({
        targetUserIds,
        tripId,
        type: "pollUpdated",
        title: "Poll Updated",
        message: `${creatorName} updated the poll: "${poll.question}"`,
        referenceId: poll._id,
        referenceType: "Poll",
      });
    } catch (notifErr) {
      console.error("Error creating poll update notification:", notifErr);
    }

    return res.status(200).json({
      success: true,
      message: "Poll updated successfully.",
      data: formatted,
    });
  } catch (error) {
    console.error("Error editing poll:", error);
    return res.status(500).json({ success: false, message: "Failed to edit poll." });
  }
};

// 5. Delete a poll (Trip Leader only)
export const deletePoll = async (req, res) => {
  try {
    const { tripId, pollId } = req.params;

    const isLeader = await checkIsTripLeader(tripId, req.user._id);
    if (!isLeader) {
      return res.status(403).json({
        success: false,
        message: "Only the Trip Leader can delete polls.",
      });
    }

    const poll = await Poll.findOneAndDelete({ _id: pollId, tripId });
    if (!poll) {
      return res.status(404).json({ success: false, message: "Poll not found." });
    }

    await PollVote.deleteMany({ pollId });

    // Broadcast poll deletion live to all trip members
    emitToTripRoom(tripId, "poll_deleted", { pollId });

    return res.status(200).json({
      success: true,
      message: "Poll deleted successfully.",
      pollId,
    });
  } catch (error) {
    console.error("Error deleting poll:", error);
    return res.status(500).json({ success: false, message: "Failed to delete poll." });
  }
};

// 6. Get voters breakdown (only members joined with email address, showing voted & not voted)
export const getPollVoters = async (req, res) => {
  try {
    const { tripId, pollId } = req.params;

    const poll = await Poll.findOne({ _id: pollId, tripId }).lean();
    if (!poll) {
      return res.status(404).json({ success: false, message: "Poll not found." });
    }

    const trip = await Trip.findById(tripId).lean();
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found." });
    }

    // Fetch all approved participants with registered email account
    const participants = await TripParticipant.find({ tripId, status: "approved" })
      .populate("userId", "firstName lastName email profilePhoto")
      .lean();

    const registeredUsersMap = new Map();

    for (const p of participants) {
      if (p.userId && p.userId.email && p.userId.email.trim().length > 0) {
        const uId = p.userId._id.toString();
        const fullName = `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim();
        registeredUsersMap.set(uId, {
          id: uId,
          _id: uId,
          name: (p.name && p.name.trim().length > 0) ? p.name.trim() : (fullName.length > 0 ? fullName : "Member"),
          email: p.userId.email,
          avatar: p.userId.profilePhoto || null,
          role: p.role || "traveler",
        });
      }
    }

    // Also include trip creator if registered
    if (trip.createdBy) {
      const creatorId = trip.createdBy.toString();
      if (!registeredUsersMap.has(creatorId)) {
        const creatorUser = await User.findById(trip.createdBy)
          .select("firstName lastName email profilePhoto")
          .lean();
        if (creatorUser && creatorUser.email) {
          const fullName = `${creatorUser.firstName || ""} ${creatorUser.lastName || ""}`.trim();
          registeredUsersMap.set(creatorId, {
            id: creatorId,
            _id: creatorId,
            name: fullName.length > 0 ? fullName : "Trip Leader",
            email: creatorUser.email,
            avatar: creatorUser.profilePhoto || null,
            role: "tripLeader",
          });
        }
      }
    }

    // Option-by-option and overall voted members breakdown
    const votedUsersMap = new Map();
    const optionsBreakdown = [];

    for (const opt of poll.options) {
      const optVoters = [];
      for (const vId of (opt.voterIds || [])) {
        const vIdStr = vId.toString();
        const userObj = registeredUsersMap.get(vIdStr);
        if (userObj) {
          optVoters.push(userObj);

          if (!votedUsersMap.has(vIdStr)) {
            votedUsersMap.set(vIdStr, {
              ...userObj,
              votedOptions: [opt.text],
            });
          } else {
            votedUsersMap.get(vIdStr).votedOptions.push(opt.text);
          }
        }
      }

      optionsBreakdown.push({
        id: opt._id.toString(),
        text: opt.text,
        voteCount: optVoters.length,
        voters: optVoters,
      });
    }

    // Members who have not voted yet
    const notVotedMembers = [];
    for (const [uId, userObj] of registeredUsersMap.entries()) {
      if (!votedUsersMap.has(uId)) {
        notVotedMembers.push(userObj);
      }
    }

    const votedMembers = Array.from(votedUsersMap.values());

    return res.status(200).json({
      success: true,
      data: {
        pollId: poll._id.toString(),
        question: poll.question,
        totalEligible: registeredUsersMap.size,
        totalVoted: votedMembers.length,
        totalNotVoted: notVotedMembers.length,
        options: optionsBreakdown,
        votedMembers,
        notVotedMembers,
      },
    });
  } catch (error) {
    console.error("Error in getPollVoters:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch poll voters." });
  }
};
