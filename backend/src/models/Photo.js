import mongoose from "mongoose";

const photoSchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },
    uploaderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    photoUrl: {
      type: String,
      required: true,
    },
    visibility: {
      type: String,
      enum: ["Everyone", "SelectedMembers"],
      default: "Everyone",
      required: true,
    },
    permittedUsers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Photo", photoSchema);
