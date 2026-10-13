import ItineraryDay from "../models/ItineraryDay.js";
import Activity from "../models/Activity.js";
import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import { createAndSendNotification } from "../services/notificationService.js";
import { emitToTripRoom } from "../socket.js";


export const addActivity = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { title, description, date, time, location, type, cost, notes } = req.body;

    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id });
    if (!participant || participant.status === "removed" || participant.status === "left") {
      return res.status(403).json({ success: false, message: "You have left or been removed from this trip and cannot add activities." });
    }

    const targetDateStr = date.split('T')[0];
    const targetDate = new Date(`${targetDateStr}T00:00:00Z`);

    // Calculate day number based on trip start date
    const tripStartStr = trip.startDate.split('T')[0];
    const tripStart = new Date(`${tripStartStr}T00:00:00Z`);
    
    const diffTime = targetDate.getTime() - tripStart.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
    const dayNumber = diffDays > 0 ? diffDays : 1;

    // Find or create ItineraryDay
    let itineraryDay = await ItineraryDay.findOne({ tripId, date: targetDate });
    if (!itineraryDay) {
      itineraryDay = new ItineraryDay({
        tripId,
        dayNumber,
        date: targetDate,
        title: `Day ${dayNumber}`,
        createdBy: req.user._id,
      });
      await itineraryDay.save();
    }

    // Handle time properly
    let startTime = null;
    if (time) {
      // time might be coming as "HH:mm AM/PM" or just "HH:mm" from frontend
      // For simplicity let's store it as Date object combining targetDate and time
      // Or we can just store the string if we added a string field, but Activity schema has startTime as Date
      const timeParts = time.match(/(\d+):(\d+)\s*(AM|PM)?/i);
      if (timeParts) {
        let hours = parseInt(timeParts[1], 10);
        const minutes = parseInt(timeParts[2], 10);
        const ampm = timeParts[3];
        if (ampm && ampm.toUpperCase() === 'PM' && hours < 12) hours += 12;
        if (ampm && ampm.toUpperCase() === 'AM' && hours === 12) hours = 0;
        
        startTime = new Date(targetDate);
        startTime.setHours(hours, minutes, 0, 0);
      }
    }

    // Check for conflicting activity at the same time on the same day
    if (startTime) {
      const startRange = new Date(startTime.getTime());
      const endRange = new Date(startTime.getTime() + 59999);
      const conflictingActivity = await Activity.findOne({
        tripId,
        itineraryDayId: itineraryDay._id,
        startTime: { $gte: startRange, $lte: endRange },
      });

      if (conflictingActivity) {
        return res.status(409).json({
          success: false,
          conflict: true,
          message: `An event "${conflictingActivity.title}" is already scheduled at ${time}.`,
          conflictingActivity: {
            _id: conflictingActivity._id,
            title: conflictingActivity.title,
            time: time,
            location: conflictingActivity.location?.name || "",
          },
        });
      }
    }

    // Create the Activity
    let locationName = "";
    let locationAddress = "";
    let locationLat = null;
    let locationLng = null;

    if (typeof location === "object" && location !== null) {
      locationName = location.name || "";
      locationAddress = location.address || "";
      locationLat = location.latitude !== undefined && location.latitude !== null ? parseFloat(location.latitude) : null;
      locationLng = location.longitude !== undefined && location.longitude !== null ? parseFloat(location.longitude) : null;
    } else if (typeof location === "string") {
      locationName = location;
      locationAddress = req.body.address || "";
      locationLat = req.body.latitude !== undefined && req.body.latitude !== null ? parseFloat(req.body.latitude) : null;
      locationLng = req.body.longitude !== undefined && req.body.longitude !== null ? parseFloat(req.body.longitude) : null;
    }

    const activity = new Activity({
      tripId,
      itineraryDayId: itineraryDay._id,
      title,
      description: description || notes,
      type: type || "other",
      startTime,
      location: {
        name: locationName,
        address: locationAddress,
        latitude: locationLat,
        longitude: locationLng,
      },
      estimatedCost: cost ? parseFloat(cost.toString().replace(/[^0-9.-]+/g,"")) || 0 : 0,
      createdBy: req.user._id,
      status: "planned",
    });

    await activity.save();

    // Send notifications to trip participants
    try {
      const participants = await TripParticipant.find({ tripId, status: "approved" });
      const targetUserIds = participants
        .map((p) => p.userId ? p.userId.toString() : null)
        .filter((id) => id && id !== req.user._id.toString());

      if (trip.createdBy && trip.createdBy.toString() !== req.user._id.toString() && !targetUserIds.includes(trip.createdBy.toString())) {
        targetUserIds.push(trip.createdBy.toString());
      }



      const userName = req.user.firstName ? `${req.user.firstName} ${req.user.lastName || ''}`.trim() : (req.user.name || "A member");
      await createAndSendNotification({
        targetUserIds,
        tripId,
        type: "itineraryUpdate",
        title: "New Itinerary Activity",
        message: `${userName} added "${activity.title}" to the trip itinerary.`,
        referenceId: activity._id,
        referenceType: "Activity",
        metadata: {
          dayNumber: itineraryDay.dayNumber,
          date: itineraryDay.date,
          activityId: activity._id.toString(),
        },
      });

      emitToTripRoom(tripId, "itinerary_updated", {
        tripId,
        activity,
        itineraryDay,
      });
    } catch (notifErr) {
      console.error("Failed to send itinerary notification:", notifErr);
    }

    res.status(201).json({
      success: true,
      data: {
        itineraryDay,
        activity,
      },
      message: "Activity added to itinerary",
    });
  } catch (error) {
    console.error("Error adding activity:", error);
    res.status(500).json({ success: false, message: "Failed to add activity" });
  }
};


