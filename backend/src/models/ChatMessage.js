import mongoose from "mongoose";

const readReceiptSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    readAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false }
);

const chatMessageSchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    chatType: {
      type: String,
      enum: ["group", "family"],
      required: true,
    },

    familyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Family",
      default: null,
      index: true,
    },

    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    messageType: {
      type: String,
      enum: ["text", "image", "document", "location"],
      default: "text",
    },

    message: {
      type: String,
      default: "",
      trim: true,
    },

    fileUrl: {
      type: String,
      default: null,
    },

    fileName: {
      type: String,
      default: null,
      trim: true,
    },

    location: {
      latitude: {
        type: Number,
        default: null,
      },
      longitude: {
        type: Number,
        default: null,
      },
    },

    replyTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "ChatMessage",
      default: null,
      index: true,
    },

    isDeleted: {
      type: Boolean,
      default: false,
    },

    readBy: [readReceiptSchema],
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("ChatMessage", chatMessageSchema);
