import dotenv from 'dotenv';
dotenv.config({ path: './.env' });
import mongoose from 'mongoose';
import Photo from './src/models/Photo.js';
import User from './src/models/User.js';

mongoose.connect(process.env.MONGODB_URI).then(async () => {
  try {
    const selectedUserId = new mongoose.Types.ObjectId('6a871be188c0a693a978205a');
    const tripId = '6a8ad7bdcf68201eb4f3db23';

    const photos = await Photo.find({
      tripId,
      $or: [
        { visibility: 'Everyone' },
        { uploaderId: selectedUserId },
        { permittedUsers: { $in: [selectedUserId] } }
      ]
    }).populate('uploaderId', 'firstName lastName email profilePhoto').sort({ createdAt: -1 });

    console.log('Photos count for selected user:', photos.length);
    const visibilities = photos.map(p => p.visibility);
    console.log(visibilities);
  } catch(e) {
    console.error('QUERY FAILED:', e);
  }
  process.exit(0);
});
