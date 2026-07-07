const mongoose = require('mongoose');

const projectRequestSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  clientName: { type: String, required: true, trim: true },
  totalCost: { type: Number, default: 0 },
  initialPayment: { type: Number, default: 0 },
  milestones: [{ type: String, trim: true }],
  startDate: { type: Date, required: true },
  expectedCompletionDate: { type: Date, required: true },
  projectStatus: {
    type: String,
    enum: ['planned', 'inProgress', 'completed'],
    default: 'planned',
  },
  requestedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  requestedByName: { type: String, default: '' },
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
  proofPath: { type: String, default: null },
  bankAccountId: { type: mongoose.Schema.Types.ObjectId, ref: 'BankAccount', default: null },
  projectId: { type: mongoose.Schema.Types.ObjectId, ref: 'Project', default: null },
  createdAt: { type: Date, default: Date.now },
});

projectRequestSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    name: this.name,
    clientName: this.clientName,
    totalCost: this.totalCost,
    initialPayment: this.initialPayment,
    milestones: this.milestones || [],
    startDate: this.startDate.toISOString(),
    expectedCompletionDate: this.expectedCompletionDate.toISOString(),
    projectStatus: this.projectStatus,
    requestedBy: this.requestedBy.toString(),
    requestedByName: this.requestedByName,
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
    proofPath: this.proofPath || null,
    bankAccountId: this.bankAccountId ? this.bankAccountId.toString() : null,
    projectId: this.projectId ? this.projectId.toString() : null,
    createdAt: this.createdAt.toISOString(),
  };
};

module.exports = mongoose.model('ProjectRequest', projectRequestSchema);
