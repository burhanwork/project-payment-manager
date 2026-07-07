const express = require('express');
const multer = require('multer');
const path = require('path');
const Payment = require('../models/Payment');
const Project = require('../models/Project');
const BankAccount = require('../models/BankAccount');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

// Multer config for receipt uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => {
    const uniqueName = `receipt_${Date.now()}_${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    // Accept any image or pdf — iOS/Android may send heic, heif, webp, jpeg, png, etc.
    const allowedMime = /^image\/|application\/pdf/;
    const allowedExt = /jpeg|jpg|png|gif|pdf|heic|heif|webp/i;
    const extOk = allowedExt.test(path.extname(file.originalname).toLowerCase());
    const mimeOk = allowedMime.test(file.mimetype);
    console.log(`[upload] file: ${file.originalname}, mime: ${file.mimetype}, extOk: ${extOk}, mimeOk: ${mimeOk}`);
    cb(null, extOk || mimeOk);
  },
});

// GET /api/payments - Get all payments
router.get('/', authMiddleware, async (req, res) => {
  try {
    const payments = await Payment.find().sort({ createdAt: -1 });
    res.json(payments.map((p) => p.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch payments: ' + err.message });
  }
});

// GET /api/payments/project/:projectId - Get payments for a project
router.get('/project/:projectId', authMiddleware, async (req, res) => {
  try {
    const payments = await Payment.find({ projectId: req.params.projectId }).sort({
      createdAt: -1,
    });
    res.json(payments.map((p) => p.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch payments: ' + err.message });
  }
});

// GET /api/payments/pending - Get pending payments
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const payments = await Payment.find({
      status: { $in: ['pending', 'partiallyApproved'] },
    }).sort({ createdAt: -1 });
    res.json(payments.map((p) => p.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch pending payments: ' + err.message });
  }
});

// POST /api/payments - Create payment (with optional receipt upload)
router.post('/', authMiddleware, requireRole('developer', 'accountant', 'boss'), upload.single('receipt'), async (req, res) => {
  try {
    const { projectId, title, module, amount, date, method, notes, bankAccountId } = req.body;
    console.log(`[payment create] file received: ${req.file ? req.file.filename : 'none'}`);

    const project = await Project.findById(projectId);
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Validate bank account if provided
    if (bankAccountId) {
      const account = await BankAccount.findById(bankAccountId);
      if (!account || account.status !== 'active') {
        return res.status(400).json({ error: 'Bank account not found or not active' });
      }
    }

    const role = req.user.role;

    const payment = new Payment({
      projectId,
      title,
      module: module || null,
      amount,
      date: new Date(date),
      method: method || 'bankTransfer',
      notes: notes || null,
      proofPath: req.file ? `/uploads/${req.file.filename}` : null,
      bankAccountId: bankAccountId || null,
      addedBy: req.user._id,
      addedByName: req.user.name,
      status: 'partiallyApproved',
      approvals: {
        developer: role === 'developer' ? true : null,
        boss: role === 'boss' ? true : null,
        accountant: role === 'accountant' ? true : null,
        developerUid: role === 'developer' ? req.user._id.toString() : null,
        bossUid: role === 'boss' ? req.user._id.toString() : null,
        accountantUid: role === 'accountant' ? req.user._id.toString() : null,
        developerAt: role === 'developer' ? new Date() : null,
        bossAt: role === 'boss' ? new Date() : null,
        accountantAt: role === 'accountant' ? new Date() : null,
      },
    });

    await payment.save();

    const io = req.app.get('io');
    if (io) io.emit('payment:created', payment.toPublicJSON());

    // Notify all other users (excluding the submitter) that a new payment needs approval
    sendPush({
      title: 'New Payment Submitted',
      body: `${req.user.name} submitted "${title}" for ${project.name} — $${amount}`,
      data: { type: 'payment', paymentId: payment._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(payment.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create payment: ' + err.message });
  }
});

// PATCH /api/payments/:id/receipt - Upload or replace receipt for an existing payment
router.patch('/:id/receipt', authMiddleware, upload.single('receipt'), async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment) return res.status(404).json({ error: 'Payment not found' });
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    payment.proofPath = `/uploads/${req.file.filename}`;
    await payment.save();
    const io = req.app.get('io');
    if (io) io.emit('payment:updated', payment.toPublicJSON());
    res.json(payment.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to update receipt: ' + err.message });
  }
});

// POST /api/payments/:id/approve - Approve payment
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    if (payment.status === 'approved' || payment.status === 'rejected') {
      return res.status(400).json({ error: 'Payment already finalized' });
    }

    const role = req.user.role;

    // Check if user already approved
    if (payment.approvals[role] !== null && payment.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this payment' });
    }

    // Set approval
    payment.approvals[role] = true;
    payment.approvals[`${role}Uid`] = req.user._id.toString();
    payment.approvals[`${role}At`] = new Date();

    // Calculate new status
    const devApproved = payment.approvals.developer === true;
    const bossApproved = payment.approvals.boss === true;
    const accApproved = payment.approvals.accountant === true;

    if (devApproved && bossApproved && accApproved) {
      payment.status = 'approved';
    } else {
      payment.status = 'partiallyApproved';
    }

    payment.markModified('approvals');
    await payment.save();

    // Recalculate project financials from all approved payments
    if (payment.status === 'approved') {
      const project = await Project.findById(payment.projectId);
      if (project) {
        const approvedPayments = await Payment.find({
          projectId: payment.projectId,
          status: 'approved',
        });
        project.totalPaid = approvedPayments.reduce((sum, p) => sum + p.amount, 0);
        project.remainingBalance = project.totalCost - project.totalPaid;
        await project.save();

        const io = req.app.get('io');
        if (io) io.emit('project:updated', project.toPublicJSON());
      }

      // Deduct from linked bank account
      if (payment.bankAccountId) {
        const account = await BankAccount.findById(payment.bankAccountId);
        if (account && account.status === 'active') {
          account.currentBalance -= payment.amount;
          await account.save();
          const io = req.app.get('io');
          if (io) io.emit('account:updated', account.toPublicJSON());
        }
      }
    }

    const io = req.app.get('io');
    if (io) io.emit('payment:updated', { ...payment.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    // Notify all roles about the approval status
    if (payment.status === 'approved') {
      sendPush({
        title: 'Payment Fully Approved',
        body: `Payment "${payment.title}" has been approved by all parties.`,
        data: { type: 'payment', paymentId: payment._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
      });
    } else {
      sendPush({
        title: 'Payment Partially Approved',
        body: `${req.user.name} (${role}) approved "${payment.title}". Awaiting other approvals.`,
        data: { type: 'payment', paymentId: payment._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
        excludeUserIds: [req.user._id.toString()],
      });
    }

    res.json(payment.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to approve payment: ' + err.message });
  }
});

// POST /api/payments/:id/reject - Reject payment
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    if (payment.status === 'approved' || payment.status === 'rejected') {
      return res.status(400).json({ error: 'Payment already finalized' });
    }

    const role = req.user.role;

    if (payment.approvals[role] !== null && payment.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this payment' });
    }

    payment.approvals[role] = false;
    payment.approvals[`${role}Uid`] = req.user._id.toString();
    payment.approvals[`${role}At`] = new Date();
    payment.status = 'rejected';

    payment.markModified('approvals');
    await payment.save();

    const io = req.app.get('io');
    if (io) io.emit('payment:updated', { ...payment.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    // Notify all roles about the rejection
    sendPush({
      title: 'Payment Rejected',
      body: `${req.user.name} rejected payment "${payment.title}".`,
      data: { type: 'payment', paymentId: payment._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(payment.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to reject payment: ' + err.message });
  }
});

module.exports = router;
