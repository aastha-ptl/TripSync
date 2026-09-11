import express from "express";
import { uploadPhoto, getTripPhotos } from "../controllers/photoController.js";
import { protect } from "../middleware/authMiddleware.js";
import photoUploadMiddleware from "../middleware/photoUploadMiddleware.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

router.post("/", photoUploadMiddleware.single("photo"), uploadPhoto);
router.get("/", getTripPhotos);

export default router;
