import { useState, useEffect } from 'react';
import api from '../api';
import { useNavigate } from 'react-router-dom';

const STATUS_COLORS = { todo: '#6366f1', 'in-progress': '#f59e0b', done: '#10b981', blocked: '#ef4444' };
const PRIORITY_COLORS = { low: '#22c55e', medium: '#f59e0b', high: '#ef4444' };

export default function Dashboard() {
  const [projects, setProjects] = useState([]);
  const [selectedProject, setSelectedProject] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [showProjectForm, setShowProjectForm] = useState(false);
  const [showTaskForm, setShowTaskForm] = useState(false);
  const [newProject, setNewProject] = useState({ name: '', description: '' });
  const [newTask, setNewTask] = useState({ title: '', description: '', status: 'todo', priority: 'medium', due_date: '' });
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const navigate = useNavigate();

  useEffect(() => { fetchProjects(); }, []);
  useEffect(() => { if (selectedProject) fetchTasks(selectedProject.id); }, [selectedProject]);

  const fetchProjects = async () => {
    const res = await api.get('/projects');
    setProjects(res.data);
    if (res.data.length > 0 && !selectedProject) setSelectedProject(res.data[0]);
  };

  const fetchTasks = async (projectId) => {
    const res = await api.get(`/projects/${projectId}/tasks`);
    setTasks(res.data);
  };

  const createProject = async (e) => {
    e.preventDefault();
    await api.post('/projects', newProject);
    setNewProject({ name: '', description: '' });
    setShowProjectForm(false);
    fetchProjects();
  };

  const createTask = async (e) => {
    e.preventDefault();
    await api.post(`/projects/${selectedProject.id}/tasks`, newTask);
    setNewTask({ title: '', description: '', status: 'todo', priority: 'medium', due_date: '' });
    setShowTaskForm(false);
    fetchTasks(selectedProject.id);
  };

  const updateTaskStatus = async (task, status) => {
    await api.put(`/tasks/${task.id}`, { ...task, status });
    fetchTasks(selectedProject.id);
  };

  const deleteTask = async (taskId) => {
    await api.delete(`/tasks/${taskId}`);
    fetchTasks(selectedProject.id);
  };

  const logout = () => { localStorage.clear(); navigate('/'); };

  const tasksByStatus = (status) => tasks.filter(t => t.status === status);

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#0f172a', color: '#f8fafc', fontFamily: 'sans-serif' }}>
      {/* Sidebar */}
      <div style={{ width: 260, background: '#1e293b', padding: 20, display: 'flex', flexDirection: 'column' }}>
        <h2 style={{ color: '#6366f1', marginBottom: 4 }}>🚀 TaskFlow</h2>
        <p style={{ color: '#94a3b8', fontSize: 13, marginBottom: 24 }}>Welcome, {user.name}</p>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase', letterSpacing: 1 }}>Projects</span>
          <button onClick={() => setShowProjectForm(!showProjectForm)} style={{ background: '#6366f1', border: 'none', color: '#fff', borderRadius: 4, padding: '2px 8px', cursor: 'pointer', fontSize: 18 }}>+</button>
        </div>
        {showProjectForm && (
          <form onSubmit={createProject} style={{ marginBottom: 16 }}>
            <input style={sideInput} placeholder="Project name" value={newProject.name}
              onChange={e => setNewProject({ ...newProject, name: e.target.value })} required />
            <input style={sideInput} placeholder="Description" value={newProject.description}
              onChange={e => setNewProject({ ...newProject, description: e.target.value })} />
            <button style={{ ...sideInput, background: '#6366f1', border: 'none', cursor: 'pointer', color: '#fff' }} type="submit">Create</button>
          </form>
        )}
        {projects.map(p => (
          <div key={p.id} onClick={() => setSelectedProject(p)}
            style={{ padding: '10px 12px', borderRadius: 8, cursor: 'pointer', marginBottom: 4, background: selectedProject?.id === p.id ? '#334155' : 'transparent', color: selectedProject?.id === p.id ? '#f8fafc' : '#94a3b8' }}>
            📁 {p.name}
          </div>
        ))}
        <div style={{ marginTop: 'auto' }}>
          <button onClick={logout} style={{ background: 'transparent', border: '1px solid #334155', color: '#94a3b8', padding: '8px 12px', borderRadius: 8, cursor: 'pointer', width: '100%' }}>Logout</button>
        </div>
      </div>

      {/* Main Board */}
      <div style={{ flex: 1, padding: 30, overflowY: 'auto' }}>
        {selectedProject ? (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 28 }}>
              <div>
                <h1 style={{ margin: 0, fontSize: 22 }}>{selectedProject.name}</h1>
                <p style={{ margin: 0, color: '#94a3b8', fontSize: 14 }}>{selectedProject.description}</p>
              </div>
              <button onClick={() => setShowTaskForm(!showTaskForm)}
                style={{ background: '#6366f1', border: 'none', color: '#fff', padding: '10px 20px', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}>
                + New Task
              </button>
            </div>
            {showTaskForm && (
              <form onSubmit={createTask} style={{ background: '#1e293b', padding: 20, borderRadius: 12, marginBottom: 24, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <input style={formInput} placeholder="Task title" value={newTask.title}
                  onChange={e => setNewTask({ ...newTask, title: e.target.value })} required />
                <input style={formInput} placeholder="Description" value={newTask.description}
                  onChange={e => setNewTask({ ...newTask, description: e.target.value })} />
                <select style={formInput} value={newTask.status} onChange={e => setNewTask({ ...newTask, status: e.target.value })}>
                  <option value="todo">To Do</option>
                  <option value="in-progress">In Progress</option>
                  <option value="done">Done</option>
                  <option value="blocked">Blocked</option>
                </select>
                <select style={formInput} value={newTask.priority} onChange={e => setNewTask({ ...newTask, priority: e.target.value })}>
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high">High</option>
                </select>
                <input style={formInput} type="date" value={newTask.due_date}
                  onChange={e => setNewTask({ ...newTask, due_date: e.target.value })} />
                <button type="submit" style={{ background: '#6366f1', border: 'none', color: '#fff', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}>Add Task</button>
              </form>
            )}

            {/* Kanban Board */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
              {['todo', 'in-progress', 'done', 'blocked'].map(status => (
                <div key={status} style={{ background: '#1e293b', borderRadius: 12, padding: 16 }}>
                  <div style={{ display: 'flex', alignItems: 'center', marginBottom: 14, gap: 8 }}>
                    <div style={{ width: 10, height: 10, borderRadius: '50%', background: STATUS_COLORS[status] }}></div>
                    <span style={{ fontWeight: 600, textTransform: 'capitalize', fontSize: 14 }}>{status.replace('-', ' ')}</span>
                    <span style={{ marginLeft: 'auto', background: '#334155', borderRadius: 12, padding: '2px 8px', fontSize: 12 }}>{tasksByStatus(status).length}</span>
                  </div>
                  {tasksByStatus(status).map(task => (
                    <div key={task.id} style={{ background: '#0f172a', borderRadius: 8, padding: 14, marginBottom: 10, borderLeft: `3px solid ${PRIORITY_COLORS[task.priority]}` }}>
                      <p style={{ margin: '0 0 6px', fontWeight: 600, fontSize: 14 }}>{task.title}</p>
                      {task.description && <p style={{ margin: '0 0 8px', color: '#64748b', fontSize: 12 }}>{task.description}</p>}
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
                        <span style={{ background: PRIORITY_COLORS[task.priority] + '22', color: PRIORITY_COLORS[task.priority], padding: '2px 8px', borderRadius: 12, fontSize: 11 }}>{task.priority}</span>
                        {task.due_date && <span style={{ color: '#64748b', fontSize: 11 }}>📅 {task.due_date.slice(0, 10)}</span>}
                      </div>
                      <div style={{ display: 'flex', gap: 6 }}>
                        {status !== 'in-progress' && <button onClick={() => updateTaskStatus(task, 'in-progress')} style={smallBtn('#f59e0b')}>▶</button>}
                        {status !== 'done' && <button onClick={() => updateTaskStatus(task, 'done')} style={smallBtn('#10b981')}>✓</button>}
                        <button onClick={() => deleteTask(task.id)} style={smallBtn('#ef4444')}>✕</button>
                      </div>
                    </div>
                  ))}
                </div>
              ))}
            </div>
          </>
        ) : (
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh', color: '#64748b' }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 48, marginBottom: 16 }}>📁</div>
              <p>Create your first project to get started</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

const sideInput = { width: '100%', padding: '8px 10px', marginBottom: 8, borderRadius: 6, border: '1px solid #334155', background: '#0f172a', color: '#f8fafc', fontSize: 13, boxSizing: 'border-box' };
const formInput = { padding: '10px 12px', borderRadius: 8, border: '1px solid #334155', background: '#0f172a', color: '#f8fafc', fontSize: 13 };
const smallBtn = (color) => ({ background: color + '22', color: color, border: `1px solid ${color}44`, borderRadius: 6, padding: '3px 8px', cursor: 'pointer', fontSize: 12 });
