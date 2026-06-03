const fs = require('fs');
const https = require('https');
const http = require('http');
const path = require('path');

const PORT = Number(process.env.SUPPORT_WORKER_WEB_PORT || 51243);
const ROOT = path.resolve(__dirname, 'build', 'web');
const SERVER_VERSION = '2026-06-02-drive-proxy-v1';

const TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

function send(res, code, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(code, {
    'Access-Control-Allow-Headers': 'Content-Type, X-Requested-With',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Private-Network': 'true',
    'Cache-Control': 'no-store',
    'Content-Type': type,
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';

    req.on('data', (chunk) => {
      body += chunk;

      if (body.length > 25 * 1024 * 1024) {
        reject(new Error('Request body is too large.'));
        req.destroy();
      }
    });

    req.on('end', () => {
      try {
        resolve(body);
      } catch (error) {
        reject(error);
      }
    });

    req.on('error', reject);
  });
}
async function readPayload(req) {
  const body = await readBody(req);
  const contentType = String(req.headers['content-type'] || '').toLowerCase();

  if (contentType.includes('application/x-www-form-urlencoded')) {
    const params = new URLSearchParams(body);
    const eventText = params.get('event') || '{}';

    return {
      accessToken: params.get('accessToken') || '',
      event: JSON.parse(eventText),
      wantsRedirect: true,
    };
  }

  const parsed = body.trim() ? JSON.parse(body) : {};

  return {
    accessToken: parsed.accessToken || '',
    event: parsed.event || {},
    wantsRedirect: false,
  };
}

function sendCalendarRedirect(res, created) {
  const link = typeof created.htmlLink === 'string' && created.htmlLink
    ? created.htmlLink
    : 'https://calendar.google.com/calendar/u/0/r';

  const escapedLink = link.replace(/&/g, '&amp;').replace(/"/g, '&quot;');

  send(
    res,
    200,
    `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=${escapedLink}"><title>Opening Google Calendar</title></head><body><p>Calendar event created. <a href="${escapedLink}">Open Google Calendar</a>.</p><script>location.replace(${JSON.stringify(link)});</script></body></html>`,
    'text/html; charset=utf-8',
  );
}

function postGoogleCalendarEvent(accessToken, event) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(event);

    const request = https.request(
      {
        hostname: 'www.googleapis.com',
        path: '/calendar/v3/calendars/primary/events',
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (response) => {
        let responseBody = '';

        response.on('data', (chunk) => {
          responseBody += chunk;
        });

        response.on('end', () => {
          const status = response.statusCode || 0;

          if (status < 200 || status >= 300) {
            reject(
              new Error(
                responseBody.trim() ||
                  `Google Calendar returned HTTP ${status}.`,
              ),
            );
            return;
          }

          try {
            resolve(JSON.parse(responseBody));
          } catch (error) {
            reject(new Error('Google Calendar returned invalid JSON.'));
          }
        });
      },
    );

    request.on('error', reject);
    request.write(body);
    request.end();
  });
}

