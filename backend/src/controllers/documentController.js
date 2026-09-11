import Document from '../models/Document.js';
import TripParticipant from '../models/TripParticipant.js';
import Family from '../models/Family.js';
import Trip from '../models/Trip.js';
import mongoose from 'mongoose';

// @desc    Upload a document
// @route   POST /api/documents/upload
// @access  Private
export const uploadDocument = async (req, res) => {
  try {
    const { tripId, name, number, belongsTo, type } = req.body;
    const uploadedBy = req.user._id;

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Please upload a file' });
    }

    if (!tripId || !name) {
      return res.status(400).json({ success: false, message: 'Trip ID and document name are required' });
    }

    // Verify user role in trip
    const participant = await TripParticipant.findOne({ tripId, userId: uploadedBy });
    if (!participant) {
      return res.status(403).json({ success: false, message: 'You are not a participant in this trip' });
    }

    if (participant.role === 'familyMember' && type && type !== 'Personal') {
      return res.status(403).json({ success: false, message: 'Family members can only upload Personal documents' });
    }

    // Set file URL
    // Ensure using forward slashes for URLs
    const fileUrl = '/' + req.file.path.replace(/\\/g, '/');

    // Solo traveler and regular members can only upload Personal documents belonging to themselves
    let documentType = type || 'Personal';
    if (participant.role === 'soloTraveler' || participant.role === 'familyMember') {
      documentType = 'Personal';
    }

    let parsedBelongsTo = uploadedBy;
    let memberNameStr = null;

    if (belongsTo && participant.role !== 'soloTraveler' && participant.role !== 'familyMember') {
      if (mongoose.Types.ObjectId.isValid(belongsTo)) {
        parsedBelongsTo = belongsTo;
      } else {
        memberNameStr = belongsTo;
      }
    }

    if (req.body.memberName && participant.role !== 'soloTraveler' && participant.role !== 'familyMember') {
      memberNameStr = req.body.memberName;
    }

    const document = new Document({
      tripId,
      uploadedBy,
      belongsTo: parsedBelongsTo,
      memberName: memberNameStr,
      name,
      number,
      type: documentType,
      fileUrl
    });

    const savedDocument = await document.save();

    res.status(201).json({
      success: true,
      message: 'Document uploaded successfully',
      document: savedDocument
    });
  } catch (error) {
    console.error('Error uploading document:', error);
    res.status(500).json({ success: false, message: 'Failed to upload document', error: error.message });
  }
};

// @desc    Get trip documents based on user role
// @route   GET /api/documents/trip/:tripId
// @access  Private
export const getTripDocuments = async (req, res) => {
  try {
    const { tripId } = req.params;
    const userId = req.user._id;

    // Verify user role or creator
    const participant = await TripParticipant.findOne({ tripId, userId });
    const trip = await Trip.findById(tripId);
    
    if (!participant && (!trip || trip.createdBy?.toString() !== userId.toString())) {
      return res.status(403).json({ success: false, message: 'You are not a participant in this trip' });
    }

    let documents = [];

    const isTripCreatorOrLeader = (participant && (participant.role === 'tripLeader' || participant.role === 'creator' || participant.role === 'admin')) || 
                                  (trip && trip.createdBy && trip.createdBy.toString() === userId.toString());

    if (isTripCreatorOrLeader) {
      // Trip leader or creator can see all documents for this trip
      documents = await Document.find({ tripId })
        .populate('belongsTo', 'firstName lastName email profilePhoto')
        .populate('uploadedBy', 'firstName lastName email profilePhoto');
    } else if (participant.role === 'familyLeader') {
      // Family leader can see their own documents + their family members' documents + trip docs
      const family = await Family.findOne({ tripId, familyLeaderId: userId });
      
      let allowedUserIds = [userId.toString()];
      
      if (family && family.members) {
        family.members.forEach(member => {
          if (member.userId) {
            allowedUserIds.push(member.userId.toString());
          }
          if (member._id) {
            allowedUserIds.push(member._id.toString());
          }
        });
      }
      
      documents = await Document.find({ 
        tripId, 
        $or: [
          { belongsTo: { $in: allowedUserIds } },
          { uploadedBy: userId },
          { type: 'Trip' }
        ]
      })
      .populate('belongsTo', 'firstName lastName email profilePhoto')
      .populate('uploadedBy', 'firstName lastName email profilePhoto');

    } else if (participant.role === 'soloTraveler') {
      // Solo traveler can see their own personal documents for this trip + trip documents
      documents = await Document.find({ 
        tripId, 
        $or: [
          { belongsTo: userId },
          { type: 'Trip' }
        ]
      })
      .populate('belongsTo', 'firstName lastName email profilePhoto')
      .populate('uploadedBy', 'firstName lastName email profilePhoto');

    } else {
      // Regular members / familyMember can see their own personal documents for this trip + trip documents
      documents = await Document.find({ 
        tripId, 
        $or: [
          { belongsTo: userId },
          { type: 'Trip' }
        ]
      })
      .populate('belongsTo', 'firstName lastName email profilePhoto')
      .populate('uploadedBy', 'firstName lastName email profilePhoto');
    }

    const docsWithIsMine = documents.map(doc => {
      const docObj = doc.toObject();
      let belongsToId = null;
      if (docObj.belongsTo) {
        belongsToId = docObj.belongsTo._id ? docObj.belongsTo._id.toString() : docObj.belongsTo.toString();
      }
      let uploadedById = null;
      if (docObj.uploadedBy) {
        uploadedById = docObj.uploadedBy._id ? docObj.uploadedBy._id.toString() : docObj.uploadedBy.toString();
      }
      
      const belongsToSelf = belongsToId && belongsToId === userId.toString();
      const hasMemberName = docObj.memberName && docObj.memberName.trim().length > 0;

      // It is only "isMine" if it belongs to this user and is not designated for another member
      docObj.isMine = Boolean(belongsToSelf && !hasMemberName);
      return docObj;
    });

    res.status(200).json({
      success: true,
      count: docsWithIsMine.length,
      documents: docsWithIsMine
    });

  } catch (error) {
    console.error('Error fetching documents:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch documents', error: error.message });
  }
};
