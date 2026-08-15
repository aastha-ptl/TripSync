import mongoose from "mongoose";
import env from "./env.js";

mongoose.set("strictQuery", true);

const connectDB = async () => {
  try {
    if (!env.MONGODB_URI) {
      throw new Error("MONGODB_URI is not defined in environment variables.");
    }

    await mongoose.connect(env.MONGODB_URI, {
      serverSelectionTimeoutMS: 10000,
      maxPoolSize: 10,
      socketTimeoutMS: 45000,
      family: 4,
    });

    console.log(`MongoDB connected successfully: ${mongoose.connection.host}`);
    return mongoose.connection;
  } catch (error) {
    console.error("MongoDB connection failed:", error.message);
    process.exit(1);
  }
};

export { connectDB };
