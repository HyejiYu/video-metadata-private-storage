const express = require("express");
const app = express();
const port = 3000;

app.get("/", (req, res) => {
	res.send("Hello, This is a Web Server made by Node.js!!!");
})

app.listen(port, () => {
	console.log(`Server is running in the "http://localhost:${port}`);
})