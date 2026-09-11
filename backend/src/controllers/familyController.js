import Family from "../models/Family.js";
import TripParticipant from "../models/TripParticipant.js";
import User from "../models/User.js";
import Trip from "../models/Trip.js";
import JoinRequest from "../models/JoinRequest.js";

// Fetch current user's family details for a trip
export const getMyFamily = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;

    const participant = await TripParticipant.findOne({
      tripId,
      userId,
      status: "approved",
    });

    if (!participant) {
      return res.status(403).json({
        success: false,
        message: "You are not an approved participant in this trip.",
      });
    }

    let family = null;
    if (participant.familyId) {
      family = await Family.findById(participant.familyId).lean();
    } else {
      // Check if a family exists where user is the familyLeaderId and has members
      const existingFamily = await Family.findOne({ tripId, familyLeaderId: userId }).lean();
      if (existingFamily && existingFamily.members && existingFamily.members.length > 0) {
        family = existingFamily;
        participant.familyId = family._id;
        await participant.save();
      }
    }

    const trip = await Trip.findById(tripId).lean();

    return res.status(200).json({
      success: true,
      data: {
        hasFamily: family !== null && (family.members?.length > 0),
        family: family,
        role: participant.role,
        tripType: trip?.tripType,
        businessTripType: trip?.businessTripType,
      },
    });
  } catch (error) {
    console.error("Error fetching family details:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

// Comprehensive validation for family member email
export const validateFamilyMemberEmail = async ({ tripId, email, currentUserId, currentFamilyId }) => {
  if (!email || email.trim() === "") {
    return { valid: false, status: 400, message: "Email is required." };
  }

  const emailTrimmed = email.trim().toLowerCase();

  // 1. Check if user exists in the system
  const user = await User.findOne({ email: emailTrimmed }).select("firstName lastName email profilePhoto phone");
  if (!user) {
    return {
      valid: false,
      status: 400,
      isRegistered: false,
      message: `Email ${email} is not registered in the system. Please remove the email or ask them to register.`,
    };
  }

  // 2. Cannot add yourself as a family member
  if (currentUserId && user._id.toString() === currentUserId.toString()) {
    return {
      valid: false,
      status: 400,
      message: "You cannot add yourself as a family member.",
    };
  }

  const trip = await Trip.findById(tripId);
  if (!trip) {
    return { valid: false, status: 404, message: "Trip not found." };
  }

  // 3. Check if this email / user is ALREADY used in THIS trip
  // A) Is this user the trip creator / trip leader?
  if (trip.creator && trip.creator.toString() === user._id.toString()) {
    return {
      valid: false,
      status: 400,
      isAlreadyInTrip: true,
      message: `User ${user.firstName} ${user.lastName} (${email}) is already the Trip Leader of this trip.`,
    };
  }

  // B) Is this user an approved participant in this trip outside of the current family?
  const existingParticipant = await TripParticipant.findOne({
    tripId,
    userId: user._id,
    status: "approved",
  });

  if (existingParticipant) {
    const isCurrentFamily = currentFamilyId &&
        existingParticipant.familyId &&
        existingParticipant.familyId.toString() === currentFamilyId.toString();
    if (!isCurrentFamily) {
      const roleLabel = existingParticipant.role === "soloTraveler"
        ? "Solo Traveler"
        : (existingParticipant.role === "familyLeader" ? "Family Leader" : "Participant");
      return {
        valid: false,
        status: 400,
        isAlreadyInTrip: true,
        message: `User ${user.firstName} ${user.lastName} (${email}) is already joined in this trip as a ${roleLabel}.`,
      };
    }
  }

  // C) Is this email in another Family in this trip?
  const otherFamilyQuery = {
    tripId,
    $or: [
      { familyLeaderId: user._id },
      { "members.userId": user._id },
      { "members.email": emailTrimmed },
    ],
  };
  if (currentFamilyId) {
    otherFamilyQuery._id = { $ne: currentFamilyId };
  }
  const otherFamily = await Family.findOne(otherFamilyQuery);
  if (otherFamily) {
    return {
      valid: false,
      status: 400,
      isAlreadyInTrip: true,
      message: `Email ${email} is already part of another family in this trip.`,
    };
  }

  // D) Is there a pending join request with this email or user?
  const pendingReqQuery = {
    tripId,
    status: "pending",
    $or: [
      { userId: user._id },
      { "familyMembers.email": emailTrimmed },
    ],
  };
  if (currentUserId) {
    pendingReqQuery.userId = { $ne: currentUserId };
  }
  const pendingReq = await JoinRequest.findOne(pendingReqQuery);
  if (pendingReq) {
    return {
      valid: false,
      status: 400,
      isAlreadyInTrip: true,
      message: `User with email ${email} already has a pending join request for this trip.`,
    };
  }

  // 4. Check if this email's schedule CONFLICTS with other trips of that email address user
  const memberParticipants = await TripParticipant.find({ userId: user._id, status: "approved" });
  const pTripIds = memberParticipants.map((p) => p.tripId.toString());

  const createdTrips = await Trip.find({ creator: user._id, status: { $ne: "cancelled" } }).select("_id");
  const cTripIds = createdTrips.map((t) => t._id.toString());

  const familyRecords = await Family.find({
    $or: [
      { familyLeaderId: user._id },
      { "members.userId": user._id },
      { "members.email": emailTrimmed },
    ],
  }).select("tripId");
  const fTripIds = familyRecords.map((f) => f.tripId.toString());

  const allOtherTripIds = [...new Set([...pTripIds, ...cTripIds, ...fTripIds])]
    .filter((id) => id !== tripId.toString());

  if (allOtherTripIds.length > 0) {
    const memberClash = await Trip.findOne({
      _id: { $in: allOtherTripIds },
      status: { $ne: "cancelled" },
      startDate: { $lte: trip.endDate },
      endDate: { $gte: trip.startDate },
    });

    if (memberClash) {
      return {
        valid: false,
        status: 400,
        isRegistered: true,
        hasClash: true,
        message: `User ${user.firstName} ${user.lastName} (${email}) already has an active trip scheduled during these dates (${memberClash.name}).`,
      };
    }
  }

  return {
    valid: true,
    user: {
      id: user._id,
      name: `${user.firstName} ${user.lastName}`,
      email: user.email,
      phone: user.phone,
      profilePhoto: user.profilePhoto,
    },
  };
};

// Check if an email is registered and if they have clashing trips
export const checkMemberEmail = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { email } = req.query;
    const currentUserId = req.user._id;

    const participant = await TripParticipant.findOne({ tripId, userId: currentUserId, status: "approved" });
    const currentFamilyId = participant?.familyId || null;

    const validation = await validateFamilyMemberEmail({
      tripId,
      email,
      currentUserId,
      currentFamilyId,
    });

    if (!validation.valid) {
      return res.status(validation.status || 400).json({
        success: false,
        isRegistered: validation.isRegistered ?? true,
        hasClash: validation.hasClash ?? false,
        isAlreadyInTrip: validation.isAlreadyInTrip ?? false,
        message: validation.message,
      });
    }

    return res.status(200).json({
      success: true,
      isRegistered: true,
      hasClash: false,
      user: validation.user,
    });
  } catch (error) {
    console.error("Check email error:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

// Create or update current user's family members
export const updateMyFamily = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;
    const { members } = req.body; // Array of { name, age, relationship, email, phone }

    if (!Array.isArray(members)) {
      return res.status(400).json({
        success: false,
        message: "Members must be an array.",
      });
    }

    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found." });
    }

    const participant = await TripParticipant.findOne({
      tripId,
      userId,
      status: "approved",
    });

    if (!participant) {
      return res.status(403).json({
        success: false,
        message: "You are not an approved participant in this trip.",
      });
    }

    // Check duplicate emails within the submitted members list & validate each email
    const seenEmails = new Set();
    for (const member of members) {
      const emailTrimmed = member.email ? member.email.trim().toLowerCase() : null;
      if (emailTrimmed && emailTrimmed.length > 0) {
        if (seenEmails.has(emailTrimmed)) {
          return res.status(400).json({
            success: false,
            message: `Email ${member.email} cannot be added more than once in the same family.`,
          });
        }
        seenEmails.add(emailTrimmed);

        const validation = await validateFamilyMemberEmail({
          tripId,
          email: emailTrimmed,
          currentUserId: userId,
          currentFamilyId: participant.familyId || null,
        });

        if (!validation.valid) {
          return res.status(validation.status || 400).json({
            success: false,
            message: validation.message,
          });
        }
      }
    }

    // Build processedMembers
    const processedMembers = [];
    for (const member of members) {
      let linkedUserId = null;
      const emailTrimmed = member.email ? member.email.trim().toLowerCase() : null;

      if (emailTrimmed && emailTrimmed.length > 0) {
        const foundUser = await User.findOne({ email: emailTrimmed });
        if (foundUser) {
          linkedUserId = foundUser._id;
        }
      }

      processedMembers.push({
        name: member.name ? member.name.trim() : "Family Member",
        age: Number(member.age) || 0,
        relationship: member.relationship ? member.relationship.trim() : "Family",
        email: emailTrimmed || null,
        phone: member.phone ? member.phone.trim() : null,
        userId: linkedUserId,
      });
    }

    let family = null;
    if (participant.familyId) {
      family = await Family.findById(participant.familyId);
    } else {
      family = await Family.findOne({ tripId, familyLeaderId: userId });
    }

    // Handle "Only Me" (0 members) vs "Me + Family" (> 0 members)
    if (processedMembers.length === 0) {
      if (family) {
        // Delete any familyMember participant rows linked to this family
        await TripParticipant.deleteMany({
          tripId,
          familyId: family._id,
          role: "familyMember",
        });
        family.members = [];
        await family.save();
      }

      // If participant was familyLeader or soloTraveler, role becomes soloTraveler (tripLeader stays tripLeader)
      if (participant.role !== "tripLeader") {
        participant.role = "soloTraveler";
      }
      participant.familyId = null;
      await participant.save();

      return res.status(200).json({
        success: true,
        message: "Family details updated to solo traveler successfully",
        data: {
          family: null,
          role: participant.role,
        },
      });
    }

    // Has family members
    if (family) {
      family.members = processedMembers;
      await family.save();
    } else {
      family = await Family.create({
        tripId,
        familyLeaderId: userId,
        members: processedMembers,
      });
    }

    participant.familyId = family._id;
    if (participant.role !== "tripLeader") {
      participant.role = "familyLeader";
    }
    await participant.save();

    // Clean up any old TripParticipant records for this family that are no longer in processedMembers
    const keepUserIds = processedMembers.map((m) => m.userId).filter(Boolean);
    await TripParticipant.deleteMany({
      tripId,
      familyId: family._id,
      role: "familyMember",
      userId: { $nin: keepUserIds },
    });

    // Ensure TripParticipant exists for any linked registered accounts
    for (const m of processedMembers) {
      if (m.userId) {
        const existingMemberParticipant = await TripParticipant.findOne({
          tripId,
          userId: m.userId,
        });

        if (!existingMemberParticipant) {
          await TripParticipant.create({
            tripId,
            userId: m.userId,
            role: "familyMember",
            status: "approved",
            familyId: family._id,
            joinedAt: new Date(),
          });
        } else if (!existingMemberParticipant.familyId || existingMemberParticipant.familyId.toString() !== family._id.toString()) {
          existingMemberParticipant.familyId = family._id;
          await existingMemberParticipant.save();
        }
      }
    }

    return res.status(200).json({
      success: true,
      message: "Family details saved successfully",
      data: {
        family,
        role: participant.role,
      },
    });
  } catch (error) {
    console.error("Error updating family details:", error);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};
