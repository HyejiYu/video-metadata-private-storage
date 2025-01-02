// app.js
const http = require("http");
const createServer = http.createServer((req, res) => {
	res.writeHead(200, { "Content-Type": "text/html" });
	res.end("Hello World!");
});

createServer.listen(3000, () => {
	console.log("Server Started!");
});
