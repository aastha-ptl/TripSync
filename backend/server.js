import app from "./src/app.js";
import { connectDB } from "./src/config/db.js";
import env from "./src/config/env.js";

const startServer = async () => {
  try {
    await connectDB();

    const server = app.listen(env.PORT, () => {
      console.log(`TripSync API server running on port ${env.PORT}`);
    });

    return server;
  } catch (error) {
    console.error("Server startup failed:", error.message);
    process.exit(1);
  }
};

if (process.env.NODE_ENV !== "test") {
  startServer();
}

export { startServer };
