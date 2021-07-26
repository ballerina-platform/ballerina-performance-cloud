const http = require('http');

const hostname = '127.0.0.1';
const port = 9090;

const server = http.createServer((req, res) => {
   if (req.url == "/hello") {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/json');
      res.end(`{"msg": "Hello world"}`);
   } else {
      res.writeHead(404);
      res.end(JSON.stringify({ error: "Resource not found" }));
   }
});

server.listen(port, hostname, () => {
   console.log(`Server running at http://${hostname}:${port}/`);
});
