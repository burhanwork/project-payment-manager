const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  projectId: { type: mongoose.Schema.Types.ObjectId, ref: 'Project', required: true },
  title: { type: String, required: true, trim: true },
  module: { type: String, default: null, trim: true },
  amount: { type: Number, required: true },
  date: { type: Date, required: true },
  method: {
    type: String,
    enum: ['bankTransfer', 'cash', 'check', 'creditCard', 'online', 'other'],
    default: 'bankTransfer',
  },
  notes: { type: String, default: null },
  proofPath: { type: String, default: null },
  bankAccountId: { type: mongoose.Schema.Types.ObjectId, ref: 'BankAccount', default: null },
  addedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  addedByName: { type: String, default: '' },
  approvals: {
    developer: { type: Boolean, default: null },
    boss: { type: Boolean, default: null },
    accountant: { type: Boolean, default: null },
    developerUid: { type: String, default: null },
    bossUid: { type: String, default: null },
    accountantUid: { type: String, default: null },
    developerAt: { type: Date, default: null },
    bossAt: { type: Date, default: null },
    accountantAt: { type: Date, default: null },
  },
  status: {
    type: String,
    enum: ['pending', 'partiallyApproved', 'approved', 'rejected'],
    default: 'pending',
  },
  createdAt: { type: Date, default: Date.now },
});

paymentSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    projectId: this.projectId.toString(),
    title: this.title,
    module: this.module,
    amount: this.amount,
    date: this.date.toISOString(),
    method: this.method,
    notes: this.notes,
    proofPath: this.proofPath,
    bankAccountId: this.bankAccountId ? this.bankAccountId.toString() : null,
    addedBy: this.addedBy.toString(),
    addedByName: this.addedByName,
    approvals: {
      developer: this.approvals.developer,
      boss: this.approvals.boss,
      accountant: this.approvals.accountant,
      developerUid: this.approvals.developerUid,
      bossUid: this.approvals.bossUid,
      accountantUid: this.approvals.accountantUid,
      developerAt: this.approvals.developerAt ? this.approvals.developerAt.toISOString() : null,
      bossAt: this.approvals.bossAt ? this.approvals.bossAt.toISOString() : null,
      accountantAt: this.approvals.accountantAt ? this.approvals.accountantAt.toISOString() : null,
    },
    status: this.status,
    createdAt: this.createdAt.toISOString(),
  };
};

module.exports = mongoose.model('Payment', paymentSchema);
