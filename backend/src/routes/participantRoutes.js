import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  getTripParticipants,
  getJoinRequests,
  updateJoinRequest,
  leaveTrip,
  removeFamilyMember,
} from "../controllers/participantController.js";

const router = express.Router({ mergeParams: true });

// Routes are prefixed with /api/trips/:tripId in app.js
router.get("/participants", protect, getTripParticipants);
router.get("/requests", protect, getJoinRequests);
router.put("/requests/:requestId", protect, updateJoinRequest);
router.post("/leave", protect, leaveTrip);
router.post("/remove-family-member", protect, removeFamilyMember);

export default router;
