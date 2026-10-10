import mongoose from "mongoose";
import ChatMessage from "../models/ChatMessage.js";
import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import { emitToTripRoom } from "../socket.js";
import { createAndSendNotification } from "../services/notificationService.js";



/**
 * Flexible trip resolver: resolves by ObjectId, name, or invitation code
 */
const findTripByParam = async (tripIdParam) => {
  if (!tripIdParam) return null;

  if (mongoose.Types.ObjectId.isValid(tripIdParam)) {
    const trip = await Trip.findById(tripIdParam);
    if (trip) return trip;
  }

  const cleanName = decodeURIComponent(tripIdParam).trim();
  const tripByName = await Trip.findOne({
    $or: [
      { name: new RegExp(`^${cleanName}$`, "i") },
      { invitationCode: cleanName },
    ],
  });
  if (tripByName) return tripByName;

  return await Trip.findOne().sort({ createdAt: -1 });
};

/**
 * Check if a user is the trip leader for a resolved trip
 */
const isUserTripLeader = async (trip, userId) => {
  if (!trip) return false;

  if (trip.createdBy.toString() === userId.toString()) {
    return true;
  }

  const participant = await TripParticipant.findOne({
    tripId: trip._id,
    userId,
    status: "approved",
  });

  if (participant && participant.role === "tripLeader") {
    return true;
  }

  return false;
};

/**
 * GET /api/trips/:tripId/chat/announcements
 * Fetch all announcements for a trip
 */
export const getAnnouncements = async (req, res) => {
  try {
    const { tripId } = req.params;
    const trip = await findTripByParam(tripId);

    if (!trip) {
      return res.status(200).json({
        success: true,
        data: [],
        message: "Trip not found",
      });
    }

    const announcements = await ChatMessage.find({
      tripId: trip._id,
      chatType: "announcement",
      isDeleted: false,
    })
      .populate("senderId", "firstName lastName name profilePhoto role email")
      .sort({ createdAt: 1 });

    const formattedAnnouncements = announcements.map((msg) => {
      const sender = msg.senderId || {};
      const firstName = sender.firstName || "";
      const lastName = sender.lastName || "";
      let fullName = `${firstName} ${lastName}`.trim();
      if (!fullName && sender.name) fullName = sender.name;
      if (!fullName) fullName = "Trip Leader";

      const currentUserId = req.user._id.toString();
      const senderIdStr = sender._id ? sender._id.toString() : "";

      return {
        id: msg._id.toString(),
        tripId: trip._id.toString(),
        senderId: senderIdStr,
        senderName: fullName,
        senderAvatar: sender.profilePhoto || "",
        senderRole: sender.role || "tripLeader",
        content: msg.message,
        timestamp: msg.createdAt,
        type: "announcement",
        messageType: msg.messageType,
        fileUrl: msg.fileUrl,
        fileName: msg.fileName,
        isMe: senderIdStr === currentUserId,
        isLeader: true,
      };
    });

    return res.status(200).json({
      success: true,
      data: formattedAnnouncements,
    });
  } catch (error) {
    console.error("Error fetching announcements:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch announcements",
      error: error.message,
    });
  }
};

/**
 * POST /api/trips/:tripId/chat/announcements
 * Post a new announcement for a trip (Trip Leader only)
 */
export const createAnnouncement = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { message, messageType = "text", fileUrl, fileName } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: "Announcement message content is required",
      });
    }

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: "Trip not found",
      });
    }

    const canCreate = await isUserTripLeader(trip, req.user._id);
    if (!canCreate) {
      return res.status(403).json({
        success: false,
        message: "Only the Trip Leader can send announcements!",
      });
    }

    const newAnnouncement = await ChatMessage.create({
      tripId: trip._id,
      chatType: "announcement",
      senderId: req.user._id,
      messageType,
      message: message.trim(),
      fileUrl: fileUrl || null,
      fileName: fileName || null,
    });

    await newAnnouncement.populate(
      "senderId",
      "firstName lastName name profilePhoto role email"
    );

    const sender = newAnnouncement.senderId || {};
    const firstName = sender.firstName || "";
    const lastName = sender.lastName || "";
    let fullName = `${firstName} ${lastName}`.trim();
    if (!fullName && sender.name) fullName = sender.name;
    if (!fullName) fullName = "Trip Leader";

    const formattedAnnouncement = {
      id: newAnnouncement._id.toString(),
      tripId: trip._id.toString(),
      senderId: sender._id ? sender._id.toString() : req.user._id.toString(),
      senderName: fullName,
      senderAvatar: sender.profilePhoto || "",
      senderRole: sender.role || "tripLeader",
      content: newAnnouncement.message,
      timestamp: newAnnouncement.createdAt,
      type: "announcement",
      messageType: newAnnouncement.messageType,
      fileUrl: newAnnouncement.fileUrl,
      fileName: newAnnouncement.fileName,
      isMe: true,
      isLeader: true,
    };

    emitToTripRoom(trip._id.toString(), "new_announcement", formattedAnnouncement);

    try {
      const participants = await TripParticipant.find({ tripId: trip._id, status: "approved" });
      const targetUserIds = participants
        .map((p) => p.userId ? p.userId.toString() : null)
        .filter((id) => id && id !== req.user._id.toString());

      if (trip.createdBy && trip.createdBy.toString() !== req.user._id.toString() && !targetUserIds.includes(trip.createdBy.toString())) {
        targetUserIds.push(trip.createdBy.toString());
      }


      await createAndSendNotification({
        targetUserIds,
        tripId: trip._id,
        type: "announcement",
        title: `Announcement in ${trip.name || "Trip"}`,
        message: `${fullName || "Trip Leader"}: ${newAnnouncement.message}`,
        referenceId: newAnnouncement._id,
        referenceType: "ChatMessage",
      });
    } catch (notifErr) {
      console.error("Error creating announcement notification:", notifErr);
    }


    return res.status(201).json({
      success: true,
      message: "Announcement posted successfully",
      data: formattedAnnouncement,
    });


  } catch (error) {
    console.error("Error posting announcement:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to post announcement",
      error: error.message,
    });
  }
};

