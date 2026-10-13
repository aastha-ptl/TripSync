import Location from "../models/Location.js";
import Trip from "../models/Trip.js";
import User from "../models/User.js";
import TripParticipant from "../models/TripParticipant.js";
import { emitToTripRoom } from "../socket.js";

// Helper to find trip by param (supporting _id, custom tripId, invitationCode)
const findTripByParam = async (tripId) => {
  if (!tripId) return null;
  const cleanId = tripId.toString().trim();
  let trip = null;
  if (/^[0-9a-fA-F]{24}$/.test(cleanId)) {
    trip = await Trip.findById(cleanId);
  }
  if (!trip) {
    trip = await Trip.findOne({ tripId: cleanId });
  }
  if (!trip) {
    trip = await Trip.findOne({ invitationCode: cleanId });
  }
  return trip;
};

/**
 * GET /api/trips/:tripId/locations
 * Returns active live locations of members who have enabled sharing,
 * plus any bookmarked/pinned trip locations.
 */
export const getTripLocations = async (req, res) => {
  try {
    const { tripId } = req.params;
    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const locations = await Location.find({
      tripId: trip._id,
      $or: [{ isSharing: true }, { userId: req.user._id }],
    })
      .populate("userId", "firstName lastName profilePhoto phone email")
      .sort({ updatedAt: -1 });

    res.status(200).json({
      success: true,
      data: locations,
    });
  } catch (error) {
    console.error("Error fetching trip locations:", error);
    res.status(500).json({ success: false, message: "Failed to fetch locations", error: error.message });
  }
};

/**
 * POST /api/trips/:tripId/locations/update
 * Updates current user's live location and broadcast via socket
 */
export const updateMyLocation = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { latitude, longitude, isSharing, name, address, accuracy } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({ success: false, message: "Latitude and longitude are required" });
    }

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    let location = await Location.findOne({
      tripId: trip._id,
      userId: req.user._id,
      type: "live",
    });

    if (!location) {
      location = new Location({
        tripId: trip._id,
        userId: req.user._id,
        type: "live",
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        isSharing: isSharing !== undefined ? Boolean(isSharing) : true,
        name: name || "",
        address: address || "",
        accuracy: accuracy ? parseFloat(accuracy) : null,
        timestamp: new Date(),
      });
    } else {
      location.latitude = parseFloat(latitude);
      location.longitude = parseFloat(longitude);
      if (isSharing !== undefined) location.isSharing = Boolean(isSharing);
      if (name !== undefined) location.name = name;
      if (address !== undefined) location.address = address;
      if (accuracy !== undefined) location.accuracy = parseFloat(accuracy);
      location.timestamp = new Date();
    }

    await location.save();
    await location.populate("userId", "firstName lastName profilePhoto phone email");

    // Broadcast live location to trip room
    emitToTripRoom(trip._id.toString(), "member_location_updated", location);
    if (tripId && tripId.toString() !== trip._id.toString()) {
      emitToTripRoom(tripId.toString(), "member_location_updated", location);
    }

    res.status(200).json({
      success: true,
      data: location,
      message: "Location updated successfully",
    });
  } catch (error) {
    console.error("Error updating location:", error);
    res.status(500).json({ success: false, message: "Failed to update location", error: error.message });
  }
};

/**
 * POST /api/trips/:tripId/locations/toggle-sharing
 * Toggles location sharing permission for current user
 */
export const toggleLocationSharing = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { isSharing } = req.body;

    const trip = await findTripByParam(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const sharingState = Boolean(isSharing);

    let location = await Location.findOne({
      tripId: trip._id,
      userId: req.user._id,
      type: "live",
    });

    if (!location) {
      location = new Location({
        tripId: trip._id,
        userId: req.user._id,
        type: "live",
        latitude: req.body.latitude ? parseFloat(req.body.latitude) : 0,
        longitude: req.body.longitude ? parseFloat(req.body.longitude) : 0,
        isSharing: sharingState,
        timestamp: new Date(),
      });
    } else {
      location.isSharing = sharingState;
      if (req.body.latitude !== undefined) location.latitude = parseFloat(req.body.latitude);
      if (req.body.longitude !== undefined) location.longitude = parseFloat(req.body.longitude);
      location.timestamp = new Date();
    }

    await location.save();
    await location.populate("userId", "firstName lastName profilePhoto phone email");

    emitToTripRoom(trip._id.toString(), "member_location_sharing_toggled", {
      userId: req.user._id.toString(),
      isSharing: sharingState,
      location,
    });
    if (tripId && tripId.toString() !== trip._id.toString()) {
      emitToTripRoom(tripId.toString(), "member_location_sharing_toggled", {
        userId: req.user._id.toString(),
        isSharing: sharingState,
        location,
      });
    }

    res.status(200).json({
      success: true,
      data: { isSharing: sharingState, location },
      message: sharingState ? "Location sharing enabled" : "Location sharing disabled",
    });
  } catch (error) {
    console.error("Error toggling location sharing:", error);
    res.status(500).json({ success: false, message: "Failed to toggle location sharing", error: error.message });
  }
};
