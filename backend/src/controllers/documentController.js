import Document from '../models/Document.js';
import TripParticipant from '../models/TripParticipant.js';
import Family from '../models/Family.js';
import Trip from '../models/Trip.js';
import mongoose from 'mongoose';
import fs from 'fs';

// @desc    Upload a document
// @route   POST /api/documents/upload
// @access  Private
export const uploadDocument = async (req, res) => {
  try {
    const { tripId, name, number, belongsTo, type, category, docDate, notes } = req.body;
    const uploadedBy = req.user._id;

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Please upload a file' });
    }

    if (!tripId || !name) {
      return res.status(400).json({ success: false, message: 'Trip ID and document name are required' });
    }

    // Verify user role in trip
    const participant = await TripParticipant.findOne({ tripId, userId: uploadedBy });
    const trip = await Trip.findById(tripId);
    if (!participant && (!trip || trip.createdBy?.toString() !== uploadedBy.toString())) {
      return res.status(403).json({ success: false, message: 'You are not a participant in this trip' });
    }

    const isTripLeaderOrCreator = (participant && (participant.role === 'tripLeader' || participant.role === 'creator' || participant.role === 'admin')) ||
                                  (trip && trip.createdBy && trip.createdBy.toString() === uploadedBy.toString());

    if (type === 'Trip' && !isTripLeaderOrCreator) {
      return res.status(403).json({ success: false, message: 'Only trip leader can upload trip documents' });
    }

    if (participant && participant.role === 'familyMember' && type && type !== 'Personal') {
      return res.status(403).json({ success: false, message: 'Family members can only upload Personal documents' });
    }

    // Set file URL
    // Ensure using forward slashes for URLs
    const fileUrl = '/' + req.file.path.replace(/\\/g, '/');

    // Solo traveler and regular members can only upload Personal documents belonging to themselves
    let documentType = type || 'Personal';
    if (participant && (participant.role === 'soloTraveler' || participant.role === 'familyMember')) {
      documentType = 'Personal';
    }

    let parsedBelongsTo = uploadedBy;
    let memberNameStr = null;

    if (belongsTo && participant && participant.role !== 'soloTraveler' && participant.role !== 'familyMember') {
      if (mongoose.Types.ObjectId.isValid(belongsTo)) {
        parsedBelongsTo = belongsTo;
      } else {
        memberNameStr = belongsTo;
      }
    }

    if (req.body.memberName && participant && participant.role !== 'soloTraveler' && participant.role !== 'familyMember') {
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
      category: category || (documentType === 'Trip' ? 'General' : null),
      docDate: docDate || null,
      notes: notes || null,
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
    let participant = await TripParticipant.findOne({ tripId, userId });
    const trip = await Trip.findById(tripId);
    
    // Check if user is a member of any family in this trip
    let userFamily = null;
    const userEmail = req.user.email ? req.user.email.toLowerCase() : '';
    if (!participant || participant.role === 'familyMember') {
      userFamily = await Family.findOne({
        tripId,
        $or: [
          { "members.userId": userId },
          ...(userEmail ? [{ "members.email": { $regex: new RegExp(`^${userEmail}$`, 'i') } }] : [])
        ]
      });
    }

    if (!participant && !userFamily && (!trip || trip.createdBy?.toString() !== userId.toString())) {
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
    } else if (participant && participant.role === 'familyLeader') {
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

    } else if (participant && participant.role === 'soloTraveler') {
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
      // Regular members / familyMember can see all shared Trip documents + their personal documents
      let memberIds = [userId.toString()];
      let memberNames = [];

      const fam = userFamily || (participant?.familyId ? await Family.findById(participant.familyId) : await Family.findOne({ tripId, "members.userId": userId }));
      if (fam && fam.members) {
        const found = fam.members.find(m => 
          (m.userId && m.userId.toString() === userId.toString()) || 
          (m.email && userEmail && m.email.toLowerCase() === userEmail)
        );
        if (found) {
          if (found._id) memberIds.push(found._id.toString());
          if (found.name) memberNames.push(found.name.trim());
        }
      }

      documents = await Document.find({ 
        tripId, 
        $or: [
          { type: 'Trip' },
          { belongsTo: { $in: memberIds } },
          { uploadedBy: userId },
          ...(memberNames.length > 0 ? [{ memberName: { $in: memberNames } }] : [])
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
      } else if (doc._doc && doc._doc.belongsTo) {
        belongsToId = doc._doc.belongsTo.toString();
        docObj.belongsToId = belongsToId;
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

// @desc    Update a document
// @route   PUT /api/documents/:id
// @access  Private
export const updateDocument = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, number, category, docDate, notes } = req.body;
    const userId = req.user._id;

    const document = await Document.findById(id);
    if (!document) {
      return res.status(404).json({ success: false, message: 'Document not found' });
    }

    const participant = await TripParticipant.findOne({ tripId: document.tripId, userId });
    const trip = await Trip.findById(document.tripId);

    const isUploader = document.uploadedBy.toString() === userId.toString();
    const isOwner = document.belongsTo && document.belongsTo.toString() === userId.toString();
    const isTripLeaderOrCreator = (participant && (participant.role === 'tripLeader' || participant.role === 'creator' || participant.role === 'admin')) ||
                                  (trip && trip.createdBy && trip.createdBy.toString() === userId.toString());

    // Only trip leader can update Trip documents
    if (document.type === 'Trip' && !isTripLeaderOrCreator) {
      return res.status(403).json({ success: false, message: 'Only trip leader can update trip documents' });
    }

    let isFamilyLeader = false;
    if (participant && (participant.role === 'familyLeader' || participant.role === 'family leader')) {
      const family = await Family.findOne({ tripId: document.tripId, familyLeaderId: userId });
      if (family && family.members) {
        const allowedIds = [userId.toString(), ...family.members.map(m => (m.userId ? m.userId.toString() : m._id ? m._id.toString() : ''))];
        if (allowedIds.includes(document.uploadedBy.toString()) || (document.belongsTo && allowedIds.includes(document.belongsTo.toString()))) {
          isFamilyLeader = true;
        }
      }
    }

    if (!isUploader && !isOwner && !isTripLeaderOrCreator && !isFamilyLeader) {
      return res.status(403).json({ success: false, message: 'Not authorized to update this document' });
    }

    if (name) document.name = name.trim();
    if (number !== undefined) document.number = number.trim();
    if (category !== undefined) document.category = category ? category.trim() : null;
    if (docDate !== undefined) document.docDate = docDate ? docDate.trim() : null;
    if (notes !== undefined) document.notes = notes ? notes.trim() : null;

    if (req.file) {
      // Remove old file if it exists
      if (document.fileUrl) {
        const oldRelative = document.fileUrl.startsWith('/') ? document.fileUrl.substring(1) : document.fileUrl;
        if (fs.existsSync(oldRelative)) {
          try {
            fs.unlinkSync(oldRelative);
          } catch (e) {
            console.error('Error deleting old document file:', e);
          }
        }
      }
      document.fileUrl = '/' + req.file.path.replace(/\\/g, '/');
    }

    const updatedDocument = await document.save();

    res.status(200).json({
      success: true,
      message: 'Document updated successfully',
      document: updatedDocument
    });
  } catch (error) {
    console.error('Error updating document:', error);
    res.status(500).json({ success: false, message: 'Failed to update document', error: error.message });
  }
};

// @desc    Delete a document
// @route   DELETE /api/documents/:id
// @access  Private
export const deleteDocument = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const document = await Document.findById(id);
    if (!document) {
      return res.status(404).json({ success: false, message: 'Document not found' });
    }

    const participant = await TripParticipant.findOne({ tripId: document.tripId, userId });
    const trip = await Trip.findById(document.tripId);

    const isUploader = document.uploadedBy.toString() === userId.toString();
    const isOwner = document.belongsTo && document.belongsTo.toString() === userId.toString();
    const isTripLeaderOrCreator = (participant && (participant.role === 'tripLeader' || participant.role === 'creator' || participant.role === 'admin')) ||
                                  (trip && trip.createdBy && trip.createdBy.toString() === userId.toString());

    // Only trip leader can delete Trip documents
    if (document.type === 'Trip' && !isTripLeaderOrCreator) {
      return res.status(403).json({ success: false, message: 'Only trip leader can delete trip documents' });
    }

    let isFamilyLeader = false;
    if (participant && (participant.role === 'familyLeader' || participant.role === 'family leader')) {
      const family = await Family.findOne({ tripId: document.tripId, familyLeaderId: userId });
      if (family && family.members) {
        const allowedIds = [userId.toString(), ...family.members.map(m => (m.userId ? m.userId.toString() : m._id ? m._id.toString() : ''))];
        if (allowedIds.includes(document.uploadedBy.toString()) || (document.belongsTo && allowedIds.includes(document.belongsTo.toString()))) {
          isFamilyLeader = true;
        }
      }
    }

    if (!isUploader && !isOwner && !isTripLeaderOrCreator && !isFamilyLeader) {
      return res.status(403).json({ success: false, message: 'Not authorized to delete this document' });
    }

    // Delete file from disk if exists
    if (document.fileUrl) {
      const oldRelative = document.fileUrl.startsWith('/') ? document.fileUrl.substring(1) : document.fileUrl;
      if (fs.existsSync(oldRelative)) {
        try {
          fs.unlinkSync(oldRelative);
        } catch (e) {
          console.error('Error deleting document file from disk:', e);
        }
      }
    }

    await Document.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'Document deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting document:', error);
    res.status(500).json({ success: false, message: 'Failed to delete document', error: error.message });
  }
};
