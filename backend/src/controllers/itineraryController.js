import ItineraryDay from "../models/ItineraryDay.js";
import Activity from "../models/Activity.js";
import Trip from "../models/Trip.js";

export const addActivity = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { title, description, date, time, location, type, cost, notes } = req.body;

    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
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

    // Create the Activity
    const activity = new Activity({
      tripId,
      itineraryDayId: itineraryDay._id,
      title,
      description: description || notes,
      type: type || "other",
      startTime,
      location: {
        name: location || "",
        address: "",
      },
      estimatedCost: cost ? parseFloat(cost.toString().replace(/[^0-9.-]+/g,"")) || 0 : 0,
      createdBy: req.user._id,
      status: "planned",
    });

    await activity.save();

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

    const days = await ItineraryDay.find({ tripId }).sort({ date: 1 }).lean();
    const activities = await Activity.find({ tripId }).sort({ startTime: 1 }).lean();

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

    activity.title = title || activity.title;
    activity.description = description || notes || activity.description;
    activity.type = type || activity.type;
    activity.startTime = startTime || activity.startTime;
    if (location !== undefined) {
      activity.location.name = location;
    }
    if (cost !== undefined) {
      activity.estimatedCost = parseFloat(cost.toString().replace(/[^0-9.-]+/g,"")) || 0;
    }
    activity.itineraryDayId = itineraryDay._id;

    await activity.save();

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

    if (activity.tripId.toString() !== tripId) {
      return res.status(400).json({ success: false, message: "Activity does not belong to this trip" });
    }

    await activity.deleteOne();
    res.status(200).json({ success: true, message: "Activity deleted" });
  } catch (error) {
    console.error("Error deleting activity:", error);
    res.status(500).json({ success: false, message: "Failed to delete activity" });
  }
};
