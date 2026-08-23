// Trip routes

import express from "express";
import { createTrip, getInviteInfo, joinTrip, getUserTrips, updateTrip, getAllPendingRequests, deleteTrip } from "../controllers/tripController.js";
import { protect } from "../middleware/authMiddleware.js";
import upload from "../middleware/uploadMiddleware.js";

const router = express.Router();

router.post("/", protect, upload.single("coverImage"), createTrip);
router.get("/", protect, getUserTrips);
router.get("/all-pending-requests", protect, getAllPendingRequests);
router.get("/invite/:inviteToken", getInviteInfo);
router.post("/join", protect, joinTrip);
router.put("/:tripId", protect, upload.single("coverImage"), updateTrip);
router.delete("/:tripId", protect, deleteTrip);

export default router;
