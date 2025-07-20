const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const { authenticate: auth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// Get current user profile
router.get('/profile', auth, async (req, res) => {
  try {
    const user = await db('users')
      .select('id', 'email', 'first_name', 'last_name', 'role', 'school_id', 'created_at')
      .where('id', req.user.id)
      .first();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get school info if user has one
    if (user.school_id) {
      const school = await db('schools')
        .select('name', 'address')
        .where('id', user.school_id)
        .first();
      user.school = school;
    }

    res.json(user);
  } catch (error) {
    logger.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// Update user profile
router.put('/profile', [
  auth,
  body('first_name').optional().isLength({ min: 1 }).trim(),
  body('last_name').optional().isLength({ min: 1 }).trim(),
  body('email').optional().isEmail().normalizeEmail()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { first_name, last_name, email } = req.body;
    const updateData = {};

    if (first_name) updateData.first_name = first_name;
    if (last_name) updateData.last_name = last_name;
    if (email) updateData.email = email;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    updateData.updated_at = new Date();

    await db('users')
      .where('id', req.user.id)
      .update(updateData);

    const updatedUser = await db('users')
      .select('id', 'email', 'first_name', 'last_name', 'role', 'school_id')
      .where('id', req.user.id)
      .first();

    res.json(updatedUser);
  } catch (error) {
    logger.error('Error updating user profile:', error);
    res.status(500).json({ error: 'Failed to update user profile' });
  }
});

// Change password
router.put('/password', [
  auth,
  body('current_password').notEmpty().withMessage('Current password is required'),
  body('new_password').isLength({ min: 8 }).withMessage('New password must be at least 8 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { current_password, new_password } = req.body;

    // Get current user
    const user = await db('users')
      .select('password')
      .where('id', req.user.id)
      .first();

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(current_password, user.password);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const saltRounds = 12;
    const hashedNewPassword = await bcrypt.hash(new_password, saltRounds);

    // Update password
    await db('users')
      .where('id', req.user.id)
      .update({
        password: hashedNewPassword,
        updated_at: new Date()
      });

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    logger.error('Error changing password:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
});

// Get users by school (admin only)
router.get('/school/:schoolId', auth, async (req, res) => {
  try {
    const { schoolId } = req.params;

    // Check if user is admin or belongs to the school
    if (req.user.role !== 'admin' && req.user.school_id !== schoolId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const users = await db('users')
      .select('id', 'email', 'first_name', 'last_name', 'role', 'created_at')
      .where('school_id', schoolId)
      .orderBy('last_name', 'asc');

    res.json(users);
  } catch (error) {
    logger.error('Error fetching school users:', error);
    res.status(500).json({ error: 'Failed to fetch school users' });
  }
});

module.exports = router; 