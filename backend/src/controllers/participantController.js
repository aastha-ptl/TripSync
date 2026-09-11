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

    // Fetch all approved participants, including family members
    const participants = await TripParticipant.find({ tripId, status: "approved" })
      .populate("userId", "firstName lastName profilePhoto phone")
      .lean();

    // Group by familyId
    const familiesMap = {};
    const individuals = [];

    for (const p of participants) {
      if (p.familyId) {
        const fId = p.familyId.toString();
        if (!familiesMap[fId]) {
          familiesMap[fId] = { leader: null, members: [] };
        }
        if (p.role === "familyLeader" || p.role === "tripLeader") {
          // If there are multiple leaders in a family somehow, just take the first
          if (!familiesMap[fId].leader) {
            familiesMap[fId].leader = p;
          } else {
            familiesMap[fId].members.push(p);
          }
        } else {
          familiesMap[fId].members.push(p);
        }
      } else {
        individuals.push(p);
      }
    }

    const formattedParticipants = [];

    // Format individuals
    for (const p of individuals) {
      const user = p.userId;
      const isTripLeader = p.role === "tripLeader";
      const isSolo = p.role === "soloTraveler" || p.role === "familyLeader";
      formattedParticipants.push({
        id: p._id,
        userId: user ? user._id : null,
        name: user ? `${user.firstName} ${user.lastName}` : "Unknown User",
        role: isTripLeader ? "tripLeader" : (isSolo ? "soloTraveler" : p.role),
        type: isTripLeader ? "Individual" : (isSolo ? "Solo" : "Individual"),
        group: isTripLeader ? "Individual" : (isSolo ? "Solo Traveler" : "Individual"),
        avatar: user?.profilePhoto || null,
        phone: user?.phone || "N/A",
        familyMembers: [],
      });
    }

    // Format families
    for (const fId in familiesMap) {
      const familyData = familiesMap[fId];
      let leaderP = familyData.leader;
      
      // If no leader found in TripParticipants, fallback to first member
      if (!leaderP && familyData.members.length > 0) {
        leaderP = familyData.members.shift();
      }

      if (leaderP) {
        const lUser = leaderP.userId;
        
        // Find the Family document to get all family members
        const familyDoc = await Family.findById(fId).lean();
        const allFamilyMembers = [];

        if (familyDoc && familyDoc.members && familyDoc.members.length > 0) {
          for (const fm of familyDoc.members) {
            // Find registered TripParticipant if linked to user
            const regParticipant = familyData.members.find(
              (regM) => regM.userId && fm.userId && regM.userId._id.toString() === fm.userId.toString()
            );
            const mUser = regParticipant?.userId;

            allFamilyMembers.push({
              _id: fm._id || (regParticipant ? regParticipant._id : null),
              id: fm._id || (regParticipant ? regParticipant._id : null),
              userId: fm.userId || (mUser ? mUser._id : null),
              name: fm.name, // The exact name entered by the family leader!
              relationship: fm.relationship || "Family Member",
              email: fm.email || mUser?.email || null,
              phone: fm.phone || mUser?.phone || "N/A",
              age: fm.age || 0,
              avatar: mUser?.profilePhoto || null,
            });
          }
        } else if (familyData.members.length > 0) {
          for (const regM of familyData.members) {
            const mUser = regM.userId;
            allFamilyMembers.push({
              _id: regM._id,
              id: regM._id,
              userId: mUser ? mUser._id : null,
              name: mUser ? `${mUser.firstName} ${mUser.lastName}` : "Family Member",
              relationship: "Family Member",
              email: mUser?.email || null,
              phone: mUser?.phone || "N/A",
              age: 0,
              avatar: mUser?.profilePhoto || null,
            });
          }
        }

        if (allFamilyMembers.length === 0) {
          const isTripLeader = leaderP.role === "tripLeader";
          formattedParticipants.push({
            id: leaderP._id,
            userId: lUser ? lUser._id : null,
            name: lUser ? `${lUser.firstName} ${lUser.lastName}` : "Unknown User",
            role: isTripLeader ? "tripLeader" : "soloTraveler",
            type: isTripLeader ? "Individual" : "Solo",
            group: isTripLeader ? "Individual" : "Solo Traveler",
            avatar: lUser?.profilePhoto || null,
            phone: lUser?.phone || "N/A",
            familyMembers: [],
          });
        } else {
          formattedParticipants.push({
            id: leaderP._id,
            userId: lUser ? lUser._id : null,
            name: lUser ? `${lUser.firstName} ${lUser.lastName}` : "Unknown User",
            role: leaderP.role,
            type: "Family",
            group: "Family Group",
            avatar: lUser?.profilePhoto || null,
            phone: lUser?.phone || "N/A",
            familyMembers: allFamilyMembers,
          });
        }
      }
    }

    // Sort participants: trip leader first
    formattedParticipants.sort((a, b) => {
      if (a.role === "tripLeader") return -1;
      if (b.role === "tripLeader") return 1;
      return 0;
    });
    res.status(200).json({
      success: true,
      data: formattedParticipants,
      tripType: trip.tripType,
      businessTripType: trip.businessTripType,
    });
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
      const hasFamily = (reqItem.familyMembers?.length || 0) > 0;
      const isSolo = reqItem.requestedRole === "soloTraveler" || !hasFamily;
      return {
        id: reqItem._id,
        name: user ? `${user.firstName} ${user.lastName}` : "Unknown User",
        type: isSolo ? "Solo" : "Family",
        group: isSolo ? "Solo Traveler" : "Family Group",
        avatar: user?.profilePhoto || null,
        phone: user?.phone || "N/A",
        time: reqItem.createdAt,
        familyMembers: reqItem.familyMembers || [],
        totalMembers: 1 + (reqItem.familyMembers?.length || 0),
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
      let assignedRole = joinRequest.requestedRole;

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
        assignedRole = "familyLeader";
        
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
      } else if (joinRequest.requestedRole === "familyLeader" && (!joinRequest.familyMembers || joinRequest.familyMembers.length === 0)) {
        // Family leader requested without family members (joined alone) -> they are a solo traveler!
        assignedRole = "soloTraveler";
      }

      await TripParticipant.create({
        tripId: joinRequest.tripId,
        userId: joinRequest.userId,
        role: assignedRole,
        status: "approved",
        joinedAt: new Date(),
        familyId: createdFamilyId || (assignedRole === "soloTraveler" ? null : joinRequest.familyId),
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
