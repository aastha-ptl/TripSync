import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { getMyFamily, updateMyFamily, checkMemberEmail } from "../controllers/familyController.js";

const router = express.Router({ mergeParams: true });

router.get("/my-family", protect, getMyFamily);
router.get("/check-email", protect, checkMemberEmail);
router.post("/members", protect, updateMyFamily);
router.put("/", protect, updateMyFamily);

export default router;
