import mongoose from "mongoose";

const familyMemberSchema = new mongoose.Schema(
  {
    familyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Family",
      required: true,
      index: true,
    },

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

    relationship: {
      type: String,
      enum: ["father", "mother", "brother", "sister", "spouse", "child", "other"],
      default: "other",
    },

    status: {
      type: String,
      enum: ["active", "pending", "removed"],
      default: "pending",
    },

    joinedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

familyMemberSchema.index({ familyId: 1, userId: 1 }, { unique: true });

export default mongoose.model("FamilyMember", familyMemberSchema);