/**
 * GET /api/trips/:tripId/chat/messages
 * Fetch all group chat messages for a trip
 */
export const getGroupMessages = async (req, res) => {
  try {
    const { tripId } = req.params;
    const trip = await findTripByParam(tripId);

    if (!trip) {
      return res.status(200).json({
        success: true,
        data: [],
        message: "Trip not found",
      });
    }

    const messages = await ChatMessage.find({
      tripId: trip._id,
      chatType: "group",
      isDeleted: false,
    })
      .populate("senderId", "firstName lastName name profilePhoto role email")
      .sort({ createdAt: 1 });

    const formattedMessages = messages.map((msg) => {
      const sender = msg.senderId || {};
      const firstName = sender.firstName || "";
      const lastName = sender.lastName || "";
      let fullName = `${firstName} ${lastName}`.trim();
      if (!fullName && sender.name) fullName = sender.name;
      if (!fullName) fullName = "User";

      const currentUserId = req.user._id.toString();
      const senderIdStr = sender._id ? sender._id.toString() : "";

      return {
        id: msg._id.toString(),
        tripId: trip._id.toString(),
        senderId: senderIdStr,
        senderName: fullName,
        senderAvatar: sender.profilePhoto || "",
        senderRole: sender.role || "member",
        content: msg.message,
        timestamp: msg.createdAt,
        type: msg.messageType || "text",
        messageType: msg.messageType,
        fileUrl: msg.fileUrl,
        fileName: msg.fileName,
        isMe: senderIdStr === currentUserId,
      };
    });

    return res.status(200).json({
      success: true,
      data: formattedMessages,
    });
  } catch (error) {
    console.error("Error fetching group messages:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch group messages",
      error: error.message,
    });
  }
};

/**
 * POST /api/trips/:tripId/chat/messages
 * Send a new group message
 */
export const sendGroupMessage = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { message, messageType = "text", fileUrl, fileName } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: "Message content is required",
      });
    }

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: "Trip not found",
      });
    }

    const newMsg = await ChatMessage.create({
      tripId: trip._id,
      chatType: "group",
      senderId: req.user._id,
      messageType,
      message: message.trim(),
      fileUrl: fileUrl || null,
      fileName: fileName || null,
    });

    await newMsg.populate(
      "senderId",
      "firstName lastName name profilePhoto role email"
    );

    const sender = newMsg.senderId || {};
    const firstName = sender.firstName || "";
    const lastName = sender.lastName || "";
    let fullName = `${firstName} ${lastName}`.trim();
    if (!fullName && sender.name) fullName = sender.name;
    if (!fullName) fullName = "User";

    const formattedMessage = {
      id: newMsg._id.toString(),
      tripId: trip._id.toString(),
      senderId: sender._id ? sender._id.toString() : req.user._id.toString(),
      senderName: fullName,
      senderAvatar: sender.profilePhoto || "",
      senderRole: sender.role || "member",
      content: newMsg.message,
      timestamp: newMsg.createdAt,
      type: newMsg.messageType || "text",
      messageType: newMsg.messageType,
      fileUrl: newMsg.fileUrl,
      fileName: newMsg.fileName,
      isMe: true,
    };

    emitToTripRoom(trip._id.toString(), "new_group_message", formattedMessage);

    try {
      const participants = await TripParticipant.find({ tripId: trip._id, status: "approved" });
      const targetUserIds = participants
        .map((p) => p.userId ? p.userId.toString() : null)
        .filter((id) => id && id !== req.user._id.toString());

      if (trip.createdBy && trip.createdBy.toString() !== req.user._id.toString() && !targetUserIds.includes(trip.createdBy.toString())) {
        targetUserIds.push(trip.createdBy.toString());
      }


      await createAndSendNotification({
        targetUserIds,
        tripId: trip._id,
        type: "newMessage",
        title: `Chat in ${trip.name || "Trip"}`,
        message: `${fullName || "A member"}: ${newMsg.message}`,
        referenceId: newMsg._id,
        referenceType: "ChatMessage",
      });
    } catch (notifErr) {
      console.error("Error creating chat notification:", notifErr);
    }


    return res.status(201).json({
      success: true,
      message: "Message sent successfully",
      data: formattedMessage,
    });


  } catch (error) {
    console.error("Error sending message:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to send message",
      error: error.message,
    });
  }
};
