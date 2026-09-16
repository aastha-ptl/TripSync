import multer from 'multer';
import path from 'path';
import fs from 'fs';

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const tripId = req.params.tripId || 'general';
    const finalDir = path.join('uploads/expenses/', tripId);

    if (!fs.existsSync(finalDir)) {
      fs.mkdirSync(finalDir, { recursive: true });
    }
    cb(null, finalDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const cleanExt = path.extname(file.originalname).toLowerCase();
    cb(null, 'receipt-' + uniqueSuffix + cleanExt);
  }
});

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.gif', '.bmp', '.pdf'];
  const isImage = file.mimetype.startsWith('image/') || allowedExtensions.includes(ext);
  const isPdf = file.mimetype === 'application/pdf' || ext === '.pdf';
  
  if (isImage || isPdf) {
    cb(null, true);
  } else {
    cb(new Error('Only Image files (JPG, JPEG, PNG, WEBP, HEIC, etc.) and PDF documents are allowed as proof.'), false);
  }
};

export const expenseUpload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB file size limit
  },
  fileFilter: fileFilter
});
