import Document from '../models/Document.js';
import TripParticipant from '../models/TripParticipant.js';
import Family from '../models/Family.js';
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

    if (participant.role === 'familyMember') {
      return res.status(403).json({ success: false, message: 'Family members cannot upload documents' });
    }

    // Set file URL
    // Ensure using forward slashes for URLs
    const fileUrl = '/' + req.file.path.replace(/\\/g, '/');

    const documentType = type || 'Personal';

    let parsedBelongsTo = uploadedBy;
    let memberNameStr = null;

    if (belongsTo) {
      if (mongoose.Types.ObjectId.isValid(belongsTo)) {
        parsedBelongsTo = belongsTo;
      } else {
        memberNameStr = belongsTo;
      }
    }

    if (req.body.memberName) {
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

    // Verify user role
    const participant = await TripParticipant.findOne({ tripId, userId });
    
    if (!participant) {
      return res.status(403).json({ success: false, message: 'You are not a participant in this trip' });
    }

    let documents = [];

    if (participant.role === 'tripLeader') {
      // Trip leader can see all documents
      documents = await Document.find({ tripId }).populate('belongsTo', 'firstName lastName email profilePhoto').populate('uploadedBy', 'firstName lastName email profilePhoto');
    } else if (participant.role === 'familyLeader') {
      // Family leader can see their own documents + their family members' documents
      // Find the family where this user is the familyLeader
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
          { uploadedBy: userId }
        ]
      }).populate('belongsTo', 'firstName lastName email profilePhoto').populate('uploadedBy', 'firstName lastName email profilePhoto');

    } else if (participant.role === 'soloTraveler') {
      // Solo traveler can only see their own documents
      documents = await Document.find({ 
        tripId, 
        belongsTo: userId 
      }).populate('belongsTo', 'firstName lastName email profilePhoto').populate('uploadedBy', 'firstName lastName email profilePhoto');

    } else if (participant.role === 'familyMember') {
      // Family member cannot see documents
      return res.status(403).json({ success: false, message: 'Family members do not have access to view documents' });
    }

    const docsWithIsMine = documents.map(doc => {
      const docObj = doc.toObject();
      docObj.isMine = docObj.belongsTo && docObj.belongsTo._id.toString() === userId.toString();
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
