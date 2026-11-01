const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/user.model');
const authMiddleware = require('../middleware/auth.middleware');

// POST /api/auth/register - Đăng ký
router.post('/register', async (req, res) => {
    try {
        const { fullName, email, password } = req.body;

        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'Email đã tồn tại' });
        }

        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(password, salt);

        const newUser = new User({ fullName, email, passwordHash });
        await newUser.save();

        res.status(201).json({ message: 'Đăng ký tài khoản thành công' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// POST /api/auth/login - Đăng nhập
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(400).json({ message: 'Email hoặc mật khẩu không đúng' });
        }

        const isMatch = await bcrypt.compare(password, user.passwordHash);
        if (!isMatch) {
            return res.status(400).json({ message: 'Email hoặc mật khẩu không đúng' });
        }

        const token = jwt.sign(
            { userId: user._id, email: user.email },
            process.env.JWT_SECRET || 'secret',
            { expiresIn: '7d' }
        );

        res.json({
            token,
            user: {
                id: user._id,
                fullName: user.fullName,
                email: user.email
            }
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
// GET /api/auth/me - Xem thông tin cá nhân
router.get('/me', authMiddleware, async (req, res) => {
    try {
        const user = await User.findById(req.userId).select('-passwordHash');
        if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
        res.json(user);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// PUT /api/auth/me - Cập nhật thông tin cá nhân
router.put('/me', authMiddleware, async (req, res) => {
    try {
        console.log('PUT /me', req.userId, req.body);
        const { fullName, avatarUrl } = req.body;

        const user = await User.findById(req.userId);
        if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

        if (fullName) user.fullName = fullName;
        if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;
        await user.save();

        res.json({
            message: 'Cập nhật thành công',
            user: { id: user._id, fullName: user.fullName, email: user.email, avatarUrl: user.avatarUrl },
        });
    } catch (err) {
        console.error('PUT /me lỗi:', err);
        res.status(500).json({ message: err.message });
    }
});

// PUT /api/auth/change-password - Đổi mật khẩu
router.put('/change-password', authMiddleware, async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        const user = await User.findById(req.userId);

        const isMatch = await bcrypt.compare(oldPassword, user.passwordHash);
        if (!isMatch) {
            return res.status(400).json({ message: 'Mật khẩu cũ không đúng' });
        }

        const salt = await bcrypt.genSalt(10);
        user.passwordHash = await bcrypt.hash(newPassword, salt);
        await user.save();

        res.json({ message: 'Đổi mật khẩu thành công' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});
module.exports = router;