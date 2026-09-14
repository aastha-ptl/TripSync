import express from 'express';
import { uploadDocument, getTripDocuments, updateDocument, deleteDocument } from '../controllers/documentController.js';
import { protect } from '../middleware/authMiddleware.js';
import { documentUpload } from '../middleware/documentUpload.js';

const router = express.Router();

router.use(protect);

const uploadMiddleware = (req, res, next) => {
  documentUpload.single('file')(req, res, (err) => {
    if (err) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
          success: false,
          message: 'File too large. Maximum allowed file size is 50MB.',
        });
      }
      return res.status(400).json({
        success: false,
        message: err.message || 'File upload error',
      });
    }
    next();
  });
};

router.post('/upload', uploadMiddleware, uploadDocument);
router.get('/trip/:tripId', getTripDocuments);
router.put('/:id', uploadMiddleware, updateDocument);
router.delete('/:id', deleteDocument);

export default router;
