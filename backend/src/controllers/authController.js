import bcrypt from "bcryptjs";
import User from "../models/User.js";
import OTP from "../models/OTP.js";
import { generateAccessToken, generateRefreshToken } from "../utils/generateToken.js";
import { sendEmail } from "../services/emailService.js";
import { generateOTPEmailTemplate } from "../utils/emailTemplates.js";

const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

export const register = async (req, res, next) => {
  try {
    const { firstName, lastName, email, phone, password } = req.body;
    const profilePhoto = req.file ? req.file.path : null;

    if (!firstName || !lastName || !email || !phone || !password) {
      return res.status(400).json({ success: false, message: "Please provide all required fields." });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: "Email is already registered." });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const otp = generateOTP();
    await OTP.deleteMany({ email }); // Clear any existing OTPs for this email
    await OTP.create({ 
      email, 
      otp,
      userData: {
        firstName,
        lastName,
        phone,
        passwordHash,
        profilePhoto,
      }
    });

    const html = generateOTPEmailTemplate(otp);
    await sendEmail({
      email,
      subject: "TripSync - Account Verification OTP",
      html,
    });

    res.status(201).json({
      success: true,
      message: "Registration successful. Please check your email for the OTP.",
      data: {
        email: email,
      }
    });
  } catch (error) {
    next(error);
  }
};

export const verifyOTP = async (req, res, next) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: "Please provide email and OTP." });
    }

    const otpRecord = await OTP.findOne({ email, otp });
    if (!otpRecord) {
      return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
    }

    let user = await User.findOne({ email });
    if (user) {
      if (user.accountStatus === "active") {
        return res.status(400).json({ success: false, message: "Account is already active." });
      }
      user.accountStatus = "active";
      user.isEmailVerified = true;
      user.isActive = true;
      await user.save();
    } else {
      user = await User.create({
        ...otpRecord.userData,
        email: otpRecord.email,
        authProvider: "local",
        accountStatus: "active",
        isEmailVerified: true,
        isActive: true,
      });
    }

    await OTP.deleteMany({ email }); // Delete OTP after successful verification

    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    res.status(200).json({
      success: true,
      message: "Account verified successfully.",
      data: {
        user: {
          id: user._id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
        },
        accessToken,
        refreshToken,
      }
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Please provide email and password." });
    }

    const user = await User.findOne({ email }).select("+passwordHash");
    if (!user) {
      return res.status(401).json({ success: false, message: "Invalid credentials." });
    }

    if (user.authProvider !== "local") {
      return res.status(400).json({ success: false, message: "Please sign in using your registered provider." });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid credentials." });
    }

    if (user.accountStatus === "pending_verification") {
      return res.status(403).json({ success: false, message: "Please verify your email first." });
    }

    if (user.accountStatus !== "active" || !user.isActive) {
      return res.status(403).json({ success: false, message: "Account is not active." });
    }
    
    user.lastLoginAt = new Date();
    await user.save();

    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    res.status(200).json({
      success: true,
      message: "Login successful.",
      data: {
        user: {
          id: user._id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          profilePhoto: user.profilePhoto,
        },
        accessToken,
        refreshToken,
      }
    });
  } catch (error) {
    next(error);
  }
};

export const resendOTP = async (req, res, next) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: "Please provide an email." });
    }

    const user = await User.findOne({ email });
    if (user && user.accountStatus === "active") {
      return res.status(400).json({ success: false, message: "Account is already verified." });
    }

    const existingOtp = await OTP.findOne({ email });
    if (!existingOtp) {
      return res.status(404).json({ success: false, message: "OTP expired or not found. Please register again." });
    }

    const otp = generateOTP();
    existingOtp.otp = otp;
    existingOtp.createdAt = new Date();
    await existingOtp.save();

    const html = generateOTPEmailTemplate(otp);
    await sendEmail({
      email,
      subject: "TripSync - New Account Verification OTP",
      html,
    });

    res.status(200).json({
      success: true,
      message: "A new OTP has been sent to your email.",
    });
  } catch (error) {
    next(error);
  }
};
