// /api/notifications — thông báo trong ứng dụng
const express = require('express');
const Notification = require('../models/notification.model');
const { auth, getUserId, asyncHandler, requireValidId, HttpError } = require('../utils/helpers');

const router = express.Router();
router.use(auth);

// GET /api/notifications?unreadOnly=true&limit=50
router.get('/', asyncHandler(async (req, res) => {
  const filter = { userId: getUserId(req) };
  if (req.query.unreadOnly === 'true') filter.isRead = false;
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const items = await Notification.find(filter).sort({ createdAt: -1 }).limit(limit).lean();
  res.json(items);
}));

// GET /api/notifications/unread-count
router.get('/unread-count', asyncHandler(async (req, res) => {
  const count = await Notification.countDocuments({ userId: getUserId(req), isRead: false });
  res.json({ count });
}));

// PATCH /api/notifications/read-all
router.patch('/read-all', asyncHandler(async (req, res) => {
  const r = await Notification.updateMany({ userId: getUserId(req), isRead: false }, { isRead: true });
  res.json({ message: 'Đã đánh dấu tất cả là đã đọc', updated: r.modifiedCount });
}));

// PATCH /api/notifications/:id/read
router.patch('/:id/read', asyncHandler(async (req, res) => {
  requireValidId(req.params.id, 'Mã thông báo');
  const n = await Notification.findOneAndUpdate(
    { _id: req.params.id, userId: getUserId(req) },
    { isRead: true },
    { returnDocument: 'after' }
  );
  if (!n) throw new HttpError(404, 'Không tìm thấy thông báo');
  res.json(n);
}));

module.exports = router;
