import mongoose from "mongoose";

const pollVoteSchema = new mongoose.Schema(
  {
    pollId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Poll",
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

    optionId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },

    votedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

pollVoteSchema.index({ pollId: 1, userId: 1, optionId: 1 }, { unique: true });

export default mongoose.model("PollVote", pollVoteSchema);
