import http from "http";
import app from "./src/app.js";
import { connectDB } from "./src/config/db.js";
import env from "./src/config/env.js";
import { initSocket } from "./src/socket.js";

const startServer = async () => {
  try {
    await connectDB();

    const server = http.createServer(app);
    initSocket(server);

    server.listen(env.PORT, "0.0.0.0", () => {
      console.log(`TripSync API & Socket.IO server running on port ${env.PORT}`);
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
