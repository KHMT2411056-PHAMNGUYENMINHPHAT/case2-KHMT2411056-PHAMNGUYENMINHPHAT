const express = require('express');
const router = express.Router();
const Task = require('../models/task.model');

// 1. GET: Lấy danh sách công việc
router.get('/', async (req, res) => {
    try {
        const tasks = await Task.find().sort({ createdAt: -1 });
        res.json(tasks);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// 2. GET: Lấy chi tiết 1 công việc
router.get('/:id', async (req, res) => {
    try {
        const task = await Task.findById(req.params.id);
        if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });
        res.json(task);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// 3. POST: Tạo công việc mới
router.post('/', async (req, res) => {
    const task = new Task({
        title: req.body.title,
        description: req.body.description || '',
        status: req.body.status || 'todo',
        priority: req.body.priority || 'medium',
        dueDate: req.body.dueDate ? new Date(req.body.dueDate) : null
    });

    try {
        const newTask = await task.save();
        res.status(201).json(newTask);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// 4. PUT: Chỉnh sửa công việc
router.put('/:id', async (req, res) => {
    try {
        const updatedTask = await Task.findByIdAndUpdate(
            req.params.id,
            req.body,
            { new: true, runValidators: true }
        );
        if (!updatedTask) return res.status(404).json({ message: 'Không tìm thấy công việc' });
        res.json(updatedTask);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// 5. DELETE: Xóa công việc
router.delete('/:id', async (req, res) => {
    try {
        const deletedTask = await Task.findByIdAndDelete(req.params.id);
        if (!deletedTask) return res.status(404).json({ message: 'Không tìm thấy công việc' });
        res.json({ message: 'Xóa công việc thành công' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;