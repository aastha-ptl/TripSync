import multer from 'multer';
import path from 'path';
import fs from 'fs';

// Ensure the uploads directory exists
const uploadDir = 'uploads/documents/';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let finalDir = 'uploads/documents/Personal';

    if (req.body.type === 'Family') {
      let leaderName = req.user ? (req.user.firstName + (req.user.lastName ? '_' + req.user.lastName : '')) : 'Leader';
      let memberName = req.body.memberName || req.body.belongsTo || 'Member';
      
      leaderName = leaderName.replace(/[^a-zA-Z0-9_-]/g, '_');
      memberName = memberName.replace(/[^a-zA-Z0-9_-]/g, '_');
      
      finalDir = path.join('uploads/documents/', leaderName, memberName);
    } else if (req.user) {
      let userName = (req.user.firstName + (req.user.lastName ? '_' + req.user.lastName : ''));
      userName = userName.replace(/[^a-zA-Z0-9_-]/g, '_');
      finalDir = path.join('uploads/documents/', userName);
    }
    
    if (!fs.existsSync(finalDir)) {
      fs.mkdirSync(finalDir, { recursive: true });
    }
    cb(null, finalDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Only PDF, JPEG, JPG, and PNG files are allowed.'), false);
  }
};

export const documentUpload = multer({ 
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB file size limit
  },
  fileFilter: fileFilter
});
