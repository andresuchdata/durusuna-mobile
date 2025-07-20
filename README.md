# Durusuna Mobile - School Classroom Chat App

A production-grade Flutter mobile application for real-time school communication featuring class updates and direct messaging.

## ✨ Features Completed

### 🎯 Core Features
- **Class Updates** - Social media-like announcements system
- **Direct Messaging** - WhatsApp-style real-time chat
- **User Authentication** - JWT-based secure login/registration
- **Modern UI** - Clean, professional design with proper theming

### 📢 Class Updates
- Teachers can post announcements, homework, reminders, and events
- Support for emoji reactions (👍, ❤️, 😊, 😮, 😢, 😡)
- Comments system with threaded discussions
- Attachment support (framework ready)
- Pin important updates
- Edit/delete own posts
- Real-time updates

### 💬 Direct Messaging
- WhatsApp-like chat interface
- Real-time messaging with Socket.io
- Typing indicators
- Message status (sent, delivered, read)
- Media support (images, files, audio - framework ready)
- Message reactions and replies (framework ready)
- Search users to start conversations
- Online/offline status indicators

### 👥 User Management
- Multiple user types: Teacher, Student, Parent
- Role-based access control (admin/user)
- School-based organization
- User profiles with avatars

### 🎨 UI/UX
- Modern Material Design 3
- Dark/Light theme support
- Responsive design
- Smooth animations
- Clean typography
- Professional color scheme

## 🏗️ Architecture

### Frontend (Flutter)
```
lib/
├── core/
│   ├── constants/        # App constants, themes, API endpoints
│   └── storage/         # Local storage service (Hive)
├── shared/
│   ├── models/          # Data models with JSON serialization
│   ├── services/        # API, Socket, Auth, Chat services
│   ├── providers/       # Riverpod state management
│   └── widgets/         # Reusable UI components
└── features/
    ├── auth/            # Authentication screens
    ├── home/            # Dashboard and navigation
    ├── class_updates/   # Class announcements system
    └── chat/            # Messaging system
```

### Backend (Node.js)
```
backend/
├── src/
│   ├── config/          # Database and server configuration
│   ├── middleware/      # Authentication and validation
│   ├── routes/          # API endpoints
│   ├── utils/           # Helper functions
│   └── migrations/      # Database schema
└── package.json
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Node.js (>=16.0.0)
- PostgreSQL (>=12.0)

### Backend Setup

1. **Install dependencies**
```bash
cd backend
npm install
```

2. **Environment setup**
```bash
cp .env.example .env
# Edit .env with your database credentials and configurations
```

3. **Database setup**
```bash
# Create database
createdb durusuna_dev

# Run migrations
npx knex migrate:latest

# (Optional) Run seeds
npx knex seed:run
```

4. **Start the server**
```bash
npm run dev
```

Server will run on `http://localhost:3001`

### Frontend Setup

1. **Get dependencies**
```bash
flutter pub get
```

2. **Generate code**
```bash
flutter packages pub run build_runner build
```

3. **Run the app**
```bash
flutter run
```

## 🔧 Configuration

### API Configuration
Update `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'http://your-backend-url/api';
```

### Database Configuration
Update `backend/.env`:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=durusuna_dev
DB_USER=your_username
DB_PASSWORD=your_password
```

## 📱 Key Technologies

### Frontend
- **Flutter** - Cross-platform UI framework
- **Riverpod** - State management
- **Dio** - HTTP client with interceptors
- **Socket.io Client** - Real-time communication
- **Hive** - Local storage and caching
- **JSON Annotation** - Serialization

### Backend
- **Express.js** - Web framework
- **Socket.io** - Real-time WebSocket communication
- **Knex.js** - SQL query builder
- **PostgreSQL** - Primary database
- **JWT** - Authentication
- **Joi** - Request validation
- **Winston** - Logging

## 🎨 Design System

### Colors
- **Primary**: Professional blue (#2196F3)
- **Success**: Green for positive actions
- **Warning**: Amber for attention
- **Error**: Red for errors
- **Text**: Proper contrast ratios

### Typography
- **Headlines**: Medium weight
- **Body**: Regular weight
- **Captions**: Light weight
- Clean, readable fonts

## 🔐 Security Features

- JWT-based authentication with refresh tokens
- Role-based access control
- Input validation and sanitization
- SQL injection prevention
- Rate limiting (configured)
- Secure password hashing

## 📊 Database Schema

### Core Tables
- `schools` - School organizations
- `users` - All user types with roles
- `classes` - Class entities
- `user_classes` - Many-to-many relationships
- `lessons` - Individual lessons
- `messages` - Chat messages
- `class_updates` - Announcements
- `class_update_comments` - Comment system

## 🔄 Real-time Features

### Socket.io Events
- Message sending/receiving
- Typing indicators
- User online/offline status
- Class update notifications
- Comment notifications

## 🧪 Testing Strategy

### Frontend Testing
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

### Backend Testing
```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage
```

## 🚀 Deployment

### Backend Deployment
1. Set production environment variables
2. Run migrations on production database
3. Deploy to your preferred platform (AWS, Heroku, etc.)
4. Configure Socket.io for production

### Mobile App Deployment
1. Update API endpoints for production
2. Build release versions:
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📈 Upcoming Features

- [ ] File upload and media sharing
- [ ] Push notifications
- [ ] Class management dashboard
- [ ] Assignment system
- [ ] Calendar integration
- [ ] Video/voice calling
- [ ] Offline support
- [ ] Multi-language support

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team

---

**Built with ❤️ for educational communication** 