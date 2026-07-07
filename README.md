# Project Payment Manager

A Flutter app for tracking projects, recording payments against them, and moving
those payments through an approval workflow. It's built for a small team where a
boss signs off on money going out, an accountant records and reconciles it, and a
developer keeps the whole thing running. Updates show up live across everyone's
devices over a Socket.io connection to the backend.

## What it does

- **Projects** — create projects, see their status, and track what has been paid
  against each one.
- **Payments** — log payments, attach receipt images, and view a payment's full
  history and detail.
- **Approvals** — payments and account changes go through an approval queue.
  Requests are raised by one role and approved or rejected by another.
- **Accounts & bank details** — manage user accounts and bank account records,
  with requests for new accounts and for deletions handled through the same
  review flow.
- **Roles** — three roles ship by default: `boss`, `accountant`, and `developer`,
  each seeing the parts of the app that apply to them.
- **Real-time updates** — the app holds a live socket to the server, so a payment
  approved on one device updates the others without a manual refresh.

## Tech

**App (Flutter)**
- Flutter with Riverpod for state management
- `socket_io_client` for the live connection
- `http` for the REST API
- `sqflite` for local caching / offline data
- Firebase (push/messaging) via `firebase_core`

**Backend (Node)**
- Express REST API
- MongoDB via Mongoose
- Socket.io for real-time events
- JWT auth with bcrypt-hashed passwords
- Multer for receipt/image uploads

## Getting started

### Backend

```bash
cd backend
npm install
cp .env.example .env      # then edit .env with your own values
npm run seed              # creates the three default role accounts
npm start                 # starts the API + socket server on PORT (default 3003)
```

The server reads its config from environment variables (see `backend/.env.example`):

- `MONGO_URI` — MongoDB connection string
- `JWT_SECRET` — secret for signing tokens (required; the server won't start
  without it)
- `PORT` — port to listen on (default `3003`)

Running `npm run seed` creates three starter accounts, all with the password
`ChangeMe123!` — change these before using the app for anything real:

| Role       | Email                    |
| ---------- | ------------------------ |
| boss       | boss@example.com         |
| accountant | accountant@example.com   |
| developer  | developer@example.com    |

### App

```bash
flutter pub get
flutter run
```

The API base URL defaults to `http://localhost:3003` (see
`lib/services/api_client.dart` and `lib/services/socket_service.dart`). Point it
at your own server if you're running the backend elsewhere.

Firebase is configured through `lib/firebase_options.dart`, which ships with
placeholder values. Generate your own with `flutterfire configure` (or drop in
your `GoogleService-Info.plist`) before building for a device.

## Notes

- No secrets are committed. Copy `.env.example` to `.env` and supply your own
  Mongo URI, JWT secret, and Firebase credentials.
- The seed accounts and passwords are placeholders meant only to get you a
  working login on first run.
