const express = require('express');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const { authenticate: auth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// Get messages for a class
router.get('/class/:classId', auth, async (req, res) => {
  try {
    const { classId } = req.params;
    const { page = 1, limit = 50 } = req.query;

    // Check if user has access to this class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: classId
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    const offset = (page - 1) * limit;

    const messages = await db('messages')
      .leftJoin('users', 'messages.sender_id', 'users.id')
      .where('messages.class_id', classId)
      .select(
        'messages.id',
        'messages.content',
        'messages.message_type',
        'messages.created_at',
        'users.first_name',
        'users.last_name',
        'users.id as sender_id'
      )
      .orderBy('messages.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    res.json(messages);
  } catch (error) {
    logger.error('Error fetching messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// Send a message
router.post('/', [
  auth,
  body('class_id').notEmpty().withMessage('Class ID is required'),
  body('content').notEmpty().withMessage('Message content is required'),
  body('message_type').optional().isIn(['text', 'image', 'file']).withMessage('Invalid message type')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { class_id, content, message_type = 'text' } = req.body;

    // Check if user has access to this class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: class_id
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    const [message] = await db('messages')
      .insert({
        sender_id: req.user.id,
        class_id,
        content,
        message_type,
        created_at: new Date(),
        updated_at: new Date()
      })
      .returning(['id', 'content', 'message_type', 'created_at']);

    res.status(201).json(message);
  } catch (error) {
    logger.error('Error sending message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

module.exports = router; 