import Notification from "../models/Notification.js";
import Trip from "../models/Trip.js";
import { emitToUserRoom } from "../socket.js";

/**
 * Creates notifications for target users and emits real-time socket events.
 */
export const createAndSendNotification = async ({
  targetUserIds = [],
  tripId = null,
  tripName = null,
  type,
  title,
  message,
  referenceId = null,
  referenceType = null,
}) => {
  try {
    if (!targetUserIds || targetUserIds.length === 0) return [];

    let resolvedTripName = tripName;
    if (!resolvedTripName && tripId) {
      try {
        const trip = await Trip.findById(tripId).select("name title");
        if (trip) resolvedTripName = trip.name || trip.title;
      } catch (_) {}
    }

    const uniqueUserIds = Array.from(
      new Set(
        targetUserIds
          .filter((id) => id !== null && id !== undefined)
          .map((id) => id.toString())
      )
    );

    const createdNotifications = [];

    for (const userId of uniqueUserIds) {
      const notification = await Notification.create({
        userId,
        tripId,
        type,
        title,
        message,
        referenceId,
        referenceType,
        isRead: false,
      });

      const payload = {
        _id: notification._id.toString(),
        userId: userId.toString(),
        tripId: tripId ? tripId.toString() : null,
        tripName: resolvedTripName || "",
        type: notification.type,
        title: notification.title,
        message: notification.message,
        referenceId: notification.referenceId
          ? notification.referenceId.toString()
          : null,
        referenceType: notification.referenceType,
        isRead: false,
        createdAt: notification.createdAt,
      };

      // Emit real-time notification to user's personal room
      emitToUserRoom(userId, "new_notification", payload);
      createdNotifications.push(payload);
    }

    return createdNotifications;
  } catch (error) {
    console.error("[NotificationService] Error creating notification:", error);
    return [];
  }
};