function listGoogleCalendarEvents(accessToken, timeMin, timeMax) {
  return new Promise((resolve, reject) => {
    if (!accessToken) {
      reject(new Error('Missing Google access token.'));
      return;
    }

    const params = new URLSearchParams({
      singleEvents: 'true',
      orderBy: 'startTime',
      timeMin,
      timeMax,
    });

    const request = https.request(
      {
        hostname: 'www.googleapis.com',
        path: `/calendar/v3/calendars/primary/events?${params.toString()}`,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
      (response) => {
        let responseBody = '';

        response.on('data', (chunk) => {
          responseBody += chunk;
        });

        response.on('end', () => {
          const status = response.statusCode || 0;

          if (status < 200 || status >= 300) {
            reject(
              new Error(
                responseBody.trim() ||
                  `Google Calendar returned HTTP ${status}.`,
              ),
            );
            return;
          }

          try {
            resolve(JSON.parse(responseBody));
          } catch (error) {
            reject(new Error('Google Calendar returned invalid JSON.'));
          }
        });
      },
    );

    request.on('error', (error) => {
      reject(
        new Error(
          error && error.message
            ? `Could not reach Google Calendar: ${error.message}`
            : 'Could not reach Google Calendar.',
        ),
      );
    });
    request.end();
  });
}

function googleDriveJsonRequest({ accessToken, method, path: requestPath, body }) {
  return new Promise((resolve, reject) => {
    if (!accessToken) {
      reject(new Error('Missing Google access token.'));
      return;
    }

    const bodyText = body == null ? '' : JSON.stringify(body);

    const request = https.request(
      {
        hostname: 'www.googleapis.com',
        path: requestPath,
        method,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json; charset=utf-8',
          ...(bodyText
            ? { 'Content-Length': Buffer.byteLength(bodyText) }
            : {}),
        },
      },
      (response) => {
        let responseBody = '';

        response.on('data', (chunk) => {
          responseBody += chunk;
        });

        response.on('end', () => {
          const status = response.statusCode || 0;

          if (status < 200 || status >= 300) {
            reject(
              new Error(
                responseBody.trim() || `Google Drive returned HTTP ${status}.`,
              ),
            );
            return;
          }

          try {
            resolve(JSON.parse(responseBody));
          } catch (error) {
            reject(new Error('Google Drive returned invalid JSON.'));
          }
        });
      },
    );

    request.on('error', (error) => {
      reject(
        new Error(
          error && error.message
            ? `Could not reach Google Drive: ${error.message}`
            : 'Could not reach Google Drive.',
        ),
      );
    });

    if (bodyText) request.write(bodyText);
    request.end();
  });
}

function googleDriveMultipartRequest({
  accessToken,
  method,
  path: requestPath,
  metadata,
  bytesBase64,
  contentMimeType,
}) {
  return new Promise((resolve, reject) => {
    if (!accessToken) {
      reject(new Error('Missing Google access token.'));
      return;
    }

    const boundary = `support_worker_log_${Date.now()}`;
    const fileBytes = Buffer.from(String(bytesBase64 || ''), 'base64');
    const head = Buffer.from(
      `--${boundary}\r\n` +
        'Content-Type: application/json; charset=utf-8\r\n\r\n' +
        `${JSON.stringify(metadata)}\r\n` +
        `--${boundary}\r\n` +
        `Content-Type: ${contentMimeType}\r\n\r\n`,
      'utf8',
    );
    const tail = Buffer.from(`\r\n--${boundary}--`, 'utf8');
    const body = Buffer.concat([head, fileBytes, tail]);

    const request = https.request(
      {
        hostname: 'www.googleapis.com',
        path: requestPath,
        method,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': `multipart/related; boundary=${boundary}`,
          'Content-Length': body.length,
        },
      },
      (response) => {
        let responseBody = '';

        response.on('data', (chunk) => {
          responseBody += chunk;
        });

        response.on('end', () => {
          const status = response.statusCode || 0;

          if (status < 200 || status >= 300) {
            reject(
              new Error(
                responseBody.trim() || `Google Drive returned HTTP ${status}.`,
              ),
            );
            return;
          }

          try {
            resolve(JSON.parse(responseBody));
          } catch (error) {
            reject(new Error('Google Drive returned invalid JSON.'));
          }
        });
      },
    );

    request.on('error', (error) => {
      reject(
        new Error(
          error && error.message
            ? `Could not reach Google Drive: ${error.message}`
            : 'Could not reach Google Drive.',
        ),
      );
    });

    request.write(body);
    request.end();
  });
}

async function readJsonBody(req) {
  const body = await readBody(req);
  return body.trim() ? JSON.parse(body) : {};
}

