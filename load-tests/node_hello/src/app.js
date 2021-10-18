const http = require('http');

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

server.listen(port, () => {
   console.log(`Server running at :${port}/`);
});
