const express = require('express');
const DeletionRequest = require('../models/DeletionRequest');
const Project = require('../models/Project');
const Payment = require('../models/Payment');
const BankAccount = require('../models/BankAccount');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

// POST /api/deletions - Create deletion request
router.post('/', authMiddleware, requireRole('developer', 'accountant', 'boss'), async (req, res) => {
  try {
    const { targetType, targetId } = req.body;

    if (!targetType || !targetId) {
      return res.status(400).json({ error: 'targetType and targetId are required' });
    }

    if (!['project', 'payment', 'milestone'].includes(targetType)) {
      return res.status(400).json({ error: 'targetType must be project, payment, or milestone' });
    }

    // Validate target exists
    let targetName = '';
    if (targetType === 'project') {
      const project = await Project.findById(targetId);
      if (!project) return res.status(404).json({ error: 'Project not found' });
      targetName = project.name;
    } else if (targetType === 'payment') {
      const payment = await Payment.findById(targetId);
      if (!payment) return res.status(404).json({ error: 'Payment not found' });
      targetName = payment.title;
    } else if (targetType === 'milestone') {
      // For milestones: targetId is projectId, milestoneName is in req.body
      const { milestoneName } = req.body;
      if (!milestoneName) return res.status(400).json({ error: 'milestoneName is required for milestone deletion' });
      const project = await Project.findById(targetId);
      if (!project) return res.status(404).json({ error: 'Project not found' });
      if (!project.milestones.includes(milestoneName)) {
        return res.status(404).json({ error: 'Milestone not found in project' });
      }
      targetName = milestoneName;
    }

    // Check no active request already exists
    const query = {
      targetType,
      targetId,
      status: { $in: ['pending', 'partiallyApproved'] },
    };
    // For milestones, also check targetName to allow multiple milestone deletions per project
    if (targetType === 'milestone') {
      query.targetName = targetName;
    }
    const existing = await DeletionRequest.findOne(query);
    if (existing) {
      return res.status(400).json({ error: 'An active deletion request already exists for this item' });
    }

    const role = req.user.role;

    // Create with auto-approval for requester's role
    const deletion = new DeletionRequest({
      targetType,
      targetId,
      targetName,
      requestedBy: req.user._id,
      requestedByName: req.user.name,
      approvals: {
        [role]: true,
        [`${role}Uid`]: req.user._id.toString(),
        [`${role}At`]: new Date(),
      },
      status: 'partiallyApproved',
    });

    await deletion.save();

    const io = req.app.get('io');
    if (io) io.emit('deletion:created', deletion.toPublicJSON());

    // Notify other roles that a deletion needs their approval
    sendPush({
      title: 'Deletion Approval Needed',
      body: `${req.user.name} wants to delete ${targetType} "${targetName}". Your approval is required.`,
      data: { type: 'deletion', deletionId: deletion._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(deletion.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create deletion request: ' + err.message });
  }
});

// GET /api/deletions - List all deletion requests
router.get('/', authMiddleware, async (req, res) => {
  try {
    const deletions = await DeletionRequest.find().sort({ createdAt: -1 });
    res.json(deletions.map((d) => d.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch deletion requests: ' + err.message });
  }
});

// GET /api/deletions/pending - List pending deletion requests
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const deletions = await DeletionRequest.find({
      status: { $in: ['pending', 'partiallyApproved'] },
    }).sort({ createdAt: -1 });
    res.json(deletions.map((d) => d.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch pending deletion requests: ' + err.message });
  }
});

// POST /api/deletions/:id/approve - Approve deletion request
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    const deletion = await DeletionRequest.findById(req.params.id);
    if (!deletion) {
      return res.status(404).json({ error: 'Deletion request not found' });
    }

    if (deletion.status === 'approved' || deletion.status === 'rejected') {
      return res.status(400).json({ error: 'Deletion request already finalized' });
    }

    const role = req.user.role;

    if (deletion.approvals[role] !== null && deletion.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this deletion request' });
    }

    deletion.approvals[role] = true;
    deletion.approvals[`${role}Uid`] = req.user._id.toString();
    deletion.approvals[`${role}At`] = new Date();

    const devApproved = deletion.approvals.developer === true;
    const bossApproved = deletion.approvals.boss === true;
    const accApproved = deletion.approvals.accountant === true;

    if (devApproved && bossApproved && accApproved) {
      deletion.status = 'approved';

      // Actually delete the target
      const io = req.app.get('io');

      if (deletion.targetType === 'project') {
        const project = await Project.findById(deletion.targetId);
        if (project) {
          // Reverse financials for approved payments before deleting
          const payments = await Payment.find({ projectId: project._id });

          await Payment.deleteMany({ projectId: project._id });
          await Project.deleteOne({ _id: project._id });

          // Clean up any deletion requests for payments of this project
          const paymentIds = payments.map((p) => p._id);
          await DeletionRequest.deleteMany({
            targetType: 'payment',
            targetId: { $in: paymentIds },
          });

          if (io) {
            io.emit('project:deleted', { id: deletion.targetId.toString(), actorName: req.user.name, actorId: req.user._id.toString() });
            io.emit('payments:refresh');
            io.emit('deletions:refresh');
          }
        }
      } else if (deletion.targetType === 'milestone') {
        const project = await Project.findById(deletion.targetId);
        if (project) {
          project.milestones = project.milestones.filter(m => m !== deletion.targetName);
          await project.save();

          if (io) {
            io.emit('project:updated', project.toPublicJSON());
          }
        }
      } else if (deletion.targetType === 'payment') {
        const payment = await Payment.findById(deletion.targetId);
        if (payment) {
          const projectId = payment.projectId;

          // Reverse bank account balance if payment was approved
          if (payment.status === 'approved' && payment.bankAccountId) {
            const account = await BankAccount.findById(payment.bankAccountId);
            if (account && account.status === 'active') {
              account.currentBalance += payment.amount;
              await account.save();
              if (io) io.emit('account:updated', account.toPublicJSON());
            }
          }

          await Payment.deleteOne({ _id: payment._id });

          // Recalculate project financials from remaining approved payments
          const project = await Project.findById(projectId);
          if (project) {
            const approvedPayments = await Payment.find({
              projectId: projectId,
              status: 'approved',
            });
            project.totalPaid = approvedPayments.reduce((sum, p) => sum + p.amount, 0);
            project.remainingBalance = project.totalCost - project.totalPaid;
            await project.save();

            if (io) io.emit('project:updated', project.toPublicJSON());
          }

          if (io) io.emit('payments:refresh');
        }
      }
    } else {
      deletion.status = 'partiallyApproved';
    }

    deletion.markModified('approvals');
    await deletion.save();

    const io = req.app.get('io');
    if (io) io.emit('deletion:updated', { ...deletion.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    if (deletion.status === 'approved') {
      sendPush({
        title: 'Deletion Approved & Executed',
        body: `"${deletion.targetName}" has been deleted by unanimous approval.`,
        data: { type: 'deletion', deletionId: deletion._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
      });
    } else {
      sendPush({
        title: 'Deletion Partially Approved',
        body: `${req.user.name} approved deleting "${deletion.targetName}". Awaiting other approvals.`,
        data: { type: 'deletion', deletionId: deletion._id.toString() },
        roles: ['developer', 'boss', 'accountant'],
        excludeUserIds: [req.user._id.toString()],
      });
    }

    res.json(deletion.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to approve deletion request: ' + err.message });
  }
});

// POST /api/deletions/:id/reject - Reject deletion request
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    const deletion = await DeletionRequest.findById(req.params.id);
    if (!deletion) {
      return res.status(404).json({ error: 'Deletion request not found' });
    }

    if (deletion.status === 'approved' || deletion.status === 'rejected') {
      return res.status(400).json({ error: 'Deletion request already finalized' });
    }

    const role = req.user.role;

    if (deletion.approvals[role] !== null && deletion.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this deletion request' });
    }

    deletion.approvals[role] = false;
    deletion.approvals[`${role}Uid`] = req.user._id.toString();
    deletion.approvals[`${role}At`] = new Date();
    deletion.status = 'rejected';

    deletion.markModified('approvals');
    await deletion.save();

    const io = req.app.get('io');
    if (io) io.emit('deletion:updated', { ...deletion.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    sendPush({
      title: 'Deletion Rejected',
      body: `${req.user.name} rejected the deletion of "${deletion.targetName}".`,
      data: { type: 'deletion', deletionId: deletion._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(deletion.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to reject deletion request: ' + err.message });
  }
});

module.exports = router;
