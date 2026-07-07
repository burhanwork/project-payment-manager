#!/bin/bash

echo "========================================"
echo " Project Payment Manager - Setup"
echo "========================================"

# 1. Install Node dependencies
echo ""
echo "[1/3] Installing Node.js dependencies..."
npm install

# 2. Restore MongoDB database
echo ""
echo "[2/3] Restoring MongoDB database..."
mongorestore --db project_payment_manager <path-to-backup>
echo "Database restored successfully."

# 3. Start the server
echo ""
echo "[3/3] Starting backend server..."
echo "Server will run on http://localhost:3000"
echo ""
node server.js
