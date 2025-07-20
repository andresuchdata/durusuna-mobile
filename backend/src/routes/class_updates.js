const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../config/database');
const { authenticate: auth } = require('../middleware/auth');
const { validate, classUpdateSchema, commentSchema } = require('../utils/validation');
const logger = require('../utils/logger');

const router = express.Router();

// Helper function to safely parse JSON
const safeJsonParse = (jsonString, fallback = null) => {
  try {
    return jsonString && jsonString.trim() ? JSON.parse(jsonString) : fallback;
  } catch (error) {
    logger.warn('Failed to parse JSON:', { jsonString, error: error.message });
    return fallback;
  }
};

/**
 * @route GET /api/class-updates/:classId
 * @desc Get class updates for a specific class
 * @access Private
 */
router.get('/:classId', auth, async (req, res) => {
  try {
    const { classId } = req.params;
    const { page = 1, limit = 20, type } = req.query;
    const offset = (page - 1) * limit;

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

    // Build query for class updates
    let query = db('class_updates')
      .join('users', 'class_updates.author_id', 'users.id')
      .where('class_updates.class_id', classId)
      .where('class_updates.is_deleted', false)
      .select(
        'class_updates.*',
        'users.id as author_user_id',
        'users.first_name as author_first_name',
        'users.last_name as author_last_name',
        'users.email as author_email',
        'users.phone as author_phone',
        'users.avatar_url as author_avatar',
        'users.user_type as author_user_type',
        'users.role as author_role',
        'users.school_id as author_school_id',
        'users.is_active as author_is_active',
        'users.last_login_at as author_last_active_at',
        'users.created_at as author_created_at',
        'users.updated_at as author_updated_at'
      );

    // Filter by type if specified
    if (type) {
      query = query.where('class_updates.update_type', type);
    }

    const updates = await query
      .orderBy([
        { column: 'class_updates.is_pinned', order: 'desc' },
        { column: 'class_updates.created_at', order: 'desc' }
      ])
      .limit(limit)
      .offset(offset);

    // Get comments count for each update
    const updateIds = updates.map(update => update.id);
    let commentCounts = [];
    
    if (updateIds.length > 0) {
      commentCounts = await db('class_update_comments')
        .whereIn('class_update_id', updateIds)
        .where('is_deleted', false)
        .groupBy('class_update_id')
        .select('class_update_id')
        .count('* as count');
    }

    // Create a map for quick lookup of comment counts
    const commentCountMap = {};
    commentCounts.forEach(item => {
      commentCountMap[item.class_update_id] = parseInt(item.count);
    });

    // Format response with comment counts
    const formattedUpdates = updates.map(update => ({
      id: update.id,
      class_id: update.class_id,
      author_id: update.author_id,
      title: update.title,
      content: update.content,
      update_type: update.update_type,
              attachments: safeJsonParse(update.attachments, []),
        reactions: safeJsonParse(update.reactions, {}),
      is_pinned: update.is_pinned,
      is_edited: update.is_edited,
      edited_at: update.edited_at,
      is_deleted: update.is_deleted,
      deleted_at: update.deleted_at,
      created_at: update.created_at,
      updated_at: update.updated_at,
      author: {
        id: update.author_user_id,
        first_name: update.author_first_name,
        last_name: update.author_last_name,
        email: update.author_email,
        phone: update.author_phone,
        avatar_url: update.author_avatar || "",
        user_type: update.author_user_type,
        role: update.author_role,
        school_id: update.author_school_id,
        is_active: update.author_is_active,
        last_active_at: update.author_last_active_at,
        created_at: update.author_created_at,
        updated_at: update.author_updated_at
      },
      comments_count: commentCountMap[update.id] || 0
    }));

    res.json({
      updates: formattedUpdates,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: updates.length === parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Error fetching class updates:', error);
    res.status(500).json({ error: 'Failed to fetch class updates' });
  }
});

/**
 * @route POST /api/class-updates/create
 * @desc Create a new class update
 * @access Private (Teachers only)
 */
router.post('/create', auth, validate(classUpdateSchema), async (req, res) => {
  try {
    const {
      class_id,
      title,
      content,
      update_type = 'announcement',
      attachments = []
    } = req.body;

    // Get current user details
    const currentUser = await db('users')
      .where('id', req.user.id)
      .select('user_type', 'role', 'school_id')
      .first();

    if (!currentUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if user is an admin teacher - they can create updates for any class in their school
    if (currentUser.role === 'admin' && currentUser.user_type === 'teacher') {
      // Verify the class exists and belongs to their school
      const targetClass = await db('classes')
        .where('id', class_id)
        .where('school_id', currentUser.school_id)
        .first();

      if (!targetClass) {
        return res.status(404).json({ error: 'Class not found or access denied' });
      }
    } else {
      // For non-admin users, check if they're enrolled in the specific class
      const userClass = await db('user_classes')
        .join('users', 'user_classes.user_id', 'users.id')
        .where({
          'user_classes.user_id': req.user.id,
          'user_classes.class_id': class_id
        })
        .select('users.user_type', 'user_classes.role_in_class')
        .first();

      if (!userClass) {
        return res.status(403).json({ error: 'Access denied to this class' });
      }

      if (userClass.user_type !== 'teacher' && userClass.role_in_class !== 'teacher') {
        return res.status(403).json({ error: 'Only teachers can create class updates' });
      }
    }

    // Create the class update
    const updateId = uuidv4();
    const [newUpdate] = await db('class_updates')
      .insert({
        id: updateId,
        class_id,
        author_id: req.user.id,
        title,
        content,
        update_type,
        attachments: JSON.stringify(attachments),
        reactions: JSON.stringify({}),
        is_pinned: false,
        is_edited: false,
        is_deleted: false,
        created_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');

    // Get the created update with author information
    const createdUpdate = await db('class_updates')
      .join('users', 'class_updates.author_id', 'users.id')
      .where('class_updates.id', updateId)
      .select(
        'class_updates.*',
        'users.id as author_user_id',
        'users.first_name as author_first_name',
        'users.last_name as author_last_name',
        'users.email as author_email',
        'users.phone as author_phone',
        'users.avatar_url as author_avatar',
        'users.user_type as author_user_type',
        'users.role as author_role',
        'users.school_id as author_school_id',
        'users.is_active as author_is_active',
        'users.last_login_at as author_last_active_at',
        'users.created_at as author_created_at',
        'users.updated_at as author_updated_at'
      )
      .first();

    const formattedUpdate = {
      id: createdUpdate.id,
      class_id: createdUpdate.class_id,
      author_id: createdUpdate.author_id,
      title: createdUpdate.title,
      content: createdUpdate.content,
      update_type: createdUpdate.update_type,
      attachments: safeJsonParse(createdUpdate.attachments, []),
      reactions: safeJsonParse(createdUpdate.reactions, {}),
      is_pinned: createdUpdate.is_pinned,
      is_edited: createdUpdate.is_edited,
      edited_at: createdUpdate.edited_at,
      is_deleted: createdUpdate.is_deleted,
      deleted_at: createdUpdate.deleted_at,
      created_at: createdUpdate.created_at,
      updated_at: createdUpdate.updated_at,
      author: {
        id: createdUpdate.author_user_id,
        first_name: createdUpdate.author_first_name || "",
        last_name: createdUpdate.author_last_name || "",
        email: createdUpdate.author_email || "",
        phone: createdUpdate.author_phone || "",
        avatar_url: createdUpdate.author_avatar || "",
        user_type: createdUpdate.author_user_type || "",
        role: createdUpdate.author_role || "",
        school_id: createdUpdate.author_school_id || null,
        is_active: createdUpdate.author_is_active || false,
        last_active_at: createdUpdate.author_last_active_at || "",
        created_at: createdUpdate.author_created_at || "",
        updated_at: createdUpdate.author_updated_at || ""
      },
      comments_count: 0
    };

    res.status(201).json({
      update: formattedUpdate
    });

  } catch (error) {
    logger.error('Error creating class update:', error);
    res.status(500).json({ error: 'Failed to create class update' });
  }
});

/**
 * @route PUT /api/class-updates/:updateId
 * @desc Update a class update
 * @access Private (Author or Teacher)
 */
router.put('/:updateId', auth, async (req, res) => {
  try {
    const { updateId } = req.params;
    const {
      title,
      content,
      update_type,
      attachments
    } = req.body;

    // Get the existing update
    const existingUpdate = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!existingUpdate) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user is the author or a teacher in the class
    let canEdit = existingUpdate.author_id === req.user.id;

    if (!canEdit) {
      const userClass = await db('user_classes')
        .join('users', 'user_classes.user_id', 'users.id')
        .where({
          'user_classes.user_id': req.user.id,
          'user_classes.class_id': existingUpdate.class_id
        })
        .select('users.user_type', 'user_classes.role_in_class')
        .first();

      canEdit = userClass && (userClass.user_type === 'teacher' || userClass.role_in_class === 'teacher');
    }

    if (!canEdit) {
      return res.status(403).json({ error: 'You can only edit your own updates or you must be a teacher' });
    }

    // Prepare update data
    const updateData = {
      updated_at: new Date(),
      is_edited: true,
      edited_at: new Date()
    };

    if (title !== undefined) updateData.title = title;
    if (content !== undefined) updateData.content = content;
    if (update_type !== undefined) updateData.update_type = update_type;
    if (attachments !== undefined) updateData.attachments = JSON.stringify(attachments);

    // Update the class update
    await db('class_updates')
      .where('id', updateId)
      .update(updateData);

    // Get the updated record with author information
    const updatedRecord = await db('class_updates')
      .join('users', 'class_updates.author_id', 'users.id')
      .where('class_updates.id', updateId)
      .select(
        'class_updates.*',
        'users.id as author_user_id',
        'users.first_name as author_first_name',
        'users.last_name as author_last_name',
        'users.email as author_email',
        'users.phone as author_phone',
        'users.avatar_url as author_avatar',
        'users.user_type as author_user_type',
        'users.role as author_role',
        'users.school_id as author_school_id',
        'users.is_active as author_is_active',
        'users.last_login_at as author_last_active_at',
        'users.created_at as author_created_at',
        'users.updated_at as author_updated_at'
      )
      .first();

    const formattedUpdate = {
      id: updatedRecord.id,
      class_id: updatedRecord.class_id,
      author_id: updatedRecord.author_id,
      title: updatedRecord.title,
      content: updatedRecord.content,
      update_type: updatedRecord.update_type,
      attachments: safeJsonParse(updatedRecord.attachments, []),
      reactions: safeJsonParse(updatedRecord.reactions, {}),
      is_pinned: updatedRecord.is_pinned,
      is_edited: updatedRecord.is_edited,
      edited_at: updatedRecord.edited_at,
      is_deleted: updatedRecord.is_deleted,
      deleted_at: updatedRecord.deleted_at,
      created_at: updatedRecord.created_at,
      updated_at: updatedRecord.updated_at,
      author: {
        id: updatedRecord.author_id,
        name: updatedRecord.author_name,
        email: updatedRecord.author_email,
        avatar_url: updatedRecord.author_avatar
      }
    };

    res.json({
      update: formattedUpdate
    });

  } catch (error) {
    logger.error('Error updating class update:', error);
    res.status(500).json({ error: 'Failed to update class update' });
  }
});

/**
 * @route DELETE /api/class-updates/:updateId
 * @desc Delete a class update (soft delete)
 * @access Private (Author or Teacher)
 */
router.delete('/:updateId', auth, async (req, res) => {
  try {
    const { updateId } = req.params;

    // Get the existing update
    const existingUpdate = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!existingUpdate) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user is the author or a teacher in the class
    let canDelete = existingUpdate.author_id === req.user.id;

    if (!canDelete) {
      const userClass = await db('user_classes')
        .join('users', 'user_classes.user_id', 'users.id')
        .where({
          'user_classes.user_id': req.user.id,
          'user_classes.class_id': existingUpdate.class_id
        })
        .select('users.user_type', 'user_classes.role_in_class')
        .first();

      canDelete = userClass && (userClass.user_type === 'teacher' || userClass.role_in_class === 'teacher');
    }

    if (!canDelete) {
      return res.status(403).json({ error: 'Only the author or class teachers can delete this update' });
    }

    // Soft delete the update
    await db('class_updates')
      .where('id', updateId)
      .update({
        is_deleted: true,
        deleted_at: new Date(),
        updated_at: new Date()
      });

    res.json({
      message: 'Class update deleted successfully'
    });

  } catch (error) {
    logger.error('Error deleting class update:', error);
    res.status(500).json({ error: 'Failed to delete class update' });
  }
});

/**
 * @route GET /api/class-updates/:updateId/comments
 * @desc Get comments for a class update
 * @access Private
 */
router.get('/:updateId/comments', auth, async (req, res) => {
  try {
    const { updateId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Check if update exists
    const update = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!update) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user has access to the class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: update.class_id
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    // Get comments with author information
    const comments = await db('class_update_comments')
      .join('users', 'class_update_comments.author_id', 'users.id')
      .where('class_update_comments.class_update_id', updateId)
      .where('class_update_comments.is_deleted', false)
      .select(
        'class_update_comments.*',
        db.raw("CONCAT(users.first_name, ' ', users.last_name) as author_name"),
        'users.email as author_email',
        'users.avatar_url as author_avatar'
      )
      .orderBy('class_update_comments.created_at', 'asc')
      .limit(limit)
      .offset(offset);

    const formattedComments = comments.map(comment => ({
      id: comment.id,
      class_update_id: comment.class_update_id,
      author_id: comment.author_id,
      content: comment.content,
      reply_to_id: comment.reply_to_id,
      is_edited: comment.is_edited,
      edited_at: comment.edited_at,
      created_at: comment.created_at,
      updated_at: comment.updated_at,
      author: {
        id: comment.author_id,
        name: comment.author_name,
        email: comment.author_email,
        avatar_url: comment.author_avatar
      }
    }));

    res.json({
      comments: formattedComments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: comments.length === parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Error fetching comments:', error);
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

/**
 * @route POST /api/class-updates/:updateId/comments
 * @desc Add a comment to a class update
 * @access Private
 */
router.post('/:updateId/comments', auth, validate(commentSchema), async (req, res) => {
  try {
    const { updateId } = req.params;
    const { content, reply_to_id } = req.body;

    // Check if update exists
    const update = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!update) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user has access to the class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: update.class_id
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    // Validate reply_to_id if provided
    if (reply_to_id) {
      const parentComment = await db('class_update_comments')
        .where('id', reply_to_id)
        .where('class_update_id', updateId)
        .where('is_deleted', false)
        .first();

      if (!parentComment) {
        return res.status(400).json({ error: 'Invalid reply-to comment' });
      }
    }

    // Create the comment
    const commentId = uuidv4();
    const [newComment] = await db('class_update_comments')
      .insert({
        id: commentId,
        class_update_id: updateId,
        author_id: req.user.id,
        content,
        reply_to_id: reply_to_id || null,
        is_edited: false,
        is_deleted: false,
        created_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');

    // Get the created comment with author information
    const createdComment = await db('class_update_comments')
      .join('users', 'class_update_comments.author_id', 'users.id')
      .where('class_update_comments.id', commentId)
      .select(
        'class_update_comments.*',
        db.raw("CONCAT(users.first_name, ' ', users.last_name) as author_name"),
        'users.email as author_email',
        'users.avatar_url as author_avatar'
      )
      .first();

    const formattedComment = {
      id: createdComment.id,
      class_update_id: createdComment.class_update_id,
      author_id: createdComment.author_id,
      content: createdComment.content,
      reply_to_id: createdComment.reply_to_id,
      is_edited: createdComment.is_edited,
      edited_at: createdComment.edited_at,
      created_at: createdComment.created_at,
      updated_at: createdComment.updated_at,
      author: {
        id: createdComment.author_id,
        name: createdComment.author_name,
        email: createdComment.author_email,
        avatar_url: createdComment.author_avatar
      }
    };

    res.status(201).json({
      comment: formattedComment
    });

  } catch (error) {
    logger.error('Error creating comment:', error);
    res.status(500).json({ error: 'Failed to create comment' });
  }
});

/**
 * @route PUT /api/class-updates/:updateId/pin
 * @desc Pin or unpin a class update
 * @access Private (Teachers only)
 */
router.put('/:updateId/pin', auth, async (req, res) => {
  try {
    const { updateId } = req.params;
    const { is_pinned } = req.body;

    if (typeof is_pinned !== 'boolean') {
      return res.status(400).json({ error: 'is_pinned must be a boolean value' });
    }

    // Get the existing update
    const existingUpdate = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!existingUpdate) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user is a teacher in the class
    const userClass = await db('user_classes')
      .join('users', 'user_classes.user_id', 'users.id')
      .where({
        'user_classes.user_id': req.user.id,
        'user_classes.class_id': existingUpdate.class_id
      })
      .select('users.user_type', 'user_classes.role_in_class')
      .first();

    if (!userClass || (userClass.user_type !== 'teacher' && userClass.role_in_class !== 'teacher')) {
      return res.status(403).json({ error: 'Only teachers can pin/unpin updates' });
    }

    // Update pin status
    await db('class_updates')
      .where('id', updateId)
      .update({
        is_pinned,
        updated_at: new Date()
      });

    // Get the updated record
    const updatedRecord = await db('class_updates')
      .join('users', 'class_updates.author_id', 'users.id')
      .where('class_updates.id', updateId)
      .select(
        'class_updates.*',
        db.raw("CONCAT(users.first_name, ' ', users.last_name) as author_name"),
        'users.email as author_email',
        'users.avatar_url as author_avatar'
      )
      .first();

    const formattedUpdate = {
      id: updatedRecord.id,
      class_id: updatedRecord.class_id,
      author_id: updatedRecord.author_id,
      title: updatedRecord.title,
      content: updatedRecord.content,
      update_type: updatedRecord.update_type,
      attachments: safeJsonParse(updatedRecord.attachments, []),
      reactions: safeJsonParse(updatedRecord.reactions, {}),
      is_pinned: updatedRecord.is_pinned,
      is_edited: updatedRecord.is_edited,
      edited_at: updatedRecord.edited_at,
      is_deleted: updatedRecord.is_deleted,
      deleted_at: updatedRecord.deleted_at,
      created_at: updatedRecord.created_at,
      updated_at: updatedRecord.updated_at,
      author: {
        id: updatedRecord.author_id,
        name: updatedRecord.author_name,
        email: updatedRecord.author_email,
        avatar_url: updatedRecord.author_avatar
      }
    };

    res.json({
      update: formattedUpdate
    });

  } catch (error) {
    logger.error('Error updating pin status:', error);
    res.status(500).json({ error: 'Failed to update pin status' });
  }
});

/**
 * @route POST /api/class-updates/:updateId/reactions
 * @desc Add or update a reaction to a class update
 * @access Private
 */
router.post('/:updateId/reactions', auth, async (req, res) => {
  try {
    const { updateId } = req.params;
    const { emoji } = req.body;

    if (!emoji || typeof emoji !== 'string') {
      return res.status(400).json({ error: 'Emoji is required' });
    }

    // Get the existing update
    const existingUpdate = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!existingUpdate) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user has access to the class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: existingUpdate.class_id
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    // Parse existing reactions
    const reactions = safeJsonParse(existingUpdate.reactions, {});
    
    // Initialize emoji count if it doesn't exist
    if (!reactions[emoji]) {
      reactions[emoji] = 0;
    }

    // Increment reaction count
    reactions[emoji] += 1;

    // Update the class update with new reactions
    await db('class_updates')
      .where('id', updateId)
      .update({
        reactions: JSON.stringify(reactions),
        updated_at: new Date()
      });

    res.json({
      message: 'Reaction added successfully',
      reactions
    });

  } catch (error) {
    logger.error('Error adding reaction:', error);
    res.status(500).json({ error: 'Failed to add reaction' });
  }
});

/**
 * @route DELETE /api/class-updates/:updateId/reactions
 * @desc Remove a reaction from a class update
 * @access Private
 */
router.delete('/:updateId/reactions', auth, async (req, res) => {
  try {
    const { updateId } = req.params;
    const { emoji } = req.body;

    if (!emoji || typeof emoji !== 'string') {
      return res.status(400).json({ error: 'Emoji is required' });
    }

    // Get the existing update
    const existingUpdate = await db('class_updates')
      .where('id', updateId)
      .where('is_deleted', false)
      .first();

    if (!existingUpdate) {
      return res.status(404).json({ error: 'Class update not found' });
    }

    // Check if user has access to the class
    const userClass = await db('user_classes')
      .where({
        user_id: req.user.id,
        class_id: existingUpdate.class_id
      })
      .first();

    if (!userClass) {
      return res.status(403).json({ error: 'Access denied to this class' });
    }

    // Parse existing reactions
    const reactions = safeJsonParse(existingUpdate.reactions, {});
    
    // Decrease reaction count if it exists
    if (reactions[emoji] && reactions[emoji] > 0) {
      reactions[emoji] -= 1;
      
      // Remove emoji if count reaches 0
      if (reactions[emoji] === 0) {
        delete reactions[emoji];
      }
    }

    // Update the class update with new reactions
    await db('class_updates')
      .where('id', updateId)
      .update({
        reactions: JSON.stringify(reactions),
        updated_at: new Date()
      });

    res.json({
      message: 'Reaction removed successfully',
      reactions
    });

  } catch (error) {
    logger.error('Error removing reaction:', error);
    res.status(500).json({ error: 'Failed to remove reaction' });
  }
});

module.exports = router; 