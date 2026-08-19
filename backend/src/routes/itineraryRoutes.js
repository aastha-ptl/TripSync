import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { addActivity, getItinerary } from "../controllers/itineraryController.js";

const router = express.Router({ mergeParams: true });

// Routes for /api/trips/:tripId/itinerary
router.use(protect);

router.post("/events", addActivity);
router.get("/", getItinerary);

export default router;
