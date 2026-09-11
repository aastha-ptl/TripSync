import express from 'express';
import { uploadDocument, getTripDocuments } from '../controllers/documentController.js';
import { protect } from '../middleware/authMiddleware.js';
import { documentUpload } from '../middleware/documentUpload.js';

const router = express.Router();

router.use(protect);

router.post('/upload', documentUpload.single('file'), uploadDocument);
router.get('/trip/:tripId', getTripDocuments);

export default router;
