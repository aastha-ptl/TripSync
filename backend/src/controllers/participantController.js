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
      .populate("userId", "firstName lastName profilePhoto phone dateOfBirth")
      .lean();

    const calculateAge = (dob) => {
      if (!dob) return null;
      const birthDate = new Date(dob);
      if (isNaN(birthDate.getTime())) return null;
      const today = new Date();
      let age = today.getFullYear() - birthDate.getFullYear();
      const m = today.getMonth() - birthDate.getMonth();
      if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
        age--;
      }
      return age >= 0 ? age : null;
    };

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
        type: "Solo",
        group: "Solo Traveler",
        avatar: user?.profilePhoto || null,
        phone: user?.phone || "N/A",
        age: calculateAge(user?.dateOfBirth),
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
            if (fm.status === "removed" || fm.status === "left") continue;
            // Skip if this member is currently the Family Leader
            const isLeaderByUserId = (
              (fm.userId && familyDoc.familyLeaderId && fm.userId.toString() === familyDoc.familyLeaderId.toString()) ||
              (leaderP && leaderP.userId && fm.userId && fm.userId.toString() === (leaderP.userId._id || leaderP.userId).toString())
            );
            const isLeaderByLeaderName = (
              familyDoc.leaderName && fm.name && fm.name.trim().toLowerCase() === familyDoc.leaderName.trim().toLowerCase()
            );
            const isLeaderByEmail = (
              lUser?.email && fm.email && fm.email.trim().toLowerCase() === lUser.email.trim().toLowerCase()
            );

            if (isLeaderByUserId || isLeaderByLeaderName || isLeaderByEmail) {
              continue;
            }

            // Find registered TripParticipant if linked to user
            const regParticipant = familyData.members.find(
              (regM) => regM.userId && fm.userId && regM.userId._id.toString() === fm.userId.toString()
            );
            let mUser = regParticipant?.userId;

            // If not in regParticipant, check User directly if fm has userId or email
            if (!mUser) {
              if (fm.userId) {
                mUser = await User.findById(fm.userId).select("firstName lastName profilePhoto phone dateOfBirth email").lean();
              } else if (fm.email) {
                mUser = await User.findOne({ email: fm.email.toLowerCase() }).select("firstName lastName profilePhoto phone dateOfBirth email").lean();
                if (mUser && !fm.userId) {
                  await Family.updateOne(
                    { _id: familyDoc._id, "members._id": fm._id },
                    { $set: { "members.$.userId": mUser._id } }
                  );
                }
              }
            }

            allFamilyMembers.push({
              _id: fm._id || (regParticipant ? regParticipant._id : null),
              id: fm._id || (regParticipant ? regParticipant._id : null),
              userId: fm.userId || (mUser ? (mUser._id || mUser) : null),
              name: fm.name, // The exact name entered for the family member (e.g. "Ushmaben")
              relationship: fm.relationship || "Family Member",
              email: fm.email || mUser?.email || null,
              phone: (mUser && mUser.phone && mUser.phone !== "N/A") ? mUser.phone : (fm.phone || "N/A"),
              age: fm.age || (mUser?.dateOfBirth ? calculateAge(mUser.dateOfBirth) : 0),
              avatar: mUser?.profilePhoto || null,
            });
          }
        } else if (familyData.members.length > 0) {
          for (const regM of familyData.members) {
            const mUser = regM.userId;
            const profileName = mUser ? `${mUser.firstName || ""} ${mUser.lastName || ""}`.trim() : "";
            allFamilyMembers.push({
              _id: regM._id,
              id: regM._id,
              userId: mUser ? mUser._id : null,
              name: profileName.length > 0 ? profileName : "Family Member",
              relationship: "Family Member",
              email: mUser?.email || null,
              phone: mUser?.phone || "N/A",
              age: mUser?.dateOfBirth ? calculateAge(mUser.dateOfBirth) : 0,
              avatar: mUser?.profilePhoto || null,
            });
          }
        }

        const isTripLeader = leaderP.role === "tripLeader";
        const isSolo = leaderP.role === "soloTraveler";

        const leaderDisplayName = (familyDoc && familyDoc.leaderName)
          ? familyDoc.leaderName
          : (lUser ? `${lUser.firstName} ${lUser.lastName}`.trim() : "Unknown User");

        const leaderAge = (lUser?.dateOfBirth ? calculateAge(lUser.dateOfBirth) : null) ||
          familyDoc?.leaderAge || null;

        formattedParticipants.push({
          id: leaderP._id,
          userId: lUser ? lUser._id : null,
          name: leaderDisplayName,
          role: leaderP.role,
          type: isSolo ? "Solo" : "Family",
          group: isSolo ? "Solo Traveler" : "Family Group",
          avatar: lUser?.profilePhoto || null,
          phone: (lUser && lUser.phone && lUser.phone !== "N/A") ? lUser.phone : (familyDoc?.leaderPhone || "N/A"),
          age: leaderAge,
          familyMembers: allFamilyMembers,
        });
      }
    }

    // Sort participants: trip leader first
    formattedParticipants.sort((a, b) => {
      if (a.role === "tripLeader") return -1;
      if (b.role === "tripLeader") return 1;
      return 0;
    });

    // Fetch removed participants
    const removedParticipants = await TripParticipant.find({
      tripId,
      status: { $in: ["removed", "left"] },
    })
      .populate("userId", "firstName lastName profilePhoto phone dateOfBirth")
      .populate("familyId")
      .lean();

    const formattedRemoved = [];
    const removedUserIds = new Set();

    for (const rp of removedParticipants) {
      const user = rp.userId;
      const uId = user ? user._id.toString() : rp._id.toString();
      removedUserIds.add(uId);

      let familyLeaderName = null;
      if (rp.familyId) {
        const fam = await Family.findById(rp.familyId).populate("familyLeaderId", "firstName lastName").lean();
        if (fam) {
          familyLeaderName = fam.leaderName || (fam.familyLeaderId ? `${fam.familyLeaderId.firstName || ""} ${fam.familyLeaderId.lastName || ""}`.trim() : null);
        }
      }

      formattedRemoved.push({
        id: rp._id,
        userId: user ? user._id : null,
        name: rp.name || (user ? `${user.firstName} ${user.lastName}`.trim() : "Removed Traveler"),
        role: rp.role,
        type: rp.familyId ? "Family Member" : "Solo",
        group: rp.familyId ? "Family Group" : "Solo Traveler",
        avatar: user?.profilePhoto || null,
        phone: (user && user.phone && user.phone !== "N/A") ? user.phone : (rp.phone || "N/A"),
        status: rp.status,
        isRemoved: true,
        familyLeaderName: familyLeaderName,
      });
    }

    // Also check non-app family members marked as removed/left in Family.members
    const allFamilies = await Family.find({ tripId })
      .populate("familyLeaderId", "firstName lastName")
      .lean();

    for (const fam of allFamilies) {
      const fLeaderName = fam.leaderName || (fam.familyLeaderId
        ? `${fam.familyLeaderId.firstName || ""} ${fam.familyLeaderId.lastName || ""}`.trim()
        : "Family Leader");

      if (fam.members && fam.members.length > 0) {
        for (const fm of fam.members) {
          if (fm.status === "removed" || fm.status === "left") {
            const fmId = fm._id ? fm._id.toString() : null;
            const alreadyAdded = (fm.userId && removedUserIds.has(fm.userId.toString())) ||
              formattedRemoved.some(r => r.id?.toString() === fmId);
            if (!alreadyAdded) {
              formattedRemoved.push({
                id: fm._id,
                userId: fm.userId || null,
                name: fm.name || "Removed Family Member",
                role: "familyMember",
                type: "Family Member",
                group: "Family Group",
                avatar: null,
                phone: fm.phone || "N/A",
                status: fm.status,
                isRemoved: true,
                familyLeaderName: fLeaderName,
              });
            }
          }
        }
      }
    }

    res.status(200).json({
      success: true,
      data: formattedParticipants,
      removedTravelers: formattedRemoved,
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
            const cleanEmail = member.email.trim().toLowerCase();
            const existingUser = await User.findOne({ email: cleanEmail });
            if (existingUser) {
              linkedUserId = existingUser._id;
            }
          }
          return {
            name: member.name,
            age: member.age,
            relationship: member.relationship,
            email: member.email ? member.email.trim().toLowerCase() : null,
            phone: member.phone,
            userId: linkedUserId,
            status: "approved",
            leftAt: null,
          };
        }));
        
        let family = await Family.findOne({ tripId: joinRequest.tripId, familyLeaderId: joinRequest.userId });
        if (family) {
          family.members = membersToSave;
          await family.save();
        } else {
          family = await Family.create({
            tripId: joinRequest.tripId,
            familyLeaderId: joinRequest.userId,
            members: membersToSave,
          });
        }
        createdFamilyId = family._id;
        assignedRole = "familyLeader";
        
        const linkedUsers = membersToSave.map(m => m.userId).filter(id => id);
        for (const uid of linkedUsers) {
          await TripParticipant.findOneAndUpdate(
            { tripId: joinRequest.tripId, userId: uid },
            {
              role: "familyMember",
              status: "approved",
              joinedAt: new Date(),
              leftAt: null,
              familyId: createdFamilyId,
              permissions: {
                manageTrip: false,
                manageParticipants: false,
                manageFamily: false,
                manageItinerary: false,
                managePolls: false,
                manageDocuments: false,
                manageExpenses: false,
                managePhotos: false,
              },
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
          );
        }
      } else if (joinRequest.requestedRole === "familyLeader" && (!joinRequest.familyMembers || joinRequest.familyMembers.length === 0)) {
        // Family leader requested without family members (joined alone) -> they are a solo traveler!
        assignedRole = "soloTraveler";
      }

      await TripParticipant.findOneAndUpdate(
        { tripId: joinRequest.tripId, userId: joinRequest.userId },
        {
          role: assignedRole,
          status: "approved",
          joinedAt: new Date(),
          leftAt: null,
          familyId: createdFamilyId || (assignedRole === "soloTraveler" ? null : joinRequest.familyId || null),
          permissions: {
            manageTrip: false,
            manageParticipants: false,
            manageFamily: assignedRole === "familyLeader",
            manageItinerary: false,
            managePolls: false,
            manageDocuments: false,
            manageExpenses: false,
            managePhotos: false,
          },
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
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

// Remove a family member (only family leader of that family can do this)
export const removeFamilyMember = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { memberId } = req.body;
    const currentUserId = req.user._id;

    if (!memberId) {
      return res.status(400).json({ success: false, message: "Member ID is required." });
    }

    const family = await Family.findOne({ tripId, familyLeaderId: currentUserId });
    if (!family) {
      return res.status(403).json({ success: false, message: "You are not a Family Leader in this trip." });
    }

    const member = family.members.find(
      (m) => (m._id && m._id.toString() === memberId.toString()) || (m.userId && m.userId.toString() === memberId.toString())
    );

    if (!member) {
      return res.status(404).json({ success: false, message: "Family member not found in your family." });
    }

    // Mark as removed
    member.status = "removed";
    member.leftAt = new Date();
    await family.save();

    // If linked to an app account, update their TripParticipant status
    if (member.userId) {
      await TripParticipant.updateOne(
        { tripId, userId: member.userId, status: "approved" },
        { $set: { status: "removed", leftAt: new Date() } }
      );
    }

    res.status(200).json({
      success: true,
      message: `${member.name || "Family member"} has been removed from the trip.`,
    });
  } catch (error) {
    console.error("Error removing family member:", error);
    res.status(500).json({ success: false, message: "Server error removing family member." });
  }
};

