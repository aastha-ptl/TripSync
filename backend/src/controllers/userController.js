import User from "../models/User.js";
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

export const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    console.error("Get profile error:", error);
    res.status(500).json({ success: false, message: "Server error fetching profile." });
  }
};

export const updateProfile = async (req, res) => {
  try {
    const { firstName, lastName, phone, gender, dateOfBirth, country, city, bio } = req.body;
    
    const user = await User.findById(req.user._id);
    if (!user) {
      if (req.file) await deleteUploadedFile(req.file);
      return res.status(404).json({ success: false, message: "User not found" });
    }

    if (firstName) user.firstName = firstName;
    if (lastName) user.lastName = lastName;
    if (phone) user.phone = phone;
    if (gender) user.gender = gender;
    if (dateOfBirth) user.dateOfBirth = new Date(dateOfBirth);
    if (country !== undefined) user.country = country;
    if (city !== undefined) user.city = city;
    if (bio !== undefined) user.bio = bio;

    if (req.file && req.file.path) {
      // User uploaded a new profile photo
      user.profilePhoto = req.file.path; // Cloudinary URL
    }

    await user.save();

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      data: user,
    });
  } catch (error) {
    console.error("Update profile error:", error);
    if (req.file) await deleteUploadedFile(req.file);
    res.status(500).json({ success: false, message: "Server error updating profile." });
  }
};
