import Photo from "../models/Photo.js";
import TripParticipant from "../models/TripParticipant.js";

export const uploadPhoto = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { visibility } = req.body;
    let permittedUsers = [];

    if (visibility === "SelectedMembers" && req.body.permittedUsers) {
      // It might be a JSON string from form-data
      if (typeof req.body.permittedUsers === "string") {
        permittedUsers = JSON.parse(req.body.permittedUsers);
      } else {
        permittedUsers = req.body.permittedUsers;
      }
    }

    if (!req.file) {
      return res.status(400).json({ success: false, message: "No photo uploaded" });
    }

    // Verify user is a participant
    const participant = await TripParticipant.findOne({ tripId, userId: req.user._id, status: "approved" });
    if (!participant) {
      return res.status(403).json({ success: false, message: "You are not a participant of this trip" });
    }

    const photo = new Photo({
      tripId,
      uploaderId: req.user._id,
      photoUrl: req.file.path,
      visibility,
      permittedUsers,
    });

    await photo.save();
    
    // Populate uploader details to return to the frontend
    await photo.populate("uploaderId", "firstName lastName email profilePhoto");

    res.status(201).json({
      success: true,
      message: "Photo uploaded successfully",
      photo,
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

    res.status(200).json({
      success: true,
      photos,
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
