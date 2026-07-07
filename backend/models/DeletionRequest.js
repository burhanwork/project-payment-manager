const mongoose = require('mongoose');

const deletionRequestSchema = new mongoose.Schema({
  targetType: {
    type: String,
    enum: ['project', 'payment', 'milestone'],
    required: true,
  },
  targetId: { type: mongoose.Schema.Types.ObjectId, required: true },
  targetName: { type: String, required: true },
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
  createdAt: { type: Date, default: Date.now },
});

deletionRequestSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    targetType: this.targetType,
    targetId: this.targetId.toString(),
    targetName: this.targetName,
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
    createdAt: this.createdAt.toISOString(),
  };
};

module.exports = mongoose.model('DeletionRequest', deletionRequestSchema);
