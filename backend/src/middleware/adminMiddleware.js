import jwt from "jsonwebtoken";
import User from "../models/User.js";
import env from "../config/env.js";

export const protectAdmin = async (req, res, next) => {
  let token;

  if (
    (req.headers.authorization && req.headers.authorization.startsWith("Bearer")) ||
    (req.query && req.query.token)
  ) {
    try {
      token = req.query?.token || req.headers.authorization.split(" ")[1];
      const decoded = jwt.verify(token, env.JWT_SECRET);

      const user = await User.findById(decoded.id).select("-passwordHash");

      if (!user) {
        return res.status(401).json({ success: false, message: "Not authorized, user not found" });
      }

      if (user.role !== "admin") {
        return res.status(403).json({
          success: false,
          message: "Access denied. Administrator privileges required.",
        });
      }

      if (user.accountStatus !== "active" || !user.isActive) {
        return res.status(403).json({ success: false, message: "Admin account is deactivated." });
      }

      req.admin = user;
      next();
    } catch (error) {
      if (error.name === "TokenExpiredError") {
        return res.status(401).json({ success: false, message: "Admin session expired. Please log in again." });
      }
      return res.status(401).json({ success: false, message: "Not authorized as administrator." });
    }
  } else {
    return res.status(401).json({ success: false, message: "Not authorized, admin token required." });
  }
};
