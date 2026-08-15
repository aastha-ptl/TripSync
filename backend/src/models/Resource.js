import mongoose from "mongoose";

const resourceSchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    uploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    resourceType: {
      type: String,
      enum: ["document", "photo"],
      required: true,
    },

    category: {
      type: String,
      enum: [
        "personalDocument",
        "travelDocument",
        "ticket",
        "identityProof",
        "hotelBooking",
        "other",
        "gallery",
      ],
      default: "other",
    },

    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },

    fileUrl: {
      type: String,
      required: true,
      trim: true,
    },

    thumbnailUrl: {
      type: String,
      default: null,
      trim: true,
    },

    fileType: {
      type: String,
      default: null,
      trim: true,
    },

    fileSize: {
      type: Number,
      default: 0,
      min: 0,
    },

    description: {
      type: String,
      default: "",
      trim: true,
    },

    visibility: {
      type: String,
      enum: ["private", "trip", "family", "selectedUsers"],
      default: "private",
    },

    familyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Family",
      default: null,
      index: true,
    },

    sharedWith: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Resource", resourceSchema);
