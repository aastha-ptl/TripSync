import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  getTripLocations,
  updateMyLocation,
  toggleLocationSharing,
} from "../controllers/locationController.js";

const router = express.Router({ mergeParams: true });

// All location routes require authentication
router.use(protect);

router.get("/", getTripLocations);
router.post("/update", updateMyLocation);
router.post("/toggle-sharing", toggleLocationSharing);

export default router;