// Leave Trip
export const leaveTrip = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { leaveType, newTripLeaderId, newFamilyLeaderId, newFamilyLeaderEmail } = req.body;
    const userId = req.user._id;

    const participant = await TripParticipant.findOne({ tripId, userId, status: "approved" });
    if (!participant) {
      return res.status(404).json({ success: false, message: "Active trip participant record not found." });
    }

    const trip = await Trip.findById(tripId);
    if (!trip) {
      return res.status(404).json({ success: false, message: "Trip not found." });
    }

    const isFriendsOrEmployeeOnly = trip.tripType === "Friends" ||
      (trip.tripType === "Business" && trip.businessTripType === "Employees Only");
    const isFamilyOrEmployeeWithFamily = trip.tripType === "Family" ||
      (trip.tripType === "Business" && trip.businessTripType === "Employees + Family");

    // 1. Friends or Employees Only
    if (isFriendsOrEmployeeOnly) {
      if (participant.role === "tripLeader") {
        const otherParticipants = await TripParticipant.find({
          tripId,
          userId: { $ne: userId },
          status: "approved",
        });

        if (otherParticipants.length === 0) {
          participant.status = "left";
          await participant.save();
          trip.status = "cancelled";
          await trip.save();
          return res.status(200).json({ success: true, message: "You were the only member. The trip has been cancelled and you have left." });
        }

        if (!newTripLeaderId) {
          return res.status(400).json({
            success: false,
            message: "Please select another member to assign as Trip Leader before leaving.",
          });
        }

        const newLeaderParticipant = otherParticipants.find(
          (p) => p.userId.toString() === newTripLeaderId.toString()
        );

        if (!newLeaderParticipant) {
          return res.status(400).json({
            success: false,
            message: "Selected user is not an active member in this trip.",
          });
        }

        // Transfer leadership
        newLeaderParticipant.role = "tripLeader";
        newLeaderParticipant.permissions = {
          manageTrip: true,
          manageParticipants: true,
          manageFamily: true,
          manageItinerary: true,
          managePolls: true,
          manageDocuments: true,
          manageExpenses: true,
          managePhotos: true,
        };
        await newLeaderParticipant.save();

        trip.createdBy = newLeaderParticipant.userId;
        await trip.save();

        participant.status = "left";
        participant.leftAt = new Date();
        await participant.save();

        return res.status(200).json({
          success: true,
          message: "Trip leadership transferred and you have left the trip successfully.",
        });
      } else {
        // Regular member leaves without needing permission
        participant.status = "left";
        participant.leftAt = new Date();
        await participant.save();
        return res.status(200).json({ success: true, message: "You have left the trip successfully." });
      }
    }

    // 2. Family or Employees + Family
    if (isFamilyOrEmployeeWithFamily) {
      // A. Family Member: cannot leave directly
      if (participant.role === "familyMember") {
        return res.status(403).json({
          success: false,
          message: "Family members cannot leave the trip directly. Only your Family Leader can remove you from the trip.",
        });
      }

      // B. Solo Traveler (and not trip leader)
      if (participant.role === "soloTraveler" && participant.role !== "tripLeader") {
        participant.status = "left";
        participant.leftAt = new Date();
        await participant.save();
        return res.status(200).json({ success: true, message: "You have left the trip successfully." });
      }

      // C. Family Leader (and not trip leader)
      if (participant.role === "familyLeader" && participant.role !== "tripLeader") {
        const family = await Family.findOne({ tripId, familyLeaderId: userId });
        const activeFamilyMembers = family
          ? family.members.filter((m) => m.status !== "removed" && m.status !== "left")
          : [];

        if (!family || activeFamilyMembers.length === 0) {
          participant.status = "left";
          participant.leftAt = new Date();
          await participant.save();
          return res.status(200).json({ success: true, message: "You have left the trip successfully." });
        }

        if (leaveType === "full_family") {
          for (const m of activeFamilyMembers) {
            m.status = "left";
            m.leftAt = new Date();
            if (m.userId) {
              await TripParticipant.updateOne(
                { tripId, userId: m.userId, status: "approved" },
                { $set: { status: "left", leftAt: new Date(), name: m.name } }
              );
            }
          }
          await family.save();

          const departingLeaderName = family.leaderName || participant.name || (req.user ? `${req.user.firstName} ${req.user.lastName}`.trim() : null);
          participant.status = "left";
          participant.leftAt = new Date();
          if (departingLeaderName) {
            participant.name = departingLeaderName;
          }
          await participant.save();
          return res.status(200).json({ success: true, message: "You and your family have left the trip successfully." });
        } else if (leaveType === "only_me") {
          let candidateUserId = newFamilyLeaderId;
          let regUser = null;

          // If linking an email address
          if (newFamilyLeaderEmail && newFamilyLeaderEmail.trim().length > 0) {
            const cleanEmail = newFamilyLeaderEmail.trim().toLowerCase();
            regUser = await User.findOne({ email: cleanEmail });
            if (!regUser) {
              return res.status(400).json({
                success: false,
                message: `Email ${newFamilyLeaderEmail} is not registered in the app. A family member must have an account in the app to become Family Leader.`,
              });
            }
          }

          // Robustly find target family member in family.members by subdocument _id, userId, or email
          const cleanEmail = newFamilyLeaderEmail ? newFamilyLeaderEmail.trim().toLowerCase() : null;
          let targetFm = family.members.find(
            (m) =>
              (newFamilyLeaderId && m._id && m._id.toString() === newFamilyLeaderId.toString()) ||
              (newFamilyLeaderId && m.userId && m.userId.toString() === newFamilyLeaderId.toString()) ||
              (regUser && m.userId && m.userId.toString() === regUser._id.toString()) ||
              (cleanEmail && m.email && m.email.toLowerCase() === cleanEmail)
          );

          if (!targetFm && regUser) {
            targetFm = family.members.find(m => 
              m.name && regUser.firstName && m.name.trim().toLowerCase() === regUser.firstName.trim().toLowerCase()
            );
            if (!targetFm && family.members.length === 1) {
              targetFm = family.members[0];
            }
          }

          let chosenLeaderName = null;
          let chosenLeaderAge = null;
          let chosenLeaderPhone = null;

          if (targetFm) {
            chosenLeaderName = targetFm.name; // Preserves custom name like "Nil" or "Ushmaben"!
            chosenLeaderAge = targetFm.age;
            chosenLeaderPhone = targetFm.phone;
            if (regUser) {
              targetFm.userId = regUser._id;
              targetFm.email = regUser.email;
              candidateUserId = regUser._id.toString();
            } else if (targetFm.userId) {
              candidateUserId = targetFm.userId.toString();
            } else if (targetFm.email) {
              regUser = await User.findOne({ email: targetFm.email.toLowerCase() });
              if (regUser) {
                targetFm.userId = regUser._id;
                candidateUserId = regUser._id.toString();
              }
            }
          } else if (regUser) {
            candidateUserId = regUser._id.toString();
          }

          if (!candidateUserId) {
            return res.status(400).json({
              success: false,
              message: "Please select a family member who has an app account to assign as the new Family Leader.",
            });
          }

          const actualUserId = regUser ? regUser._id : (targetFm?.userId || candidateUserId);

          if (!actualUserId) {
            return res.status(400).json({
              success: false,
              message: "The selected family member does not have an account in the app. Please add their registered email first.",
            });
          }

          // Capture departing leader's name BEFORE updating family.leaderName!
          const departingLeaderName = family.leaderName || participant.name || (req.user ? `${req.user.firstName} ${req.user.lastName}`.trim() : null);

          family.familyLeaderId = actualUserId;
          if (chosenLeaderName) {
            family.leaderName = chosenLeaderName;
          }
          if (chosenLeaderAge) {
            family.leaderAge = chosenLeaderAge;
          }
          if (chosenLeaderPhone) {
            family.leaderPhone = chosenLeaderPhone;
          }

          // Remove the new leader from family.members so they aren't listed as both leader and child member
          family.members = family.members.filter(
            (m) =>
              (targetFm ? m._id.toString() !== targetFm._id.toString() : true) &&
              (!m.userId || m.userId.toString() !== actualUserId.toString()) &&
              (!newFamilyLeaderId || !m._id || m._id.toString() !== newFamilyLeaderId.toString()) &&
              (!newFamilyLeaderId || !m.userId || m.userId.toString() !== newFamilyLeaderId.toString()) &&
              (!cleanEmail || !m.email || m.email.toLowerCase() !== cleanEmail)
          );
          await family.save();

          await TripParticipant.findOneAndUpdate(
            { tripId, userId: actualUserId },
            {
              role: "familyLeader",
              status: "approved",
              familyId: family._id,
              name: chosenLeaderName || null,
              leftAt: null,
              permissions: {
                manageTrip: false,
                manageParticipants: false,
                manageFamily: true,
                manageItinerary: false,
                managePolls: false,
                manageDocuments: false,
                manageExpenses: false,
                managePhotos: false,
              },
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
          );

          participant.status = "left";
          participant.leftAt = new Date();
          if (departingLeaderName) {
            participant.name = departingLeaderName;
          }
          await participant.save();
          return res.status(200).json({ success: true, message: "Family leadership transferred and you have left the trip successfully." });
        } else {
          return res.status(400).json({
            success: false,
            message: "Please specify whether you want to leave with your full family or only yourself.",
          });
        }
      }

      // D. Trip Leader
      if (participant.role === "tripLeader") {
        const myFamily = await Family.findOne({ tripId, familyLeaderId: userId });
        const activeFamilyMembers = myFamily
          ? myFamily.members.filter((m) => m.status !== "removed" && m.status !== "left")
          : [];
        const isWithFamily = activeFamilyMembers.length > 0;

        // Subcase 1: Trip Leader is Solo Traveler (no family)
        if (!isWithFamily) {
          const eligibleLeaders = await TripParticipant.find({
            tripId,
            userId: { $ne: userId },
            status: "approved",
            role: { $in: ["soloTraveler", "familyLeader"] },
          });

          if (eligibleLeaders.length === 0) {
            participant.status = "left";
            participant.leftAt = new Date();
            await participant.save();
            trip.status = "cancelled";
            await trip.save();
            return res.status(200).json({ success: true, message: "You were the only leader. The trip has been cancelled and you have left." });
          }

          if (!newTripLeaderId) {
            return res.status(400).json({
              success: false,
              message: "Please assign the Trip Leader position to another Solo Traveler or Family Leader.",
            });
          }

          const chosenLeader = eligibleLeaders.find(
            (p) => p.userId.toString() === newTripLeaderId.toString()
          );

          if (!chosenLeader) {
            return res.status(400).json({
              success: false,
              message: "The chosen user must be an approved Solo Traveler or Family Leader.",
            });
          }

          chosenLeader.role = "tripLeader";
          chosenLeader.permissions = {
            manageTrip: true,
            manageParticipants: true,
            manageFamily: true,
            manageItinerary: true,
            managePolls: true,
            manageDocuments: true,
            manageExpenses: true,
            managePhotos: true,
          };
          await chosenLeader.save();

          const departingSoloLeaderName = participant.name || (req.user ? `${req.user.firstName} ${req.user.lastName}`.trim() : null);
          trip.createdBy = chosenLeader.userId;
          await trip.save();

          participant.status = "left";
          participant.leftAt = new Date();
          if (departingSoloLeaderName) {
            participant.name = departingSoloLeaderName;
          }
          await participant.save();
          return res.status(200).json({ success: true, message: "Leadership transferred and you have left the trip successfully." });
        }

        // Subcase 2: Trip Leader is WITH Family
        if (leaveType === "full_family") {
          for (const m of activeFamilyMembers) {
            m.status = "left";
            m.leftAt = new Date();
            if (m.userId) {
              await TripParticipant.updateOne(
                { tripId, userId: m.userId, status: "approved" },
                { $set: { status: "left", leftAt: new Date(), name: m.name } }
              );
            }
          }
          await myFamily.save();

          // Trip Leader position must be assigned to an outside Family Leader or Solo Traveler
          const familyUserIds = activeFamilyMembers
            .map((m) => (m.userId ? m.userId.toString() : null))
            .filter(Boolean);
          familyUserIds.push(userId.toString());

          const outsideLeaders = await TripParticipant.find({
            tripId,
            userId: { $nin: familyUserIds },
            status: "approved",
            role: { $in: ["soloTraveler", "familyLeader"] },
          });

          const departingLeaderName = myFamily.leaderName || participant.name || (req.user ? `${req.user.firstName} ${req.user.lastName}`.trim() : null);

          if (outsideLeaders.length === 0) {
            participant.status = "left";
            participant.leftAt = new Date();
            if (departingLeaderName) {
              participant.name = departingLeaderName;
            }
            await participant.save();
            trip.status = "cancelled";
            await trip.save();
            return res.status(200).json({ success: true, message: "You and your family have left. The trip has been cancelled." });
          }

          if (!newTripLeaderId) {
            return res.status(400).json({
              success: false,
              message: "Please assign the Trip Leader position to another Family Leader or Solo Traveler.",
            });
          }

          const chosenLeader = outsideLeaders.find(
            (p) => p.userId.toString() === newTripLeaderId.toString()
          );

          if (!chosenLeader) {
            return res.status(400).json({
              success: false,
              message: "Selected user is not an eligible Family Leader or Solo Traveler outside your family.",
            });
          }

          chosenLeader.role = "tripLeader";
          await chosenLeader.save();

          trip.createdBy = chosenLeader.userId;
          await trip.save();

          participant.status = "left";
          participant.leftAt = new Date();
          if (departingLeaderName) {
            participant.name = departingLeaderName;
          }
          await participant.save();
          return res.status(200).json({ success: true, message: "You and your family have left the trip. Trip leadership transferred." });

        } else if (leaveType === "only_me") {
          // 1. Assign Family Leader position to another own family member
          let candidateFmUserId = newFamilyLeaderId;
          let regUser = null;
          const cleanEmail = newFamilyLeaderEmail ? newFamilyLeaderEmail.trim().toLowerCase() : null;

          if (cleanEmail) {
            regUser = await User.findOne({ email: cleanEmail });
            if (!regUser) {
              return res.status(400).json({
                success: false,
                message: `Email ${newFamilyLeaderEmail} is not registered in the app.`,
              });
            }
          }

          let targetFm = myFamily.members.find(
            (m) =>
              (newFamilyLeaderId && m._id && m._id.toString() === newFamilyLeaderId.toString()) ||
              (newFamilyLeaderId && m.userId && m.userId.toString() === newFamilyLeaderId.toString()) ||
              (regUser && m.userId && m.userId.toString() === regUser._id.toString()) ||
              (cleanEmail && m.email && m.email.toLowerCase() === cleanEmail)
          );

          if (!targetFm && regUser) {
            targetFm = myFamily.members.find(m => 
              m.name && regUser.firstName && m.name.trim().toLowerCase() === regUser.firstName.trim().toLowerCase()
            );
            if (!targetFm && myFamily.members.length === 1) {
              targetFm = myFamily.members[0];
            }
          }

          let chosenLeaderName = null;
          let chosenLeaderAge = null;
          let chosenLeaderPhone = null;

          if (targetFm) {
            chosenLeaderName = targetFm.name;
            chosenLeaderAge = targetFm.age;
            chosenLeaderPhone = targetFm.phone;
            if (regUser) {
              targetFm.userId = regUser._id;
              targetFm.email = regUser.email;
              candidateFmUserId = regUser._id.toString();
            } else if (targetFm.userId) {
              candidateFmUserId = targetFm.userId.toString();
            } else if (targetFm.email) {
              regUser = await User.findOne({ email: targetFm.email.toLowerCase() });
              if (regUser) {
                targetFm.userId = regUser._id;
                candidateFmUserId = regUser._id.toString();
              }
            }
          } else if (regUser) {
            candidateFmUserId = regUser._id.toString();
          }

          if (!candidateFmUserId) {
            return res.status(400).json({
              success: false,
              message: "Please select a family member with an app account to assign as Family Leader.",
            });
          }

          const actualFmUserId = regUser ? regUser._id : (targetFm?.userId || candidateFmUserId);

          if (!actualFmUserId) {
            return res.status(400).json({
              success: false,
              message: "Selected family member must be part of your family and registered in the app.",
            });
          }

          // Capture departing trip leader's name BEFORE updating myFamily.leaderName!
          const departingTripLeaderName = myFamily.leaderName || participant.name || (req.user ? `${req.user.firstName} ${req.user.lastName}`.trim() : null);

          myFamily.familyLeaderId = actualFmUserId;
          if (chosenLeaderName) {
            myFamily.leaderName = chosenLeaderName;
          }
          if (chosenLeaderAge) {
            myFamily.leaderAge = chosenLeaderAge;
          }
          if (chosenLeaderPhone) {
            myFamily.leaderPhone = chosenLeaderPhone;
          }
          myFamily.members = myFamily.members.filter(
            (m) =>
              (targetFm ? m._id.toString() !== targetFm._id.toString() : true) &&
              (!m.userId || m.userId.toString() !== actualFmUserId.toString()) &&
              (!newFamilyLeaderId || !m._id || m._id.toString() !== newFamilyLeaderId.toString()) &&
              (!newFamilyLeaderId || !m.userId || m.userId.toString() !== newFamilyLeaderId.toString()) &&
              (!cleanEmail || !m.email || m.email.toLowerCase() !== cleanEmail)
          );
          await myFamily.save();

          await TripParticipant.findOneAndUpdate(
            { tripId, userId: actualFmUserId },
            {
              role: "familyLeader",
              status: "approved",
              familyId: myFamily._id,
              name: chosenLeaderName || null,
              leftAt: null,
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
          );

          // 2. Assign Trip Leader position to another Family Leader (including the newly appointed one) or Solo Traveler
          if (!newTripLeaderId) {
            return res.status(400).json({
              success: false,
              message: "Please assign the Trip Leader position to another Family Leader or Solo Traveler.",
            });
          }

          const isPromotingNewFmLeader = (
            newTripLeaderId.toString() === actualFmUserId.toString() ||
            (targetFm && targetFm._id && targetFm._id.toString() === newTripLeaderId.toString()) ||
            (targetFm && targetFm.userId && targetFm.userId.toString() === newTripLeaderId.toString()) ||
            newTripLeaderId.toString() === newFamilyLeaderId?.toString()
          );

          let chosenTripLeader = null;
          if (isPromotingNewFmLeader) {
            chosenTripLeader = await TripParticipant.findOne({ tripId, userId: actualFmUserId });
          } else {
            const eligibleLeaders = await TripParticipant.find({
              tripId,
              userId: { $ne: userId },
              status: "approved",
              role: { $in: ["soloTraveler", "familyLeader"] },
            });

            chosenTripLeader = eligibleLeaders.find(
              (p) => p.userId.toString() === newTripLeaderId.toString()
            );
          }

          if (!chosenTripLeader) {
            return res.status(400).json({
              success: false,
              message: "The chosen Trip Leader must be an approved Solo Traveler or Family Leader.",
            });
          }

          chosenTripLeader.role = "tripLeader";
          chosenTripLeader.permissions = {
            manageTrip: true,
            manageParticipants: true,
            manageFamily: true,
            manageItinerary: true,
            managePolls: true,
            manageDocuments: true,
            manageExpenses: true,
            managePhotos: true,
          };
          await chosenTripLeader.save();

          trip.createdBy = chosenTripLeader.userId;
          await trip.save();

          participant.status = "left";
          participant.leftAt = new Date();
          if (departingTripLeaderName) {
            participant.name = departingTripLeaderName;
          }
          await participant.save();
          return res.status(200).json({
            success: true,
            message: "Family and Trip leadership transferred, and you have left the trip successfully.",
          });
        } else {
          return res.status(400).json({
            success: false,
            message: "Please choose whether to leave with your full family or only yourself.",
          });
        }
      }
    }

    res.status(400).json({ success: false, message: "Unhandled trip leave scenario." });
  } catch (error) {
    console.error("Error in leaveTrip:", error);
    res.status(500).json({ success: false, message: "Server error while leaving trip." });
  }
};
