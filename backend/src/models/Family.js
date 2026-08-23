import mongoose from "mongoose";

const familySchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    familyLeaderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    members: [
      {
        name: { type: String, trim: true, required: true },
        age: { type: Number, required: true },
        relationship: { type: String, trim: true, required: true },
        email: { type: String, trim: true, default: null },
        phone: { type: String, trim: true, default: null },
        userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
      }
    ]
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Family", familySchema);
