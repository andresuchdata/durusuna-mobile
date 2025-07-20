const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const socketAuth = (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    
    if (!token) {
      return next(new Error('Authentication error: No token provided'));
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.id;
    socket.userRole = decoded.role;
    next();
  } catch (error) {
    logger.error('Socket authentication error:', error);
    next(new Error('Authentication error: Invalid token'));
  }
};

const handleConnection = (socket) => {
  logger.info(`User ${socket.userId} connected to socket`);

  // Join user to their personal room
  socket.join(`user_${socket.userId}`);

  // Join class rooms
  socket.on('join_class', (classId) => {
    socket.join(`class_${classId}`);
    logger.info(`User ${socket.userId} joined class ${classId}`);
  });

  // Leave class rooms
  socket.on('leave_class', (classId) => {
    socket.leave(`class_${classId}`);
    logger.info(`User ${socket.userId} left class ${classId}`);
  });

  // Handle typing indicators
  socket.on('typing_start', (data) => {
    socket.to(`class_${data.classId}`).emit('user_typing', {
      userId: socket.userId,
      classId: data.classId
    });
  });

  socket.on('typing_stop', (data) => {
    socket.to(`class_${data.classId}`).emit('user_stopped_typing', {
      userId: socket.userId,
      classId: data.classId
    });
  });

  // Handle new messages
  socket.on('new_message', (messageData) => {
    // Broadcast to all users in the class
    socket.to(`class_${messageData.classId}`).emit('message_received', {
      ...messageData,
      senderId: socket.userId
    });
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    logger.info(`User ${socket.userId} disconnected`);
  });
};

const initializeSocket = (io) => {
  // Apply authentication middleware
  io.use(socketAuth);

  // Handle connections
  io.on('connection', handleConnection);

  return io;
};

module.exports = initializeSocket; 