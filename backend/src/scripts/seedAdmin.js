import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import User from "../models/User.js";
import env from "../config/env.js";

async function seedAdmin() {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log("Connected to MongoDB");

    const email = process.argv[2] || "admin@tripsync.app";
    const password = process.argv[3] || "Admin@123456";

    let admin = await User.findOne({ email });

    const passwordHash = await bcrypt.hash(password, 10);

    if (admin) {
      admin.role = "admin";
      admin.accountStatus = "active";
      admin.isActive = true;
      admin.passwordHash = passwordHash;
      await admin.save();
      console.log(`[SUCCESS] Existing user ${email} upgraded to administrator.`);
    } else {
      admin = await User.create({
        firstName: "System",
        lastName: "Admin",
        email,
        passwordHash,
        authProvider: "local",
        role: "admin",
        accountStatus: "active",
        isActive: true,
        isEmailVerified: true,
      });
      console.log(`[SUCCESS] New admin created: ${email}`);
    }

    console.log(`Login credentials:\n  Email: ${email}\n  Password: ${password}`);
    process.exit(0);
  } catch (err) {
    console.error("[ERROR] Failed to seed admin:", err);
    process.exit(1);
  }
}

seedAdmin();
