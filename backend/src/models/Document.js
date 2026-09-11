import mongoose from 'mongoose';

const documentSchema = new mongoose.Schema({
  tripId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Trip',
    required: true,
    index: true
  },
  belongsTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  number: {
    type: String,
    trim: true
  },
  type: {
    type: String,
    enum: ['Personal', 'Family', 'Trip'],
    default: 'Personal'
  },
  memberName: {
    type: String,
    trim: true,
    default: null
  },
  fileUrl: {
    type: String,
    required: true
  }
}, { timestamps: true });

export default mongoose.model('Document', documentSchema);
