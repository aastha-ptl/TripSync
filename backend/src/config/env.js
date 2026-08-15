import dotenv from "dotenv";

dotenv.config();

const env = {
  NODE_ENV: process.env.NODE_ENV || "development",
  PORT: Number(process.env.PORT) || 5000,

  MONGODB_URI:
    process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/tripsync",

  JWT_SECRET: process.env.JWT_SECRET || "",
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || "15m",

  REFRESH_TOKEN_SECRET:
    process.env.REFRESH_TOKEN_SECRET || process.env.JWT_REFRESH_SECRET || "",
  REFRESH_TOKEN_EXPIRES_IN:
    process.env.REFRESH_TOKEN_EXPIRES_IN || process.env.JWT_REFRESH_EXPIRES_IN || "7d",

  JWT_REFRESH_SECRET:
    process.env.REFRESH_TOKEN_SECRET || process.env.JWT_REFRESH_SECRET || "",
  JWT_REFRESH_EXPIRES_IN:
    process.env.REFRESH_TOKEN_EXPIRES_IN || process.env.JWT_REFRESH_EXPIRES_IN || "7d",

  GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID || "",

  CLIENT_URL: process.env.CLIENT_URL || "http://localhost:3000",

  SMTP_HOST: process.env.SMTP_HOST || "smtp.gmail.com",
  SMTP_PORT: Number(process.env.SMTP_PORT) || 587,
  SMTP_USER: process.env.SMTP_USER || "",
  SMTP_PASSWORD: process.env.SMTP_PASSWORD || "",
  EMAIL_FROM: process.env.EMAIL_FROM || "TripSync <noreply@tripsync.app>",

  OTP_EXPIRES_IN_MINUTES: Number(process.env.OTP_EXPIRES_IN_MINUTES) || 10,
  OTP_MAX_ATTEMPTS: Number(process.env.OTP_MAX_ATTEMPTS) || 5,

  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || "",
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || "",
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET || "",

  MAX_FILE_SIZE: Number(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024,
  LOG_LEVEL: process.env.LOG_LEVEL || "info",

  FILE_UPLOAD_PATH: process.env.FILE_UPLOAD_PATH || "uploads",
  ALLOWED_FILE_TYPES: process.env.ALLOWED_FILE_TYPES || "jpg,jpeg,png,pdf,doc,docx,xlsx,csv",
  IMAGE_UPLOAD_SIZE_LIMIT: Number(process.env.IMAGE_UPLOAD_SIZE_LIMIT) || 5 * 1024 * 1024,
  DOCUMENT_UPLOAD_SIZE_LIMIT: Number(process.env.DOCUMENT_UPLOAD_SIZE_LIMIT) || 10 * 1024 * 1024,
};

export default env;
