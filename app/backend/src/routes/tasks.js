const express = require('express');
const { pool } = require('../db');
const auth = require('../middleware/auth');
const router = express.Router();

// Get all projects
router.get('/projects', auth, async (req, res) => {
  const result = await pool.query(
    'SELECT * FROM projects WHERE owner_id = $1 ORDER BY created_at DESC',
    [req.user.id]
  );
  res.json(result.rows);
});

// Create project
router.post('/projects', auth, async (req, res) => {
  const { name, description } = req.body;
  const result = await pool.query(
    'INSERT INTO projects (name, description, owner_id) VALUES ($1, $2, $3) RETURNING *',
    [name, description, req.user.id]
  );
  res.status(201).json(result.rows[0]);
});

// Get tasks by project
router.get('/projects/:projectId/tasks', auth, async (req, res) => {
  const result = await pool.query(
    'SELECT t.*, u.name as assignee_name FROM tasks t LEFT JOIN users u ON t.assignee_id = u.id WHERE t.project_id = $1 ORDER BY t.created_at DESC',
    [req.params.projectId]
  );
  res.json(result.rows);
});

// Create task
router.post('/projects/:projectId/tasks', auth, async (req, res) => {
  const { title, description, status, priority, due_date } = req.body;
  const result = await pool.query(
    'INSERT INTO tasks (title, description, status, priority, project_id, assignee_id, due_date) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
    [title, description, status || 'todo', priority || 'medium', req.params.projectId, req.user.id, due_date || null]
  );
  res.status(201).json(result.rows[0]);
});

// Update task
router.put('/tasks/:id', auth, async (req, res) => {
  const { title, description, status, priority, due_date } = req.body;
  const result = await pool.query(
    'UPDATE tasks SET title=$1, description=$2, status=$3, priority=$4, due_date=$5 WHERE id=$6 RETURNING *',
    [title, description, status, priority, due_date, req.params.id]
  );
  res.json(result.rows[0]);
});

// Delete task
router.delete('/tasks/:id', auth, async (req, res) => {
  await pool.query('DELETE FROM tasks WHERE id = $1', [req.params.id]);
  res.json({ message: 'Task deleted' });
});

module.exports = router;
