import TripParticipant from "../models/TripParticipant.js";
import JoinRequest from "../models/JoinRequest.js";
import Trip from "../models/Trip.js";
import Family from "../models/Family.js";
import User from "../models/User.js";

// Fetch approved participants for a trip
export const getTripParticipants = async (req, res) => {
  try {
    const { tripId } = req.params;

    // Check if trip exists
    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found" });
    }

    const participants = await TripParticipant.find({ tripId, status: "approved", role: { $ne: "familyMember" } })
      .populate("userId", "firstName lastName profilePhoto phone")
      .lean();

    const formattedParticipants = await Promise.all(participants.map(async (p) => {
      const user = p.userId;
      let familyMembers = [];
      if (p.role === "familyLeader") {
        const family = await Family.findOne({ tripId, familyLeaderId: user._id }).lean();
        if (family) {
          familyMembers = family.members || [];
        }
      }
      return {
        id: p._id,
        name: user ? `${user.firstName} ${user.lastName}` : "Unknown User",
        role: p.role, // e.g. "tripLeader", "soloTraveler", "familyMember", "familyLeader"
        type: p.role === "soloTraveler" ? "Solo" : "Family",
        group: p.role === "soloTraveler" ? "Solo Traveler" : "Family Group",
        avatar: user?.profilePhoto || null,
        phone: user?.phone || "N/A",
        familyMembers,
      };
    }));

    res.status(200).json({ success: true, data: formattedParticipants });
  } catch (error) {
    console.error("Error fetching participants:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Fetch pending join requests for a trip
export const getJoinRequests = async (req, res) => {
  try {
    const { tripId } = req.params;

    const requests = await JoinRequest.find({ tripId, status: "pending" })
      .populate("userId", "firstName lastName profilePhoto phone")
      .lean();

    const formattedRequests = requests.map((reqItem) => {
      const user = reqItem.userId;
      return {
        id: reqItem._id,
        name: user ? `${user.firstName} ${user.lastName}` : "Unknown User",
        type: reqItem.requestedRole === "soloTraveler" ? "Solo" : "Family",
        group: reqItem.requestedRole === "soloTraveler" ? "Solo Traveler" : "Family Group",
        avatar: user?.profilePhoto || null,
        phone: user?.phone || "N/A",
        time: reqItem.createdAt,
      };
    });

    res.status(200).json({ success: true, data: formattedRequests });
  } catch (error) {
    console.error("Error fetching join requests:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Update join request status (approve/reject)
export const updateJoinRequest = async (req, res) => {
  try {
    const { tripId, requestId } = req.params;
    const { status } = req.body; // 'approved' or 'rejected'

    if (!["approved", "rejected"].includes(status)) {
      return res.status(400).json({ success: false, message: "Invalid status" });
    }

    const joinRequest = await JoinRequest.findById(requestId);
    if (!joinRequest || joinRequest.tripId.toString() !== tripId) {
      return res.status(404).json({ success: false, message: "Join request not found" });
    }

    if (joinRequest.status !== "pending") {
      return res.status(400).json({ success: false, message: "Request already processed" });
    }

    joinRequest.status = status;
    joinRequest.reviewedBy = req.user._id;
    joinRequest.reviewedAt = new Date();
    await joinRequest.save();

    if (status === "approved") {
      let createdFamilyId = null;
      if (joinRequest.requestedRole === "familyLeader" && joinRequest.familyMembers && joinRequest.familyMembers.length > 0) {
        const membersToSave = await Promise.all(joinRequest.familyMembers.map(async (member) => {
          let linkedUserId = null;
          if (member.email) {
            const existingUser = await User.findOne({ email: member.email });
            if (existingUser) {
              linkedUserId = existingUser._id;
            }
          }
          return {
            name: member.name,
            age: member.age,
            relationship: member.relationship,
            email: member.email,
            phone: member.phone,
            userId: linkedUserId,
          };
        }));
        
        const family = await Family.create({
          tripId: joinRequest.tripId,
          familyLeaderId: joinRequest.userId,
          members: membersToSave,
        });
        createdFamilyId = family._id;
        
        const linkedUsers = membersToSave.map(m => m.userId).filter(id => id);
        for (const uid of linkedUsers) {
          await TripParticipant.create({
            tripId: joinRequest.tripId,
            userId: uid,
            role: "familyMember",
            status: "approved",
            joinedAt: new Date(),
            familyId: createdFamilyId,
          });
        }
      }

      await TripParticipant.create({
        tripId: joinRequest.tripId,
        userId: joinRequest.userId,
        role: joinRequest.requestedRole,
        status: "approved",
        joinedAt: new Date(),
        familyId: createdFamilyId || joinRequest.familyId,
      });
    }

    res.status(200).json({
      success: true,
      message: `Join request ${status} successfully`,
      data: joinRequest,
    });
  } catch (error) {
    console.error("Error updating join request:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};
