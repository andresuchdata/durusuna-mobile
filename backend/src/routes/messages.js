const express = require('express');
const db = require('../config/database');
const { authenticate: auth } = require('../middleware/auth');
const { validate, messageSchema } = require('../utils/validation');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * @route GET /api/messages/conversations
 * @desc Get all conversations for the current user
 * @access Private
 */
router.get('/conversations', auth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Get conversations with latest message info
    const conversations = await db('messages as m1')
      .select(
        'other_user.id as other_user_id',
        'other_user.first_name as other_user_first_name',
        'other_user.last_name as other_user_last_name',
        'other_user.avatar_url as other_user_avatar',
        'other_user.user_type as other_user_type',
        'other_user.is_active as other_user_is_active',
        'm1.content as last_message_content',
        'm1.message_type as last_message_type',
        'm1.created_at as last_message_at',
        'm1.sender_id as last_message_sender_id',
        db.raw('COUNT(CASE WHEN m2.is_read = false AND m2.receiver_id = ? THEN 1 END) as unread_count', [req.user.id])
      )
      .leftJoin('messages as m2', function() {
        this.on(function() {
          this.on('m2.sender_id', '=', 'other_user.id')
              .andOn('m2.receiver_id', '=', db.raw('?', [req.user.id]))
              .orOn('m2.sender_id', '=', db.raw('?', [req.user.id]))
              .andOn('m2.receiver_id', '=', 'other_user.id');
        });
      })
      .join('users as other_user', function() {
        this.on(function() {
          this.on('other_user.id', '=', 'm1.sender_id')
              .andOn('m1.receiver_id', '=', db.raw('?', [req.user.id]))
              .orOn('other_user.id', '=', 'm1.receiver_id')
              .andOn('m1.sender_id', '=', db.raw('?', [req.user.id]));
        });
      })
      .where(function() {
        this.where('m1.sender_id', req.user.id)
            .orWhere('m1.receiver_id', req.user.id);
      })
      .where('other_user.id', '!=', req.user.id)
      .where('other_user.is_active', true)
      .whereIn('m1.id', function() {
        this.select(db.raw('MAX(messages.id)'))
            .from('messages')
            .where(function() {
              this.where('messages.sender_id', req.user.id)
                  .orWhere('messages.receiver_id', req.user.id);
            })
            .groupByRaw('LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id)');
      })
      .groupBy([
        'other_user.id',
        'other_user.first_name',
        'other_user.last_name',
        'other_user.avatar_url',
        'other_user.user_type',
        'other_user.is_active',
        'm1.content',
        'm1.message_type',
        'm1.created_at',
        'm1.sender_id'
      ])
      .orderBy('m1.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Format response
    const formattedConversations = conversations.map(conv => ({
      id: `${Math.min(req.user.id, conv.other_user_id)}_${Math.max(req.user.id, conv.other_user_id)}`,
      otherUser: {
        id: conv.other_user_id,
        firstName: conv.other_user_first_name,
        lastName: conv.other_user_last_name,
        displayName: `${conv.other_user_first_name} ${conv.other_user_last_name}`,
        avatarUrl: conv.other_user_avatar,
        userType: conv.other_user_type,
        isActive: conv.other_user_is_active
      },
      lastMessage: {
        content: conv.last_message_content,
        messageType: conv.last_message_type,
        createdAt: conv.last_message_at,
        isFromMe: conv.last_message_sender_id === req.user.id
      },
      unreadCount: parseInt(conv.unread_count) || 0,
      lastActivity: conv.last_message_at
    }));

    res.json({
      conversations: formattedConversations,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: conversations.length === parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Error fetching conversations:', error);
    res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

/**
 * @route GET /api/messages/conversation/:userId
 * @desc Get messages for a specific conversation
 * @access Private
 */
router.get('/conversation/:userId', auth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    // Verify other user exists and is active
    const otherUser = await db('users')
      .where('id', userId)
      .where('is_active', true)
      .first();

    if (!otherUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get messages between the two users
    const messages = await db('messages')
      .leftJoin('users as sender', 'messages.sender_id', 'sender.id')
      .leftJoin('message_attachments', 'messages.id', 'message_attachments.message_id')
      .where(function() {
        this.where({
          'messages.sender_id': req.user.id,
          'messages.receiver_id': userId
        }).orWhere({
          'messages.sender_id': userId,
          'messages.receiver_id': req.user.id
        });
      })
      .where('messages.is_deleted', false)
      .select(
        'messages.id',
        'messages.sender_id',
        'messages.receiver_id',
        'messages.content',
        'messages.message_type',
        'messages.reply_to_id',
        'messages.is_read',
        'messages.is_edited',
        'messages.edited_at',
        'messages.created_at',
        'messages.updated_at',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.avatar_url as sender_avatar',
        db.raw('COALESCE(json_agg(json_build_object(\'id\', message_attachments.id, \'fileName\', message_attachments.file_name, \'fileUrl\', message_attachments.file_url, \'fileType\', message_attachments.file_type, \'fileSize\', message_attachments.file_size)) FILTER (WHERE message_attachments.id IS NOT NULL), \'[]\') as attachments')
      )
      .groupBy([
        'messages.id',
        'messages.sender_id',
        'messages.receiver_id',
        'messages.content',
        'messages.message_type',
        'messages.reply_to_id',
        'messages.is_read',
        'messages.is_edited',
        'messages.edited_at',
        'messages.created_at',
        'messages.updated_at',
        'sender.first_name',
        'sender.last_name',
        'sender.avatar_url'
      ])
      .orderBy('messages.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Format messages
    const formattedMessages = messages.map(msg => ({
      id: msg.id,
      senderId: msg.sender_id,
      receiverId: msg.receiver_id,
      content: msg.content,
      messageType: msg.message_type,
      replyToId: msg.reply_to_id,
      isRead: msg.is_read,
      isEdited: msg.is_edited,
      editedAt: msg.edited_at,
      createdAt: msg.created_at,
      updatedAt: msg.updated_at,
      sender: {
        id: msg.sender_id,
        firstName: msg.sender_first_name,
        lastName: msg.sender_last_name,
        displayName: `${msg.sender_first_name} ${msg.sender_last_name}`,
        avatarUrl: msg.sender_avatar
      },
      attachments: Array.isArray(msg.attachments) ? msg.attachments : [],
      isFromMe: msg.sender_id === req.user.id
    }));

    res.json({
      messages: formattedMessages.reverse(), // Return in chronological order
      otherUser: {
        id: otherUser.id,
        firstName: otherUser.first_name,
        lastName: otherUser.last_name,
        displayName: `${otherUser.first_name} ${otherUser.last_name}`,
        avatarUrl: otherUser.avatar_url,
        userType: otherUser.user_type,
        isActive: otherUser.is_active
      },
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: messages.length === parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Error fetching conversation messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

/**
 * @route POST /api/messages/send
 * @desc Send a new message
 * @access Private
 */
router.post('/send', auth, validate(messageSchema), async (req, res) => {
  try {
    const {
      receiver_id,
      content,
      message_type = 'text',
      reply_to_id,
      metadata
    } = req.body;

    // Verify receiver exists and is active
    const receiver = await db('users')
      .where('id', receiver_id)
      .where('is_active', true)
      .first();

    if (!receiver) {
      return res.status(404).json({ error: 'Receiver not found' });
    }

    // Verify reply-to message exists if provided
    if (reply_to_id) {
      const replyMessage = await db('messages')
        .where('id', reply_to_id)
        .where(function() {
          this.where({
            sender_id: req.user.id,
            receiver_id: receiver_id
          }).orWhere({
            sender_id: receiver_id,
            receiver_id: req.user.id
          });
        })
        .first();

      if (!replyMessage) {
        return res.status(400).json({ error: 'Invalid reply-to message' });
      }
    }

    // Create message
    const [message] = await db('messages')
      .insert({
        sender_id: req.user.id,
        receiver_id,
        content: content || null,
        message_type,
        reply_to_id: reply_to_id || null,
        metadata: metadata ? JSON.stringify(metadata) : null,
        is_read: false,
        is_edited: false,
        is_deleted: false,
        created_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');

    // Get complete message data with sender info
    const completeMessage = await db('messages')
      .leftJoin('users as sender', 'messages.sender_id', 'sender.id')
      .where('messages.id', message.id)
      .select(
        'messages.*',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.avatar_url as sender_avatar'
      )
      .first();

    const formattedMessage = {
      id: completeMessage.id,
      senderId: completeMessage.sender_id,
      receiverId: completeMessage.receiver_id,
      content: completeMessage.content,
      messageType: completeMessage.message_type,
      replyToId: completeMessage.reply_to_id,
      isRead: completeMessage.is_read,
      isEdited: completeMessage.is_edited,
      editedAt: completeMessage.edited_at,
      createdAt: completeMessage.created_at,
      updatedAt: completeMessage.updated_at,
      sender: {
        id: completeMessage.sender_id,
        firstName: completeMessage.sender_first_name,
        lastName: completeMessage.sender_last_name,
        displayName: `${completeMessage.sender_first_name} ${completeMessage.sender_last_name}`,
        avatarUrl: completeMessage.sender_avatar
      },
      attachments: [],
      isFromMe: true
    };

    res.status(201).json({
      message: formattedMessage
    });

    // TODO: Emit socket event for real-time messaging
    // socketService.emitToUser(receiver_id, 'new_message', formattedMessage);

  } catch (error) {
    logger.error('Error sending message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

/**
 * @route PUT /api/messages/:messageId/mark-read
 * @desc Mark a message as read
 * @access Private
 */
router.put('/:messageId/mark-read', auth, async (req, res) => {
  try {
    const { messageId } = req.params;

    // Verify message exists and user is the receiver
    const message = await db('messages')
      .where('id', messageId)
      .where('receiver_id', req.user.id)
      .where('is_deleted', false)
      .first();

    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Update message as read
    await db('messages')
      .where('id', messageId)
      .update({
        is_read: true,
        updated_at: new Date()
      });

    res.json({
      message: 'Message marked as read'
    });

  } catch (error) {
    logger.error('Error marking message as read:', error);
    res.status(500).json({ error: 'Failed to mark message as read' });
  }
});

/**
 * @route PUT /api/messages/:messageId
 * @desc Edit a message
 * @access Private
 */
router.put('/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: 'Message content is required' });
    }

    // Verify message exists and user is the sender
    const message = await db('messages')
      .where('id', messageId)
      .where('sender_id', req.user.id)
      .where('is_deleted', false)
      .first();

    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Check if message is too old to edit (24 hours)
    const messageAge = new Date() - new Date(message.created_at);
    const maxEditAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

    if (messageAge > maxEditAge) {
      return res.status(400).json({ 
        error: 'Message is too old to edit (24 hour limit)' 
      });
    }

    // Update message
    await db('messages')
      .where('id', messageId)
      .update({
        content: content.trim(),
        is_edited: true,
        edited_at: new Date(),
        updated_at: new Date()
      });

    // Get updated message
    const updatedMessage = await db('messages')
      .leftJoin('users as sender', 'messages.sender_id', 'sender.id')
      .where('messages.id', messageId)
      .select(
        'messages.*',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.avatar_url as sender_avatar'
      )
      .first();

    const formattedMessage = {
      id: updatedMessage.id,
      senderId: updatedMessage.sender_id,
      receiverId: updatedMessage.receiver_id,
      content: updatedMessage.content,
      messageType: updatedMessage.message_type,
      replyToId: updatedMessage.reply_to_id,
      isRead: updatedMessage.is_read,
      isEdited: updatedMessage.is_edited,
      editedAt: updatedMessage.edited_at,
      createdAt: updatedMessage.created_at,
      updatedAt: updatedMessage.updated_at,
      sender: {
        id: updatedMessage.sender_id,
        firstName: updatedMessage.sender_first_name,
        lastName: updatedMessage.sender_last_name,
        displayName: `${updatedMessage.sender_first_name} ${updatedMessage.sender_last_name}`,
        avatarUrl: updatedMessage.sender_avatar
      },
      attachments: [],
      isFromMe: updatedMessage.sender_id === req.user.id
    };

    res.json({
      message: formattedMessage
    });

  } catch (error) {
    logger.error('Error editing message:', error);
    res.status(500).json({ error: 'Failed to edit message' });
  }
});

/**
 * @route DELETE /api/messages/:messageId
 * @desc Delete a message (soft delete)
 * @access Private
 */
router.delete('/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;

    // Verify message exists and user is the sender
    const message = await db('messages')
      .where('id', messageId)
      .where('sender_id', req.user.id)
      .where('is_deleted', false)
      .first();

    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Soft delete message
    await db('messages')
      .where('id', messageId)
      .update({
        is_deleted: true,
        deleted_at: new Date(),
        updated_at: new Date()
      });

    res.json({
      message: 'Message deleted successfully'
    });

  } catch (error) {
    logger.error('Error deleting message:', error);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

/**
 * @route GET /api/messages/search
 * @desc Search messages
 * @access Private
 */
router.get('/search', auth, async (req, res) => {
  try {
    const { q, user_id, message_type, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({ 
        error: 'Search query must be at least 2 characters long' 
      });
    }

    let query = db('messages')
      .leftJoin('users as sender', 'messages.sender_id', 'sender.id')
      .leftJoin('users as receiver', 'messages.receiver_id', 'receiver.id')
      .where(function() {
        this.where('messages.sender_id', req.user.id)
            .orWhere('messages.receiver_id', req.user.id);
      })
      .where('messages.is_deleted', false)
      .where('messages.content', 'ilike', `%${q.trim()}%`);

    if (user_id) {
      query = query.where(function() {
        this.where({
          'messages.sender_id': user_id,
          'messages.receiver_id': req.user.id
        }).orWhere({
          'messages.sender_id': req.user.id,
          'messages.receiver_id': user_id
        });
      });
    }

    if (message_type) {
      query = query.where('messages.message_type', message_type);
    }

    const messages = await query
      .select(
        'messages.*',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.avatar_url as sender_avatar',
        'receiver.first_name as receiver_first_name',
        'receiver.last_name as receiver_last_name',
        'receiver.avatar_url as receiver_avatar'
      )
      .orderBy('messages.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    const formattedMessages = messages.map(msg => ({
      id: msg.id,
      senderId: msg.sender_id,
      receiverId: msg.receiver_id,
      content: msg.content,
      messageType: msg.message_type,
      replyToId: msg.reply_to_id,
      isRead: msg.is_read,
      isEdited: msg.is_edited,
      editedAt: msg.edited_at,
      createdAt: msg.created_at,
      sender: {
        id: msg.sender_id,
        firstName: msg.sender_first_name,
        lastName: msg.sender_last_name,
        displayName: `${msg.sender_first_name} ${msg.sender_last_name}`,
        avatarUrl: msg.sender_avatar
      },
      receiver: {
        id: msg.receiver_id,
        firstName: msg.receiver_first_name,
        lastName: msg.receiver_last_name,
        displayName: `${msg.receiver_first_name} ${msg.receiver_last_name}`,
        avatarUrl: msg.receiver_avatar
      },
      isFromMe: msg.sender_id === req.user.id
    }));

    res.json({
      messages: formattedMessages,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: messages.length === parseInt(limit)
      },
      query: q.trim()
    });

  } catch (error) {
    logger.error('Error searching messages:', error);
    res.status(500).json({ error: 'Failed to search messages' });
  }
});

module.exports = router; 