import { Server } from "socket.io";
import env from "./config/env.js";

let io;

export const initSocket = (server) => {
  io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
      credentials: true,
    },
  });

  io.on("connection", (socket) => {
    console.log(`[Socket.io] Client connected: ${socket.id}`);

    // Join user room for personal notifications
    socket.on("join_user_room", (userId) => {
      if (userId) {
        const roomName = `user_${userId.toString().trim()}`;
        socket.join(roomName);
        console.log(`[Socket.io] Socket ${socket.id} joined user room ${roomName}`);
      }
    });

    // Leave user room
    socket.on("leave_user_room", (userId) => {
      if (userId) {
        const roomName = `user_${userId.toString().trim()}`;
        socket.leave(roomName);
        console.log(`[Socket.io] Socket ${socket.id} left user room ${roomName}`);
      }
    });

    // Join trip room for announcements and group chat
    socket.on("join_trip_room", (tripId) => {
      if (tripId) {
        const roomName = `trip_${tripId.toString().trim()}`;
        socket.join(roomName);
        console.log(`[Socket.io] Socket ${socket.id} joined trip room ${roomName}`);
      }
    });

    // Leave trip room
    socket.on("leave_trip_room", (tripId) => {
      if (tripId) {
        const roomName = `trip_${tripId.toString().trim()}`;
        socket.leave(roomName);
        console.log(`[Socket.io] Socket ${socket.id} left trip room ${roomName}`);
      }
    });

    socket.on("disconnect", () => {
      console.log(`[Socket.io] Client disconnected: ${socket.id}`);
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    throw new Error("Socket.io not initialized!");
  }
  return io;
};

export const emitToUserRoom = (userId, event, data) => {
  if (io && userId) {
    const roomName = `user_${userId.toString().trim()}`;
    io.to(roomName).emit(event, data);
    console.log(`[Socket.io] Emitted '${event}' to user room ${roomName}`);
  }
};

export const emitToTripRoom = (tripId, event, data) => {
  if (io && tripId) {
    const roomName = `trip_${tripId.toString().trim()}`;
    io.to(roomName).emit(event, data);
    console.log(`[Socket.io] Emitted '${event}' to trip room ${roomName}`);
  }
};

