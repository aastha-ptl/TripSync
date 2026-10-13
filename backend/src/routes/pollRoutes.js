import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
  getTripPolls,
  createPoll,
  votePoll,
  editPoll,
  deletePoll,
  getPollVoters,
} from "../controllers/pollController.js";

const router = express.Router({ mergeParams: true });

router.use(protect);

router.route("/")
  .get(getTripPolls)
  .post(createPoll);

router.route("/:pollId")
  .put(editPoll)
  .delete(deletePoll);

router.route("/:pollId/vote")
  .post(votePoll);

router.route("/:pollId/voters")
  .get(getPollVoters);

export default router;
