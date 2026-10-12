import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath, URL } from 'node:url';

const root = fileURLToPath(new URL('./dist', import.meta.url));
const contentTypes = { '.css': 'text/css', '.js': 'text/javascript', '.html': 'text/html' };

const server = createServer(async (request, response) => {
  const requestPath = request.url === '/' ? '/index.html' : request.url.split('?')[0];
  const filePath = normalize(join(root, requestPath));
  const safePath = filePath.startsWith(root) ? filePath : join(root, 'index.html');

  try {
    const body = await readFile(safePath);
    response.writeHead(200, { 'Content-Type': contentTypes[extname(safePath)] ?? 'text/plain' });
    response.end(body);
  } catch {
    const body = await readFile(join(root, 'index.html'));
    response.writeHead(200, { 'Content-Type': 'text/html' });
    response.end(body);
  }
});

server.listen(5173, '0.0.0.0');
