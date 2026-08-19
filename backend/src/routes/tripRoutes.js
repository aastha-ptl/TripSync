// Trip routes

import express from "express";
import { createTrip, getInviteInfo, joinTrip, getUserTrips } from "../controllers/tripController.js";
import { protect } from "../middleware/authMiddleware.js";
import upload from "../middleware/uploadMiddleware.js";

const router = express.Router();

router.post("/", protect, upload.single("coverImage"), createTrip);
router.get("/", protect, getUserTrips);
router.get("/invite/:inviteToken", getInviteInfo);
router.post("/join", protect, joinTrip);

export default router;
