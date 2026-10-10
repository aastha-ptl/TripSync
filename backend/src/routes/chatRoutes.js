import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  getAnnouncements,
  createAnnouncement,
  getGroupMessages,
  sendGroupMessage,
} from "../controllers/chatController.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

router
  .route("/announcements")
  .get(getAnnouncements)
  .post(createAnnouncement);

router
  .route("/messages")
  .get(getGroupMessages)
  .post(sendGroupMessage);

export default router;
