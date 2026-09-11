import express from "express";
import { uploadPhoto, getTripPhotos, deletePhoto } from "../controllers/photoController.js";
import { protect } from "../middleware/authMiddleware.js";
import photoUploadMiddleware from "../middleware/photoUploadMiddleware.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

router.post("/", photoUploadMiddleware.any(), uploadPhoto);
router.get("/", getTripPhotos);
router.delete("/:photoId", deletePhoto);

export default router;
