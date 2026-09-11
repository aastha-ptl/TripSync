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
      formattedParticipants.push({
        id: p._id,
        userId: user ? user._id : null,
        name: user ? `${user.firstName} ${user.lastName}` : "Unknown User",
        role: p.role,
        type: p.role === "soloTraveler" ? "Solo" : "Individual",
        group: p.role === "soloTraveler" ? "Solo Traveler" : "Individual",
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
        
        // Find the Family document to get unregistered members as well
        const familyDoc = await Family.findById(fId).lean();
        const unregisteredMembers = [];
        
        if (familyDoc && familyDoc.members) {
          // Find members in familyDoc that are NOT in TripParticipants yet
          // We can check by matching userId or just include them if they have no userId
          for (const m of familyDoc.members) {
            const isRegistered = familyData.members.some(
              (regM) => regM.userId && m.userId && regM.userId._id.toString() === m.userId.toString()
            );
            if (!isRegistered) {
              unregisteredMembers.push({
                _id: m._id,
                id: m._id,
                userId: m.userId || null,
                name: m.name,
                relationship: m.relationship,
                email: m.email,
                phone: m.phone,
                avatar: null,
              });
            }
          }
        }

        const registeredMembers = familyData.members.map((m) => {
          const mUser = m.userId;
          return {
            _id: m._id,
            id: m._id,
            userId: mUser ? mUser._id : null,
            name: mUser ? `${mUser.firstName} ${mUser.lastName}` : "Unknown User",
            relationship: "Family Member",
            email: mUser?.email,
            phone: mUser?.phone,
            avatar: mUser?.profilePhoto || null,
          };
        });

        const allFamilyMembers = [...registeredMembers, ...unregisteredMembers];

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

    // Sort participants (e.g. leaders first) or leave as is
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
        familyMembers: reqItem.familyMembers || [],
        totalMembers: reqItem.requestedRole === "soloTraveler" ? 1 : 1 + (reqItem.familyMembers?.length || 0),
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
