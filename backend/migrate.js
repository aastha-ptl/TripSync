import dotenv from "dotenv";
dotenv.config();
import mongoose from "mongoose";
import TripParticipant from "./src/models/TripParticipant.js";
import JoinRequest from "./src/models/JoinRequest.js";
import env from "./src/config/env.js";

async function migrate() {
  try {
    await mongoose.connect(env.MONGODB_URI);
    const legacyParticipants = await TripParticipant.find({ status: "pending" });
    console.log(`Found ${legacyParticipants.length} legacy pending TripParticipants`);
    for (const lp of legacyParticipants) {
      const existing = await JoinRequest.findOne({ tripId: lp.tripId, userId: lp.userId });
      if (!existing) {
        await JoinRequest.create({
          tripId: lp.tripId,
          userId: lp.userId,
          requestedRole: lp.role || "soloTraveler",
          requestedBy: lp.userId,
          status: "pending",
          invitationCode: null,
        });
        console.log(`Migrated request for user ${lp.userId} on trip ${lp.tripId}`);
      }
      await TripParticipant.deleteOne({ _id: lp._id });
    }
    console.log("Migration complete");
  } catch (error) {
    console.error(error);
  } finally {
    process.exit();
  }
}
migrate();
