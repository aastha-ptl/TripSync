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

    tripType: {
      type: String,
      enum: ["Friends", "Family", "Business"],
      required: true,
    },

    businessTripType: {
      type: String,
      enum: ["Employees Only", "Employees + Family"],
      default: null,
    },

    coverImage: {
      type: String,
      default: null,
    },

    startDate: {
      type: String,
      required: true,
      match: [/^\d{4}-\d{2}-\d{2}$/, 'Please use YYYY-MM-DD format'],
    },

    endDate: {
      type: String,
      required: true,
      match: [/^\d{4}-\d{2}-\d{2}$/, 'Please use YYYY-MM-DD format'],
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
