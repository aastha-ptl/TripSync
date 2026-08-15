import mongoose from "mongoose";

const refreshTokenSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    tokenHash: {
      type: String,
      required: true,
      trim: true,
    },

    expiresAt: {
      type: Date,
      required: true,
      index: true,
    },

    deviceId: {
      type: String,
      default: null,
      trim: true,
    },

    deviceName: {
      type: String,
      default: null,
      trim: true,
    },

    ipAddress: {
      type: String,
      default: null,
      trim: true,
    },

    revoked: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("RefreshToken", refreshTokenSchema);
