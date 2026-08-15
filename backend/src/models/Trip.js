import mongoose from "mongoose";

const tripSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },

    description: {
      type: String,
      default: "",
      trim: true,
    },

    coverImage: {
      type: String,
      default: null,
    },

    startDate: {
      type: Date,
      required: true,
    },

    endDate: {
      type: Date,
      required: true,
    },

    destination: {
      name: {
        type: String,
        trim: true,
      },
      latitude: {
        type: Number,
        default: null,
      },
      longitude: {
        type: Number,
        default: null,
      },
      address: {
        type: String,
        default: "",
        trim: true,
      },
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    invitationCode: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },

    invitationLink: {
      type: String,
      default: null,
    },

    status: {
      type: String,
      enum: ["planning", "ongoing", "completed", "cancelled"],
      default: "planning",
    },

    isActive: {
      type: Boolean,
      default: true,
    },

    settings: {
      allowMemberActivityCreation: {
        type: Boolean,
        default: true,
      },
      allowMemberExpenseCreation: {
        type: Boolean,
        default: true,
      },
      allowMemberPollCreation: {
        type: Boolean,
        default: true,
      },
      allowLocationSharing: {
        type: Boolean,
        default: true,
      },
      allowPhotoSharing: {
        type: Boolean,
        default: true,
      },
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Trip", tripSchema);
