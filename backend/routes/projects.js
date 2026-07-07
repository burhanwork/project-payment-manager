const express = require('express');
const multer = require('multer');
const path = require('path');
const Project = require('../models/Project');
const Payment = require('../models/Payment');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpg|jpeg|png|gif|pdf|webp/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    const mime = allowed.test(file.mimetype);
    cb(null, ext || mime);
  },
});

// GET /api/projects - Get all projects
router.get('/', authMiddleware, async (req, res) => {
  try {
    const projects = await Project.find().sort({ createdAt: -1 });
    res.json(projects.map((p) => p.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch projects: ' + err.message });
  }
});

// GET /api/projects/:id - Get single project
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.json(project.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch project: ' + err.message });
  }
});

// POST /api/projects - Create project (direct, no approval needed)
router.post('/', authMiddleware, requireRole('developer', 'accountant', 'boss'), upload.single('receipt'), async (req, res) => {
  try {
    const { name, clientName, totalCost, initialPayment, startDate, expectedCompletionDate, status, milestones } = req.body;

    // milestones may arrive as JSON array or as milestones[0], milestones[1]... from multipart
    let parsedMilestones = [];
    if (Array.isArray(milestones)) {
      parsedMilestones = milestones.filter(m => m && m.trim());
    } else {
      const keys = Object.keys(req.body).filter(k => k.startsWith('milestones['));
      parsedMilestones = keys
        .sort()
        .map(k => req.body[k])
        .filter(m => m && m.trim());
    }

    const paid = Number(initialPayment) || 0;
    const project = new Project({
      name,
      clientName,
      totalCost: totalCost || 0,
      totalPaid: paid,
      milestones: parsedMilestones,
      startDate: new Date(startDate),
      expectedCompletionDate: new Date(expectedCompletionDate),
      status: status || 'planned',
      createdBy: req.user._id,
    });

    await project.save();

    // If there's an initial payment, create an approved Payment document
    if (paid > 0) {
      const initialPaymentDoc = new Payment({
        projectId: project._id,
        title: 'Initial Payment',
        amount: paid,
        date: project.startDate,
        method: 'bankTransfer',
        addedBy: req.user._id,
        addedByName: req.user.name,
        status: 'approved',
        proofPath: req.file ? `/uploads/${req.file.filename}` : null,
        approvals: {
          developer: true,
          boss: true,
          accountant: true,
          developerUid: req.user._id.toString(),
          bossUid: req.user._id.toString(),
          accountantUid: req.user._id.toString(),
          developerAt: new Date(),
          bossAt: new Date(),
          accountantAt: new Date(),
        },
      });
      await initialPaymentDoc.save();
    }

    // Emit real-time events
    const io = req.app.get('io');
    if (io) {
      io.emit('project:created', project.toPublicJSON());
      io.emit('project:user_created', { ...project.toPublicJSON(), createdByName: req.user.name, createdById: req.user._id.toString() });
    }

    // Notify all users about the new project
    sendPush({
      title: 'New Project Created',
      body: `${req.user.name} created project "${name}" for ${clientName}.`,
      data: { type: 'project', projectId: project._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(project.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create project: ' + err.message });
  }
});

// PUT /api/projects/:id - Update project
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const { name, clientName, totalCost, startDate, expectedCompletionDate, status, milestones } = req.body;

    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    if (name !== undefined) project.name = name;
    if (clientName !== undefined) project.clientName = clientName;
    if (totalCost !== undefined) {
      project.totalCost = totalCost;
      project.remainingBalance = totalCost - project.totalPaid;
    }
    if (milestones !== undefined) {
      project.milestones = Array.isArray(milestones) ? milestones.filter(m => m && m.trim()) : [];
    }
    if (startDate !== undefined) project.startDate = new Date(startDate);
    if (expectedCompletionDate !== undefined)
      project.expectedCompletionDate = new Date(expectedCompletionDate);
    if (status !== undefined) project.status = status;

    await project.save();

    const io = req.app.get('io');
    if (io) {
      io.emit('project:updated', project.toPublicJSON());
      io.emit('project:user_updated', { ...project.toPublicJSON(), updatedByName: req.user.name, updatedById: req.user._id.toString() });
    }

    sendPush({
      title: 'Project Updated',
      body: `${req.user.name} updated project "${project.name}".`,
      data: { type: 'project', projectId: project._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(project.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to update project: ' + err.message });
  }
});

// PATCH /api/projects/:id/completion - Update completion percentage (developer only)
router.patch('/:id/completion', authMiddleware, requireRole('developer'), async (req, res) => {
  try {
    const { completionPercentage } = req.body;
    const value = Number(completionPercentage);
    if (isNaN(value) || value < 0 || value > 100) {
      return res.status(400).json({ error: 'completionPercentage must be 0–100' });
    }

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });

    project.completionPercentage = value;
    await project.save();

    const io = req.app.get('io');
    if (io) {
      io.emit('project:updated', project.toPublicJSON());
      io.emit('project:user_updated', { ...project.toPublicJSON(), updatedByName: req.user.name, updatedById: req.user._id.toString(), completionValue: value });
    }

    sendPush({
      title: 'Project Progress Updated',
      body: `${req.user.name} updated completion of "${project.name}" to ${value}%.`,
      data: { type: 'project', projectId: project._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(project.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to update completion: ' + err.message });
  }
});

// POST /api/projects/migrate/initial-payments - One-time fix for projects
// created before the initial payment tracking fix. Creates approved Payment
// documents for any project whose totalPaid exceeds the sum of its Payment docs.
router.post('/migrate/initial-payments', authMiddleware, requireRole('developer', 'boss', 'accountant'), async (req, res) => {
  try {
    const projects = await Project.find({ totalPaid: { $gt: 0 } });
    const results = [];

    for (const project of projects) {
      const approvedPayments = await Payment.find({ projectId: project._id, status: 'approved' });
      const paymentDocsTotal = approvedPayments.reduce((sum, p) => sum + p.amount, 0);
      const gap = project.totalPaid - paymentDocsTotal;

      if (gap > 0) {
        // Try to find the originating project request for proofPath and creator info
        const ProjectRequest = require('../models/ProjectRequest');
        const projectRequest = await ProjectRequest.findOne({ projectId: project._id });
        const proofPath = projectRequest ? projectRequest.proofPath : null;
        const addedBy = projectRequest ? projectRequest.requestedBy : req.user._id;
        const addedByName = projectRequest ? projectRequest.requestedByName : req.user.name;

        const doc = new Payment({
          projectId: project._id,
          title: 'Initial Payment',
          amount: gap,
          date: project.startDate,
          method: 'bankTransfer',
          addedBy,
          addedByName,
          status: 'approved',
          proofPath,
          approvals: {
            developer: true,
            boss: true,
            accountant: true,
            developerUid: req.user._id.toString(),
            bossUid: req.user._id.toString(),
            accountantUid: req.user._id.toString(),
            developerAt: new Date(),
            bossAt: new Date(),
            accountantAt: new Date(),
          },
        });
        await doc.save();
        results.push({ project: project.name, gap, fixed: true, proofPath });
      } else {
        results.push({ project: project.name, gap: 0, fixed: false });
      }
    }

    res.json({ message: 'Migration complete', results });
  } catch (err) {
    res.status(500).json({ error: 'Migration failed: ' + err.message });
  }
});

module.exports = router;
