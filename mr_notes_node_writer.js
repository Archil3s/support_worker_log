const http = require('http');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const HOST = '127.0.0.1';
const PORT = 51239;
const ROOT = 'C:\\Users\\Danie\\OneDrive\\Desktop\\MR notes to submit';
const MAX_BODY_BYTES = 150 * 1024 * 1024;

fs.mkdirSync(ROOT, { recursive: true });

function send(res, code, data) {
  const body = JSON.stringify(data);

  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Private-Network': 'true',
    'Cache-Control': 'no-store',
    Connection: 'close',
  });

  res.end(body);
}

function safePath(fileName) {
  if (!fileName || typeof fileName !== 'string') {
    throw new Error('Missing fileName.');
  }

  const cleanParts = fileName
    .replace(/\\/g, '/')
    .split('/')
    .map((part) => part.trim())
    .filter((part) => part && part !== '.' && part !== '..')
    .map((part) => part.replace(/[<>:"|?*\x00-\x1F]/g, '_'));

  if (cleanParts.length === 0) {
    throw new Error('Invalid fileName.');
  }

  const rootPath = path.resolve(ROOT);
  const targetPath = path.resolve(rootPath, ...cleanParts);
  const rootPrefix = rootPath.toLowerCase() + path.sep;
  const lowerTarget = targetPath.toLowerCase();

  if (lowerTarget !== rootPath.toLowerCase() && !lowerTarget.startsWith(rootPrefix)) {
    throw new Error('Unsafe file path blocked.');
  }

  return targetPath;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    let bytes = 0;

    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      bytes += Buffer.byteLength(chunk, 'utf8');
      if (bytes > MAX_BODY_BYTES) {
        reject(new Error('Request body too large.'));
        req.destroy();
        return;
      }
      body += chunk;
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function parseJson(raw) {
  if (!raw || !raw.trim()) return {};

  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error('Invalid JSON body: ' + error.message);
  }
}

function decodeContents(contents) {
  if (typeof contents === 'string' && contents.startsWith('__BASE64__:')) {
    const base64 = contents.substring('__BASE64__:'.length).replace(/\s/g, '');
    const buffer = Buffer.from(base64, 'base64');

    if (buffer.length < 4 || buffer[0] !== 0x50 || buffer[1] !== 0x4B) {
      throw new Error('Base64 data did not decode to a DOCX/ZIP file.');
    }

    return { buffer, mode: 'base64-docx', bytes: buffer.length };
  }

  const text = String(contents ?? '');
  return {
    buffer: Buffer.from(text, 'utf8'),
    mode: 'text',
    bytes: Buffer.byteLength(text, 'utf8'),
  };
}

function isBrokenBase64TextFile(filePath) {
  if (!fs.existsSync(filePath)) return false;

  try {
    const fd = fs.openSync(filePath, 'r');
    const buffer = Buffer.alloc(11);
    const read = fs.readSync(fd, buffer, 0, 11, 0);
    fs.closeSync(fd);
    return read === 11 && buffer.toString('utf8') === '__BASE64__:';
  } catch (_) {
    return false;
  }
}

function writeNote(fileName, contents) {
  const targetPath = safePath(fileName);
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });

  if (fs.existsSync(targetPath) && isBrokenBase64TextFile(targetPath)) {
    fs.renameSync(targetPath, targetPath + '.broken-base64-' + Date.now());
  }

  const decoded = decodeContents(contents);
  fs.writeFileSync(targetPath, decoded.buffer);

  return {
    path: targetPath,
    created: true,
    preserved: false,
    updated: true,
    mode: decoded.mode,
    bytes: decoded.bytes,
  };
}

function renameNote(oldFileName, newFileName, contents) {
  const newPath = safePath(newFileName);
  const oldPath = oldFileName ? safePath(oldFileName) : '';

  fs.mkdirSync(path.dirname(newPath), { recursive: true });
  const decoded = decodeContents(contents);
  fs.writeFileSync(newPath, decoded.buffer);

  if (
    oldPath &&
    oldPath.toLowerCase() !== newPath.toLowerCase() &&
    fs.existsSync(oldPath)
  ) {
    fs.unlinkSync(oldPath);
  }

  return {
    path: newPath,
    oldPath,
    renamed: Boolean(oldPath && oldPath !== newPath),
    preserved: false,
    updated: true,
    mode: decoded.mode,
    bytes: decoded.bytes,
  };
}

function readNote(fileName) {
  const targetPath = safePath(fileName);

  if (!fs.existsSync(targetPath)) {
    throw new Error('File does not exist: ' + targetPath);
  }

  const stat = fs.statSync(targetPath);
  const buffer = fs.readFileSync(targetPath);
  if (buffer.length < 4 || buffer[0] !== 0x50 || buffer[1] !== 0x4B) {
    throw new Error('Local note is not a valid Word DOCX file.');
  }

  return {
    path: targetPath,
    contentsBase64: buffer.toString('base64'),
    modifiedAt: stat.mtime.toISOString(),
    bytes: buffer.length,
  };
}

function openNote(fileName) {
  const targetPath = safePath(fileName);
  if (!fs.existsSync(targetPath)) {
    throw new Error('File does not exist: ' + targetPath);
  }

  childProcess.execFile('cmd', ['/c', 'start', '', targetPath], {
    windowsHide: true,
  });
  return { path: targetPath, opened: true };
}

function openFolder(fileName) {
  const targetPath = safePath(fileName);
  if (!fs.existsSync(targetPath)) {
    throw new Error('File does not exist: ' + targetPath);
  }

  const folderPath = path.dirname(targetPath);
  childProcess.execFile('cmd', ['/c', 'start', '', folderPath], {
    windowsHide: true,
  });
  return { path: folderPath, opened: true };
}

const server = http.createServer(async (req, res) => {
  try {
    const route = new URL(req.url, `http://${HOST}:${PORT}`).pathname;

    if (req.method === 'OPTIONS') {
      send(res, 200, { ok: true });
      return;
    }

    if (route === '/ping') {
      send(res, 200, {
        ok: true,
        service: 'mr_notes_node_writer',
        version: '2026-07-24-document-read-v1',
        root: ROOT,
        mode: 'base64-docx-read-write',
        time: new Date().toISOString(),
      });
      return;
    }

    if (req.method !== 'POST') {
      send(res, 405, { ok: false, error: 'POST only.' });
      return;
    }

    const data = parseJson(await readBody(req));
    const handlers = {
      '/write-note': () => writeNote(data.fileName, data.contents),
      '/rename-note': () =>
        renameNote(data.oldFileName, data.newFileName, data.contents),
      '/read-note': () => readNote(data.fileName),
      '/open-note': () => openNote(data.fileName),
      '/open-folder': () => openFolder(data.fileName),
    };
    const handler = handlers[route];

    if (!handler) {
      send(res, 404, { ok: false, error: 'Unknown route: ' + route });
      return;
    }

    send(res, 200, { ok: true, ...handler() });
  } catch (error) {
    send(res, 500, {
      ok: false,
      error: error && error.message ? error.message : String(error),
    });
  }
});

server.listen(PORT, HOST, () => {
  console.log('MR Notes writer running on http://' + HOST + ':' + PORT);
  console.log('Root: ' + ROOT);
  console.log('Mode: base64-docx-read-write');
});
