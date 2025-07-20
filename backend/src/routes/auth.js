const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db = require('../config/database');
const { generateTokenPair, verifyRefreshToken } = require('../utils/jwt');
const { validate, registerSchema, loginSchema, passwordResetRequestSchema, passwordResetSchema } = require('../utils/validation');
const { authenticate, rateLimitSensitive } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * @route POST /api/auth/register
 * @desc Register a new user
 * @access Public
 */
router.post('/register', validate(registerSchema), rateLimitSensitive, async (req, res) => {
  const trx = await db.transaction();
  
  try {
    const {
      email,
      password,
      first_name,
      last_name,
      user_type,
      school_id,
      phone,
      date_of_birth,
      student_id,
      employee_id
    } = req.body;

    // Check if email already exists
    const existingUser = await trx('users').where('email', email).first();
    if (existingUser) {
      await trx.rollback();
      return res.status(409).json({
        error: 'Conflict',
        message: 'Email already registered'
      });
    }

    // Verify school exists
    const school = await trx('schools').where({ id: school_id, is_active: true }).first();
    if (!school) {
      await trx.rollback();
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid school ID'
      });
    }

    // Hash password
    const saltRounds = 12;
    const password_hash = await bcrypt.hash(password, saltRounds);

    // Create user
    const [user] = await trx('users').insert({
      id: uuidv4(),
      email,
      password_hash,
      first_name,
      last_name,
      user_type,
      school_id,
      phone,
      date_of_birth,
      student_id,
      employee_id,
      role: 'user', // Default role
      is_active: true,
      email_verified: false
    }).returning(['id', 'email', 'first_name', 'last_name', 'user_type', 'role', 'school_id']);

    await trx.commit();

    // Generate tokens
    const tokens = generateTokenPair(user);

    // Log successful registration
    logger.info(`User registered successfully: ${email}`);

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        user_type: user.user_type,
        role: user.role,
        school_id: user.school_id
      },
      ...tokens
    });
  } catch (error) {
    await trx.rollback();
    logger.error('Registration error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Registration failed'
    });
  }
});

/**
 * @route POST /api/auth/login
 * @desc Login user
 * @access Public
 */
router.post('/login', validate(loginSchema), rateLimitSensitive, async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user by email
    const user = await db('users')
      .select('id', 'email', 'password_hash', 'first_name', 'last_name', 'user_type', 'role', 'school_id', 'is_active', 'email_verified', 'created_at', 'updated_at')
      .where('email', email)
      .first();

    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password'
      });
    }

    if (!user.is_active) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Account is deactivated'
      });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password'
      });
    }

    // Update last login
    await db('users').where('id', user.id).update({
      last_login_at: db.fn.now()
    });

    // Generate tokens
    const tokens = generateTokenPair(user);

    // Log successful login
    logger.info(`User logged in successfully: ${email}`);

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        user_type: user.user_type,
        role: user.role,
        school_id: user.school_id,
        email_verified: user.email_verified,
        is_active: user.is_active,
        created_at: user.created_at || new Date().toISOString(),
        updated_at: user.updated_at || new Date().toISOString()
      },
      ...tokens
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Login failed'
    });
  }
});

/**
 * @route POST /api/auth/refresh
 * @desc Refresh access token
 * @access Public
 */
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Refresh token is required'
      });
    }

    // Verify refresh token
    const decoded = verifyRefreshToken(refreshToken);

    // Get user
    const user = await db('users')
      .select('id', 'email', 'first_name', 'last_name', 'user_type', 'role', 'school_id', 'is_active')
      .where({ id: decoded.id, is_active: true })
      .first();

    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User not found or inactive'
      });
    }

    // Generate new tokens
    const tokens = generateTokenPair(user);

    res.json({
      message: 'Token refreshed successfully',
      ...tokens
    });
  } catch (error) {
    logger.error('Token refresh error:', error);
    
    if (error.message.includes('expired') || error.message.includes('invalid')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired refresh token'
      });
    }
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Token refresh failed'
    });
  }
});

/**
 * @route POST /api/auth/logout
 * @desc Logout user (invalidate tokens)
 * @access Private
 */
router.post('/logout', authenticate, async (req, res) => {
  try {
    // In a production environment, you would typically:
    // 1. Add the token to a blacklist (Redis)
    // 2. Store refresh tokens in database and remove them here
    // For now, we'll just log the logout
    
    logger.info(`User logged out: ${req.user.email}`);
    
    res.json({
      message: 'Logout successful'
    });
  } catch (error) {
    logger.error('Logout error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Logout failed'
    });
  }
});

/**
 * @route GET /api/auth/me
 * @desc Get current user profile
 * @access Private
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    const user = await db('users')
      .select(
        'id', 'email', 'first_name', 'last_name', 'phone', 'avatar_url',
        'user_type', 'role', 'date_of_birth', 'student_id', 'employee_id',
        'preferences', 'email_verified', 'last_login_at', 'created_at'
      )
      .where('id', req.user.id)
      .first();

    if (!user) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'User not found'
      });
    }

    // Get school information
    const school = await db('schools')
      .select('id', 'name', 'logo_url')
      .where('id', req.user.school_id)
      .first();

    res.json({
      user: {
        ...user,
        school
      }
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to get user profile'
    });
  }
});

/**
 * @route POST /api/auth/change-password
 * @desc Change user password
 * @access Private
 */
router.post('/change-password', authenticate, rateLimitSensitive, async (req, res) => {
  try {
    const { current_password, new_password } = req.body;

    if (!current_password || !new_password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Current password and new password are required'
      });
    }

    // Validate new password strength
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
    if (!passwordRegex.test(new_password)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'New password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character'
      });
    }

    // Get current user with password
    const user = await db('users')
      .select('id', 'password_hash')
      .where('id', req.user.id)
      .first();

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(current_password, user.password_hash);
    if (!isCurrentPasswordValid) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Current password is incorrect'
      });
    }

    // Hash new password
    const saltRounds = 12;
    const new_password_hash = await bcrypt.hash(new_password, saltRounds);

    // Update password
    await db('users')
      .where('id', req.user.id)
      .update({
        password_hash: new_password_hash,
        updated_at: db.fn.now()
      });

    logger.info(`Password changed for user: ${req.user.email}`);

    res.json({
      message: 'Password changed successfully'
    });
  } catch (error) {
    logger.error('Change password error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to change password'
    });
  }
});

module.exports = router; 