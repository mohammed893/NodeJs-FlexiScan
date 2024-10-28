const jwt = require('jsonwebtoken');
require('dotenv').config();

const verifyToken = (req, res, next) => {
    const token = req.headers.authorization?.split(" ")[1];

    if (!token) {
        return res.status(401).json({ status: 'error', message: 'Token required' });
    }

    jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, decoded) => {
        if (err) {
            return res.status(403).json({ status: 'error', message: 'Invalid or expired token' });
        }

        req.user = decoded;
        next();
    });
};

module.exports = verifyToken;