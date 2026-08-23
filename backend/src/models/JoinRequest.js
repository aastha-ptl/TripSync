import mongoose from "mongoose";

const joinRequestSchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    requestedRole: {
      type: String,
      enum: ["soloTraveler", "familyLeader"],
      required: true,
    },

    familyMembers: [
      {
        name: { type: String, trim: true, required: true },
        age: { type: Number, required: true },
        relationship: { type: String, trim: true, required: true },
        email: { type: String, trim: true, default: null },
        phone: { type: String, trim: true, default: null },
      },
    ],

    familyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Family",
      default: null,
      index: true,
    },

    invitationCode: {
      type: String,
      default: null,
      trim: true,
    },

    requestedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "cancelled"],
      default: "pending",
    },

    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true,
    },

    reviewedAt: {
      type: Date,
      default: null,
    },

    rejectionReason: {
      type: String,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

joinRequestSchema.index({ tripId: 1, userId: 1 }, { unique: false });

export default mongoose.model("JoinRequest", joinRequestSchema);
