const express = require('express');
const BankAccount = require('../models/BankAccount');
const AccountRequest = require('../models/AccountRequest');
const { authMiddleware, requireRole } = require('../middleware/auth');
const { sendPush } = require('../utils/pushNotification');

const router = express.Router();

// GET /api/bank-accounts - Get active + pending accounts
router.get('/', authMiddleware, async (req, res) => {
  try {
    const accounts = await BankAccount.find({ status: { $in: ['pending', 'active'] } }).sort({ createdAt: -1 });
    res.json(accounts.map((a) => a.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch accounts: ' + err.message });
  }
});

// GET /api/bank-accounts/all - Get all accounts including inactive
router.get('/all', authMiddleware, async (req, res) => {
  try {
    const accounts = await BankAccount.find().sort({ createdAt: -1 });
    res.json(accounts.map((a) => a.toPublicJSON()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch accounts: ' + err.message });
  }
});

// GET /api/bank-accounts/:id - Get single account
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const account = await BankAccount.findById(req.params.id);
    if (!account) return res.status(404).json({ error: 'Account not found' });
    res.json(account.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch account: ' + err.message });
  }
});

// POST /api/bank-accounts - Create bank account (requires approval)
router.post('/', authMiddleware, requireRole('accountant'), async (req, res) => {
  try {
    const { name, bankName, accountNumber, currentBalance, currency, notes } = req.body;

    if (!name || !bankName) {
      return res.status(400).json({ error: 'name and bankName are required' });
    }
    if (currentBalance === undefined || currentBalance === null) {
      return res.status(400).json({ error: 'currentBalance is required' });
    }

    const role = req.user.role;

    const account = new BankAccount({
      name,
      bankName,
      accountNumber: accountNumber || null,
      currentBalance: parseFloat(currentBalance),
      currency: currency || 'USD',
      notes: notes || null,
      createdBy: req.user._id,
      createdByName: req.user.name,
      status: 'pending',
    });

    await account.save();

    const request = new AccountRequest({
      requestType: 'create',
      accountId: account._id,
      accountName: name,
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
    if (io) {
      io.emit('account:created', account.toPublicJSON());
      io.emit('account-request:created', request.toPublicJSON());
    }

    sendPush({
      title: 'Bank Account Approval Needed',
      body: `${req.user.name} wants to add bank account "${name}". Your approval is required.`,
      data: { type: 'account', accountId: account._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json({ account: account.toPublicJSON(), request: request.toPublicJSON() });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create bank account: ' + err.message });
  }
});

// POST /api/bank-accounts/:id/request-update - Request balance update
router.post('/:id/request-update', authMiddleware, requireRole('accountant'), async (req, res) => {
  try {
    const account = await BankAccount.findById(req.params.id);
    if (!account) return res.status(404).json({ error: 'Account not found' });
    if (account.status !== 'active') return res.status(400).json({ error: 'Account is not active' });

    const { newBalance } = req.body;
    if (newBalance === undefined || newBalance === null) {
      return res.status(400).json({ error: 'newBalance is required' });
    }

    const existing = await AccountRequest.findOne({
      accountId: account._id,
      requestType: 'updateBalance',
      status: { $in: ['pending', 'partiallyApproved'] },
    });
    if (existing) return res.status(400).json({ error: 'An active update request already exists for this account' });

    const role = req.user.role;

    const request = new AccountRequest({
      requestType: 'updateBalance',
      accountId: account._id,
      accountName: account.name,
      requestedBy: req.user._id,
      requestedByName: req.user.name,
      previousBalance: account.currentBalance,
      newBalance: parseFloat(newBalance),
      approvals: {
        [role]: true,
        [`${role}Uid`]: req.user._id.toString(),
        [`${role}At`]: new Date(),
      },
      status: 'partiallyApproved',
    });

    await request.save();

    const io = req.app.get('io');
    if (io) io.emit('account-request:created', request.toPublicJSON());

    sendPush({
      title: 'Balance Update Approval Needed',
      body: `${req.user.name} wants to update "${account.name}" balance from $${account.currentBalance} to $${newBalance}.`,
      data: { type: 'account', accountId: account._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create update request: ' + err.message });
  }
});

// POST /api/bank-accounts/:id/request-delete - Request account deletion
router.post('/:id/request-delete', authMiddleware, requireRole('accountant'), async (req, res) => {
  try {
    const account = await BankAccount.findById(req.params.id);
    if (!account) return res.status(404).json({ error: 'Account not found' });
    if (account.status !== 'active') return res.status(400).json({ error: 'Account is not active' });

    const existing = await AccountRequest.findOne({
      accountId: account._id,
      requestType: 'delete',
      status: { $in: ['pending', 'partiallyApproved'] },
    });
    if (existing) return res.status(400).json({ error: 'An active deletion request already exists for this account' });

    const role = req.user.role;

    const request = new AccountRequest({
      requestType: 'delete',
      accountId: account._id,
      accountName: account.name,
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
    if (io) io.emit('account-request:created', request.toPublicJSON());

    sendPush({
      title: 'Account Deletion Approval Needed',
      body: `${req.user.name} wants to delete bank account "${account.name}". Your approval is required.`,
      data: { type: 'account', accountId: account._id.toString() },
      roles: ['developer', 'boss', 'accountant'],
      excludeUserIds: [req.user._id.toString()],
    });

    res.status(201).json(request.toPublicJSON());
  } catch (err) {
    res.status(500).json({ error: 'Failed to create deletion request: ' + err.message });
  }
});

module.exports = router;
