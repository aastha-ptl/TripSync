import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { addActivity, getItinerary, updateActivity, deleteActivity } from "../controllers/itineraryController.js";

const router = express.Router({ mergeParams: true });

// Routes for /api/trips/:tripId/itinerary
router.use(protect);

router.post("/events", addActivity);
router.get("/", getItinerary);
router.put("/events/:activityId", updateActivity);
router.delete("/events/:activityId", deleteActivity);

export default router;
