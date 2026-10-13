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

    const participant = await TripParticipant.findOne({ tripId: trip._id, userId: req.user._id });
    const announcementQuery = {
      tripId: trip._id,
      chatType: "announcement",
      isDeleted: false,
      deletedByUsers: { $ne: req.user._id },
    };

    if (participant && (participant.status === "removed" || participant.status === "left")) {
      const leftAt = participant.leftAt || participant.updatedAt;
      if (leftAt) {
        announcementQuery.createdAt = { $lte: leftAt };
      }
    }

    const announcements = await ChatMessage.find(announcementQuery)
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
        isEdited: msg.isEdited === true,
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
      readBy: [{ userId: req.user._id, readAt: new Date() }],
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
      isEdited: false,
    };

    const broadcastAnnouncement = {
      ...formattedAnnouncement,
      isMe: false,
    };

    emitToTripRoom(trip._id.toString(), "new_announcement", broadcastAnnouncement);
    if (tripId && tripId.toString() !== trip._id.toString()) {
      emitToTripRoom(tripId.toString(), "new_announcement", broadcastAnnouncement);
    }

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

    const participant = await TripParticipant.findOne({ tripId: trip._id, userId: req.user._id });
    const msgQuery = {
      tripId: trip._id,
      chatType: "group",
      isDeleted: false,
      deletedByUsers: { $ne: req.user._id },
    };

    if (participant && (participant.status === "removed" || participant.status === "left")) {
      const leftAt = participant.leftAt || participant.updatedAt;
      if (leftAt) {
        msgQuery.createdAt = { $lte: leftAt };
      }
    }

    const messages = await ChatMessage.find(msgQuery)
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
        isEdited: msg.isEdited === true,
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

    const participant = await TripParticipant.findOne({ tripId: trip._id, userId: req.user._id });
    if (!participant || participant.status === "removed" || participant.status === "left") {
      return res.status(403).json({
        success: false,
        message: "You have left or been removed from this trip and cannot send messages.",
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
      readBy: [{ userId: req.user._id, readAt: new Date() }],
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
      isEdited: false,
    };

    const broadcastMessage = {
      ...formattedMessage,
      isMe: false,
    };

    emitToTripRoom(trip._id.toString(), "new_group_message", broadcastMessage);
    if (tripId && tripId.toString() !== trip._id.toString()) {
      emitToTripRoom(tripId.toString(), "new_group_message", broadcastMessage);
    }

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

/**
 * PUT /api/trips/:tripId/chat/messages/:messageId
 * Edit a chat message (Only the sender can edit)
 */
export const editMessage = async (req, res) => {
  try {
    const { tripId, messageId } = req.params;
    const { message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: "Message content cannot be empty",
      });
    }

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: "Trip not found",
      });
    }

    const chatMsg = await ChatMessage.findOne({
      _id: messageId,
      tripId: trip._id,
      isDeleted: false,
    });

    if (!chatMsg) {
      return res.status(404).json({
        success: false,
        message: "Message not found",
      });
    }

    // Only original sender can edit
    if (chatMsg.senderId.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only edit your own messages",
      });
    }

    chatMsg.message = message.trim();
    chatMsg.isEdited = true;
    await chatMsg.save();

    const editPayload = {
      id: chatMsg._id.toString(),
      tripId: trip._id.toString(),
      content: chatMsg.message,
      isEdited: true,
      updatedAt: chatMsg.updatedAt,
    };

    emitToTripRoom(trip._id.toString(), "message_edited", editPayload);
    if (tripId && tripId.toString() !== trip._id.toString()) {
      emitToTripRoom(tripId.toString(), "message_edited", editPayload);
    }

    return res.status(200).json({
      success: true,
      message: "Message edited successfully",
      data: editPayload,
    });
  } catch (error) {
    console.error("Error editing message:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to edit message",
      error: error.message,
    });
  }
};

/**
 * POST /api/trips/:tripId/chat/messages/delete
 * Delete messages (Delete for me OR Delete for everyone)
 */
