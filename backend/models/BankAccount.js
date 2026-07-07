const mongoose = require('mongoose');

const bankAccountSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  accountNumber: { type: String, default: null, trim: true },
  bankName: { type: String, required: true, trim: true },
  currency: { type: String, default: 'USD' },
  currentBalance: { type: Number, required: true, default: 0 },
  notes: { type: String, default: null },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  createdByName: { type: String, default: '' },
  status: {
    type: String,
    enum: ['pending', 'active', 'inactive'],
    default: 'pending',
  },
  createdAt: { type: Date, default: Date.now },
});

bankAccountSchema.methods.toPublicJSON = function () {
  return {
    id: this._id.toString(),
    name: this.name,
    accountNumber: this.accountNumber,
    bankName: this.bankName,
    currency: this.currency,
    currentBalance: this.currentBalance,
    notes: this.notes,
    createdBy: this.createdBy.toString(),
    createdByName: this.createdByName,
    status: this.status,
    createdAt: this.createdAt.toISOString(),
  };
};

module.exports = mongoose.model('BankAccount', bankAccountSchema);
