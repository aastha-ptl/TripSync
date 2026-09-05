import jwt from "jsonwebtoken";
import User from "../models/User.js";
import env from "../config/env.js";

export const protect = async (req, res, next) => {
  let token;

  if (
    (req.headers.authorization && req.headers.authorization.startsWith("Bearer")) ||
    (req.query && req.query.token)
  ) {
    try {
      token = req.query?.token || req.headers.authorization.split(" ")[1];
      const decoded = jwt.verify(token, env.JWT_SECRET);

      req.user = await User.findById(decoded.id).select("-passwordHash");

      if (!req.user) {
        return res.status(401).json({ success: false, message: "Not authorized, user not found" });
      }

      if (req.user.accountStatus !== "active" || !req.user.isActive) {
         return res.status(403).json({ success: false, message: "Account is not active." });
      }

      next();
    } catch (error) {
      if (error.name === "TokenExpiredError") {
        console.error("JWT token expired for a request.");
      } else {
        console.error("Auth Middleware Error:", error.message || error);
      }
      res.status(401).json({ success: false, message: "Not authorized, token failed" });
    }
  }

  if (!token) {
    res.status(401).json({ success: false, message: "Not authorized, no token" });
  }
};