export const getItinerary = async (req, res) => {
  try {
    const { tripId } = req.params;

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id });
    const isRemoved = participant && (participant.status === "removed" || participant.status === "left");
    const leftAt = isRemoved ? (participant.leftAt || participant.updatedAt) : null;

    const actQuery = { tripId };
    if (leftAt) {
      actQuery.createdAt = { $lte: leftAt };
    }

    const days = await ItineraryDay.find({ tripId }).sort({ date: 1 }).lean();
    const activities = await Activity.find(actQuery).sort({ startTime: 1 }).lean();

    // Group activities by itineraryDayId
    const activitiesByDay = {};
    activities.forEach((act) => {
      const dayId = act.itineraryDayId.toString();
      if (!activitiesByDay[dayId]) activitiesByDay[dayId] = [];
      activitiesByDay[dayId].push(act);
    });

    const itinerary = days.map((day) => ({
      ...day,
      activities: activitiesByDay[day._id.toString()] || [],
    }));

    res.status(200).json({
      success: true,
      data: itinerary,
    });
  } catch (error) {
    console.error("Error fetching itinerary:", error);
    res.status(500).json({ success: false, message: "Failed to fetch itinerary" });
  }
};

export const updateActivity = async (req, res) => {
  try {
    const { tripId, activityId } = req.params;
    const { title, description, date, time, location, type, cost, notes } = req.body;

    const activity = await Activity.findById(activityId);
    if (!activity) {
      return res.status(404).json({ success: false, message: "Activity not found" });
    }

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id });
    if (!participant || participant.status === "removed" || participant.status === "left") {
      return res.status(403).json({ success: false, message: "You have left or been removed from this trip and cannot edit activities." });
    }

    if (activity.tripId.toString() !== tripId) {
      return res.status(400).json({ success: false, message: "Activity does not belong to this trip" });
    }

    // Handle date change
    const targetDateStr = date.split('T')[0];
    const targetDate = new Date(`${targetDateStr}T00:00:00Z`);

    const trip = await Trip.findById(tripId);
    const tripStartStr = trip.startDate.split('T')[0];
    const tripStart = new Date(`${tripStartStr}T00:00:00Z`);
    
    const diffTime = targetDate.getTime() - tripStart.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
    const dayNumber = diffDays > 0 ? diffDays : 1;

    let itineraryDay = await ItineraryDay.findOne({ tripId, date: targetDate });
    if (!itineraryDay) {
      itineraryDay = new ItineraryDay({
        tripId,
        dayNumber,
        date: targetDate,
        title: `Day ${dayNumber}`,
        createdBy: req.user._id,
      });
      await itineraryDay.save();
    }

    let startTime = null;
    if (time) {
      const timeParts = time.match(/(\d+):(\d+)\s*(AM|PM)?/i);
      if (timeParts) {
        let hours = parseInt(timeParts[1], 10);
        const minutes = parseInt(timeParts[2], 10);
        const ampm = timeParts[3];
        if (ampm && ampm.toUpperCase() === 'PM' && hours < 12) hours += 12;
        if (ampm && ampm.toUpperCase() === 'AM' && hours === 12) hours = 0;
        
        startTime = new Date(targetDate);
        startTime.setHours(hours, minutes, 0, 0);
      }
    }

    // Check for conflicting activity at the same time on the same day
    const effectiveStartTime = startTime || activity.startTime;
    if (effectiveStartTime) {
      const startRange = new Date(effectiveStartTime.getTime());
      const endRange = new Date(effectiveStartTime.getTime() + 59999);
      const conflictingActivity = await Activity.findOne({
        _id: { $ne: activityId },
        tripId,
        itineraryDayId: itineraryDay._id,
        startTime: { $gte: startRange, $lte: endRange },
      });

      if (conflictingActivity) {
        return res.status(409).json({
          success: false,
          conflict: true,
          message: `An event "${conflictingActivity.title}" is already scheduled at ${time || "this time"}.`,
          conflictingActivity: {
            _id: conflictingActivity._id,
            title: conflictingActivity.title,
            time: time || "",
            location: conflictingActivity.location?.name || "",
          },
        });
      }
    }

    activity.title = title || activity.title;
    activity.description = description || notes || activity.description;
    activity.type = type || activity.type;
    activity.startTime = startTime || activity.startTime;
    if (req.body.status) {
      activity.status = req.body.status;
    }
    if (location !== undefined) {
      if (typeof location === "object" && location !== null) {
        activity.location.name = location.name || "";
        if (location.address !== undefined) activity.location.address = location.address;
        if (location.latitude !== undefined) activity.location.latitude = location.latitude !== null ? parseFloat(location.latitude) : null;
        if (location.longitude !== undefined) activity.location.longitude = location.longitude !== null ? parseFloat(location.longitude) : null;
      } else {
        activity.location.name = location;
      }
    }
    if (req.body.address !== undefined) activity.location.address = req.body.address;
    if (req.body.latitude !== undefined) activity.location.latitude = req.body.latitude !== null ? parseFloat(req.body.latitude) : null;
    if (req.body.longitude !== undefined) activity.location.longitude = req.body.longitude !== null ? parseFloat(req.body.longitude) : null;
    if (cost !== undefined) {
      activity.estimatedCost = parseFloat(cost.toString().replace(/[^0-9.-]+/g,"")) || 0;
    }
    activity.itineraryDayId = itineraryDay._id;

    await activity.save();

    // Send notifications to trip participants
    try {
      const participants = await TripParticipant.find({ tripId, status: "approved" });
      const targetUserIds = participants
        .map((p) => (p.userId ? p.userId.toString() : null))
        .filter((id) => id && id !== req.user._id.toString());

      if (
        trip.createdBy &&
        trip.createdBy.toString() !== req.user._id.toString() &&
        !targetUserIds.includes(trip.createdBy.toString())
      ) {
        targetUserIds.push(trip.createdBy.toString());
      }

      const userName = req.user.firstName
        ? `${req.user.firstName} ${req.user.lastName || ""}`.trim()
        : req.user.name || "A member";

      await createAndSendNotification({
        targetUserIds,
        tripId,
        type: "itineraryUpdate",
        title: "Itinerary Activity Updated",
        message: `${userName} updated "${activity.title}" in the trip itinerary.`,
        referenceId: activity._id,
        referenceType: "Activity",
        metadata: {
          dayNumber: itineraryDay.dayNumber,
          date: itineraryDay.date,
          activityId: activity._id.toString(),
        },
      });
    } catch (notifErr) {
      console.error("Failed to send itinerary update notification:", notifErr);
    }

    // Broadcast to trip room so maps and itinerary sync in real-time
    emitToTripRoom(tripId, "itinerary_updated", {
      tripId,
      activity,
      itineraryDay,
    });

    res.status(200).json({ success: true, data: activity, message: "Activity updated" });
  } catch (error) {
    console.error("Error updating activity:", error);
    res.status(500).json({ success: false, message: "Failed to update activity" });
  }
};

export const deleteActivity = async (req, res) => {
  try {
    const { tripId, activityId } = req.params;

    const activity = await Activity.findById(activityId);
    if (!activity) {
      return res.status(404).json({ success: false, message: "Activity not found" });
    }

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id });
    if (!participant || participant.status === "removed" || participant.status === "left") {
      return res.status(403).json({ success: false, message: "You have left or been removed from this trip and cannot delete activities." });
    }

    if (activity.tripId.toString() !== tripId) {
      return res.status(400).json({ success: false, message: "Activity does not belong to this trip" });
    }

    await activity.deleteOne();

    // Broadcast to trip room so maps and itinerary sync in real-time
    emitToTripRoom(tripId, "itinerary_deleted", {
      tripId,
      activityId,
    });

    res.status(200).json({ success: true, message: "Activity deleted" });
  } catch (error) {
    console.error("Error deleting activity:", error);
    res.status(500).json({ success: false, message: "Failed to delete activity" });
  }
};

