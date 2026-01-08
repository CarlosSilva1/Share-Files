const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueId = uuidv4();
    const ext = path.extname(file.originalname);
    cb(null, `${uniqueId}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB max file size
  }
});

// Store file metadata in memory (in production, use a database)
const fileMetadata = new Map();

// Serve static files
app.use(express.static('public'));

// Upload endpoint
app.post('/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  const fileId = path.parse(req.file.filename).name;
  const metadata = {
    originalName: req.file.originalname,
    filename: req.file.filename,
    size: req.file.size,
    uploadDate: new Date(),
    downloads: 0
  };

  fileMetadata.set(fileId, metadata);

  const shareUrl = `${req.protocol}://${req.get('host')}/download/${fileId}`;
  
  res.json({
    success: true,
    fileId: fileId,
    shareUrl: shareUrl,
    filename: req.file.originalname,
    size: req.file.size
  });
});

// Download endpoint
app.get('/download/:fileId', (req, res) => {
  const fileId = req.params.fileId;
  const metadata = fileMetadata.get(fileId);

  if (!metadata) {
    return res.status(404).send('File not found or expired');
  }

  const filePath = path.join(uploadsDir, metadata.filename);

  if (!fs.existsSync(filePath)) {
    fileMetadata.delete(fileId);
    return res.status(404).send('File not found');
  }

  metadata.downloads++;
  
  res.download(filePath, metadata.originalName, (err) => {
    if (err) {
      console.error('Download error:', err);
    }
  });
});

// File info endpoint
app.get('/info/:fileId', (req, res) => {
  const fileId = req.params.fileId;
  const metadata = fileMetadata.get(fileId);

  if (!metadata) {
    return res.status(404).json({ error: 'File not found' });
  }

  res.json({
    filename: metadata.originalName,
    size: metadata.size,
    uploadDate: metadata.uploadDate,
    downloads: metadata.downloads
  });
});

// Home page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`File sharing server running on port ${PORT}`);
  console.log(`Access the application at http://localhost:${PORT}`);
});
