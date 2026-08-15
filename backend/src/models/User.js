import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    // =====================================
    // BASIC USER INFORMATION
    // =====================================

    firstName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 50,
    },

    lastName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 50,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },

    phone: {
      type: String,
      required: true,
      trim: true,
    },

    profilePhoto: {
      type: String,
      default: null,
    },

    dateOfBirth: {
      type: Date,
      default: null,
    },

    gender: {
      type: String,
      enum: [
        "male",
        "female",
        "other",
        "prefer_not_to_say",
      ],
      default: "prefer_not_to_say",
    },

    // =====================================
    // AUTHENTICATION
    // =====================================

    authProvider: {
      type: String,
      enum: ["local", "google"],
      required: true,
    },

    passwordHash: {
      type: String,
      default: null,
      select: false,
    },

    googleId: {
      type: String,
      unique: true,
      sparse: true,
      select: false,
    },

    // =====================================
    // EMAIL VERIFICATION
    // =====================================

    isEmailVerified: {
      type: Boolean,
      default: false,
    },

    // =====================================
    // ACCOUNT STATUS
    // =====================================

    accountStatus: {
      type: String,
      enum: [
        "pending_verification",
        "active",
        "suspended",
        "deleted",
      ],
      default: "pending_verification",
    },

    isActive: {
      type: Boolean,
      default: true,
    },

    lastLoginAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("User", userSchema);