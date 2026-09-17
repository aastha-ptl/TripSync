import express from "express";
import cors from "cors";
import path from "path";
import env from "./config/env.js";

const app = express();

app.use(
  cors({
    origin: env.CLIENT_URL,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  })
);

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
app.use(
  '/uploads/expenses',
  express.static(path.join(process.cwd(), 'uploads/expenses'), {
    setHeaders: (res, filePath) => {
      if (filePath.toLowerCase().endsWith('.pdf')) {
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', 'inline');
      }
    },
  })
);
app.use('/uploads/documents', express.static(path.join(process.cwd(), 'uploads/documents')));

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
import expenseRoutes from "./routes/expenseRoutes.js";
import photoRoutes from "./routes/photoRoutes.js";
import familyRoutes from "./routes/familyRoutes.js";

app.use("/api/auth", authRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/trips/:tripId/family", familyRoutes);
app.use("/api/trips/:tripId", participantRoutes);
app.use("/api/trips/:tripId/itinerary", itineraryRoutes);
app.use("/api/trips/:tripId/expenses", expenseRoutes);
app.use("/api/trips/:tripId/photos", photoRoutes);
app.use("/api/users", userRoutes);
import documentRoutes from "./routes/documentRoutes.js";
app.use("/api/documents", documentRoutes);

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
  if (err.name === 'MulterError' || err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      success: false,
      message: err.code === 'LIMIT_FILE_SIZE' 
        ? 'File too large. Maximum allowed file size is 50MB.' 
        : err.message,
    });
  }

  console.error("Unhandled error:", err.stack || err.message || err);

  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || "Internal Server Error",
  });
});

export default app;
