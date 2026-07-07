const express = require('express');
const AccountRequest = require('../models/AccountRequest');
const BankAccount = require('../models/BankAccount');
const Payment = require('../models/Payment');
const { authMiddleware } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

// GET /api/account-requests - Get all requests
router.get('/', authMiddleware, async (req, res) => {
  try {
    const requests = await AccountRequest.find().sort({ createdAt: -1 });
    res.json(requests.map((r) => r.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch account requests: ' + err.message });
  }
});

// GET /api/account-requests/pending - Get pending requests
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const requests = await AccountRequest.find({
      status: { $in: ['pending', 'partiallyApproved'] },
    }).sort({ createdAt: -1 });
    res.json(requests.map((r) => r.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch pending account requests: ' + err.message });
  }
});

// POST /api/account-requests/:id/approve - Approve request
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    const request = await AccountRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Account request not found' });

    if (request.status === 'approved' || request.status === 'rejected') {
      return res.status(400).json({ error: 'Request already finalized' });
    }

    const role = req.user.role;

    if (role === 'accountant') {
      return res.status(403).json({ error: 'Accountant initiates requests and cannot vote on them' });
    }

    if (request.approvals[role] !== null && request.approvals[role] !== undefined) {
      return res.status(400).json({ error: 'You have already voted on this request' });
    }

    request.approvals[role] = true;
    request.approvals[`${role}Uid`] = req.user._id.toString();
    request.approvals[`${role}At`] = new Date();

    const devApproved = request.approvals.developer === true;
    const bossApproved = request.approvals.boss === true;

    if (devApproved && bossApproved) {
      request.status = 'approved';

      const io = req.app.get('io');
      const account = await BankAccount.findById(request.accountId);

      if (account) {
        if (request.requestType === 'create') {
          account.status = 'active';
          await account.save();
          if (io) io.emit('account:activated', account.toPublicJSON());
        } else if (request.requestType === 'updateBalance') {
          account.currentBalance = request.newBalance;
          await account.save();
          if (io) io.emit('account:updated', account.toPublicJSON());
        } else if (request.requestType === 'delete') {
          account.status = 'inactive';
          await account.save();
          // Null out bankAccountId on all payments referencing this account
          await Payment.updateMany({ bankAccountId: account._id }, { $set: { bankAccountId: null } });
          if (io) io.emit('account:deactivated', account.toPublicJSON());
        }
      }
    } else {
      request.status = 'partiallyApproved';
    }

    request.markModified('approvals');
    await request.save();

    const io = req.app.get('io');
    if (io) io.emit('account-request:updated', { ...request.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    const typeLabel = request.requestType === 'create' ? 'creation' : request.requestType === 'updateBalance' ? 'balance update' : 'deletion';

    if (request.status === 'approved') {
      sendPush({
        title: 'Account Request Approved',
        body: `"${request.accountName}" ${typeLabel} has been approved by all parties.`,
        data: { type: 'account', accountId: request.accountId.toString() },
        roles: ['developer', 'boss', 'accountant'],
      });
    } else {
      sendPush({
        title: 'Account Request Partially Approved',
        body: `${req.user.name} approved "${request.accountName}" ${typeLabel}. Awaiting other approvals.`,
        data: { type: 'account', accountId: request.accountId.toString() },
        roles: ['developer', 'boss', 'accountant'],
        excludeUserIds: [req.user._id.toString()],
      });
    }

    res.json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to approve request: ' + err.message });
  }
});

// POST /api/account-requests/:id/reject - Reject request
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    const request = await AccountRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Account request not found' });

    if (request.status === 'approved' || request.status === 'rejected') {
      return res.status(400).json({ error: 'Request already finalized' });
    }

    const role = req.user.role;

    if (role === 'accountant') {
      return res.status(403).json({ error: 'Accountant initiates requests and cannot vote on them' });
    }

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
    if (io) io.emit('account-request:updated', { ...request.toPublicJSON(), actorName: req.user.name, actorId: req.user._id.toString() });

    const typeLabel = request.requestType === 'create' ? 'creation' : request.requestType === 'updateBalance' ? 'balance update' : 'deletion';

    sendPush({
      title: 'Account Request Rejected',
      body: `${req.user.name} rejected the ${typeLabel} of "${request.accountName}".`,
      data: { type: 'account', accountId: request.accountId.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to reject request: ' + err.message });
  }
});

module.exports = router;
