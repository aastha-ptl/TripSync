import mongoose from "mongoose";

const paidBySchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ["user", "guest"],
      required: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    guestName: {
      type: String,
      default: null,
      trim: true,
    },
  },
  { _id: false }
);

const expenseSchema = new mongoose.Schema(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
      index: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 150,
    },

    description: {
      type: String,
      default: "",
      trim: true,
    },

    amount: {
      type: Number,
      required: true,
      min: 0,
    },

    currency: {
      type: String,
      required: true,
      trim: true,
      uppercase: true,
      maxlength: 10,
    },

    category: {
      type: String,
      enum: ["food", "transport", "hotel", "shopping", "tickets", "other"],
      default: "other",
    },

    paidBy: {
      type: paidBySchema,
      required: true,
    },

    splitType: {
      type: String,
      enum: ["equal", "exact", "percentage"],
      default: "equal",
    },

    date: {
      type: Date,
      required: true,
      default: Date.now,
    },

    receiptUrl: {
      type: String,
      default: null,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Expense", expenseSchema);
