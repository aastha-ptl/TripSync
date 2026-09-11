import Photo from "../models/Photo.js";
import TripParticipant from "../models/TripParticipant.js";
import Family from "../models/Family.js";

// Helper to resolve trip names for participants and family members
const buildTripNameMap = async (tripId) => {
  try {
    const participants = await TripParticipant.find({ tripId, status: "approved" })
      .populate("userId", "firstName lastName email profilePhoto")
      .lean();
    const families = await Family.find({ tripId }).lean();

    const nameMap = {};

    // Default: registered user full name
    for (const p of participants) {
      if (p.userId) {
        const uId = p.userId._id ? p.userId._id.toString() : p.userId.toString();
        const fullName = `${p.userId.firstName || ""} ${p.userId.lastName || ""}`.trim();
        nameMap[uId] = fullName || "Unknown User";
      }
    }

    // Override with Family member name if specified in this trip
    for (const f of families) {
      if (f.members && Array.isArray(f.members)) {
        for (const m of f.members) {
          if (m.userId && m.name) {
            nameMap[m.userId.toString()] = m.name;
          }
          if (m.email && m.name) {
            const matched = participants.find(
              (p) => p.userId && p.userId.email && p.userId.email.toLowerCase() === m.email.toLowerCase()
            );
            if (matched && matched.userId) {
              const uId = matched.userId._id ? matched.userId._id.toString() : matched.userId.toString();
              nameMap[uId] = m.name;
            }
          }
        }
      }
    }

    return nameMap;
  } catch (err) {
    console.error("Error building trip name map:", err);
    return {};
  }
};

export const uploadPhoto = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { visibility } = req.body;
    let permittedUsers = [];

    if (visibility === "SelectedMembers" && req.body.permittedUsers) {
      if (typeof req.body.permittedUsers === "string") {
        permittedUsers = JSON.parse(req.body.permittedUsers);
      } else {
        permittedUsers = req.body.permittedUsers;
      }
    }

    // Support both single file and multiple files
    let files = [];
    if (Array.isArray(req.files) && req.files.length > 0) {
      files = req.files;
    } else if (req.files && typeof req.files === "object") {
      files = [...(req.files.photos || []), ...(req.files.photo || [])];
    } else if (req.file) {
      files = [req.file];
    }

    if (!files || files.length === 0) {
      return res.status(400).json({ success: false, message: "No photo uploaded" });
    }

    // Verify user is a participant
    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: "approved" });
    if (!participant) {
      return res.status(403).json({ success: false, message: "You are not a participant of this trip" });
    }

    const nameMap = await buildTripNameMap(tripId);
    const createdPhotos = [];

    for (const file of files) {
      const photo = new Photo({
        tripId,
        uploaderId: req.user._id,
        photoUrl: file.path,
        visibility,
        permittedUsers,
      });

      await photo.save();
      await photo.populate("uploaderId", "firstName lastName email profilePhoto");

      const photoObj = photo.toObject();
      if (photoObj.uploaderId && typeof photoObj.uploaderId === "object") {
        const uId = photoObj.uploaderId._id ? photoObj.uploaderId._id.toString() : photoObj.uploaderId.toString();
        if (uId && nameMap[uId]) {
          photoObj.uploaderId.name = nameMap[uId];
        } else {
          photoObj.uploaderId.name = `${photoObj.uploaderId.firstName || ""} ${photoObj.uploaderId.lastName || ""}`.trim() || "Unknown User";
        }
      }
      createdPhotos.push(photoObj);
    }

    res.status(201).json({
      success: true,
      message: `${createdPhotos.length} photo(s) uploaded successfully`,
      photos: createdPhotos,
      photo: createdPhotos[0],
    });
  } catch (error) {
    console.error("Upload photo error:", error);
    res.status(500).json({
      success: false,
      message: "Error uploading photo",
      error: error.message,
    });
  }
};

export const getTripPhotos = async (req, res) => {
  try {
    const { tripId } = req.params;

    // Verify user is a participant
    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: "approved" });
    if (!participant) {
      return res.status(403).json({ success: false, message: "You are not a participant of this trip" });
    }

    const photos = await Photo.find({
      tripId,
      $or: [
        { visibility: "Everyone" },
        { uploaderId: req.user._id },
        { permittedUsers: { $in: [req.user._id] } }
      ]
    }).populate("uploaderId", "firstName lastName email profilePhoto").sort({ createdAt: -1 });

    const nameMap = await buildTripNameMap(tripId);

    const formattedPhotos = photos.map((photo) => {
      const p = photo.toObject();
      if (p.uploaderId && typeof p.uploaderId === "object") {
        const uId = p.uploaderId._id ? p.uploaderId._id.toString() : p.uploaderId.toString();
        if (uId && nameMap[uId]) {
          p.uploaderId.name = nameMap[uId];
        } else {
          p.uploaderId.name = `${p.uploaderId.firstName || ""} ${p.uploaderId.lastName || ""}`.trim() || "Unknown User";
        }
      }
      return p;
    });

    res.status(200).json({
      success: true,
      photos: formattedPhotos,
    });
  } catch (error) {
    console.error("Get trip photos error:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving photos",
      error: error.message,
    });
  }
};

export const deletePhoto = async (req, res) => {
  try {
    const { tripId, photoId } = req.params;

    const photo = await Photo.findOne({ _id: photoId, tripId });
    if (!photo) {
      return res.status(404).json({ success: false, message: "Photo not found" });
    }

    // Check if current user is the uploader or tripLeader
    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: "approved" });
    const isLeader = participant && participant.role === "tripLeader";
    const isUploader = photo.uploaderId.toString() === req.user._id.toString();

    if (!isUploader && !isLeader) {
      return res.status(403).json({ success: false, message: "You are not authorized to delete this photo" });
    }

    await Photo.findByIdAndDelete(photoId);

    res.status(200).json({
      success: true,
      message: "Photo deleted successfully",
    });
  } catch (error) {
    console.error("Delete photo error:", error);
    res.status(500).json({
      success: false,
      message: "Error deleting photo",
      error: error.message,
    });
  }
};
