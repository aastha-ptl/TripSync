import bcrypt from "bcryptjs";
import User from "../models/User.js";
import Family from "../models/Family.js";
import TripParticipant from "../models/TripParticipant.js";
import OTP from "../models/OTP.js";
import { generateAccessToken, generateRefreshToken } from "../utils/generateToken.js";
import { sendEmail } from "../services/emailService.js";
import { generateOTPEmailTemplate } from "../utils/emailTemplates.js";
import { OAuth2Client } from "google-auth-library";
import env from "../config/env.js";

const googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const linkUserToFamilies = async (user) => {
  try {
    const families = await Family.find({ "members.email": user.email, "members.userId": null });
    for (const family of families) {
      let updated = false;
      family.members.forEach(m => {
        if (m.email === user.email && !m.userId) {
          m.userId = user._id;
          updated = true;
        }
      });
      if (updated) {
        await family.save();
        
        // Ensure no duplicate participant exists
        const existing = await TripParticipant.findOne({ tripId: family.tripId, userId: user._id });
        if (!existing) {
          await TripParticipant.create({
            tripId: family.tripId,
            userId: user._id,
            role: "familyMember",
            status: "approved",
            joinedAt: new Date(),
            familyId: family._id,
          });
        }
      }
    }
  } catch (err) {
    console.error("Error linking user to families:", err);
  }
};

export const register = async (req, res, next) => {
  try {
    const { firstName, lastName, email, phone, password, gender } = req.body;
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
        gender,
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
      await linkUserToFamilies(user);
    } else {
      user = await User.create({
        ...otpRecord.userData,
        email: otpRecord.email,
        authProvider: "local",
        accountStatus: "active",
        isEmailVerified: true,
        isActive: true,
      });
      
      await linkUserToFamilies(user);
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
    
    await User.updateOne({ _id: user._id }, { lastLoginAt: new Date() });

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

export const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: "Please provide your email." });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found with this email." });
    }

    const otp = generateOTP();
    await OTP.deleteMany({ email });
    await OTP.create({ email, otp });

    const html = generateOTPEmailTemplate(otp);
    await sendEmail({
      email,
      subject: "TripSync - Password Reset OTP",
      html,
    });

    res.status(200).json({
      success: true,
      message: "OTP sent to your email.",
    });
  } catch (error) {
    next(error);
  }
};

export const verifyForgotPasswordOtp = async (req, res, next) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ success: false, message: "Please provide email and OTP." });
    }

    const otpRecord = await OTP.findOne({ email, otp });
    if (!otpRecord) {
      return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
    }

    // Do NOT delete the OTP yet, we need it to reset the password, or we can just send a success 
    // and they reset in the next step. Actually, we should ideally delete it and give a temporary reset token,
    // but the simplest flow is to just verify it here and verify it AGAIN during resetPassword.
    // Or just let them reset directly with email, otp, newPassword.

    res.status(200).json({
      success: true,
      message: "OTP verified successfully.",
    });
  } catch (error) {
    next(error);
  }
};

export const resetPassword = async (req, res, next) => {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ success: false, message: "Please provide email, OTP, and new password." });
    }

    const otpRecord = await OTP.findOne({ email, otp });
    if (!otpRecord) {
      return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found." });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(newPassword, salt);
    
    await User.updateOne({ _id: user._id }, { passwordHash });
    await OTP.deleteMany({ email });

    res.status(200).json({
      success: true,
      message: "Password reset successful.",
    });
  } catch (error) {
    next(error);
  }
};

export const googleLogin = async (req, res, next) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: "Google ID token is required.",
      });
    }

    // Verify Google ID token
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();

    if (!payload) {
      return res.status(401).json({
        success: false,
        message: "Invalid Google token.",
      });
    }

    const {
      sub: googleId,
      email,
      email_verified,
      given_name,
      family_name,
      name,
      picture,
    } = payload;

    if (!email || !email_verified) {
      return res.status(401).json({
        success: false,
        message: "Google email is not verified.",
      });
    }

    // Find user by Google ID OR email
    let user = await User.findOne({
      $or: [
        { googleId },
        { email },
      ],
    }).select("+googleId");

    // =====================================
    // EXISTING USER
    // =====================================

    if (user) {
      // If account is suspended/deleted
      if (
        user.accountStatus === "suspended" ||
        user.accountStatus === "deleted" ||
        !user.isActive
      ) {
        return res.status(403).json({
          success: false,
          message: "Account is not active.",
        });
      }

      // Link Google account if user previously used local login
      if (!user.googleId) {
        user.googleId = googleId;
      }

      user.isEmailVerified = true;
      user.lastLoginAt = new Date();

      // If this was a Google-only account, keep google provider.
      // If it was an existing local account, don't overwrite
      // the provider automatically.
      await user.save();
    }

    // =====================================
    // NEW USER
    // =====================================

    else {
      const firstName =
        given_name ||
        (name ? name.split(" ")[0] : "Google");

      const lastName =
        family_name ||
        (name
          ? name.split(" ").slice(1).join(" ")
          : "");

      user = await User.create({
        firstName,
        lastName,
        email,
        phone: null,
        profilePhoto: picture || null,

        authProvider: "google",
        googleId,

        passwordHash: null,

        isEmailVerified: true,
        accountStatus: "active",
        isActive: true,
        lastLoginAt: new Date(),
      });
    }

    // =====================================
    // GENERATE YOUR NORMAL JWT TOKENS
    // =====================================

    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    return res.status(200).json({
      success: true,
      message: "Google login successful.",
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
      },
    });
  } catch (error) {
    console.error("Google login error:", error);
    next(error);
  }
};

