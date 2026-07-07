const express = require('express');
const multer = require('multer');
const path = require('path');
const ProjectRequest = require('../models/ProjectRequest');
const Project = require('../models/Project');
const Payment = require('../models/Payment');
const BankAccount = require('../models/BankAccount');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => {
    const uniqueName = `proof_${Date.now()}_${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const mimeOk = /^image\/|application\/pdf/.test(file.mimetype);
    const extOk = /jpeg|jpg|png|gif|pdf|heic|heif|webp/i.test(path.extname(file.originalname));
    cb(null, mimeOk || extOk);
  },
});

// POST /api/project-requests - Create project creation request
router.post('/', authMiddleware, requireRole('developer', 'accountant', 'boss'), upload.single('receipt'), async (req, res) => {
  try {
    const { name, clientName, totalCost, initialPayment, milestones, startDate, expectedCompletionDate, status, bankAccountId } = req.body;

    if (!name || !clientName) {
      return res.status(400).json({ error: 'name and clientName are required' });
    }

    const role = req.user.role;

    // milestones may arrive as JSON array or as milestones[0], milestones[1]... from multipart
    let parsedMilestones = [];
    if (Array.isArray(milestones)) {
      parsedMilestones = milestones.filter(m => m && m.trim());
    } else {
      // Extract milestones[0], milestones[1]... from req.body
      const keys = Object.keys(req.body).filter(k => k.startsWith('milestones['));
      parsedMilestones = keys
        .sort()
        .map(k => req.body[k])
        .filter(m => m && m.trim());
    }

    const request = new ProjectRequest({
      name,
      clientName,
      totalCost: Number(totalCost) || 0,
      initialPayment: Number(initialPayment) || 0,
      milestones: parsedMilestones,
      startDate: new Date(startDate),
      expectedCompletionDate: new Date(expectedCompletionDate),
      projectStatus: status || 'planned',
      proofPath: req.file ? `/uploads/${req.file.filename}` : null,
      bankAccountId: bankAccountId || null,
      requestedBy: req.user._id,
      requestedByName: req.user.name,
      approvals: {
        [role]: true,
        [`${role}Uid`]: req.user._id.toString(),
        [`${role}At`]: new Date(),
      },
      status: 'partiallyApproved',
    });

    await request.save();

    const io = req.app.get('io');
    if (io) io.emit('project-request:created', request.toPublicJSON());

    // Notify other roles that a new project needs their approval
    sendPush({
      title: 'New Project Request',
      body: `${req.user.name} wants to create project "${name}". Your approval is required.`,
      data: { type: 'project_request', requestId: request._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create project request: ' + err.message });
  }
});

// GET /api/project-requests - List all project requests
router.get('/', authMiddleware, async (req, res) => {
  try {
    const requests = await ProjectRequest.find().sort({ createdAt: -1 });
    res.json(requests.map((r) => r.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch project requests: ' + err.message });
  }
});

// GET /api/project-requests/pending - List pending requests
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const requests = await ProjectRequest.find({
      status: { $in: ['pending', 'partiallyApproved'] },
    }).sort({ createdAt: -1 });
    res.json(requests.map((r) => r.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch pending project requests: ' + err.message });
  }
});

// POST /api/project-requests/:id/approve - Approve project request
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    const request = await ProjectRequest.findById(req.params.id);
    if (!request) {
      return res.status(404).json({ error: 'Project request not found' });
    }

    if (request.status === 'approved' || request.status === 'rejected') {
      return res.status(400).json({ error: 'Project request already finalized' });
    }

    const role = req.user.role;

    if (request.approvals[role] !== null && request.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this request' });
    }

    request.approvals[role] = true;
    request.approvals[`${role}Uid`] = req.user._id.toString();
    request.approvals[`${role}At`] = new Date();

    const devApproved = request.approvals.developer === true;
    const bossApproved = request.approvals.boss === true;
    const accApproved = request.approvals.accountant === true;

    if (devApproved && bossApproved && accApproved) {
      request.status = 'approved';

      // Create the actual project
      const paid = Number(request.initialPayment) || 0;
      const project = new Project({
        name: request.name,
        clientName: request.clientName,
        totalCost: request.totalCost,
        totalPaid: paid,
        milestones: request.milestones,
        startDate: request.startDate,
        expectedCompletionDate: request.expectedCompletionDate,
        status: request.projectStatus,
        createdBy: request.requestedBy,
      });

      await project.save();
      request.projectId = project._id;

      // Create an approved Payment doc for the initial payment so it appears in Payment History
      if (paid > 0) {
        const initialPaymentDoc = new Payment({
          projectId: project._id,
          title: 'Initial Payment',
          amount: paid,
          date: project.startDate,
          method: 'bankTransfer',
          addedBy: request.requestedBy,
          addedByName: request.requestedByName,
          status: 'approved',
          bankAccountId: request.bankAccountId || null,
          approvals: {
            developer: true,
            boss: true,
            accountant: true,
            developerUid: request.approvals.developerUid,
            bossUid: request.approvals.bossUid,
            accountantUid: request.approvals.accountantUid,
            developerAt: request.approvals.developerAt,
            bossAt: request.approvals.bossAt,
            accountantAt: request.approvals.accountantAt,
          },
          proofPath: request.proofPath || null,
        });
        await initialPaymentDoc.save();

        // Deduct initial payment from selected bank account
        if (request.bankAccountId) {
          const account = await BankAccount.findById(request.bankAccountId);
          if (account && account.status === 'active') {
            account.currentBalance -= paid;
            await account.save();
            const io = req.app.get('io');
            if (io) io.emit('account:updated', account.toPublicJSON());
          }
        }
      }

      const io = req.app.get('io');
      if (io) {
        io.emit('project:created', project.toPublicJSON());
        io.emit('project-requests:refresh');
      }
    } else {
      request.status = 'partiallyApproved';
    }

    request.markModified('approvals');
    await request.save();

    const io = req.app.get('io');
    if (io) io.emit('project-request:updated', { ...request.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    if (request.status === 'approved') {
      sendPush({
        title: 'Project Created!',
        body: `Project "${request.name}" for ${request.clientName} has been approved and created.`,
        data: { type: 'project_request', requestId: request._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
      });
    } else {
      sendPush({
        title: 'Project Request Partially Approved',
        body: `${req.user.name} approved project "${request.name}". Awaiting other approvals.`,
        data: { type: 'project_request', requestId: request._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
        excludeUserIds: [req.user._id.toString()],
      });
    }

    res.json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to approve project request: ' + err.message });
  }
});

// POST /api/project-requests/:id/reject - Reject project request
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    const request = await ProjectRequest.findById(req.params.id);
    if (!request) {
      return res.status(404).json({ error: 'Project request not found' });
    }

    if (request.status === 'approved' || request.status === 'rejected') {
      return res.status(400).json({ error: 'Project request already finalized' });
    }

    const role = req.user.role;

    if (request.approvals[role] !== null && request.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this request' });
    }

    request.approvals[role] = false;
    request.approvals[`${role}Uid`] = req.user._id.toString();
    request.approvals[`${role}At`] = new Date();
    request.status = 'rejected';

    request.markModified('approvals');
    await request.save();

    const io = req.app.get('io');
    if (io) io.emit('project-request:updated', { ...request.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    sendPush({
      title: 'Project Request Rejected',
      body: `${req.user.name} rejected the request to create project "${request.name}".`,
      data: { type: 'project_request', requestId: request._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to reject project request: ' + err.message });
  }
});

module.exports = router;
