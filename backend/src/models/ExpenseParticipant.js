import mongoose from "mongoose";

const expenseParticipantSchema = new mongoose.Schema(
  {
    expenseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Expense",
      required: true,
      index: true,
    },

    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    participantType: {
      type: String,
      enum: ["user", "guest"],
      required: true,
      default: "user",
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true,
    },

    guestId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
      index: true,
    },

    guestName: {
      type: String,
      default: null,
      trim: true,
    },

    shareAmount: {
      type: Number,
      default: 0,
      min: 0,
    },

    sharePercentage: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },

    paidAmount: {
      type: Number,
      default: 0,
      min: 0,
    },

    settlementStatus: {
      type: String,
      enum: ["pending", "settled"],
      default: "pending",
    },

    settledAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

expenseParticipantSchema.index({ expenseId: 1, userId: 1, guestId: 1 }, { unique: true });

export default mongoose.model("ExpenseParticipant", expenseParticipantSchema);
