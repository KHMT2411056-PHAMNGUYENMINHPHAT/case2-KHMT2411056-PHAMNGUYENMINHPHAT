const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const app = express();

app.use(express.json());

// Routes
const taskRoutes = require('./routes/task.routes');
const authRoutes = require('./routes/auth.routes'); // <- Bổ sung route Auth

app.use('/api/tasks', taskRoutes);
app.use('/api/auth', authRoutes); // <- Khai báo endpoint /api/auth

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB connected');
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