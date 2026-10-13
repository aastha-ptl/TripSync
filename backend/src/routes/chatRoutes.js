import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  getAnnouncements,
  createAnnouncement,
  getGroupMessages,
  sendGroupMessage,
  editMessage,
  deleteMessages,
  getUnreadCount,
  markMessagesAsRead,
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

router.get("/unread-count", getUnreadCount);
router.post("/mark-read", markMessagesAsRead);
router.post("/messages/delete", deleteMessages);
router.put("/messages/:messageId", editMessage);

export default router;
