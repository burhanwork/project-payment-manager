require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('./config/db');
const User = require('./models/User');

const users = [
  { name: 'Boss', email: 'boss@example.com', password: 'ChangeMe123!', role: 'boss' },
  { name: 'Developer', email: 'developer@example.com', password: 'ChangeMe123!', role: 'developer' },
  { name: 'Accountant', email: 'accountant@example.com', password: 'ChangeMe123!', role: 'accountant' },
];

async function seed() {
  await connectDB();

  for (const u of users) {
    const exists = await User.findOne({ email: u.email });
    if (exists) {
      exists.password = u.password;
      await exists.save();
      console.log(`  Updated password: ${u.name} (${u.role}) - ${u.email}`);
    } else {
      await User.create(u);
      console.log(`  Created: ${u.name} (${u.role}) - ${u.email}`);
    }
  }

  console.log('\nAll 3 accounts ready with unique passwords.');
  await mongoose.disconnect();
}

seed();
