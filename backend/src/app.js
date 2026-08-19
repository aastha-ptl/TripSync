import express from "express";
import cors from "cors";
import env from "./config/env.js";

const app = express();

app.use(
  cors({
    origin: env.CLIENT_URL,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  })
);

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "TripSync API is running",
  });
});

app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Server healthy",
    timestamp: new Date().toISOString(),
  });
});

import authRoutes from "./routes/authRoutes.js";
import tripRoutes from "./routes/tripRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import participantRoutes from "./routes/participantRoutes.js";
import itineraryRoutes from "./routes/itineraryRoutes.js";

app.use("/api/auth", authRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/trips/:tripId", participantRoutes);
app.use("/api/trips/:tripId/itinerary", itineraryRoutes);
app.use("/api/users", userRoutes);

app.get("/join/:inviteToken", (req, res) => {
  const token = req.params.inviteToken;
  const deepLink = `tripsync://join/${token}`;
  
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>TripSync Invitation</title>
      <style>
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background-color: #F8FAFC;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
        }
        .container {
          background-color: white;
          padding: 40px;
          border-radius: 16px;
          box-shadow: 0 4px 12px rgba(0,0,0,0.1);
          text-align: center;
          max-width: 400px;
          width: 90%;
        }
        h1 {
          color: #1E5AE6;
          margin-bottom: 8px;
        }
        p {
          color: #64748B;
          margin-bottom: 24px;
        }
        .btn {
          display: inline-block;
          background-color: #1E5AE6;
          color: white;
          padding: 14px 24px;
          text-decoration: none;
          border-radius: 8px;
          font-weight: bold;
          font-size: 16px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>TripSync</h1>
        <p>You're invited to join a trip!</p>
        <a href="${deepLink}" class="btn">Open in TripSync</a>
      </div>
      <script>
        setTimeout(function() {
          window.location.href = "${deepLink}";
        }, 500);
      </script>
    </body>
    </html>
  `);
});

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.stack || err.message || err);

  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || "Internal Server Error",
  });
});

export default app;
