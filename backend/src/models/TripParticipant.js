import mongoose from "mongoose";

const tripParticipantSchema = new mongoose.Schema(
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

    role: {
      type: String,
      enum: ["tripLeader", "familyLeader", "familyMember", "soloTraveler"],
      required: true,
      default: "familyMember",
    },

    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "removed", "left"],
      default: "pending",
    },

    familyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Family",
      default: null,
      index: true,
    },

    joinedAt: {
      type: Date,
      default: null,
    },

    permissions: {
      manageTrip: {
        type: Boolean,
        default: false,
      },
      manageParticipants: {
        type: Boolean,
        default: false,
      },
      manageFamily: {
        type: Boolean,
        default: false,
      },
      manageItinerary: {
        type: Boolean,
        default: false,
      },
      managePolls: {
        type: Boolean,
        default: false,
      },
      manageDocuments: {
        type: Boolean,
        default: false,
      },
      manageExpenses: {
        type: Boolean,
        default: false,
      },
      managePhotos: {
        type: Boolean,
        default: false,
      },
    },
  },
  {
    timestamps: true,
  }
);

tripParticipantSchema.index({ tripId: 1, userId: 1 }, { unique: true });

export default mongoose.model("TripParticipant", tripParticipantSchema);
