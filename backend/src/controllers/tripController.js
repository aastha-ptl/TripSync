import Trip from "../models/Trip.js";
import TripParticipant from "../models/TripParticipant.js";
import JoinRequest from "../models/JoinRequest.js";
import User from "../models/User.js";
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
    const { name, description, startDate, endDate, tripType, businessTripType, cancelPendingRequest } = req.body;

    if (!name || !startDate || !endDate || !tripType) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({ success: false, message: "Name, start date, end date, and trip type are required." });
    }

    if (tripType === "Business" && !businessTripType) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({ success: false, message: "Business Trip Type is required." });
    }

    if (endDate < startDate) {
      await deleteUploadedFile(req.file);
      return res.status(400).json({ success: false, message: "End date cannot be before start date." });
    }

    // Check for overlapping approved trips
    const userParticipants = await TripParticipant.find({ userId: req.user._id, status: "approved" });
    const tripIds = userParticipants.map((p) => p.tripId);

    const overlappingTrip = await Trip.findOne({
      _id: { $in: tripIds },
      startDate: { $lte: endDate },
      endDate: { $gte: startDate },
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
      startDate: { $lte: endDate },
      endDate: { $gte: startDate },
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
      tripType,
      businessTripType: tripType === "Business" ? businessTripType : null,
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
    const trips = await Promise.all(participants.map(async (p) => {
      const membersCount = await TripParticipant.countDocuments({ tripId: p.tripId._id, status: "approved" });
      return {
        ...p.tripId.toObject(),
        participantStatus: p.status,
        participantRole: p.role,
        membersCount: membersCount
      };
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
    
    const trip = await Trip.findOne({ invitationCode: inviteToken }).select("name description startDate endDate coverImage tripType businessTripType");
    
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
    const { inviteToken, familyMembers } = req.body;
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
      startDate: { $lte: trip.endDate },
      endDate: { $gte: trip.startDate },
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

    if (familyMembers && familyMembers.length > 0) {
      for (const member of familyMembers) {
        if (member.email && member.email.trim() !== "") {
          const memberUser = await User.findOne({ email: member.email.trim() });
          if (!memberUser) {
            return res.status(400).json({ 
              success: false, 
              message: `Email ${member.email} is not registered in the system. Please remove the email or ask them to register.` 
            });
          }

          // Check if this member has a clashing trip
          const memberParticipants = await TripParticipant.find({ userId: memberUser._id, status: "approved" });
          const memberTripIds = memberParticipants.map((p) => p.tripId);
          
          const memberClash = await Trip.findOne({
            _id: { $in: memberTripIds },
            startDate: { $lte: trip.endDate },
            endDate: { $gte: trip.startDate },
          });

          if (memberClash) {
            return res.status(400).json({
              success: false,
              message: `Family member ${member.name} (${member.email}) already has an approved trip clashing with these dates.`
            });
          }
        }
      }
    }

    const requestedRole = (familyMembers && familyMembers.length > 0) ? "familyLeader" : "soloTraveler";

    await JoinRequest.create({
      tripId: trip._id,
      userId: req.user._id,
      requestedRole: requestedRole,
      requestedBy: req.user._id,
      status: "pending",
      invitationCode: inviteToken,
      familyMembers: familyMembers || [],
    });

    res.status(200).json({ success: true, message: "Join request sent successfully." });
  } catch (error) {
    console.error("Join trip error:", error);
    res.status(500).json({ success: false, message: "Server error joining trip." });
  }
};

export const updateTrip = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { name, description, startDate, endDate } = req.body;

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: "approved" });
    if (!participant || participant.role !== "tripLeader") {
      await deleteUploadedFile(req.file);
      return res.status(403).json({ success: false, message: "You don't have permission to edit this trip." });
    }

    const trip = await Trip.findById(tripId);
    if (!trip) {
      await deleteUploadedFile(req.file);
      return res.status(404).json({ success: false, message: "Trip not found." });
    }

    if (name) trip.name = name;
    if (description !== undefined) trip.description = description;
    if (startDate) trip.startDate = startDate;
    if (endDate) trip.endDate = endDate;

    if (req.file && req.file.path) {
      if (trip.coverImage) {
        // delete old image from cloudinary? We might skip it for now to avoid complexity or if it's external URL
      }
      trip.coverImage = req.file.path;
    }

    await trip.save();

    res.status(200).json({
      success: true,
      message: "Trip updated successfully",
      data: trip,
    });
  } catch (error) {
    console.error("Update trip error:", error);
    await deleteUploadedFile(req.file);
    res.status(500).json({ success: false, message: "Server error updating trip." });
  }
};

export const getAllPendingRequests = async (req, res) => {
  try {
    // Find all pending JoinRequests sent by the logged-in user
    const pendingRequests = await JoinRequest.find({
      userId: req.user._id,
      status: "pending"
    }).populate("tripId", "name coverImage").lean();

    // Format the requests
    const formattedRequests = pendingRequests.map(reqItem => {
      const trip = reqItem.tripId;
      return {
        id: reqItem._id,
        tripId: trip?._id,
        tripName: trip ? trip.name : "Unknown Trip",
        tripCoverImage: trip ? trip.coverImage : null,
        type: reqItem.requestedRole === "soloTraveler" ? "Solo" : "Family",
        group: reqItem.requestedRole === "soloTraveler" ? "Solo Traveler" : "Family Group",
        time: reqItem.createdAt,
      };
    });

    res.status(200).json({ success: true, data: formattedRequests });
  } catch (error) {
    console.error("Error fetching user's pending requests:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

export const deleteTrip = async (req, res) => {
  try {
    const { tripId } = req.params;

    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: 'approved' });
    if (!participant || participant.role !== 'tripLeader') {
      return res.status(403).json({ success: false, message: 'You do not have permission to delete this trip.' });
    }

    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: 'Trip not found.' });
    }

    if (trip.coverImage) {
      // Opt out of cloudinary image deletion for safety
    }

    await Trip.findByIdAndDelete(tripId);
    await TripParticipant.deleteMany({ tripId });
    await JoinRequest.deleteMany({ tripId });

    res.status(200).json({ success: true, message: 'Trip deleted successfully.' });
  } catch (error) {
    console.error('Delete trip error:', error);
    res.status(500).json({ success: false, message: 'Server error deleting trip.' });
  }
};
