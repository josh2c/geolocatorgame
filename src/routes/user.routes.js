const express = require('express');
const router = express.Router();
const { register, login, getProfile, updateProfile } = require('../controllers/user.controller');
const auth = require('../middleware/auth.middleware');

// Public routes
router.post('/register', register);
router.post('/login', login);

// Protected routes
router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);

module.exports = router; 