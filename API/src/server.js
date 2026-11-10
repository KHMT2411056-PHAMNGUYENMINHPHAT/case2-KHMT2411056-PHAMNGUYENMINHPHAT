const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const cors = require('cors');   // thêm dòng này

dotenv.config();

const app = express();

app.use(cors());                // thêm dòng này (trước các route)
app.use(express.json());

// Routes
const taskRoutes = require('./routes/task.routes');
const authRoutes = require('./routes/auth.routes'); // <- Bổ sung route Auth
const userRoutes = require('./routes/user.routes');             // Phần C
const assignmentRoutes = require('./routes/assignment.routes'); // Phần C
const shareRoutes = require('./routes/share.routes');           // Phần C
const notificationRoutes = require('./routes/notification.routes'); // Phần D
const emailLogRoutes = require('./routes/email_log.routes');         // Phần D
const statisticsRoutes = require('./routes/statistics.routes');      // Phần E
const activityRoutes = require('./routes/activity.routes');          // Phần E
const { verifyEmailConfig } = require('./config/email');        // Phần D
const { startReminderJob } = require('./jobs/reminder.job');    // Phần D

// Các route con của /api/tasks/:id/... phải đặt TRƯỚC /api/tasks
app.use('/api/users', userRoutes);
app.use('/api/tasks/:id/assignees', assignmentRoutes);
app.use('/api/tasks/:id/shares', shareRoutes);
app.use('/api/tasks/:id/activities', activityRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/auth', authRoutes); // <- Khai báo endpoint /api/auth
app.use('/api/notifications', notificationRoutes);
app.use('/api/statistics', statisticsRoutes);
app.use('/api', emailLogRoutes); // LUÔN đặt SAU tất cả app.use('/api/...') khác

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB connected');
    verifyEmailConfig(); // Phần D1: kiểm tra kết nối SMTP (chỉ in log)
    startReminderJob();  // Phần D3: nhắc việc trước hạn + tự gửi lại email lỗi
  })
  .catch((error) => {
    console.error(
      'MongoDB connection error:',
      error
    );
  });

app.get('/', (req, res) => {
  res.json({
    message: 'Task Manager API is running',
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(
    `Server running on port ${PORT}`
  );
});