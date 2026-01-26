# 📤 Share Files

A simple and elegant web application for sharing files that are too large for chat applications.

## Features

- 📁 **Easy Upload**: Drag and drop or click to upload files
- 🔗 **Shareable Links**: Generate unique download links for your files
- 📊 **File Size Support**: Upload files up to 100MB
- 🎨 **Beautiful UI**: Modern and responsive interface
- 🚀 **Fast**: Quick uploads and downloads
- 🔒 **Secure**: Rate limiting protection and security best practices

## Installation

1. Clone the repository:
```bash
git clone https://github.com/CarlosSilva1/Share-Files.git
cd Share-Files
```

2. Install dependencies:
```bash
npm install
```

## Usage

1. Start the server:
```bash
npm start
```

2. Open your browser and navigate to:
```
http://localhost:3000
```

3. Upload a file:
   - Click on the upload area or drag and drop a file
   - Click "Upload File"
   - Share the generated link with others

4. Download a file:
   - Visit the shared link
   - The file will download automatically

## Configuration

You can customize the following settings in `server.js`:

- **Port**: Change `PORT` environment variable (default: 3000)
- **Max File Size**: Modify the `fileSize` limit in the multer configuration (default: 100MB)
- **Upload Directory**: Change the `uploadsDir` path (default: ./uploads)
- **Rate Limiting**: Adjust the `windowMs` and `max` values in the rate limiters:
  - Upload: 10 uploads per 15 minutes per IP
  - Download/Info: 100 requests per 15 minutes per IP

## API Endpoints

### Upload File
```
POST /upload
Content-Type: multipart/form-data

Returns:
{
  "success": true,
  "fileId": "unique-file-id",
  "shareUrl": "http://localhost:3000/download/unique-file-id",
  "filename": "original-filename.ext",
  "size": 12345
}
```

### Download File
```
GET /download/:fileId

Returns the file for download
```

### File Info
```
GET /info/:fileId

Returns:
{
  "filename": "original-filename.ext",
  "size": 12345,
  "uploadDate": "2026-01-08T14:00:00.000Z",
  "downloads": 0
}
```

## Development

To run in development mode:
```bash
npm run dev
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
