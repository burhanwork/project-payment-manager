const secret = process.env.JWT_SECRET;

if (!secret) {
  throw new Error(
    'JWT_SECRET is not configured. Set it in your environment (see .env.example) before starting the server.'
  );
}

module.exports = {
  secret,
  expiresIn: '30d',
};