async function createGoogleDriveFolder(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const name = String(payload.name || '').trim();
    const parentId = String(payload.parentId || '').trim();

    if (!name) {
      send(res, 400, 'Missing folder name.');
      return;
    }

    const created = await googleDriveJsonRequest({
      accessToken: String(payload.accessToken || ''),
      method: 'POST',
      path: '/drive/v3/files?fields=id,name,mimeType,webViewLink',
      body: {
        name,
        mimeType: 'application/vnd.google-apps.folder',
        ...(parentId ? { parents: [parentId] } : {}),
      },
    });

    send(res, 200, JSON.stringify(created), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message ? error.message : 'Google Drive folder creation failed.',
    );
  }
}

async function listGoogleDriveChildren(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const parentId = String(payload.parentId || '').trim();

    if (!parentId) {
      send(res, 400, 'Missing parent folder id.');
      return;
    }

    const params = new URLSearchParams({
      fields: 'files(id,name,mimeType,webViewLink)',
      orderBy: 'folder,name',
      q: `'${parentId.replace(/'/g, "\\'")}' in parents and trashed = false`,
    });
    const listed = await googleDriveJsonRequest({
      accessToken: String(payload.accessToken || ''),
      method: 'GET',
      path: `/drive/v3/files?${params.toString()}`,
    });

    send(res, 200, JSON.stringify(listed), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message ? error.message : 'Google Drive file listing failed.',
    );
  }
}

async function uploadGoogleDriveFile(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const name = String(payload.name || '').trim();
    const mimeType = String(payload.mimeType || '').trim();
    const parentId = String(payload.parentId || '').trim();
    const contentMimeType = String(payload.contentMimeType || mimeType).trim();

    if (!name || !mimeType || !parentId || !contentMimeType) {
      send(res, 400, 'Missing Drive upload details.');
      return;
    }

    const uploaded = await googleDriveMultipartRequest({
      accessToken: String(payload.accessToken || ''),
      method: 'POST',
      path: '/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink',
      metadata: { name, mimeType, parents: [parentId] },
      bytesBase64: String(payload.bytesBase64 || ''),
      contentMimeType,
    });

    send(res, 200, JSON.stringify(uploaded), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message ? error.message : 'Google Drive upload failed.',
    );
  }
}

async function updateGoogleDriveFile(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const fileId = String(payload.fileId || '').trim();
    const name = String(payload.name || '').trim();
    const mimeType = String(payload.mimeType || '').trim();
    const contentMimeType = String(payload.contentMimeType || mimeType).trim();

    if (!fileId || !name || !mimeType || !contentMimeType) {
      send(res, 400, 'Missing Drive update details.');
      return;
    }

    const updated = await googleDriveMultipartRequest({
      accessToken: String(payload.accessToken || ''),
      method: 'PATCH',
      path: `/upload/drive/v3/files/${encodeURIComponent(fileId)}?uploadType=multipart&fields=id,name,mimeType,webViewLink`,
      metadata: { name, mimeType },
      bytesBase64: String(payload.bytesBase64 || ''),
      contentMimeType,
    });

    send(res, 200, JSON.stringify(updated), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message ? error.message : 'Google Drive file update failed.',
    );
  }
}

async function moveGoogleDriveFile(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readJsonBody(req);
    const fileId = String(payload.fileId || '').trim();
    const fromParentId = String(payload.fromParentId || '').trim();
    const toParentId = String(payload.toParentId || '').trim();

    if (!fileId || !fromParentId || !toParentId) {
      send(res, 400, 'Missing Drive move details.');
      return;
    }

    const params = new URLSearchParams({
      addParents: toParentId,
      removeParents: fromParentId,
      fields: 'id,name,mimeType,webViewLink',
    });
    const moved = await googleDriveJsonRequest({
      accessToken: String(payload.accessToken || ''),
      method: 'PATCH',
      path: `/drive/v3/files/${encodeURIComponent(fileId)}?${params.toString()}`,
      body: {},
    });

    send(res, 200, JSON.stringify(moved), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message ? error.message : 'Google Drive file move failed.',
    );
  }
}

