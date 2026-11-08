// /api/users — tìm người để giao việc / chia sẻ
const express = require('express');
const { User, PUBLIC_USER_FIELDS, publicUser } = require('../utils/user_model');
const { auth, getUserId, asyncHandler, escapeRegex, requireValidId, HttpError } = require('../utils/helpers');

const router = express.Router();
router.use(auth);

// GET /api/users/search?q=  (tìm theo họ tên hoặc email, tối đa 10 kết quả, bỏ chính mình)
router.get('/search', asyncHandler(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 1) return res.json([]);
  const regex = { $regex: escapeRegex(q), $options: 'i' };

  // Chỉ tìm trên các trường thật sự có trong schema User (tránh điều kiện rỗng)
  const or = ['fullName', 'name', 'email']
    .filter((f) => User.schema.path(f))
    .map((f) => ({ [f]: regex }));
  if (!or.length) return res.json([]);

  const users = await User.find({ $or: or, _id: { $ne: getUserId(req) } })
    .select(PUBLIC_USER_FIELDS)
    .limit(10)
    .lean();
  res.json(users.map(publicUser));
}));

// GET /api/users/:id — thông tin công khai
router.get('/:id', asyncHandler(async (req, res) => {
  requireValidId(req.params.id, 'Mã người dùng');
  const user = await User.findById(req.params.id).select(PUBLIC_USER_FIELDS).lean();
  if (!user) throw new HttpError(404, 'Không tìm thấy người dùng');
  res.json(publicUser(user));
}));

module.exports = router;
