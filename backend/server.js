require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const connectDB = require('./config/db');
const { initFirebase } = require('./config/firebase');
const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/projects');
const paymentRoutes = require('./routes/payments');
const deletionRoutes = require('./routes/deletions');
const projectRequestRoutes = require('./routes/projectRequests');
const bankAccountRoutes = require('./routes/bankAccounts');
const accountRequestRoutes = require('./routes/accountRequests');

const PORT = process.env.PORT || 3003;

const app = express();
const server = http.createServer(app);

// Socket.IO setup
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] },
});

// Make io accessible in routes
app.set('io', io);

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static('uploads'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/deletions', deletionRoutes);
app.use('/api/project-requests', projectRequestRoutes);
app.use('/api/bank-accounts', bankAccountRoutes);
app.use('/api/account-requests', accountRequestRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Test notification endpoint (for simulator testing)
app.post('/api/test-notification', async (req, res) => {
  const { sendPush } = require('./utils/pushNotification');
  const { scenario = 'payment', userId } = req.body;

  const scenarios = {
    payment: {
      title: 'New Payment Submitted',
      body: 'Test User submitted "Office Supplies" for Project Alpha — $1,500',
      data: { type: 'payment', paymentId: 'test123' },
    },
    approval: {
      title: 'Payment Fully Approved',
      body: 'Payment "Server Invoice" has been approved by all parties.',
      data: { type: 'payment', paymentId: 'test456' },
    },
    deletion: {
      title: 'Deletion Approval Needed',
      body: 'Boss wants to delete project "Old Project". Your approval is required.',
      data: { type: 'deletion', deletionId: 'test789' },
    },
    project: {
      title: 'New Project Request',
      body: 'Developer wants to create project "Mobile App v2". Your approval is required.',
      data: { type: 'project_request', requestId: 'testABC' },
    },
    reject: {
      title: 'Payment Rejected',
      body: 'Accountant rejected payment "Vendor Invoice #44".',
      data: { type: 'payment', paymentId: 'testDEF' },
    },
  };

  const payload = scenarios[scenario] || scenarios.payment;

  try {
    if (userId) {
      await sendPush({ ...payload, userIds: [userId] });
    } else {
      await sendPush({ ...payload, roles: ['developer', 'boss', 'accountant'] });
    }
    res.json({ success: true, scenario, payload });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// One-time recalculation endpoint for project financials
app.post('/api/recalculate', async (req, res) => {
  try {
    const Project = require('./models/Project');
    const Payment = require('./models/Payment');
    const projects = await Project.find();
    let fixed = 0;
    for (const project of projects) {
      const approvedPayments = await Payment.find({
        projectId: project._id,
        status: 'approved',
      });
      const correctTotal = approvedPayments.reduce((sum, p) => sum + p.amount, 0);
      if (project.totalPaid !== correctTotal) {
        project.totalPaid = correctTotal;
        project.remainingBalance = project.totalCost - correctTotal;
        await project.save();
        fixed++;
      }
    }
    res.json({ status: 'ok', projectsFixed: fixed });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Socket.IO connections
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Start server
async function start() {
  await connectDB();
  initFirebase();
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

start();
