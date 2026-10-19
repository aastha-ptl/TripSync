import React from "react";
import { ShieldCheck, EyeOff } from "lucide-react";

export default function PrivacyBanner() {
  return (
    <div className="privacy-notice-banner">
      <div className="pnb-left">
        <div className="pnb-icon">
          <EyeOff size={20} />
        </div>
        <div className="pnb-text">
          <h4>Zero-PII & Trip Content Privacy Protection Enforced</h4>
          <p>
            By design, administrators cannot view user emails, real names, private messages, personal photos,
            or individual itinerary destinations. All reports and graphs represent secure statistical aggregations.
          </p>
        </div>
      </div>
      <div className="pnb-badge">
        <ShieldCheck size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: "4px" }} />
        GDPR Compliant
      </div>
    </div>
  );
}
