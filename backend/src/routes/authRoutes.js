import express from "express";
import { register, login, verifyOTP, resendOTP, forgotPassword, verifyForgotPasswordOtp, resetPassword, googleLogin } from "../controllers/authController.js";
import upload from "../middleware/uploadMiddleware.js";

const router = express.Router();

router.post("/register", upload.single('profilePhoto'), register);
router.post("/login", login);
router.post("/google", googleLogin);
router.post("/verify-otp", verifyOTP);
router.post("/resend-otp", resendOTP);

router.post("/forgot-password", forgotPassword);
router.post("/verify-forgot-password-otp", verifyForgotPasswordOtp);
router.post("/reset-password", resetPassword);

export default router;
