import { createServer } from "node:http";

const port = 5915;
const html = `<!doctype html>
<html lang="ja">
  <head><meta charset="utf-8"><title>yunomi live demo</title></head>
  <body>
    <main>
      <h1>Live review target</h1>
      <p id="summary">Click a real DOM element to pin a comment.</p>
      <button id="deploy" type="button">Deploy preview</button>
    </main>
  </body>
</html>`;

createServer((request, response) => {
  if (request.url === "/" || request.url === "/index.html") {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    response.end(html);
    return;
  }
  response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  response.end("Not found");
}).listen(port, "127.0.0.1", () => {
  console.log(`v3 live demo target at http://127.0.0.1:${port}`);
});
