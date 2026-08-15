import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      default: null,
      index: true,
    },

    type: {
      type: String,
      enum: [
        "joinRequest",
        "requestApproved",
        "requestRejected",
        "tripUpdate",
        "itineraryUpdate",
        "newMessage",
        "pollCreated",
        "pollResult",
        "documentShared",
        "expenseAdded",
        "familyInvitation",
        "locationUpdate",
      ],
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 150,
    },

    message: {
      type: String,
      required: true,
      trim: true,
    },

    referenceId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
      index: true,
    },

    referenceType: {
      type: String,
      default: null,
      trim: true,
    },

    isRead: {
      type: Boolean,
      default: false,
    },

    readAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Notification", notificationSchema);
