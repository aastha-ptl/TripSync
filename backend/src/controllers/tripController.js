import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import JoinRequest from "../models/JoinRequest.js";
import crypto from "crypto";
import env from "../config/env.js";
import { v2 as cloudinary } from "cloudinary";

const deleteUploadedFile = async (file) => {
  if (file && file.filename) {
    try {
      await cloudinary.uploader.destroy(file.filename);
    } catch (err) {
      console.error("Error deleting image from cloudinary:", err);
    }
  }
};

export const createTrip = async (req, res) => {
  try {
    const { name, description, startDate, endDate, tripType, cancelPendingRequest } = req.body;

    if (!name || !startDate || !endDate) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({ success: false, message: "Name, start date, and end date are required." });
    }

    if (new Date(endDate) < new Date(startDate)) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({ success: false, message: "End date cannot be before start date." });
    }

    // Check for overlapping approved trips
    const userParticipants = await TripParticipant.find({ userId: req.user._id, status: "approved" });
    const tripIds = userParticipants.map((p) => p.tripId);

    const overlappingTrip = await Trip.findOne({
      _id: { $in: tripIds },
      startDate: { $lte: new Date(endDate) },
      endDate: { $gte: new Date(startDate) },
    });

    if (overlappingTrip) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({
        success: false,
        message: "You are already part of an approved trip during these dates.",
      });
    }

    // Check for overlapping pending trips
    const pendingRequests = await JoinRequest.find({ userId: req.user._id, status: "pending" });
    const pendingTripIds = pendingRequests.map((req) => req.tripId);

    const overlappingPendingTrip = await Trip.findOne({
      _id: { $in: pendingTripIds },
      startDate: { $lte: new Date(endDate) },
      endDate: { $gte: new Date(startDate) },
    });

    if (overlappingPendingTrip) {
      if (cancelPendingRequest === 'true' || cancelPendingRequest === true) {
        await JoinRequest.deleteOne({ tripId: overlappingPendingTrip._id, userId: req.user._id, status: "pending" });
      } else {
        await deleteUploadedFile(req.file);
        return res.status(409).json({
          success: false,
          code: "PENDING_OVERLAP",
          message: "You have a pending join request for an overlapping trip.",
          tripName: overlappingPendingTrip.name,
        });
      }
    }

    const invitationCode = crypto.randomBytes(6).toString("hex");

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
        inviteToken: invitationCode
      },
    });
  } catch (error) {
    console.error("Create trip error:", error);
    await deleteUploadedFile(req.file);
    res.status(500).json({ success: false, message: "Server error during trip creation." });
  }
};

export const getUserTrips = async (req, res) => {
  try {
    const participants = await TripParticipant.find({ userId: req.user._id, status: "approved" }).populate("tripId");
    const trips = participants.map(p => ({
      ...p.tripId.toObject(),
      participantStatus: p.status,
      participantRole: p.role
    }));
    res.status(200).json({ success: true, data: trips });
  } catch (error) {
    console.error("Get user trips error:", error);
    res.status(500).json({ success: false, message: "Server error fetching trips." });
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

    const existingParticipant = await TripParticipant.findOne({ tripId: trip._id, userId: req.user._id, status: "approved" });
    if (existingParticipant) {
      return res.status(409).json({ success: false, message: "You are already a member of this trip." });
    }

    // Check for overlapping approved trips
    const userParticipants = await TripParticipant.find({ userId: req.user._id, status: "approved" });
    const tripIds = userParticipants.map((p) => p.tripId);

    const overlappingTrip = await Trip.findOne({
      _id: { $in: tripIds },
      startDate: { $lte: new Date(trip.endDate) },
      endDate: { $gte: new Date(trip.startDate) },
    });

    if (overlappingTrip) {
      return res.status(400).json({
        success: false,
        message: "You are already part of an approved trip during these dates.",
      });
    }

    const existingRequest = await JoinRequest.findOne({ tripId: trip._id, userId: req.user._id, status: "pending" });
    if (existingRequest) {
      return res.status(409).json({ success: false, message: "You already have a pending join request." });
    }

    await JoinRequest.create({
      tripId: trip._id,
      userId: req.user._id,
      requestedRole: "soloTraveler",
      requestedBy: req.user._id,
      status: "pending",
      invitationCode: inviteToken,
    });

    res.status(200).json({ success: true, message: "Join request sent successfully." });
  } catch (error) {
    console.error("Join trip error:", error);
    res.status(500).json({ success: false, message: "Server error joining trip." });
  }
};
