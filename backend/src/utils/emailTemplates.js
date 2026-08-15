export const generateOTPEmailTemplate = (otp) => {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 10px;">
      <h2 style="color: #4CAF50; text-align: center;">TripSync Authentication</h2>
      <p style="font-size: 16px; color: #333;">Hello,</p>
      <p style="font-size: 16px; color: #333;">Please use the following One Time Password (OTP) to complete your registration/login process:</p>
      <div style="text-align: center; margin: 20px 0;">
        <span style="display: inline-block; font-size: 24px; font-weight: bold; background-color: #f4f4f4; padding: 10px 20px; border-radius: 5px; letter-spacing: 2px;">
          ${otp}
        </span>
      </div>
      <p style="font-size: 14px; color: #777;">This OTP is valid for 10 minutes. Do not share this code with anyone.</p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
      <p style="font-size: 12px; color: #999; text-align: center;">If you didn't request this email, you can safely ignore it.</p>
    </div>
  `;
};
