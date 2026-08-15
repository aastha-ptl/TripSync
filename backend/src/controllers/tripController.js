import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import crypto from "crypto";
import env from "../config/env.js";

export const createTrip = async (req, res) => {
  try {
    const { name, description, startDate, endDate, tripType } = req.body;

    if (!name || !startDate || !endDate) {
      return res.status(400).json({ success: false, message: "Name, start date, and end date are required." });
    }

    if (new Date(endDate) < new Date(startDate)) {
      return res.status(400).json({ success: false, message: "End date cannot be before start date." });
    }

    const invitationCode = crypto.randomBytes(6).toString("hex");
    let invitationLink = null;
    if (env.TRIP_JOIN_BASE_URL) {
      invitationLink = `${env.TRIP_JOIN_BASE_URL}/join/${invitationCode}`;
    }

    let coverImage = null;
    if (req.file && req.file.path) {
      coverImage = req.file.path; // Cloudinary URL provided by multer-storage-cloudinary
    }

    const newTrip = await Trip.create({
      name,
      description: description || "",
      startDate,
      endDate,
      coverImage,
      createdBy: req.user._id,
      invitationCode,
      invitationLink,
    });

    await TripParticipant.create({
      tripId: newTrip._id,
      userId: req.user._id,
      role: "tripLeader",
      status: "approved",
      joinedAt: new Date(),
      permissions: {
        manageTrip: true,
        manageParticipants: true,
        manageFamily: true,
        manageItinerary: true,
        managePolls: true,
        manageDocuments: true,
        manageExpenses: true,
        managePhotos: true,
      },
    });

    res.status(201).json({
      success: true,
      message: "Trip created successfully",
      data: {
        trip: newTrip,
        inviteToken: invitationCode,
        inviteLink: invitationLink,
      },
    });
  } catch (error) {
    console.error("Create trip error:", error);
    res.status(500).json({ success: false, message: "Server error during trip creation." });
  }
};

export const getInviteInfo = async (req, res) => {
  try {
    const { inviteToken } = req.params;
    
    const trip = await Trip.findOne({ invitationCode: inviteToken }).select("name description startDate endDate coverImage");
    
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip invitation not found or invalid." });
    }

    res.status(200).json({
      success: true,
      data: trip,
    });
  } catch (error) {
    console.error("Get invite error:", error);
    res.status(500).json({ success: false, message: "Server error fetching invitation." });
  }
};

export const joinTrip = async (req, res) => {
  try {
    const { inviteToken } = req.body;
    if (!inviteToken) {
      return res.status(400).json({ success: false, message: "Invite token is required." });
    }

    const trip = await Trip.findOne({ invitationCode: inviteToken });
    if (!trip) {
      return res.status(404).json({ success: false, message: "Invalid invite token." });
    }

    const existingParticipant = await TripParticipant.findOne({ tripId: trip._id, userId: req.user._id });
    if (existingParticipant) {
      return res.status(409).json({ success: false, message: "You are already a member of this trip." });
    }

    await TripParticipant.create({
      tripId: trip._id,
      userId: req.user._id,
      role: "familyMember", // default role
      status: "approved",
      joinedAt: new Date(),
    });

    res.status(200).json({ success: true, message: "Successfully joined the trip." });
  } catch (error) {
    console.error("Join trip error:", error);
    res.status(500).json({ success: false, message: "Server error joining trip." });
  }
};