export const deleteMessages = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { messageIds, deleteType } = req.body;

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Message IDs array is required",
      });
    }

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: "Trip not found",
      });
    }

    if (deleteType === "forEveryone") {
      const isLeader = await isUserTripLeader(trip, req.user._id);

      // If not trip leader, verify that all messages belong to current user
      if (!isLeader) {
        const otherMessages = await ChatMessage.countDocuments({
          _id: { $in: messageIds },
          tripId: trip._id,
          senderId: { $ne: req.user._id },
        });

        if (otherMessages > 0) {
          return res.status(403).json({
            success: false,
            message: "You can only delete your own messages for everyone",
          });
        }
      }

      await ChatMessage.updateMany(
        { _id: { $in: messageIds }, tripId: trip._id },
        { $set: { isDeleted: true } }
      );

      const deletePayload = {
        tripId: trip._id.toString(),
        messageIds: messageIds.map((id) => id.toString()),
      };

      emitToTripRoom(trip._id.toString(), "messages_deleted_for_everyone", deletePayload);
      if (tripId && tripId.toString() !== trip._id.toString()) {
        emitToTripRoom(tripId.toString(), "messages_deleted_for_everyone", deletePayload);
      }

      return res.status(200).json({
        success: true,
        message: "Messages deleted for everyone",
        data: deletePayload,
      });
    } else if (deleteType === "forMe") {
      await ChatMessage.updateMany(
        { _id: { $in: messageIds }, tripId: trip._id },
        { $addToSet: { deletedByUsers: req.user._id } }
      );

      return res.status(200).json({
        success: true,
        message: "Messages deleted for me",
        data: { messageIds: messageIds.map((id) => id.toString()) },
      });
    } else {
      return res.status(400).json({
        success: false,
        message: "Invalid deleteType. Must be 'forEveryone' or 'forMe'",
      });
    }
  } catch (error) {
    console.error("Error deleting messages:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to delete messages",
      error: error.message,
    });
  }
};

/**
 * GET /api/trips/:tripId/chat/unread-count
 * Returns total unread count for announcements + group chat combined
 */
export const getUnreadCount = async (req, res) => {
  try {
    const { tripId } = req.params;
    const currentUserId = req.user._id;

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const unreadCount = await ChatMessage.countDocuments({
      tripId: trip._id,
      chatType: { $in: ["announcement", "group"] },
      isDeleted: false,
      senderId: { $ne: currentUserId },
      deletedByUsers: { $ne: currentUserId },
      "readBy.userId": { $ne: currentUserId },
    });

    const announcementUnread = await ChatMessage.countDocuments({
      tripId: trip._id,
      chatType: "announcement",
      isDeleted: false,
      senderId: { $ne: currentUserId },
      deletedByUsers: { $ne: currentUserId },
      "readBy.userId": { $ne: currentUserId },
    });

    const groupUnread = await ChatMessage.countDocuments({
      tripId: trip._id,
      chatType: "group",
      isDeleted: false,
      senderId: { $ne: currentUserId },
      deletedByUsers: { $ne: currentUserId },
      "readBy.userId": { $ne: currentUserId },
    });

    return res.status(200).json({
      success: true,
      data: {
        total: unreadCount,
        announcement: announcementUnread,
        group: groupUnread,
      },
    });
  } catch (error) {
    console.error("Error getting unread count:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to get unread count",
      error: error.message,
    });
  }
};

/**
 * POST /api/trips/:tripId/chat/mark-read
 * Marks announcements and/or group messages as read for current user
 */
export const markMessagesAsRead = async (req, res) => {
  try {
    const { tripId } = req.params;
    const currentUserId = req.user._id;
    const { chatType } = req.body || {};

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const query = {
      tripId: trip._id,
      isDeleted: false,
      senderId: { $ne: currentUserId },
      deletedByUsers: { $ne: currentUserId },
      "readBy.userId": { $ne: currentUserId },
    };

    if (chatType) {
      query.chatType = chatType;
    } else {
      query.chatType = { $in: ["announcement", "group"] };
    }

    await ChatMessage.updateMany(query, {
      $push: {
        readBy: {
          userId: currentUserId,
          readAt: new Date(),
        },
      },
    });

    return res.status(200).json({
      success: true,
      message: "Messages marked as read",
    });
  } catch (error) {
    console.error("Error marking messages as read:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to mark messages as read",
      error: error.message,
    });
  }
};