async function createPrivateCalendarEvent(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const payload = await readPayload(req);
    const accessToken = String(payload.accessToken || '');
    const event = payload.event || {};

    if (!accessToken) {
      send(res, 400, 'Missing Google access token.');
      return;
    }

    event.transparency = 'opaque';

    const created = await postGoogleCalendarEvent(accessToken, event);

    if (payload.wantsRedirect) {
      sendCalendarRedirect(res, created);
      return;
    }

    send(res, 200, JSON.stringify(created), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message
        ? error.message
        : 'Google Calendar event creation failed.',
    );
  }
}

async function listPrivateCalendarEvents(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method !== 'POST') {
    send(res, 405, 'Method not allowed');
    return;
  }

  try {
    const body = await readBody(req);
    const payload = body.trim() ? JSON.parse(body) : {};
    const accessToken = String(payload.accessToken || '');
    const timeMin = String(payload.timeMin || '');
    const timeMax = String(payload.timeMax || '');

    if (!accessToken) {
      send(res, 400, 'Missing Google access token.');
      return;
    }

    if (!timeMin || !timeMax) {
      send(res, 400, 'Missing calendar date range.');
      return;
    }

    const events = await listGoogleCalendarEvents(accessToken, timeMin, timeMax);

    send(res, 200, JSON.stringify(events), 'application/json; charset=utf-8');
  } catch (error) {
    send(
      res,
      502,
      error && error.message
        ? error.message
        : 'Google Calendar events fetch failed.',
    );
  }
}

function filePathFor(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0]);
  const clean = decoded === '/' ? '/index.html' : decoded;
  const target = path.resolve(ROOT, clean.replace(/^\/+/, ''));

  if (!target.toLowerCase().startsWith(ROOT.toLowerCase())) {
    return null;
  }

  return target;
}

function handleRequest(req, res) {
  if (req.url === '/__health') {
    send(
      res,
      200,
      JSON.stringify({ ok: true, version: SERVER_VERSION }),
      'application/json; charset=utf-8',
    );
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_calendar/private_event') {
    createPrivateCalendarEvent(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_calendar/events') {
    listPrivateCalendarEvents(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_drive/create_folder') {
    createGoogleDriveFolder(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_drive/list_children') {
    listGoogleDriveChildren(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_drive/upload_file') {
    uploadGoogleDriveFile(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_drive/update_file') {
    updateGoogleDriveFile(req, res);
    return;
  }

  if ((req.url || '').split('?')[0] === '/__google_drive/move_file') {
    moveGoogleDriveFile(req, res);
    return;
  }

  const target = filePathFor(req.url || '/');

  if (!target) {
    send(res, 403, 'Blocked');
    return;
  }

  const resolved = fs.existsSync(target) && fs.statSync(target).isFile()
    ? target
    : path.join(ROOT, 'index.html');

  fs.readFile(resolved, (error, data) => {
    if (error) {
      send(res, 404, 'Not found');
      return;
    }

    const type = TYPES[path.extname(resolved).toLowerCase()] ||
      'application/octet-stream';

    res.writeHead(200, {
      'Cache-Control': 'no-store',
      'Content-Type': type,
    });
    res.end(data);
  });
}

function listen(host) {
  const server = http.createServer(handleRequest);

  server.on('error', (error) => {
    if (error && error.code === 'EADDRINUSE') return;
    console.error(
      `Support Worker Log desktop server failed on ${host}:${PORT}:`,
      error,
    );
  });

  server.listen(PORT, host, () => {
    console.log(`Support Worker Log desktop server: http://${host}:${PORT}`);
    console.log(`Serving: ${ROOT}`);
  });
}

listen(process.env.SUPPORT_WORKER_WEB_HOST || 'localhost');
listen('127.0.0.1');
