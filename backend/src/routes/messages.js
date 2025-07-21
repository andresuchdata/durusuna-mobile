const express = require('express');
const db = require('../config/database');
const { authenticate: auth } = require('../middleware/auth');
const { validate, messageSchema } = require('../utils/validation');
const logger = require('../utils/logger');

const router = express.Router();

// Helper function to safely parse JSON
const safeJsonParse = (jsonData, fallback = null) => {
  try {
    // If it's already an object/array, return it as-is
    if (typeof jsonData === 'object' && jsonData !== null) {
      return jsonData;
    }
    // If it's a string, try to parse it
    if (typeof jsonData === 'string' && jsonData.trim()) {
      return JSON.parse(jsonData);
    }
    return fallback;
  } catch (error) {
    logger.warn('Failed to parse JSON:', { jsonData, error: error.message });
    return fallback;
  }
};

/**
 * @route GET /api/messages/conversations
 * @desc Get all conversations for the current user
 * @access Private
 */
router.get('/conversations', auth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Get conversations with latest message info (simplified approach)
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
        'm1.sender_id as last_message_sender_id'
      )
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
      other_user: {
        id: conv.other_user_id,
        first_name: conv.other_user_first_name,
        last_name: conv.other_user_last_name,
        email: '', // Not included in conversation query
        avatar_url: conv.other_user_avatar,
        user_type: conv.other_user_type,
        role: 'user', // Default role
        is_active: conv.other_user_is_active,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      },
      last_message: {
        content: conv.last_message_content,
        message_type: conv.last_message_type,
        created_at: conv.last_message_at,
        is_from_me: conv.last_message_sender_id === req.user.id
      },
      unread_count: 0, // TODO: Implement unread count properly
      last_activity: conv.last_message_at
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

    // Get messages between the two users (simplified query without attachments for now)
    const messages = await db('messages')
      .leftJoin('users as sender', 'messages.sender_id', 'sender.id')
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
        'messages.is_deleted',
        'messages.edited_at',
        'messages.deleted_at',
        'messages.delivered_at',
        'messages.read_at',
        'messages.read_status',
        'messages.reactions',
        'messages.created_at',
        'messages.updated_at',
        'sender.id as sender_id',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.email as sender_email',
        'sender.avatar_url as sender_avatar',
        'sender.user_type as sender_user_type',
        'sender.role as sender_role',
        'sender.is_active as sender_is_active',
        'sender.created_at as sender_created_at',
        'sender.updated_at as sender_updated_at'
      )
      .orderBy('messages.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Format messages
    const formattedMessages = messages.map(msg => ({
      id: msg.id,
      sender_id: msg.sender_id,
      receiver_id: msg.receiver_id,
      content: msg.content,
      message_type: msg.message_type,
      reply_to_id: msg.reply_to_id,
      is_read: Boolean(msg.is_read),
      is_edited: Boolean(msg.is_edited),
      is_deleted: Boolean(msg.is_deleted),
      edited_at: msg.edited_at,
      deleted_at: msg.deleted_at,
      delivered_at: msg.delivered_at,
      read_at: msg.read_at,
      read_status: msg.read_status || 'sent',
      reactions: safeJsonParse(msg.reactions, {}),
      created_at: msg.created_at,
      updated_at: msg.updated_at,
      sender: {
        id: msg.sender_id,
        first_name: msg.sender_first_name,
        last_name: msg.sender_last_name,
        email: msg.sender_email,
        avatar_url: msg.sender_avatar,
        user_type: msg.sender_user_type,
        role: msg.sender_role,
        is_active: Boolean(msg.sender_is_active),
        created_at: msg.sender_created_at,
        updated_at: msg.sender_updated_at
      },
      attachments: [], // TODO: Implement attachments loading separately
      is_from_me: Boolean(msg.sender_id === req.user.id)
    }));

    res.json({
      messages: formattedMessages.reverse(), // Return in chronological order
      other_user: {
        id: otherUser.id,
        first_name: otherUser.first_name,
        last_name: otherUser.last_name,
        email: otherUser.email,
        avatar_url: otherUser.avatar_url,
        user_type: otherUser.user_type,
        role: otherUser.role || 'user',
        is_active: otherUser.is_active,
        created_at: otherUser.created_at || new Date().toISOString(),
        updated_at: otherUser.updated_at || new Date().toISOString()
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
        'messages.id',
        'messages.sender_id', 
        'messages.receiver_id',
        'messages.content',
        'messages.message_type',
        'messages.reply_to_id',
        'messages.is_read',
        'messages.is_edited',
        'messages.is_deleted',
        'messages.edited_at',
        'messages.deleted_at',
        'messages.delivered_at',
        'messages.read_at',
        'messages.read_status',
        'messages.reactions',
        'messages.created_at',
        'messages.updated_at',
        'sender.id as sender_id',
        'sender.first_name as sender_first_name',
        'sender.last_name as sender_last_name',
        'sender.email as sender_email',
        'sender.avatar_url as sender_avatar',
        'sender.user_type as sender_user_type',
        'sender.role as sender_role',
        'sender.is_active as sender_is_active',
        'sender.created_at as sender_created_at',
        'sender.updated_at as sender_updated_at'
      )
      .first();

    const formattedMessage = {
      id: completeMessage.id,
      sender_id: completeMessage.sender_id,
      receiver_id: completeMessage.receiver_id,
      content: completeMessage.content,
      message_type: completeMessage.message_type,
      reply_to_id: completeMessage.reply_to_id,
      is_read: Boolean(completeMessage.is_read),
      is_edited: Boolean(completeMessage.is_edited),
      is_deleted: Boolean(completeMessage.is_deleted),
      edited_at: completeMessage.edited_at,
      deleted_at: completeMessage.deleted_at,
      delivered_at: completeMessage.delivered_at,
      read_at: completeMessage.read_at,
      read_status: completeMessage.read_status || 'sent',
      reactions: safeJsonParse(completeMessage.reactions, {}),
      created_at: completeMessage.created_at,
      updated_at: completeMessage.updated_at,
      sender: {
        id: completeMessage.sender_id,
        first_name: completeMessage.sender_first_name,
        last_name: completeMessage.sender_last_name,
        email: completeMessage.sender_email,
        avatar_url: completeMessage.sender_avatar || '',
        user_type: completeMessage.sender_user_type,
        role: completeMessage.sender_role,
        is_active: Boolean(completeMessage.sender_is_active),
        created_at: completeMessage.sender_created_at,
        updated_at: completeMessage.sender_updated_at
      },
      attachments: [],
      is_from_me: true
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
        read_at: new Date(),
        read_status: 'read',
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
        first_name: updatedMessage.sender_first_name,
        last_name: updatedMessage.sender_last_name,
        avatar_url: updatedMessage.sender_avatar
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
        first_name: msg.sender_first_name,
        last_name: msg.sender_last_name,
        avatar_url: msg.sender_avatar
      },
      receiver: {
        id: msg.receiver_id,
        first_name: msg.receiver_first_name,
        last_name: msg.receiver_last_name,
        avatar_url: msg.receiver_avatar
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

/**
 * @route POST /api/messages/:messageId/reactions
 * @desc Add or toggle a reaction to a message
 * @access Private
 */
router.post('/:messageId/reactions', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { emoji } = req.body;

    if (!emoji || typeof emoji !== 'string') {
      return res.status(400).json({ error: 'Emoji is required' });
    }

    // Get the existing message
    const existingMessage = await db('messages')
      .where('id', messageId)
      .where('is_deleted', false)
      .where(function() {
        this.where('sender_id', req.user.id)
            .orWhere('receiver_id', req.user.id);
      })
      .first();

    if (!existingMessage) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Parse existing reactions with structure: { "emoji": { "count": 0, "users": [] } }
    const reactions = safeJsonParse(existingMessage.reactions, {});
    
    // Initialize emoji reaction if it doesn't exist
    if (!reactions[emoji]) {
      reactions[emoji] = { count: 0, users: [] };
    }

    // Check if user has already reacted with this emoji
    const userIndex = reactions[emoji].users.indexOf(req.user.id);
    
    if (userIndex > -1) {
      // User has already reacted, remove the reaction
      reactions[emoji].users.splice(userIndex, 1);
      reactions[emoji].count = Math.max(0, reactions[emoji].count - 1);
      
      // Remove emoji entirely if no reactions left
      if (reactions[emoji].count === 0) {
        delete reactions[emoji];
      }
    } else {
      // User hasn't reacted, add the reaction
      reactions[emoji].users.push(req.user.id);
      reactions[emoji].count += 1;
    }

    // Update the message with new reactions
    await db('messages')
      .where('id', messageId)
      .update({
        reactions: JSON.stringify(reactions),
        updated_at: new Date()
      });

    res.json({
      message: userIndex > -1 ? 'Reaction removed successfully' : 'Reaction added successfully',
      reactions
    });

  } catch (error) {
    logger.error('Error toggling message reaction:', error);
    res.status(500).json({ error: 'Failed to toggle reaction' });
  }
});

/**
 * @route PUT /api/messages/:messageId/delivered
 * @desc Mark a message as delivered
 * @access Private
 */
router.put('/:messageId/delivered', auth, async (req, res) => {
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

    // Update message as delivered if not already
    if (!message.delivered_at) {
      await db('messages')
        .where('id', messageId)
        .update({
          delivered_at: new Date(),
          read_status: 'delivered',
          updated_at: new Date()
        });
    }

    res.json({
      message: 'Message marked as delivered'
    });

  } catch (error) {
    logger.error('Error marking message as delivered:', error);
    res.status(500).json({ error: 'Failed to mark message as delivered' });
  }
});

module.exports = router; 