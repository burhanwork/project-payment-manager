const mongoose = require('mongoose');

const projectSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  clientName: { type: String, required: true, trim: true },
  totalCost: { type: Number, required: true, default: 0 },
  totalPaid: { type: Number, default: 0 },
  remainingBalance: { type: Number, default: 0 },
  startDate: { type: Date, required: true },
  expectedCompletionDate: { type: Date, required: true },
  milestones: [{ type: String, trim: true }],
  completionPercentage: { type: Number, default: 0, min: 0, max: 100 },
  status: { type: String, enum: ['planned', 'inProgress', 'completed'], default: 'planned' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  createdAt: { type: Date, default: Date.now },
});

projectSchema.pre('save', function (next) {
  if (this.isNew) {
    this.remainingBalance = this.totalCost - this.totalPaid;
  }
  next();
});

projectSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    name: this.name,
    clientName: this.clientName,
    totalCost: this.totalCost,
    totalPaid: this.totalPaid,
    remainingBalance: this.remainingBalance,
    startDate: this.startDate.toISOString(),
    expectedCompletionDate: this.expectedCompletionDate.toISOString(),
    milestones: this.milestones || [],
    completionPercentage: this.completionPercentage || 0,
    status: this.status,
    createdBy: this.createdBy.toString(),
    createdAt: this.createdAt.toISOString(),
  };
};

module.exports = mongoose.model('Project', projectSchema);
